#!/usr/bin/env bash
set -Eeuo pipefail

UI="${1:-}"
case "$UI" in
  console|phosh) ;;
  *) echo "ERROR: UI must be 'console' or 'phosh'" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_CONFIG="$ROOT/config/device.env"

if [[ ! -f "$DEVICE_CONFIG" ]]; then
  echo "ERROR: $DEVICE_CONFIG is missing." >&2
  echo "Run this workflow from a device/<codename> branch." >&2
  exit 3
fi

# shellcheck disable=SC1090
source "$DEVICE_CONFIG"

required_vars=(DEVICE DEVICE_PACKAGE KERNEL_PACKAGE ARCH CHANNEL)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is not set in config/device.env" >&2
    exit 4
  fi
done

if [[ -n "${GITHUB_REF_NAME:-}" && "$GITHUB_REF_NAME" != device/* ]]; then
  echo "ERROR: builds are allowed only from device/* branches (current: $GITHUB_REF_NAME)." >&2
  exit 5
fi

if [[ -z "${PMOS_PASSWORD:-}" ]]; then
  echo "ERROR: repository secret PMOS_PASSWORD is required." >&2
  exit 6
fi

PMAPORTS_REF_EFFECTIVE="${PMAPORTS_REF_OVERRIDE:-${PMAPORTS_REF:-main}}"
PMBOOTSTRAP_REF_EFFECTIVE="${PMBOOTSTRAP_REF_OVERRIDE:-${PMBOOTSTRAP_REF:-}}"
KERNEL_CHOICE="${KERNEL_CHOICE:-mainline}"
FIRMWARE_PACKAGES="${FIRMWARE_PACKAGES:-}"
USER_NAME="${USER_NAME:-user}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-GMT}"
BOOT_SIZE="${BOOT_SIZE:-512}"
EXTRA_SPACE="${EXTRA_SPACE:-0}"
CCACHE_SIZE="${CCACHE_SIZE:-2G}"
EXPORT_ODIN="${EXPORT_ODIN:-false}"
KCONFIG_CHECK="${KCONFIG_CHECK:-true}"
USB_NETWORK_FUNCTION="${PMOS_USB_NETWORK_FUNCTION:-}"

RUNNER_TMP="${RUNNER_TEMP:-/tmp}"
PMB_SRC="$RUNNER_TMP/pmbootstrap-src"
PMAPORTS_SRC="$RUNNER_TMP/pmaports-src"
WORK_DIR="$RUNNER_TMP/pmbootstrap-work"
CONFIG_FILE="$RUNNER_TMP/pmbootstrap_v3.cfg"
DIST_DIR="$ROOT/dist"
EXPORT_DIR="$DIST_DIR/export"
GOFILE_DIR="$DIST_DIR/gofile"

rm -rf "$PMB_SRC" "$PMAPORTS_SRC" "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR/cache_git" "$WORK_DIR/config" "$EXPORT_DIR/standard" "$GOFILE_DIR"

clone_at_ref() {
  local url="$1" dest="$2" ref="$3"
  git clone --filter=blob:none --depth=1 --no-checkout "$url" "$dest"
  if [[ -n "$ref" ]]; then
    git -C "$dest" fetch --force --depth=1 origin "$ref"
    git -C "$dest" checkout --detach FETCH_HEAD
  else
    git -C "$dest" checkout --detach origin/HEAD
  fi
}

echo "==> Fetch pmbootstrap"
clone_at_ref \
  "https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git" \
  "$PMB_SRC" \
  "$PMBOOTSTRAP_REF_EFFECTIVE"

echo "==> Fetch pmaports @ $PMAPORTS_REF_EFFECTIVE"
clone_at_ref \
  "https://gitlab.postmarketos.org/postmarketOS/pmaports.git" \
  "$PMAPORTS_SRC" \
  "$PMAPORTS_REF_EFFECTIVE"

if [[ -n "$USB_NETWORK_FUNCTION" ]]; then
  case "$USB_NETWORK_FUNCTION" in
    ncm.usb0|rndis.usb0|ecm.usb0) ;;
    *)
      echo "ERROR: unsupported PMOS_USB_NETWORK_FUNCTION: $USB_NETWORK_FUNCTION" >&2
      exit 8
      ;;
  esac

  mapfile -t DEVICEINFO_FILES < <(
    find "$PMAPORTS_SRC/device" -type f -path "*/$DEVICE_PACKAGE/deviceinfo" -print
  )

  if (( ${#DEVICEINFO_FILES[@]} != 1 )); then
    echo "ERROR: expected exactly one deviceinfo for $DEVICE_PACKAGE, found ${#DEVICEINFO_FILES[@]}" >&2
    printf '  %s\n' "${DEVICEINFO_FILES[@]}" >&2
    exit 8
  fi

  DEVICEINFO_FILE="${DEVICEINFO_FILES[0]}"
  echo "==> Override USB network function: $USB_NETWORK_FUNCTION"

  if grep -q '^deviceinfo_usb_network_function=' "$DEVICEINFO_FILE"; then
    sed -i "s|^deviceinfo_usb_network_function=.*|deviceinfo_usb_network_function=\"$USB_NETWORK_FUNCTION\"|" "$DEVICEINFO_FILE"
  else
    printf '\ndeviceinfo_usb_network_function="%s"\n' "$USB_NETWORK_FUNCTION" >> "$DEVICEINFO_FILE"
  fi

  grep '^deviceinfo_usb_network_function=' "$DEVICEINFO_FILE"
fi

PMBOOTSTRAP_SHA="$(git -C "$PMB_SRC" rev-parse HEAD)"
PMAPORTS_SHA="$(git -C "$PMAPORTS_SRC" rev-parse HEAD)"

mkdir -p "$HOME/.local/bin"
ln -sf "$PMB_SRC/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
export PATH="$HOME/.local/bin:$PATH"

# pmbootstrap currently uses work directory format 8. Keeping the marker here
# mirrors a normal initialized workdir while the rest of the configuration is
# generated non-interactively for CI.
echo "8" > "$WORK_DIR/version"

cat > "$CONFIG_FILE" <<EOF_CFG
[pmbootstrap]
channel = $CHANNEL
device = $DEVICE
ui = $UI
kernel = $KERNEL_CHOICE
locale = $LOCALE
timezone = $TIMEZONE
user = $USER_NAME
ssh_keys = false
extra_packages = none
extra_space = $EXTRA_SPACE
boot_size = $BOOT_SIZE
ccache_size = $CCACHE_SIZE
build_pkgs_on_install = true
sudo_timer = false
ui_extras = false
hostname =
keymap =
is_default_channel = false

[mirrors]

[providers]
EOF_CFG

PMB=(pmbootstrap --details-to-stdout -t 3600 -c "$CONFIG_FILE" -p "$PMAPORTS_SRC" -w "$WORK_DIR")

pmbootstrap --version
"${PMB[@]}" status

if [[ "$KCONFIG_CHECK" == "true" ]]; then
  echo "==> Check kernel config: $KERNEL_PACKAGE"
  "${PMB[@]}" kconfig check --arch "$ARCH" "$KERNEL_PACKAGE"
fi

if [[ -n "$FIRMWARE_PACKAGES" ]]; then
  echo "==> Build firmware packages"
  # Intentional word splitting: the config supports a space-separated package list.
  # shellcheck disable=SC2086
  "${PMB[@]}" build --force $FIRMWARE_PACKAGES
fi

echo "==> Build kernel: $KERNEL_PACKAGE"
"${PMB[@]}" build "$KERNEL_PACKAGE"

echo "==> Build device package: $DEVICE_PACKAGE"
"${PMB[@]}" build "$DEVICE_PACKAGE"

echo "==> Install postmarketOS ($UI)"
"${PMB[@]}" install --password="$PMOS_PASSWORD"

echo "==> Export standard images"
"${PMB[@]}" export "$EXPORT_DIR/standard"

if [[ "$EXPORT_ODIN" == "true" ]]; then
  echo "==> Export Odin package"
  mkdir -p "$EXPORT_DIR/odin"
  "${PMB[@]}" export --odin "$EXPORT_DIR/odin"
fi

BUILD_TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
REPO_SHA="${GITHUB_SHA:-local}"
REPO_REF="${GITHUB_REF_NAME:-local}"
RUN_ID="${GITHUB_RUN_ID:-local}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"

cat > "$EXPORT_DIR/BUILD-INFO.txt" <<EOF_INFO
build_timestamp=$BUILD_TIMESTAMP
repository_ref=$REPO_REF
repository_sha=$REPO_SHA
github_run_id=$RUN_ID
github_run_attempt=$RUN_ATTEMPT
device=$DEVICE
ui=$UI
arch=$ARCH
channel=$CHANNEL
device_package=$DEVICE_PACKAGE
kernel_package=$KERNEL_PACKAGE
kernel_choice=$KERNEL_CHOICE
firmware_packages=$FIRMWARE_PACKAGES
pmaports_ref_requested=$PMAPORTS_REF_EFFECTIVE
pmaports_sha=$PMAPORTS_SHA
pmbootstrap_ref_requested=${PMBOOTSTRAP_REF_EFFECTIVE:-default}
pmbootstrap_sha=$PMBOOTSTRAP_SHA
export_odin=$EXPORT_ODIN
usb_network_function=${USB_NETWORK_FUNCTION:-device-default}
EOF_INFO

(
  cd "$EXPORT_DIR"
  # pmbootstrap export may create symlinks to files in the work directory.
  # Follow them so exported images are included in the checksum manifest.
  find -L . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
)

SHORT_SHA="${REPO_SHA:0:12}"
if [[ "$SHORT_SHA" == "local" ]]; then
  SHORT_SHA="local"
fi
ARCHIVE="pmos-${DEVICE}-${UI}-${SHORT_SHA}.tar.zst"

echo "==> Create distribution archive: $ARCHIVE"
# Dereference pmbootstrap export symlinks so the downloaded archive contains
# the actual image bytes rather than links into the ephemeral CI workdir.
tar --dereference -C "$DIST_DIR" -cf - export | zstd -T0 -8 -o "$GOFILE_DIR/$ARCHIVE"
(
  cd "$GOFILE_DIR"
  sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
)

# Gofile uploads only top-level files. Stage the actual exported images there,
# flattening nested paths (for example dtbs/foo.dtb -> dtbs__foo.dtb).
echo "==> Stage exported build files for Gofile"
STANDARD_EXPORT_COUNT=0
while IFS= read -r -d '' file; do
  rel="${file#"$EXPORT_DIR/standard/"}"
  flat_name="${rel//\//__}"
  cp -fL -- "$file" "$GOFILE_DIR/$flat_name"
  STANDARD_EXPORT_COUNT=$((STANDARD_EXPORT_COUNT + 1))
done < <(find -L "$EXPORT_DIR/standard" -type f -print0 | sort -z)

if (( STANDARD_EXPORT_COUNT == 0 )); then
  echo "ERROR: pmbootstrap export produced no resolvable files in $EXPORT_DIR/standard" >&2
  exit 7
fi

if [[ -d "$EXPORT_DIR/odin" ]]; then
  while IFS= read -r -d '' file; do
    rel="${file#"$EXPORT_DIR/odin/"}"
    flat_name="odin__${rel//\//__}"
    cp -fL -- "$file" "$GOFILE_DIR/$flat_name"
  done < <(find -L "$EXPORT_DIR/odin" -type f -print0 | sort -z)
fi

cp -f -- "$EXPORT_DIR/BUILD-INFO.txt" "$EXPORT_DIR/SHA256SUMS" "$GOFILE_DIR/"

echo "==> Gofile staging manifest"
find "$GOFILE_DIR" -maxdepth 1 -type f -printf '%f\t%s bytes\n' | sort

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "PMOS_DEVICE=$DEVICE"
    echo "PMOS_UI=$UI"
    echo "PMOS_ARCHIVE=$ARCHIVE"
    echo "PMOS_PMAPORTS_SHA=$PMAPORTS_SHA"
    echo "PMOS_PMBOOTSTRAP_SHA=$PMBOOTSTRAP_SHA"
  } >> "$GITHUB_ENV"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## postmarketOS build"
    echo
    echo "- Device: \`$DEVICE\`"
    echo "- UI: \`$UI\`"
    echo "- Kernel: \`$KERNEL_PACKAGE\`"
    echo "- pmaports: \`$PMAPORTS_SHA\`"
    echo "- pmbootstrap: \`$PMBOOTSTRAP_SHA\`"
    echo "- Archive: \`$ARCHIVE\`"
    echo "- USB network: \`${USB_NETWORK_FUNCTION:-device-default}\`"
    echo "- Gofile staged export files: \`$STANDARD_EXPORT_COUNT\`"
  } >> "$GITHUB_STEP_SUMMARY"
fi

echo "Build completed: $DIST_DIR"
