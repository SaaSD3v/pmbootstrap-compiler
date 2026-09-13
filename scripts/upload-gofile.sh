#!/usr/bin/env bash
set -Eeuo pipefail

UPLOAD_DIR="${1:-}"
if [[ -z "$UPLOAD_DIR" || ! -d "$UPLOAD_DIR" ]]; then
  echo "ERROR: usage: $0 <directory>" >&2
  exit 2
fi

if [[ -z "${GOFILE_API_KEY:-}" ]]; then
  echo "ERROR: repository secret GOFILE_API_KEY is required." >&2
  exit 3
fi

mapfile -d '' FILES < <(find "$UPLOAD_DIR" -maxdepth 1 -type f -print0 | sort -z)
if (( ${#FILES[@]} == 0 )); then
  echo "ERROR: no files found in $UPLOAD_DIR" >&2
  exit 4
fi

AUTH=( -H "Authorization: Bearer $GOFILE_API_KEY" )
CURL=( curl --silent --show-error --fail-with-body --retry 5 --retry-delay 2 --retry-all-errors )

expect_ok() {
  local response="$1" context="$2"
  if ! jq -e '.status == "ok"' >/dev/null <<<"$response"; then
    echo "ERROR: Gofile $context failed" >&2
    jq . <<<"$response" >&2 || printf '%s\n' "$response" >&2
    exit 10
  fi
}

echo "==> Resolve Gofile account"
ACCOUNT_RESPONSE="$("${CURL[@]}" "${AUTH[@]}" https://api.gofile.io/accounts/getid)"
expect_ok "$ACCOUNT_RESPONSE" "account lookup"
ACCOUNT_ID="$(jq -r '.data.id // empty' <<<"$ACCOUNT_RESPONSE")"
[[ -n "$ACCOUNT_ID" ]] || { echo "ERROR: Gofile account id missing" >&2; exit 11; }

ACCOUNT_DETAILS="$("${CURL[@]}" "${AUTH[@]}" "https://api.gofile.io/accounts/$ACCOUNT_ID")"
expect_ok "$ACCOUNT_DETAILS" "account details"
ROOT_FOLDER="$(jq -r '.data.rootFolder // empty' <<<"$ACCOUNT_DETAILS")"
[[ -n "$ROOT_FOLDER" ]] || { echo "ERROR: Gofile root folder missing" >&2; exit 12; }

DEVICE_LABEL="${PMOS_DEVICE:-device}"
UI_LABEL="${PMOS_UI:-ui}"
RUN_LABEL="${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
FOLDER_NAME="pmos-${DEVICE_LABEL}-${UI_LABEL}-${RUN_LABEL}"

CREATE_PAYLOAD="$(jq -nc \
  --arg parent "$ROOT_FOLDER" \
  --arg name "$FOLDER_NAME" \
  '{parentFolderId:$parent, folderName:$name, public:true}')"

CREATE_RESPONSE="$("${CURL[@]}" -X POST "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  -d "$CREATE_PAYLOAD" \
  https://api.gofile.io/contents/createFolder)"
expect_ok "$CREATE_RESPONSE" "folder creation"

FOLDER_ID="$(jq -r '.data.id // .data.folderId // empty' <<<"$CREATE_RESPONSE")"
FOLDER_CODE="$(jq -r '.data.code // empty' <<<"$CREATE_RESPONSE")"
[[ -n "$FOLDER_ID" && -n "$FOLDER_CODE" ]] || {
  echo "ERROR: Gofile folder id/code missing" >&2
  jq . <<<"$CREATE_RESPONSE" >&2
  exit 13
}

for file in "${FILES[@]}"; do
  echo "==> Upload $(basename "$file")"
  RESPONSE="$("${CURL[@]}" -X POST "${AUTH[@]}" \
    -F "file=@$file" \
    -F "folderId=$FOLDER_ID" \
    https://upload.gofile.io/uploadfile)"
  expect_ok "$RESPONSE" "upload of $(basename "$file")"
done

GOFILE_URL="https://gofile.io/d/$FOLDER_CODE"
printf '%s\n' "$GOFILE_URL" | tee "$UPLOAD_DIR/gofile-url.txt"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo
    echo "## Gofile"
    echo
    echo "- Folder: [$FOLDER_NAME]($GOFILE_URL)"
    echo "- Uploaded files: ${#FILES[@]}"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "url=$GOFILE_URL" >> "$GITHUB_OUTPUT"
fi

echo "Gofile: $GOFILE_URL"
