#!/bin/sh

set -eu

APP_NAME="PulseBar"
BUNDLE_ID="com.pulsebar.app"
RELEASE_BASE_URL="${PULSEBAR_RELEASE_BASE_URL:-https://github.com/markylaredo/pulsebar/releases/latest/download}"
INSTALL_DIRECTORY="${PULSEBAR_INSTALL_DIR:-/Applications}"
ARCHIVE_NAME="${APP_NAME}.zip"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'PulseBar installer: %s\n' "$*" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v shasum >/dev/null 2>&1 || fail "shasum is required."
command -v ditto >/dev/null 2>&1 || fail "ditto is required."
command -v codesign >/dev/null 2>&1 || fail "codesign is required."

[ "$(uname -s)" = "Darwin" ] || fail "PulseBar can only be installed on macOS."

MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MACOS_MAJOR" -ge 14 ] || fail "PulseBar requires macOS 14 or later."

TEMPORARY_ROOT="${TMPDIR:-/tmp}"
WORK_DIRECTORY="$(mktemp -d "${TEMPORARY_ROOT%/}/pulsebar-install.XXXXXX")"
trap 'rm -rf "$WORK_DIRECTORY"' EXIT HUP INT TERM

ARCHIVE_PATH="$WORK_DIRECTORY/$ARCHIVE_NAME"
CHECKSUM_PATH="$WORK_DIRECTORY/$CHECKSUM_NAME"
UNPACK_DIRECTORY="$WORK_DIRECTORY/unpacked"

say "Downloading the latest PulseBar release…"
curl --fail --location --silent --show-error --retry 3 \
    --output "$ARCHIVE_PATH" "$RELEASE_BASE_URL/$ARCHIVE_NAME" \
    || fail "Could not download $ARCHIVE_NAME. Make sure a latest GitHub release is published."

curl --fail --location --silent --show-error --retry 3 \
    --output "$CHECKSUM_PATH" "$RELEASE_BASE_URL/$CHECKSUM_NAME" \
    || fail "Could not download $CHECKSUM_NAME. The release must include its SHA-256 checksum."

EXPECTED_CHECKSUM="$(awk 'NR == 1 { print $1 }' "$CHECKSUM_PATH")"
ACTUAL_CHECKSUM="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{ print $1 }')"

case "$EXPECTED_CHECKSUM" in
    *[!0-9a-fA-F]*|'') fail "The published checksum is invalid." ;;
esac

[ "${#EXPECTED_CHECKSUM}" -eq 64 ] || fail "The published checksum is invalid."
[ "$ACTUAL_CHECKSUM" = "$EXPECTED_CHECKSUM" ] || fail "Checksum verification failed. The download was not installed."

mkdir -p "$UNPACK_DIRECTORY"
ditto -x -k "$ARCHIVE_PATH" "$UNPACK_DIRECTORY"

APP_PATH="$(find "$UNPACK_DIRECTORY" -maxdepth 3 -type d -name "$APP_NAME.app" -print -quit)"
[ -n "$APP_PATH" ] || fail "$ARCHIVE_NAME does not contain $APP_NAME.app."

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[ -f "$INFO_PLIST" ] || fail "The downloaded app bundle is incomplete."

DOWNLOADED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)"
[ "$DOWNLOADED_BUNDLE_ID" = "$BUNDLE_ID" ] || fail "The downloaded app has an unexpected bundle identifier."

codesign --verify --deep --strict "$APP_PATH" 2>/dev/null \
    || fail "The downloaded app does not have a valid code signature."

DESTINATION="$INSTALL_DIRECTORY/$APP_NAME.app"

if [ ! -d "$INSTALL_DIRECTORY" ]; then
    if ! mkdir -p "$INSTALL_DIRECTORY" 2>/dev/null; then
        say "Administrator access is needed to create $INSTALL_DIRECTORY."
        sudo mkdir -p "$INSTALL_DIRECTORY"
    fi
fi

say "Installing PulseBar in ${INSTALL_DIRECTORY}…"
if [ -w "$INSTALL_DIRECTORY" ]; then
    ditto "$APP_PATH" "$DESTINATION"
else
    say "Administrator access is needed to install PulseBar."
    sudo ditto "$APP_PATH" "$DESTINATION"
fi

codesign --verify --deep --strict "$DESTINATION" 2>/dev/null \
    || fail "The installed app failed signature verification."

say "PulseBar was installed successfully."

if [ "${PULSEBAR_SKIP_LAUNCH:-0}" != "1" ]; then
    open "$DESTINATION"
    say "PulseBar is now running in your menu bar."
fi
