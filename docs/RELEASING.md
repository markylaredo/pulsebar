# Releasing PulseBar

The curl installer downloads two assets from the latest published GitHub release:

- `PulseBar.zip`
- `PulseBar.zip.sha256`

## Prepare the release

1. Archive PulseBar in Xcode with the **Release** configuration.
2. Sign the app with a Developer ID certificate and notarize it with Apple.
3. Export the finished `PulseBar.app` into an empty working directory.
4. Create the release files from that directory:

```sh
ditto -c -k --sequesterRsrc --keepParent PulseBar.app PulseBar.zip
shasum -a 256 PulseBar.zip > PulseBar.zip.sha256
```

5. Create a GitHub release, attach both files, and mark it as the latest release.
6. Test the public installer after publishing:

```sh
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/main/install.sh | bash
```

Keep the asset names unchanged. GitHub routes the installer to those files through its stable `/releases/latest/download/` URLs.
