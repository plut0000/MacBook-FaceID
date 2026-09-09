import AppKit
import ApplicationServices
import CoreGraphics

enum UnlockInjectionError: LocalizedError {
    case accessibilityDenied
    case eventFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required to type the password on the lock screen."
        case .eventFailed:
            return "Could not post keyboard events."
        }
    }
}

enum AccessibilityTyper {
    static func unlock(with password: String) throws {
        guard AXIsProcessTrusted() else {
            throw UnlockInjectionError.accessibilityDenied
        }

        DisplayWaker.wake()
        Thread.sleep(forTimeInterval: AppConstants.passwordFieldSettleDelay)

        clickPasswordFieldHeuristic()
        Thread.sleep(forTimeInterval: 0.12)

        try type(password)
        Thread.sleep(forTimeInterval: 0.08)
        try pressReturn()
    }

    static func type(_ text: String) throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw UnlockInjectionError.eventFailed
        }
        var utf16 = Array(text.utf16)
        guard !utf16.isEmpty else { return }

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            throw UnlockInjectionError.eventFailed
        }
        down.flags = []
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        down.post(tap: .cghidEventTap)

        guard let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw UnlockInjectionError.eventFailed
        }
        up.flags = []
        up.post(tap: .cghidEventTap)
    }

    static func pressReturn() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw UnlockInjectionError.eventFailed
        }
        let key: CGKeyCode = 36
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else {
            throw UnlockInjectionError.eventFailed
        }
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// The lock-screen password field is typically centered in the lower half.
    /// A click helps focus it after display wake.
    private static func clickPasswordFieldHeuristic() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let point = CGPoint(x: frame.midX, y: frame.height * 0.42)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        if let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
        if let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) {
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
            up.post(tap: .cghidEventTap)
        }
    }
}
