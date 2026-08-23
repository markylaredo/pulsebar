import Carbon
import Foundation

final class GlobalShortcutController {
    private static let signature: OSType = 0x504C5342 // PLSB
    private static let identifier: UInt32 = 1

    private let action: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var registeredShortcut: DashboardShortcut?

    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<GlobalShortcutController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                controller.action()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    @discardableResult
    func register(_ shortcut: DashboardShortcut?) -> Bool {
        guard shortcut != registeredShortcut else { return true }
        unregister()
        guard let shortcut else { return true }

        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        var registeredHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(for: shortcut.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )

        guard status == noErr else { return false }
        hotKey = registeredHotKey
        registeredShortcut = shortcut
        return true
    }

    private func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
        registeredShortcut = nil
    }

    private func carbonModifiers(for modifiers: DashboardShortcutModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
