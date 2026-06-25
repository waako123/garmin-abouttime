#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="${1:-manifest.xml}"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Error: manifest file not found: $MANIFEST_FILE" >&2
  exit 1
fi

sdk_devices_file="$(mktemp)"
manifest_devices_file="$(mktemp)"
trap 'rm -f "$sdk_devices_file" "$manifest_devices_file"' EXIT

LC_ALL=C ls -1 "${CIQ_HOME}../../Devices" \
  | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
  | sed '/^$/d' \
  | sort -u >"$sdk_devices_file"

perl -0777 -ne '
  while (/<iq:product\b[^>]*\bid="([^"]+)"/g) {
    print lc($1), "\n";
  }
' "$MANIFEST_FILE" | LC_ALL=C sort -u >"$manifest_devices_file"

manifest_not_in_sdk="$(comm -23 "$manifest_devices_file" "$sdk_devices_file")"
sdk_not_in_manifest="$(comm -13 "$manifest_devices_file" "$sdk_devices_file")"

if [[ -z "$manifest_not_in_sdk" && -z "$sdk_not_in_manifest" ]]; then
  echo "Manifest and iqdevices lists match."
  exit 0
fi

echo "Devices in $MANIFEST_FILE but not in iqdevices:"
if [[ -n "$manifest_not_in_sdk" ]]; then
  printf '%s\n' "$manifest_not_in_sdk" | sed 's/^/  - /'
else
  echo "  (none)"
fi

echo
echo "Devices in iqdevices but not in $MANIFEST_FILE:"
if [[ -n "$sdk_not_in_manifest" ]]; then
  printf '%s\n' "$sdk_not_in_manifest" | sed 's/^/  - /'
else
  echo "  (none)"
fi
