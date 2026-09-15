import Foundation

enum UnlockPipelineError: LocalizedError, Equatable {
    case disabled
    case sessionLocked
    case notAtLockScreen
    case notReady
    case cooldown
    case stillLocked

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Face Unlock is turned off."
        case .sessionLocked:
            return "The Face Unlock session is locked. Authorize with Touch ID first."
        case .notAtLockScreen:
            return "The Mac is not at the lock screen."
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
final class UnlockPipeline {
    private var lastAttempt: Date = .distantPast
    private var failedAttempts = 0

    func resetFailures() {
        failedAttempts = 0
    }

    func canAttempt() -> Bool {
        Date().timeIntervalSince(lastAttempt) >= AppConstants.unlockCooldown && failedAttempts < 3
    }

    func performUnlock(password: String) async throws {
        guard canAttempt() else { throw UnlockPipelineError.cooldown }
        lastAttempt = Date()

        try await Task.detached(priority: .userInitiated) {
            try AccessibilityTyper.unlock(with: password)
        }.value

        try await Task.sleep(nanoseconds: 1_400_000_000)
        if ScreenLockObserver.readLocked() {
            failedAttempts += 1
            throw UnlockPipelineError.stillLocked
        }
        failedAttempts = 0
    }
}
