import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FaceUnlockAnimationView(style: model.animationStyle, phase: displayPhase)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face Unlock")
                        .font(.headline)
                    Text(model.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Enable Face Unlock", isOn: $model.isEnabled)
            Picker("Animation", selection: $model.animationStyle) {
                ForEach(AnimationStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button(model.isEnrolled ? "Re-enroll" : "Enroll") {
                    model.showOnboarding = true
                }
                Button("Settings") { model.showSettings = true }
            }

            Divider()
            Button("Quit") { model.quit() }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var displayPhase: UnlockAnimationPhase {
        if model.animationPhase != .idle { return model.animationPhase }
        return model.status == .watching ? .scanning : .idle
    }
}
