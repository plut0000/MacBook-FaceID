import SwiftUI

struct IslandView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
                .frame(height: model.notchHeight)

            if model.isExpanded {
                expandedBody
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Color.clear.frame(height: AppConstants.collapsedChin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: model.isExpanded ? 24 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: model.isExpanded ? 24 : 18, style: .continuous)
                .stroke(Color.white.opacity(model.hasNotch ? 0.04 : 0.16), lineWidth: 1)
        )
        .onHover { hovering in
            model.setHovering(hovering)
        }
        .onTapGesture { model.toggleExpanded() }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: model.isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.animationPhase)
    }

    private var collapsedBar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            ScanAnimationView(
                style: model.animationStyle,
                phase: displayPhase,
                compact: true
            )
            if model.isExpanded {
                Text(model.status.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ScanAnimationView(style: model.animationStyle, phase: displayPhase, compact: false)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face Unlock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(statusDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(retryTitle) {
                    model.retryFromIsland()
                }
                .buttonStyle(IslandButtonStyle())
                Button("Settings") { model.showSettings = true }
                    .buttonStyle(IslandButtonStyle())
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayPhase: UnlockAnimationPhase {
        if model.animationPhase != .idle { return model.animationPhase }
        return (model.status == .watching || model.status == .matching) ? .scanning : .idle
    }

    private var retryTitle: String {
        if model.animationPhase == .failure { return "Retry" }
        if model.lockObserver.isLocked { return "Scan" }
        return model.isEnrolled ? "Identities" : "Enroll"
    }

    private var statusDetail: String {
        switch model.status {
        case .needsSetup:
            return "Enroll your face and save your login password."
        case .permissionNeeded:
            return "Camera and Accessibility are required."
        case .sessionLocked:
            return "Authorize with Touch ID to allow unlock."
        case .enrolled:
            return "Ready. Watching starts when this Mac locks."
        case .watching:
            return "Looking for a live match."
        case .matching:
            return "Match — unlocking…"
        case .unlocked:
            return "Welcome back."
        case .disabled:
            return "Face Unlock is turned off."
        case .failed:
            return model.bannerMessage ?? "Hover to retry."
        }
    }
}

struct IslandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
