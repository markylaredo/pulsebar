#!/bin/sh

set -eu

APP_NAME="PulseBar"
BUNDLE_ID="com.pulsebar.app"
INSTALL_DIRECTORY="${PULSEBAR_INSTALL_DIR:-/Applications}"
APP_PATH="$INSTALL_DIRECTORY/$APP_NAME.app"

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'PulseBar uninstaller: %s\n' "$*" >&2
    exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "PulseBar can only be uninstalled on macOS."

if [ ! -d "$APP_PATH" ]; then
    say "PulseBar is not installed in $INSTALL_DIRECTORY."
    exit 0
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
INSTALLED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)"
[ "$INSTALLED_BUNDLE_ID" = "$BUNDLE_ID" ] || fail "$APP_PATH is not the expected PulseBar app. Nothing was removed."

say "Closing PulseBar and disabling Launch at Login…"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

WAIT_COUNT=0
while pgrep -x "$APP_NAME" >/dev/null 2>&1 && [ "$WAIT_COUNT" -lt 20 ]; do
    sleep 0.25
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

pgrep -x "$APP_NAME" >/dev/null 2>&1 \
    && fail "PulseBar is still running. Quit it manually and run the uninstaller again."

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_NAME"
if [ -x "$APP_EXECUTABLE" ]; then
    "$APP_EXECUTABLE" --unregister-login-item >/dev/null 2>&1 || true
fi

TRASH_DIRECTORY="${PULSEBAR_TRASH_DIR:-$HOME/.Trash}"
mkdir -p "$TRASH_DIRECTORY"
TRASH_PATH="$TRASH_DIRECTORY/$APP_NAME-$(date +%Y%m%d-%H%M%S)-$$.app"

say "Moving PulseBar to the Trash…"
if [ -w "$INSTALL_DIRECTORY" ]; then
    mv "$APP_PATH" "$TRASH_PATH"
else
    say "Administrator access is needed to remove PulseBar from $INSTALL_DIRECTORY."
    sudo mv "$APP_PATH" "$TRASH_PATH"
    sudo chown -R "$(id -u):$(id -g)" "$TRASH_PATH"
fi

say "PulseBar was uninstalled and can be recovered from the Trash."
say "Your preferences were kept in case you reinstall later."
