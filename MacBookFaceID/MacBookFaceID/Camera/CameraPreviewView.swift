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

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.58, 210)
            let h = w * 1.22
            ZStack {
                Ellipse()
                    .stroke(lockedIn ? Color.green.opacity(0.95) : Color.white.opacity(0.88), lineWidth: 2.2)
                    .frame(width: w, height: h)
                PoseArrow(pose: pose)
                    .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: w * 0.42, height: h * 0.42)
                    .offset(arrowOffset(in: CGSize(width: w, height: h)))
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
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

private struct PoseArrow: Shape {
    var pose: HeadPose

    func path(in rect: CGRect) -> Path {
        if pose == .center {
            var path = Path()
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.32, dy: rect.height * 0.32))
            return path
        }
        var path = Path()
        let start = CGPoint(x: rect.midX, y: rect.midY)
        let end: CGPoint
        switch pose {
        case .up: end = CGPoint(x: rect.midX, y: rect.minY)
        case .down: end = CGPoint(x: rect.midX, y: rect.maxY)
        case .left: end = CGPoint(x: rect.minX, y: rect.midY)
        case .right: end = CGPoint(x: rect.maxX, y: rect.midY)
        case .upLeft: end = CGPoint(x: rect.minX, y: rect.minY)
        case .upRight: end = CGPoint(x: rect.maxX, y: rect.minY)
        case .downLeft: end = CGPoint(x: rect.minX, y: rect.maxY)
        case .downRight: end = CGPoint(x: rect.maxX, y: rect.maxY)
        case .center: end = start
        }
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head: CGFloat = 9
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - head * cos(angle - 0.5), y: end.y - head * sin(angle - 0.5)))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - head * cos(angle + 0.5), y: end.y - head * sin(angle + 0.5)))
        return path
    }
}
