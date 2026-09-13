#!/usr/bin/env bash
set -Eeuo pipefail

UI="${1:-}"
case "$UI" in console|phosh) ;; *) echo "invalid UI" >&2; exit 2 ;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/device.env"

PMAPORTS_REF_EFFECTIVE="${PMAPORTS_REF_OVERRIDE:-${PMAPORTS_REF:-main}}"
PMBOOTSTRAP_REF_EFFECTIVE="${PMBOOTSTRAP_REF_OVERRIDE:-${PMBOOTSTRAP_REF:-}}"
RUNNER_TMP="${RUNNER_TEMP:-/tmp}"
PMB_SRC="$RUNNER_TMP/pmbootstrap-src"
PMAPORTS_SRC="$RUNNER_TMP/pmaports-src"
WORK_DIR="$RUNNER_TMP/pmbootstrap-work"
CONFIG_FILE="$RUNNER_TMP/pmbootstrap_v3.cfg"
DIST_DIR="$ROOT/dist"
EXPORT_DIR="$DIST_DIR/export"

rm -rf "$PMB_SRC" "$PMAPORTS_SRC" "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR/cache_git" "$WORK_DIR/config" "$EXPORT_DIR/standard"

git clone --filter=blob:none --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$PMB_SRC"
if [[ -n "$PMBOOTSTRAP_REF_EFFECTIVE" ]]; then
  git -C "$PMB_SRC" fetch --force --depth=1 origin "$PMBOOTSTRAP_REF_EFFECTIVE"
  git -C "$PMB_SRC" checkout --detach FETCH_HEAD
fi

git clone --filter=blob:none --depth=1 --branch main https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$PMAPORTS_SRC"
if [[ "$PMAPORTS_REF_EFFECTIVE" != "main" ]]; then
  git -C "$PMAPORTS_SRC" fetch --force --depth=1 origin "$PMAPORTS_REF_EFFECTIVE"
  git -C "$PMAPORTS_SRC" checkout --detach FETCH_HEAD
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$PMB_SRC/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
export PATH="$HOME/.local/bin:$PATH"
echo 8 > "$WORK_DIR/version"

cat > "$CONFIG_FILE" <<EOF_CFG
[pmbootstrap]
channel = ${CHANNEL:-edge}
device = $DEVICE
ui = $UI
kernel = ${KERNEL_CHOICE:-mainline}
locale = ${LOCALE:-en_US.UTF-8}
timezone = ${TIMEZONE:-GMT}
user = ${USER_NAME:-user}
ssh_keys = false
extra_packages = none
extra_space = ${EXTRA_SPACE:-0}
boot_size = ${BOOT_SIZE:-512}
ccache_size = ${CCACHE_SIZE:-2G}
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
if [[ "${KCONFIG_CHECK:-true}" == true ]]; then
  "${PMB[@]}" kconfig check --arch "$ARCH" "$KERNEL_PACKAGE"
fi
if [[ -n "${FIRMWARE_PACKAGES:-}" ]]; then
  # shellcheck disable=SC2086
  "${PMB[@]}" build --force $FIRMWARE_PACKAGES
fi
"${PMB[@]}" build "$KERNEL_PACKAGE"
"${PMB[@]}" build "$DEVICE_PACKAGE"
"${PMB[@]}" install --password=pmos-ci-test
"${PMB[@]}" export "$EXPORT_DIR/standard"
if [[ "${EXPORT_ODIN:-false}" == true ]]; then
  mkdir -p "$EXPORT_DIR/odin"
  "${PMB[@]}" export --odin "$EXPORT_DIR/odin"
fi

PMAPORTS_SHA="$(git -C "$PMAPORTS_SRC" rev-parse HEAD)"
PMBOOTSTRAP_SHA="$(git -C "$PMB_SRC" rev-parse HEAD)"
cat > "$EXPORT_DIR/BUILD-INFO.txt" <<EOF_INFO
device=$DEVICE
ui=$UI
pmaports_sha=$PMAPORTS_SHA
pmbootstrap_sha=$PMBOOTSTRAP_SHA
repository_sha=${GITHUB_SHA:-local}
EOF_INFO
(cd "$EXPORT_DIR" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
