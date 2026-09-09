import Foundation

enum UnlockCoordinatorError: LocalizedError, Equatable {
    case disabled
    case notReady
    case cooldown
    case stillLocked

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Face Unlock is turned off."
        case .notReady:
            return "Enrollment, camera, Accessibility, or a saved password is missing."
        case .cooldown:
            return "Unlock just ran. Waiting before another attempt."
        case .stillLocked:
            return "The password was typed but the Mac is still locked. Update the saved password if it changed."
        }
    }
}

@MainActor
final class UnlockCoordinator {
    private var lastAttempt: Date = .distantPast
    private var failedAttempts = 0

    func resetFailures() {
        failedAttempts = 0
    }

    func canAttempt() -> Bool {
        Date().timeIntervalSince(lastAttempt) >= AppConstants.unlockCooldown && failedAttempts < 3
    }

    func performUnlock() async throws {
        guard canAttempt() else { throw UnlockCoordinatorError.cooldown }
        lastAttempt = Date()

        let password = try LoginPasswordKeychain.load()

        try await Task.detached(priority: .userInitiated) {
            try AccessibilityTyper.unlock(with: password)
        }.value

        try await Task.sleep(nanoseconds: 1_400_000_000)
        if ScreenLockObserver.readLocked() {
            failedAttempts += 1
            throw UnlockCoordinatorError.stillLocked
        }
        failedAttempts = 0
    }
}
