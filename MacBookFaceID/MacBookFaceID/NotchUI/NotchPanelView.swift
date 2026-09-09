import SwiftUI

struct NotchPanelView: View {
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
        .clipShape(RoundedRectangle(cornerRadius: model.isExpanded ? 22 : 14, style: .continuous))
        .onHover { model.setHovering($0) }
        .onTapGesture { model.toggleExpanded() }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: model.isExpanded)
    }

    private var collapsedBar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            FaceUnlockAnimationView(
                style: model.animationStyle,
                phase: model.animationPhase == .idle ? (model.status == .watching ? .scanning : .idle) : model.animationPhase,
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
        .padding(.horizontal, 12)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                enrollmentThumb
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

            Toggle("Enable Face Unlock", isOn: $model.isEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .onChange(of: model.isEnabled, perform: { _ in
                    model.refreshStatus()
                    if model.isEnabled && model.lockObserver.isLocked {
                        model.beginWatching()
                    } else if !model.isEnabled {
                        model.stopWatchingIfUnused()
                    }
                })

            Picker("Animation", selection: $model.animationStyle) {
                ForEach(AnimationStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .help("Minimal is a modern ring. Classic is the iPhone X–era scan.")

            HStack(spacing: 8) {
                Button(model.isEnrolled ? "Re-enroll" : "Enroll") {
                    if model.isSetupComplete {
                        model.showSettings = true
                    } else {
                        model.showOnboarding = true
                    }
                }
                    .buttonStyle(NotchButtonStyle())
                Button("Settings") { model.showSettings = true }
                    .buttonStyle(NotchButtonStyle())
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var enrollmentThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
            if let image = model.enrollmentPreview {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusDetail: String {
        switch model.status {
        case .needsSetup:
            return "Enroll your face and save your login password."
        case .permissionNeeded:
            return "Camera and Accessibility are required."
        case .enrolled:
            return "Ready. Watching starts when this Mac locks."
        case .watching:
            return "Camera is watching for your face."
        case .matching:
            return "Face matched — unlocking…"
        case .unlocked:
            return "Welcome back."
        case .disabled:
            return "Face Unlock is turned off."
        case .failed:
            return model.bannerMessage ?? "Could not unlock."
        }
    }
}

struct NotchButtonStyle: ButtonStyle {
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
