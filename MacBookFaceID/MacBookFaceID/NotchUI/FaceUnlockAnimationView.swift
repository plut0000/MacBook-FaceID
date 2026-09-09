import SwiftUI

struct FaceUnlockAnimationView: View {
    let style: AnimationStyle
    let phase: UnlockAnimationPhase
    var compact: Bool = false

    var body: some View {
        Group {
            switch style {
            case .minimal:
                MinimalFaceAnimation(phase: phase, compact: compact)
            case .classic:
                ClassicFaceAnimation(phase: phase, compact: compact)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch phase {
        case .idle: return "Face Unlock idle"
        case .scanning: return "Looking for your face"
        case .success: return "Unlocked"
        case .failure: return "Face did not match"
        }
    }
}

private struct MinimalFaceAnimation: View {
    let phase: UnlockAnimationPhase
    let compact: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: compact ? 2 : 3)
            Circle()
                .trim(from: 0, to: phase == .scanning ? 0.72 : 1)
                .stroke(color, style: StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(
                    phase == .scanning
                        ? .linear(duration: 1.1).repeatForever(autoreverses: false)
                        : .easeInOut(duration: 0.35),
                    value: pulse
                )

            if phase == .success {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 11 : 18, weight: .semibold))
                    .foregroundStyle(Color.green)
                    .transition(.scale.combined(with: .opacity))
            } else if phase == .failure {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 11 : 16, weight: .semibold))
                    .foregroundStyle(Color.red)
            } else {
                Circle()
                    .fill(color.opacity(0.9))
                    .frame(width: compact ? 4 : 6, height: compact ? 4 : 6)
            }
        }
        .frame(width: compact ? 22 : 44, height: compact ? 22 : 44)
        .onChange(of: phase, perform: { _ in syncPulse() })
        .onAppear { syncPulse() }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.7)
        case .scanning: return .white
        case .success: return .green
        case .failure: return .red
        }
    }

    private func syncPulse() {
        pulse = false
        if phase == .scanning {
            DispatchQueue.main.async { pulse = true }
        }
    }
}

private struct ClassicFaceAnimation: View {
    let phase: UnlockAnimationPhase
    let compact: Bool
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .trim(from: 0.08, to: 0.42)
                    .stroke(color.opacity(1 - Double(index) * 0.15), style: StrokeStyle(
                        lineWidth: compact ? 1.4 : 2.2,
                        lineCap: .round
                    ))
                    .padding(CGFloat(index) * (compact ? 2.4 : 4.2))
                    .rotationEffect(.degrees(spin ? Double(index + 1) * 360 : Double(index) * 28))
                    .animation(
                        phase == .scanning
                            ? .linear(duration: 1.15 + Double(index) * 0.12).repeatForever(autoreverses: false)
                            : .easeOut(duration: 0.4),
                        value: spin
                    )
            }

            if phase == .success {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 10 : 16, weight: .bold))
                    .foregroundStyle(Color.green)
            } else if phase == .failure {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 10 : 15, weight: .bold))
                    .foregroundStyle(Color.red)
            }
        }
        .frame(width: compact ? 24 : 48, height: compact ? 24 : 48)
        .onChange(of: phase, perform: { _ in syncSpin() })
        .onAppear { syncSpin() }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.75)
        case .scanning: return .white
        case .success: return .green
        case .failure: return .red
        }
    }

    private func syncSpin() {
        spin = false
        if phase == .scanning {
            DispatchQueue.main.async { spin = true }
        }
    }
}
