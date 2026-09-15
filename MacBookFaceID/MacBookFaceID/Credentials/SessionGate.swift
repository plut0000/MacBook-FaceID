import Combine
import Foundation
import LocalAuthentication

/// Holds the vault key in memory only while the user has authorized a session.
/// Re-locks after the configured idle interval so an unattended Mac does not
/// stay able to type the login password forever.
@MainActor
final class SessionGate: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastActivity = Date()

    private var holder: SymmetricKeyHolder?
    private var idleTimer: Timer?

    var key: SymmetricKeyHolder? { holder }

    func markActivity() {
        lastActivity = Date()
    }

    func authorize(prompt: String = "Unlock Face Unlock") async {
        lastError = nil
        do {
            let context = LAContext()
            context.localizedCancelTitle = "Cancel"
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                throw authError ?? KeychainError.accessControl
            }
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: prompt)
            guard ok else { return }
            if SessionKeychain.hasKey() {
                holder = try SessionKeychain.load(prompt: prompt, context: context)
            } else {
                holder = try SessionKeychain.createIfNeeded()
            }
            isAuthorized = true
            markActivity()
            startIdleTimer()
        } catch {
            lastError = error.localizedDescription
            lock()
        }
    }

    func lock() {
        holder = nil
        isAuthorized = false
        idleTimer?.invalidate()
        idleTimer = nil
    }

    func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateIdle()
            }
        }
        idleTimer?.tolerance = 4
    }

    private func evaluateIdle() {
        guard isAuthorized else { return }
        let limit = SessionIdleLimit(rawValue: UserDefaults.standard.string(forKey: "sessionIdleLimit") ?? "") ?? .fifteenMinutes
        guard let interval = limit.interval else { return }
        if Date().timeIntervalSince(lastActivity) >= interval {
            lock()
        }
    }
}
