import AVFoundation
import AppKit
import Combine
import CoreImage
import CoreMedia
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

struct CameraChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let isBuiltIn: Bool
}

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?
    @Published private(set) var devices: [CameraChoice] = []
    @Published var selectedDeviceID: String? {
        didSet {
            if oldValue != selectedDeviceID {
                reconfigure()
            }
        }
    }

    /// Invoked on the camera queue. The callback must finish (including any Vision
    /// work) before returning; do not hop to another queue while still holding the
    /// `CGImage`. The next frame is dropped until this returns, so memory stays
    /// bounded to one in-flight analysis image plus the latest preview snapshot.
    var onFrame: ((CGImage) -> Void)? {
        get {
            latestLock.lock()
            defer { latestLock.unlock() }
            return frameHandler
        }
        set {
            latestLock.lock()
            frameHandler = newValue
            latestLock.unlock()
        }
    }

    private let latestLock = NSLock()
    private var latestImage: CGImage?
    private var frameHandler: ((CGImage) -> Void)?
    private var isHandlingFrame = false
    private var currentInput: AVCaptureDeviceInput?

    var latestFrame: CGImage? {
        latestLock.lock()
        defer { latestLock.unlock() }
        return latestImage
    }

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.plut0000.MacBookFaceID.camera", qos: .userInitiated)
    private var configured = false
    private var lastFrameTime: CFTimeInterval = 0
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false
    ])

    override init() {
        super.init()
        refreshDevices()
    }

    func refreshDevices() {
        devices = Self.listCameras()
        if selectedDeviceID == nil {
            selectedDeviceID = devices.first(where: \.isBuiltIn)?.id ?? devices.first?.id
        }
    }

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
            self.latestLock.lock()
            self.latestImage = nil
            self.isHandlingFrame = false
            self.latestLock.unlock()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func selectDevice(id: String?) {
        DispatchQueue.main.async {
            self.selectedDeviceID = id
        }
    }

    private func reconfigure() {
        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let currentInput {
                self.session.removeInput(currentInput)
                self.currentInput = nil
            }
            self.configured = false
            self.session.commitConfiguration()
            do {
                try self.configureIfNeeded()
            } catch {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }
    }

    private func configureIfNeeded() throws {
        if configured { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .medium
        }

        guard let device = resolveDevice() else {
            session.commitConfiguration()
            throw CameraError.noDevice
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        currentInput = input

        if output.sampleBufferDelegate == nil {
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            output.setSampleBufferDelegate(self, queue: queue)
        }
        if session.outputs.isEmpty {
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                throw CameraError.cannotAddOutput
            }
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        session.commitConfiguration()
        configured = true
    }

    private func resolveDevice() -> AVCaptureDevice? {
        if let id = selectedDeviceID, let match = AVCaptureDevice(uniqueID: id) {
            return match
        }
        return Self.listCaptureDevices().first
    }

    static func listCameras() -> [CameraChoice] {
        listCaptureDevices().map { device in
            let builtIn = device.deviceType == .builtInWideAngleCamera
                || device.localizedName.localizedCaseInsensitiveContains("FaceTime")
            return CameraChoice(id: device.uniqueID, name: device.localizedName, isBuiltIn: builtIn)
        }
    }

    static func listCaptureDevices() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        types.append(.continuityCamera)
        types.append(.external)

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        var seen = Set<String>()
        var unique: [AVCaptureDevice] = []
        for device in discovery.devices {
            if seen.insert(device.uniqueID).inserted {
                unique.append(device)
            }
        }
        return unique.sorted { lhs, rhs in
            let leftBuiltIn = lhs.deviceType == .builtInWideAngleCamera
            let rightBuiltIn = rhs.deviceType == .builtInWideAngleCamera
            if leftBuiltIn != rightBuiltIn { return leftBuiltIn }
            return lhs.localizedName < rhs.localizedName
        }
    }

    /// Copies a downscaled bitmap. Callers must not retain this across frames.
    private func makeAnalysisImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let longest = max(extent.width, extent.height)
        let maxEdge = AppConstants.maxAnalysisLongEdge
        let source: CIImage
        let fromRect: CGRect
        if longest > maxEdge, longest > 0 {
            let scale = maxEdge / longest
            source = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            fromRect = source.extent
        } else {
            source = ciImage
            fromRect = extent
        }
        return ciContext.createCGImage(source, from: fromRect)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        let minInterval = 1.0 / AppConstants.matchingFPS

        latestLock.lock()
        guard let handler = frameHandler, !isHandlingFrame, now - lastFrameTime >= minInterval else {
            latestLock.unlock()
            return
        }
        isHandlingFrame = true
        lastFrameTime = now
        latestLock.unlock()

        defer {
            latestLock.lock()
            isHandlingFrame = false
            latestLock.unlock()
        }

        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            guard let image = makeAnalysisImage(from: pixelBuffer) else { return }
            latestLock.lock()
            latestImage = image
            latestLock.unlock()
            handler(image)
        }
    }
}
