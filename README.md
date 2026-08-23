# PulseBar

PulseBar is a native macOS 14+ menu-bar system monitor built with SwiftUI, Mach APIs, IOKit, and Swift Charts. It displays live CPU, memory, network, disk, storage, battery, and thermal-state information without a Dock icon or background database.

## Open and run

1. Open `PulseBar.xcodeproj` in Xcode 16 or newer.
2. Select the `PulseBar` scheme and your Mac as the run destination.
3. Run the app. PulseBar appears in the menu bar.

Launch at Login requires running a normally signed copy from `/Applications`; Xcode debug builds may be rejected by macOS registration.

## Verify from Terminal

```sh
xcodebuild -project PulseBar.xcodeproj \
  -scheme PulseBar \
  -configuration Debug \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO test
```

Hardware temperature and fan telemetry are intentionally not included in V1 because supported public macOS APIs do not expose those values consistently. The stable monitors do not depend on private SMC APIs.
