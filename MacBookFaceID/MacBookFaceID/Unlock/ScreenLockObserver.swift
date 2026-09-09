import AppKit
import Combine

@MainActor
final class ScreenLockObserver: ObservableObject {
    @Published private(set) var isLocked = false

    var onLocked: (() -> Void)?
    var onUnlocked: (() -> Void)?
    var onDisplayWake: (() -> Void)?

    private var tokens: [NSObjectProtocol] = []

    func start() {
        stop()
        isLocked = Self.readLocked()

        let center = DistributedNotificationCenter.default()
        tokens.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = true
                self?.onLocked?()
            }
        })
        tokens.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = false
                self?.onUnlocked?()
            }
        })
        tokens.append(center.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = true
                self?.onLocked?()
            }
        })
        tokens.append(center.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if !Self.readLocked() {
                    self?.isLocked = false
                    self?.onUnlocked?()
                }
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        tokens.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = Self.readLocked()
                self?.onDisplayWake?()
            }
        })
        tokens.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLocked = Self.readLocked()
                self?.onDisplayWake?()
            }
        })
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        for token in tokens {
            center.removeObserver(token)
            workspace.removeObserver(token)
        }
        tokens.removeAll()
    }

    static func readLocked() -> Bool {
        guard let cfDict = CGSessionCopyCurrentDictionary() else { return false }
        let dict = cfDict as NSDictionary
        if let locked = dict["CGSSessionScreenIsLocked"] as? Bool {
            return locked
        }
        if let number = dict["CGSSessionScreenIsLocked"] as? NSNumber {
            return number.boolValue
        }
        return false
    }
}
