import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey through Carbon and calls `onPress`
/// when it fires.
///
/// Carbon's `RegisterEventHotKey` is the lightweight, dependency-free way to get
/// a global shortcut: unlike a global `NSEvent` monitor it needs **no**
/// Accessibility permission, and unlike a third-party package it's pure Apple
/// framework. This lets the popover open from anywhere without Raycast/Alfred.
@MainActor
final class HotKeyManager {
    /// Called on the main thread each time the hotkey is pressed.
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Registers the hotkey, replacing any previously registered one.
    /// `keyCode` is a virtual key code (e.g. `kVK_ANSI_T`); `modifiers` is a
    /// Carbon modifier mask (e.g. `cmdKey | optionKey`).
    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let this = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hotkey events on the main run loop.
            MainActor.assumeIsolated { manager.onPress?() }
            return noErr
        }, 1, &spec, this, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x54424B59) /* 'TBKY' */, id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }
}
