import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer = previewLayer
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been used")
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}

struct FaceGuideOverlay: View {
    var pose: HeadPose = .center
    var lockedIn = false
    var progress: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.52, 188)
            let h = w * 1.28
            ZStack {
                Color.black.opacity(0.32)
                    .mask(
                        Rectangle()
                            .overlay {
                                Ellipse()
                                    .frame(width: w, height: h)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    )

                Ellipse()
                    .stroke(Color.white.opacity(lockedIn ? 0.82 : 0.38), lineWidth: 1)
                    .frame(width: w, height: h)

                Ellipse()
                    .trim(from: 0, to: CGFloat(max(progress, lockedIn ? 0.04 : 0)))
                    .stroke(
                        Color.white.opacity(0.94),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: w, height: h)

                if pose != .center {
                    PoseChevron(pose: pose)
                        .stroke(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 14)
                        .offset(arrowOffset(in: CGSize(width: w, height: h)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private func arrowOffset(in size: CGSize) -> CGSize {
        let x: CGFloat
        let y: CGFloat
        switch pose {
        case .center: return .zero
        case .up: x = 0; y = -size.height * 0.28
        case .down: x = 0; y = size.height * 0.28
        case .left: x = -size.width * 0.28; y = 0
        case .right: x = size.width * 0.28; y = 0
        case .upLeft: x = -size.width * 0.22; y = -size.height * 0.22
        case .upRight: x = size.width * 0.22; y = -size.height * 0.22
        case .downLeft: x = -size.width * 0.22; y = size.height * 0.22
        case .downRight: x = size.width * 0.22; y = size.height * 0.22
        }
        return CGSize(width: x, height: y)
    }
}

private struct PoseChevron: Shape {
    var pose: HeadPose

    func path(in rect: CGRect) -> Path {
        let angle: CGFloat
        switch pose {
        case .up: angle = -.pi / 2
        case .down: angle = .pi / 2
        case .left: angle = .pi
        case .right: angle = 0
        case .upLeft: angle = -.pi * 0.75
        case .upRight: angle = -.pi * 0.25
        case .downLeft: angle = .pi * 0.75
        case .downRight: angle = .pi * 0.25
        case .center: angle = 0
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let length = min(rect.width, rect.height) * 0.42
        func point(_ theta: CGFloat, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius)
        }
        var path = Path()
        path.move(to: point(angle + 0.85, length))
        path.addLine(to: point(angle, length * 0.15))
        path.addLine(to: point(angle - 0.85, length))
        return path
    }
}
