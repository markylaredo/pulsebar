# Installing PulseBar

PulseBar supports macOS 14 and later.

## Quick install

Open Terminal and run:

```sh
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/master/install.sh | bash
```

The installer will:

1. Download `PulseBar.zip` from the latest GitHub release.
2. Verify its published SHA-256 checksum.
3. Confirm that it contains the expected `com.pulsebar.app` bundle.
4. Verify the app's code signature.
5. Copy PulseBar into `/Applications`.
6. Open PulseBar in the macOS menu bar.

macOS may request your administrator password when the installer writes to `/Applications`. PulseBar itself does not need administrator privileges to monitor your Mac.

## Review the installer first

If you prefer to inspect scripts before running them, download the installer separately:

```sh
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/master/install.sh \
  -o /tmp/pulsebar-install.sh
less /tmp/pulsebar-install.sh
sh /tmp/pulsebar-install.sh
```

## Install somewhere else

Set `PULSEBAR_INSTALL_DIR` to use another applications directory:

```sh
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/master/install.sh \
  | PULSEBAR_INSTALL_DIR="$HOME/Applications" bash
```

Installing in `/Applications` is recommended because Launch at Login may not register an Xcode build or an app stored in a temporary development directory.

## Update PulseBar

Run the quick-install command again. The installer always downloads the latest published release and updates the existing app bundle.

Quit and reopen PulseBar after updating if it was already running.

## Uninstall PulseBar

Run:

```sh
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/master/uninstall.sh | bash
```

The uninstaller quits PulseBar, disables Launch at Login, and moves the application to the Trash. macOS may request your administrator password when removing it from `/Applications`.

PulseBar settings are small preferences stored by macOS. Leaving them in place is harmless and preserves your configuration if you reinstall later.

To uninstall manually:

1. Open PulseBar Settings and turn off **Launch at Login**.
2. Choose **Quit PulseBar** under **Settings → General**.
3. Open `/Applications` in Finder.
4. Move `PulseBar.app` to the Trash.

## Troubleshooting

### The download returns 404

There is no public latest release yet, or the release does not contain both required files:

- `PulseBar.zip`
- `PulseBar.zip.sha256`

Check the repository's [Releases page](https://github.com/markylaredo/pulsebar/releases) and try again after a release is published.

For maintainers, publishing a version tag runs the release workflow described in [RELEASING.md](RELEASING.md).

### Checksum verification failed

The downloaded archive does not match its published checksum. The installer intentionally stops without installing it. Do not bypass this check; retry later or report the failed release.

### Signature verification failed

The release is incomplete, damaged, or not signed correctly. Download a newer release or build PulseBar from source. The installer does not remove macOS security checks or quarantine attributes.

### PulseBar does not appear

PulseBar has no Dock icon. Look for its live statistics in the right side of the macOS menu bar. If the menu bar is crowded, temporarily close another menu-bar app and reopen PulseBar.

## Building from source

Developers can build PulseBar directly from `PulseBar.xcodeproj`. See the main [README](../README.md#build-from-source) for the Xcode steps.

Release maintainers should follow [RELEASING.md](RELEASING.md) so the curl installer can validate and install each published build.
