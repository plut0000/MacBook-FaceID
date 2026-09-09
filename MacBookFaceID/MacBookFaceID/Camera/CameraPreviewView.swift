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
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}

struct FaceGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.62, 180)
            let h = w * 1.28
            Ellipse()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: w, height: h)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}
