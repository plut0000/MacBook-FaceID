import Foundation

enum AppConstants {
    static let bundleID = "com.plut0000.MacBookFaceID"
    static let appDisplayName = "MacBook FaceID"
    static let featureName = "Face Unlock"

    static let keychainService = "com.plut0000.MacBookFaceID.login-password"

    /// RMS distance between similarity-normalized landmark embeddings. Lower is more similar.
    static let matchThreshold: Float = 0.12
    static let tightMatchThreshold: Float = 0.075
    static let requiredConsecutiveHits = 2

    static let enrollmentMinTemplates = 3
    static let enrollmentTargetTemplates = 8
    static let enrollmentMinQuality: Float = 0.25
    static let enrollmentCaptureSeconds: TimeInterval = 2.6

    static let matchingFPS: Double = 4
    static let unlockCooldown: TimeInterval = 6
    static let passwordFieldSettleDelay: TimeInterval = 0.45

    static let collapsedChin: CGFloat = 12
    static let expandedWidth: CGFloat = 328
    static let expandedBodyHeight: CGFloat = 196
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
        case .minimal: return "Modern iPhone-like"
        case .classic: return "iPhone X era"
        }
    }
}

enum UnlockAnimationPhase: Equatable {
    case idle
    case scanning
    case success
    case failure
}
