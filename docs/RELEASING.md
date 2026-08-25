# Releasing PulseBar

The curl installer downloads two assets from the latest published GitHub release:

- `PulseBar.zip`
- `PulseBar.zip.sha256`

The `Publish Release` GitHub Actions workflow builds a universal app and publishes both files. Without Apple credentials it creates an ad-hoc signed release. With the complete secret set below it creates a Developer ID signed and notarized release.

## Apple signing setup (recommended)

For a public release that passes normal Gatekeeper checks, add these encrypted values under **Repository Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE` | Developer ID Application `.p12` file encoded with `base64 -i certificate.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` file |
| `KEYCHAIN_PASSWORD` | A strong temporary password used only by the Actions keychain |
| `DEVELOPER_ID_APPLICATION` | Full signing identity, such as `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_PASSWORD` | App-specific password created for the Apple ID |

Never commit these values to the repository. Configure either all seven secrets or none of them; the workflow rejects partial signing configuration.

If none are configured, the workflow still publishes an ad-hoc signed, non-notarized build. This is useful for early testing, but Developer ID signing and notarization are strongly recommended before promoting PulseBar to general users.

## Publish a release

Every push to `master`, including a merged pull request, runs the release workflow. The workflow finds the latest stable semantic version tag and increments its patch component automatically. For example, the first `master` push after `v1.0.0` publishes `v1.0.1`.

The generated semantic version is passed to Xcode as `MARKETING_VERSION`. The GitHub Actions run number is passed as `CURRENT_PROJECT_VERSION`, so the packaged app reports the same release version with a monotonically increasing build number.

To intentionally increment the minor or major component, open **Actions → Publish Release → Run workflow** and select the desired bump. A workflow rerun for a commit that already has a release tag reuses that tag instead of creating another version.

When the workflow finishes, confirm that both assets appear on the repository's Releases page. The installer URL will then work without another code change.

## Manual fallback

If GitHub Actions is unavailable:

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
curl -fsSL https://raw.githubusercontent.com/markylaredo/pulsebar/master/install.sh | bash
```

Keep the asset names unchanged. GitHub routes the installer to those files through its stable `/releases/latest/download/` URLs.
