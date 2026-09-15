import Foundation

enum AppConstants {
    static let bundleID = "com.plut0000.MacBookFaceID"
    static let appDisplayName = "MacBook FaceID"
    static let featureName = "Face Unlock"
    static let marketingVersion = "0.2.0"

    static let keychainService = "com.plut0000.MacBookFaceID.vault-key"
    static let keychainAccount = "aes256-gcm"

    static let embeddingEngineClassical = "aligned-dct-lbp-v1"
    static let embeddingEngineCoreML = "coreml-112"
    static let embeddingLength = 512

    /// Cosine similarity. Higher is more similar. Tunable in Recognition settings.
    static let defaultMatchThreshold: Float = 0.62
    static let tightMatchBoost: Float = 0.08
    static let requiredConsecutiveHits = 2

    static let enrollmentPoseHold: TimeInterval = 0.38
    static let enrollmentMinQuality: Float = 0.18
    static let matchingFPS: Double = 8
    static let livenessWindow: TimeInterval = 1.8
    static let unlockCooldown: TimeInterval = 5
    static let passwordFieldSettleDelay: TimeInterval = 0.45

    static let collapsedChin: CGFloat = 10
    static let expandedWidth: CGFloat = 340
    static let expandedBodyHeight: CGFloat = 168
    static let floatingPillWidth: CGFloat = 214
}

enum AnimationStyle: String, CaseIterable, Identifiable {
    case minimal
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .classic: return "Classic"
        }
    }

    var subtitle: String {
        switch self {
        case .minimal: return "Soft island glow"
        case .classic: return "Bracket scan"
        }
    }
}

enum UnlockAnimationPhase: Equatable {
    case idle
    case scanning
    case success
    case failure
}

enum LivenessMode: String, CaseIterable, Identifiable {
    case off
    case light
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .light: return "Light"
        case .heavy: return "Heavy"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "Skip spoof checks. Photos may unlock."
        case .light:
            return "Reject screen glare and a device-shaped frame around the face."
        case .heavy:
            return "Also look for blinks, head motion, and 3D-ish landmark geometry."
        }
    }
}

enum SessionIdleLimit: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case untilQuit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .untilQuit: return "Until I quit"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .untilQuit: return nil
        }
    }
}

enum AppStatus: String {
    case needsSetup
    case permissionNeeded
    case sessionLocked
    case enrolled
    case watching
    case matching
    case unlocked
    case disabled
    case failed

    var label: String {
        switch self {
        case .needsSetup: return "Setup needed"
        case .permissionNeeded: return "Permission needed"
        case .sessionLocked: return "Session locked"
        case .enrolled: return "Ready"
        case .watching: return "Looking for you"
        case .matching: return "Unlocking"
        case .unlocked: return "Welcome back"
        case .disabled: return "Face Unlock off"
        case .failed: return "Didn’t match"
        }
    }

    var symbolName: String {
        switch self {
        case .needsSetup: return "person.crop.circle.badge.plus"
        case .permissionNeeded: return "exclamationmark.triangle"
        case .sessionLocked: return "lock.fill"
        case .enrolled: return "checkmark.shield"
        case .watching: return "eye"
        case .matching: return "faceid"
        case .unlocked: return "lock.open"
        case .disabled: return "lock"
        case .failed: return "xmark.circle"
        }
    }
}
