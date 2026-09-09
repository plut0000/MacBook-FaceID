import AppKit
import AVFoundation
import ApplicationServices
import Combine

@MainActor
final class PermissionMonitor: ObservableObject {
    @Published private(set) var camera: AVAuthorizationStatus = .notDetermined
    @Published private(set) var accessibilityTrusted = false

    var cameraGranted: Bool { camera == .authorized }
    var allRequiredGranted: Bool { cameraGranted && accessibilityTrusted }

    func refresh() {
        camera = AVCaptureDevice.authorizationStatus(for: .video)
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted ? .authorized : AVCaptureDevice.authorizationStatus(for: .video)
    }

    @discardableResult
    func promptAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessibilityTrusted = trusted
        return trusted
    }

    func openCameraSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    }

    func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openSystemSettings(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
