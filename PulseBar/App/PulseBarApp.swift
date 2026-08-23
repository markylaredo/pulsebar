import SwiftUI

@main
struct PulseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.monitor)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        }
    }
}
