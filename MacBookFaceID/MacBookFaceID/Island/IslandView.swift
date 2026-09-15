import SwiftUI

struct IslandView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
                .frame(height: model.notchHeight)

            if model.isExpanded {
                expandedBody
                    .transition(.opacity.combined(with: .offset(y: -6)))
            } else if !model.hasNotch {
                Color.clear.frame(height: AppConstants.collapsedChin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .clipShape(islandClip)
        .onHover { hovering in
            model.setHovering(hovering)
        }
        .onTapGesture { model.toggleExpanded() }
        .animation(AppConstants.islandSpring, value: model.isExpanded)
        .animation(AppConstants.islandSpring, value: model.animationPhase)
    }

    private var islandClip: IslandClip {
        IslandClip(
            topRadius: model.hasNotch ? 0 : bottomRadius,
            bottomRadius: bottomRadius
        )
    }

    private var bottomRadius: CGFloat {
        if model.isExpanded {
            return AppConstants.expandedIslandRadius
        }
        return model.hasNotch ? AppConstants.collapsedNotchRadius : AppConstants.collapsedFloatingRadius
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Button(retryTitle) {
                    model.retryFromIsland()
                }
                .buttonStyle(IslandButtonStyle())
                Button("Settings") { model.showSettings = true }
                    .buttonStyle(IslandButtonStyle())
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
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
            return "Enroll a face and save the login password."
        case .permissionNeeded:
            return "Camera and Accessibility are required."
        case .sessionLocked:
            return "Authorize with Touch ID to allow unlock."
        case .enrolled:
            return "Watching starts when this Mac locks."
        case .watching:
            return "Scanning."
        case .matching:
            return "Unlocking…"
        case .unlocked:
            return "Unlocked."
        case .disabled:
            return "Face Unlock is off."
        case .failed:
            return model.bannerMessage ?? "No match. Hover to retry."
        }
    }
}

struct IslandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
            .foregroundStyle(.white.opacity(0.9))
            .clipShape(Capsule())
            .contentShape(Capsule())
    }
}

private struct IslandClip: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        ).path(in: rect)
    }
}
