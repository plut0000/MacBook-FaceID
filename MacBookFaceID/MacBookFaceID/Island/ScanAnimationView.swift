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
        case .scanning: return "Scanning"
        case .success: return "Unlocked"
        case .failure: return "Did not match"
        }
    }
}

private struct MinimalScan: View {
    let phase: UnlockAnimationPhase
    let compact: Bool

    var body: some View {
        let size: CGFloat = compact ? 18 : 36
        TimelineView(.animation(minimumInterval: 1 / 30, paused: phase != .scanning)) { timeline in
            let turn = phase == .scanning
                ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.95) / 0.95
                : 0
            ZStack {
                Capsule()
                    .stroke(color.opacity(phase == .idle ? 0.28 : 0.18), lineWidth: compact ? 1.15 : 1.4)
                Capsule()
                    .trim(from: 0.08, to: phase == .scanning ? 0.42 : (phase == .idle ? 0.0 : 1))
                    .stroke(color, style: StrokeStyle(lineWidth: compact ? 1.2 : 1.5, lineCap: .round))
                    .rotationEffect(.degrees(turn * 360))
                    .opacity(phase == .scanning ? 1 : (phase == .idle ? 0 : 0.85))

                if phase == .success {
                    HairlineCheck()
                        .stroke(AppConstants.successStroke, style: StrokeStyle(lineWidth: compact ? 1.35 : 1.7, lineCap: .round, lineJoin: .round))
                        .frame(width: size * 0.42, height: size * 0.42)
                } else if phase == .failure {
                    HairlineX()
                        .stroke(AppConstants.failureStroke, style: StrokeStyle(lineWidth: compact ? 1.25 : 1.55, lineCap: .round))
                        .frame(width: size * 0.34, height: size * 0.34)
                }
            }
            .frame(width: size, height: size * 0.78)
        }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.7)
        case .scanning: return .white.opacity(0.92)
        case .success: return AppConstants.successStroke
        case .failure: return AppConstants.failureStroke
        }
    }
}

private struct ClassicScan: View {
    let phase: UnlockAnimationPhase
    let compact: Bool

    var body: some View {
        let size: CGFloat = compact ? 18 : 36
        TimelineView(.animation(minimumInterval: 1 / 30, paused: phase != .scanning)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let travel = phase == .scanning ? CGFloat(sin(t * .pi * 1.15) * 0.5 + 0.5) : 0.5
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    CornerBracket()
                        .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: compact ? 1.15 : 1.4, lineCap: .round, lineJoin: .round))
                        .padding(compact ? 1.5 : 2.5)
                        .rotationEffect(.degrees(Double(index) * 90))
                }

                Capsule()
                    .fill(color.opacity(phase == .scanning ? 0.9 : 0))
                    .frame(width: size * 0.62, height: compact ? 1 : 1.15)
                    .offset(y: (travel - 0.5) * size * 0.52)

                if phase == .success {
                    HairlineCheck()
                        .stroke(AppConstants.successStroke, style: StrokeStyle(lineWidth: compact ? 1.35 : 1.7, lineCap: .round, lineJoin: .round))
                        .frame(width: size * 0.42, height: size * 0.42)
                } else if phase == .failure {
                    HairlineX()
                        .stroke(AppConstants.failureStroke, style: StrokeStyle(lineWidth: compact ? 1.25 : 1.55, lineCap: .round))
                        .frame(width: size * 0.34, height: size * 0.34)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private var color: Color {
        switch phase {
        case .idle: return .white.opacity(0.62)
        case .scanning: return .white.opacity(0.92)
        case .success: return AppConstants.successStroke
        case .failure: return AppConstants.failureStroke
        }
    }
}

private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.28
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        return path
    }
}

private struct HairlineCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.78))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.88, y: rect.minY + rect.height * 0.18))
        return path
    }
}

private struct HairlineX: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
