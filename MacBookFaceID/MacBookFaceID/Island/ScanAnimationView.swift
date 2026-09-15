import SwiftUI

struct ScanAnimationView: View {
    let style: AnimationStyle
    let phase: UnlockAnimationPhase
    var compact: Bool = false

    var body: some View {
        Group {
            switch style {
            case .minimal:
                MinimalScan(phase: phase, compact: compact)
            case .classic:
                ClassicScan(phase: phase, compact: compact)
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

private struct MinimalScan: View {
    let phase: UnlockAnimationPhase
    let compact: Bool
    @State private var sweep = false
    @State private var glow = false

    var body: some View {
        let size: CGFloat = compact ? 22 : 44
        ZStack {
            Capsule()
                .stroke(color.opacity(0.22), lineWidth: compact ? 1.6 : 2.4)
            Capsule()
                .trim(from: sweep ? 0.08 : 0.55, to: sweep ? 0.92 : 0.9)
                .stroke(color, style: StrokeStyle(lineWidth: compact ? 1.8 : 2.6, lineCap: .round))
                .rotationEffect(.degrees(phase == .scanning ? (sweep ? 180 : 0) : 0))
                .scaleEffect(glow && phase == .scanning ? 1.06 : 1)
                .shadow(color: color.opacity(phase == .scanning ? 0.7 : 0), radius: compact ? 3 : 7)

            if phase == .success {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 10 : 16, weight: .bold))
                    .foregroundStyle(Color.green)
                    .transition(.scale.combined(with: .opacity))
            } else if phase == .failure {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 10 : 15, weight: .bold))
                    .foregroundStyle(Color.red)
            } else {
                Circle()
                    .fill(color.opacity(0.95))
                    .frame(width: compact ? 4 : 6, height: compact ? 4 : 6)
            }
        }
        .frame(width: size, height: size * 0.72)
        .onChange(of: phase) { _, _ in sync() }
        .onAppear { sync() }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.72)
        case .scanning: return .white
        case .success: return .green
        case .failure: return .red
        }
    }

    private func sync() {
        sweep = false
        glow = false
        if phase == .scanning {
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    sweep = true
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }
}

private struct ClassicScan: View {
    let phase: UnlockAnimationPhase
    let compact: Bool
    @State private var travel = false

    var body: some View {
        let size: CGFloat = compact ? 24 : 48
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: compact ? 4 : 7, style: .continuous)
                    .trim(from: 0.07, to: 0.18)
                    .stroke(color.opacity(1 - Double(index) * 0.16), style: StrokeStyle(
                        lineWidth: compact ? 1.5 : 2.2,
                        lineCap: .round
                    ))
                    .padding(CGFloat(index) * (compact ? 2.2 : 3.8))
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0), color, color.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: compact ? 1.4 : 2)
                .offset(y: travel ? size * 0.28 : -size * 0.28)
                .opacity(phase == .scanning ? 1 : 0)

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
        .frame(width: size, height: size)
        .onChange(of: phase) { _, _ in sync() }
        .onAppear { sync() }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.75)
        case .scanning: return .white
        case .success: return .green
        case .failure: return .red
        }
    }

    private func sync() {
        travel = false
        if phase == .scanning {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    travel = true
                }
            }
        }
    }
}
