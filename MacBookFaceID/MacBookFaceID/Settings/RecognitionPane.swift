import SwiftUI

struct RecognitionPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("On lock", isOn: $model.triggerOnLock)
                Toggle("On wake", isOn: $model.triggerOnWake)
                Toggle("Space bar at the lock screen", isOn: $model.triggerOnSpace)
            } header: {
                Text("When to watch")
            } footer: {
                Text("Space still goes to macOS so the password field can focus. Face Unlock only starts a scan.")
            }

            Section {
                HStack {
                    Text("Stricter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $model.matchThreshold, in: 0.45...0.85, step: 0.01)
                    Text("Looser")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", model.matchThreshold))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            } header: {
                Text("Similarity")
            } footer: {
                Text("A live frame must beat this cosine similarity. Default \(String(format: "%.2f", AppConstants.defaultMatchThreshold)).")
            }

            Section {
                Picker("Mode", selection: $model.livenessMode) {
                    ForEach(LivenessMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Liveness")
            } footer: {
                Text(model.livenessMode.detail)
            }

            Section {
                LabeledContent("Engine", value: model.embeddingEngineName)
            } footer: {
                Text("Frames stay in memory.")
            }
        }
        .formStyle(.grouped)
    }
}
