import SwiftUI

struct RecognitionPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recognition")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("When to watch")
                    .font(.headline)
                Toggle("On lock", isOn: $model.triggerOnLock)
                Toggle("On wake", isOn: $model.triggerOnWake)
                Toggle("Space bar at the lock screen", isOn: $model.triggerOnSpace)
                Text("Space still goes to macOS so the password field can focus. Face Unlock only starts a scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Similarity")
                    .font(.headline)
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
                        .frame(width: 36, alignment: .trailing)
                }
                Text("A live frame must beat this cosine similarity against an enabled identity. Default \(String(format: "%.2f", AppConstants.defaultMatchThreshold)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Liveness")
                    .font(.headline)
                Picker("Liveness", selection: $model.livenessMode) {
                    ForEach(LivenessMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.livenessMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Light uses deny cues only (glare, device rectangle). Heavy also requires a confirm cue — a blink, nose parallax, or 3D-ish landmark geometry — over about two seconds. Off skips the check.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Engine: \(model.embeddingEngineName). Frames stay in memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
