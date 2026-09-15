import ApplicationServices
import CoreGraphics
import Foundation

/// Listen-only tap for the space bar while the Mac is locked. Space is left
/// for the system (it still focuses the password field); we only start a scan.
final class SpacebarTrigger {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var onSpace: (() -> Void)?

    func start() {
        stop()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let port = Unmanaged<SpacebarTrigger>.fromOpaque(refcon).takeUnretainedValue().tap {
                        CGEvent.tapEnable(tap: port, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                // 49 is kVK_Space. Ignore repeats by checking only keyDown.
                if type == .keyDown && keycode == 49 {
                    let trigger = Unmanaged<SpacebarTrigger>.fromOpaque(refcon).takeUnretainedValue()
                    DispatchQueue.main.async {
                        trigger.onSpace?()
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: info
        ) else {
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    deinit {
        stop()
    }
}
