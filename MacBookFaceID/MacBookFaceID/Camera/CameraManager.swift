import AVFoundation
import AppKit
import Combine
import CoreImage
import QuartzCore

enum CameraError: LocalizedError {
    case noDevice
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "No camera is available."
        case .cannotAddInput:
            return "The camera could not be opened."
        case .cannotAddOutput:
            return "The camera output could not be configured."
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    /// Invoked on the camera queue. Keep the callback short.
    var onFrame: ((CGImage) -> Void)?

    private let latestLock = NSLock()
    private var latestImage: CGImage?

    /// Most recent frame, safe to read from any queue.
    var latestFrame: CGImage? {
        latestLock.lock()
        defer { latestLock.unlock() }
        return latestImage
    }

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.plut0000.MacBookFaceID.camera", qos: .userInitiated)
    private var configured = false
    private var lastFrameTime: CFTimeInterval = 0
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func start() {
        DispatchQueue.main.async { self.lastError = nil }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async { self.isRunning = true }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureIfNeeded() throws {
        if configured { return }
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = Self.preferredCamera() else {
            session.commitConfiguration()
            throw CameraError.noDevice
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.cannotAddOutput
        }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        session.commitConfiguration()
        configured = true
    }

    /// Prefer the built-in FaceTime camera over Continuity Camera.
    static func preferredCamera() -> AVCaptureDevice? {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            types.append(.continuityCamera)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )

        if let builtIn = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return builtIn
        }
        if let faceTime = discovery.devices.first(where: {
            $0.localizedName.localizedCaseInsensitiveContains("FaceTime")
        }) {
            return faceTime
        }
        return discovery.devices.first ?? AVCaptureDevice.default(for: .video)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        if now - lastFrameTime < (1.0 / AppConstants.matchingFPS) {
            return
        }
        lastFrameTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        latestLock.lock()
        latestImage = image
        latestLock.unlock()
        onFrame?(image)
    }
}
