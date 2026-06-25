import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

/// Persists the user's chosen global shortcut (key code + Carbon modifier mask)
/// and publishes changes so `AppDelegate` can re-register the hotkey live.
///
/// We store the *Carbon* representation (`kVK_…` virtual key code and the
/// `cmdKey | optionKey | …` mask) because that's exactly what `HotKeyManager`
/// hands to `RegisterEventHotKey` — no conversion needed at registration time.
@MainActor
final class HotKeyStore: ObservableObject {
    /// Virtual key code, e.g. `kVK_ANSI_T`.
    @Published var keyCode: UInt32 {
        didSet { defaults.set(Int(keyCode), forKey: Self.keyCodeKey) }
    }
    /// Carbon modifier mask, e.g. `cmdKey | optionKey`.
    @Published var modifiers: UInt32 {
        didSet { defaults.set(Int(modifiers), forKey: Self.modifiersKey) }
    }

    /// The original built-in shortcut, ⌥⌘T, used as the default and for "reset".
    static let defaultKeyCode = UInt32(kVK_ANSI_T)
    static let defaultModifiers = UInt32(cmdKey | optionKey)

    private let defaults: UserDefaults
    private static let keyCodeKey = "hotKeyKeyCode"
    private static let modifiersKey = "hotKeyModifiers"

    /// - Parameter defaults: settings store. Defaults to `.standard`; tests pass
    ///   a throwaway suite so they never touch the user's real shortcut.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keyCode = UInt32((defaults.object(forKey: Self.keyCodeKey) as? Int) ?? Int(Self.defaultKeyCode))
        self.modifiers = UInt32((defaults.object(forKey: Self.modifiersKey) as? Int) ?? Int(Self.defaultModifiers))
    }

    /// Whether the current shortcut is the built-in ⌥⌘T.
    var isDefault: Bool {
        keyCode == Self.defaultKeyCode && modifiers == Self.defaultModifiers
    }

    /// Records a newly captured shortcut.
    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Restores the built-in ⌥⌘T.
    func reset() {
        keyCode = Self.defaultKeyCode
        modifiers = Self.defaultModifiers
    }

    /// Human-readable shortcut, e.g. "⌥⌘T".
    var displayString: String {
        HotKeyFormatter.string(keyCode: keyCode, modifiers: modifiers)
    }
}

/// Pure formatting/conversion helpers shared by the store and the recorder UI.
/// Kept dependency-free: a small lookup table rather than `UCKeyTranslate`, which
/// is plenty for the letter/number/function-key combos a global shortcut uses
/// (assumes a standard Latin keyboard layout).
enum HotKeyFormatter {
    /// Converts an `NSEvent` modifier set to a Carbon modifier mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option)  { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift)   { mask |= UInt32(shiftKey) }
        return mask
    }

    /// Modifier symbols in canonical macOS order: ⌃⌥⇧⌘.
    static func modifierString(_ modifiers: UInt32) -> String {
        var out = ""
        if modifiers & UInt32(controlKey) != 0 { out += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { out += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { out += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { out += "⌘" }
        return out
    }

    /// Full shortcut string, e.g. "⌥⌘T".
    static func string(keyCode: UInt32, modifiers: UInt32) -> String {
        modifierString(modifiers) + keyName(keyCode)
    }

    /// Display label for a virtual key code.
    static func keyName(_ keyCode: UInt32) -> String {
        keyNames[Int(keyCode)] ?? "Key \(keyCode)"
    }

    private static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
        kVK_ANSI_RightBracket: "]", kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
        kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}
