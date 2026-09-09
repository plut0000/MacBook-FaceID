import AppKit
import Combine
import ServiceManagement
import SwiftUI

enum AppStatus: String {
    case needsSetup
    case permissionNeeded
    case enrolled
    case watching
    case matching
    case unlocked
    case disabled
    case failed

    var label: String {
        switch self {
        case .needsSetup: return "Setup needed"
        case .permissionNeeded: return "Permission needed"
        case .enrolled: return "Enrolled"
        case .watching: return "Watching"
        case .matching: return "Matching"
        case .unlocked: return "Unlocked"
        case .disabled: return "Face Unlock off"
        case .failed: return "Unlock failed"
        }
    }

    var symbolName: String {
        switch self {
        case .needsSetup: return "person.crop.circle.badge.plus"
        case .permissionNeeded: return "exclamationmark.triangle"
        case .enrolled: return "checkmark.shield"
        case .watching: return "eye"
        case .matching: return "faceid"
        case .unlocked: return "lock.open"
        case .disabled: return "lock"
        case .failed: return "xmark.circle"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var status: AppStatus = .needsSetup
    @Published var isExpanded = false
    @Published var isHovering = false
    @Published var animationPhase: UnlockAnimationPhase = .idle
    @Published var enrollmentPreview: NSImage?
    @Published var isEnrolled = false
    @Published var hasSavedPassword = false
    @Published var isEnrolling = false
    @Published var enrollmentProgress: Double = 0
    @Published var bannerMessage: String?
    @Published var hasNotch = false
    @Published var notchHeight: CGFloat = 32
    @Published var notchWidth: CGFloat = 180
    @Published var showOnboarding = false
    @Published var showSettings = false

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    @Published var animationStyle: AnimationStyle {
        didSet { defaults.set(animationStyle.rawValue, forKey: Keys.style) }
    }

    @Published var opensAtLogin: Bool {
        didSet { applyLoginItem() }
    }

    let camera = CameraManager()
    let permissions = PermissionMonitor()
    let lockObserver = ScreenLockObserver()
    let templates = FaceTemplateStore()
    let unlock = UnlockCoordinator()

    private let defaults = UserDefaults.standard
    private var collapseTask: Task<Void, Never>?
    private var consecutiveHits = 0
    private var cameraRetainCount = 0
    private var isWatching = false
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let enabled = "faceUnlockEnabled"
        static let style = "animationStyle"
        static let setupDone = "didCompleteSetup"
    }

    private init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        animationStyle = AnimationStyle(rawValue: defaults.string(forKey: Keys.style) ?? "") ?? .minimal
        opensAtLogin = SMAppService.mainApp.status == .enabled
        let geometry = NotchGeometry.current()
        hasNotch = geometry.hasNotch
        notchHeight = geometry.notchHeight
        notchWidth = geometry.notchWidth
    }

    func start() {
        refreshGeometry()
        permissions.refresh()
        isEnrolled = templates.hasEnrollment
        enrollmentPreview = templates.loadThumbnail()
        hasSavedPassword = LoginPasswordKeychain.hasPassword()

        lockObserver.onLocked = { [weak self] in
            Task { @MainActor in self?.handleLocked() }
        }
        lockObserver.onUnlocked = { [weak self] in
            Task { @MainActor in self?.handleUnlocked() }
        }
        lockObserver.onDisplayWake = { [weak self] in
            Task { @MainActor in self?.handleDisplayWake() }
        }
        lockObserver.start()

        permissions.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshStatus() }
            }
            .store(in: &cancellables)

        if !defaults.bool(forKey: Keys.setupDone) || !isSetupComplete {
            showOnboarding = true
        }

        if isEnabled && isSetupComplete && lockObserver.isLocked {
            beginWatching()
        }
        refreshStatus()
    }

    var isSetupComplete: Bool {
        isEnrolled && hasSavedPassword && permissions.allRequiredGranted
    }

    func completeSetup() {
        defaults.set(true, forKey: Keys.setupDone)
        showOnboarding = false
        refreshStatus()
    }

    func refreshGeometry() {
        let geometry = NotchGeometry.current()
        hasNotch = geometry.hasNotch
        notchHeight = geometry.notchHeight
        notchWidth = geometry.notchWidth
    }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            collapseTask?.cancel()
            isExpanded = true
        } else if !showSettings {
            scheduleCollapse()
        }
    }

    func toggleExpanded() {
        isExpanded.toggle()
        collapseTask?.cancel()
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !isHovering && !showSettings {
                isExpanded = false
            }
        }
    }

    func refreshStatus() {
        permissions.refresh()
        isEnrolled = templates.hasEnrollment
        hasSavedPassword = LoginPasswordKeychain.hasPassword()

        if !isEnabled {
            status = .disabled
            return
        }
        if !permissions.allRequiredGranted {
            status = .permissionNeeded
            return
        }
        if !isEnrolled || !hasSavedPassword {
            status = .needsSetup
            return
        }
        if lockObserver.isLocked && camera.isRunning {
            status = consecutiveHits > 0 ? .matching : .watching
            return
        }
        status = .enrolled
    }

    func handleLocked() {
        unlock.resetFailures()
        if isEnabled && isSetupComplete {
            animationPhase = .scanning
            beginWatching()
        }
        refreshStatus()
    }

    func handleUnlocked() {
        stopWatchingIfUnused()
        consecutiveHits = 0
        if animationPhase == .scanning || status == .watching || status == .matching {
            animationPhase = .success
            status = .unlocked
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                if !self.lockObserver.isLocked {
                    self.animationPhase = .idle
                    self.refreshStatus()
                }
            }
        } else {
            animationPhase = .idle
            refreshStatus()
        }
    }

    func handleDisplayWake() {
        if lockObserver.isLocked && isEnabled && isSetupComplete {
            beginWatching()
        }
    }

    func beginWatching() {
        guard isEnabled, isSetupComplete else { return }
        if !isWatching {
            isWatching = true
            retainCamera()
        }
        camera.onFrame = { [weak self] image in
            Task { @MainActor in
                await self?.considerFrame(image)
            }
        }
        camera.start()
        status = .watching
        if animationPhase == .idle {
            animationPhase = .scanning
        }
    }

    func stopWatchingIfUnused() {
        camera.onFrame = nil
        if isWatching {
            isWatching = false
            releaseCamera()
        }
    }

    func retainCamera() {
        cameraRetainCount += 1
        camera.start()
    }

    func releaseCamera() {
        cameraRetainCount = max(0, cameraRetainCount - 1)
        if cameraRetainCount == 0 {
            camera.stop()
        }
    }

    private func considerFrame(_ image: CGImage) async {
        guard isEnabled, isSetupComplete, lockObserver.isLocked else { return }
        if !unlock.canAttempt() { return }

        do {
            let distance = try await Task.detached(priority: .userInitiated) {
                let analysis = try FaceAnalyzer.analyze(image)
                return try FaceTemplateStore().bestDistance(to: analysis.embedding)
            }.value
            let matched = FaceAnalyzer.recordHit(distance: distance, consecutiveHits: &consecutiveHits)
            if matched {
                status = .matching
                animationPhase = .scanning
                await attemptUnlock()
            } else if consecutiveHits > 0 {
                status = .matching
            }
        } catch {
            consecutiveHits = 0
        }
    }

    private func attemptUnlock() async {
        do {
            try await unlock.performUnlock()
            animationPhase = .success
            status = .unlocked
        } catch {
            animationPhase = .failure
            status = .failed
            bannerMessage = error.localizedDescription
            consecutiveHits = 0
            if (error as? UnlockCoordinatorError) == .stillLocked {
                // Wrong password would lock the account if we kept typing.
                stopWatchingIfUnused()
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.animationPhase == .failure {
                    self.animationPhase = self.lockObserver.isLocked ? .scanning : .idle
                }
            }
        }
    }

    func enrollFromLiveCamera() async {
        guard !isEnrolling else { return }
        isEnrolling = true
        enrollmentProgress = 0
        bannerMessage = nil
        retainCamera()
        defer {
            isEnrolling = false
            releaseCamera()
        }

        var collected: [FaceFrameAnalysis] = []
        var thumbnail: NSImage?
        let deadline = Date().addingTimeInterval(AppConstants.enrollmentCaptureSeconds)
        let started = Date()

        while Date() < deadline && collected.count < AppConstants.enrollmentTargetTemplates {
            enrollmentProgress = min(1, Date().timeIntervalSince(started) / AppConstants.enrollmentCaptureSeconds)
            if let snapshot = camera.latestFrame {
                do {
                    let analysis = try FaceAnalyzer.analyze(
                        snapshot,
                        requireQuality: AppConstants.enrollmentMinQuality
                    )
                    collected.append(analysis)
                    if thumbnail == nil {
                        thumbnail = FaceAnalyzer.cropFace(from: snapshot, boundingBox: analysis.boundingBox)
                    }
                    bannerMessage = nil
                } catch {
                    bannerMessage = error.localizedDescription
                }
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        guard collected.count >= AppConstants.enrollmentMinTemplates else {
            bannerMessage = "Could not capture a clear face. Sit in good light and look at the camera."
            return
        }

        do {
            try templates.save(analyses: collected, thumbnail: thumbnail)
            isEnrolled = true
            enrollmentPreview = templates.loadThumbnail() ?? thumbnail
            bannerMessage = "Face enrolled on this Mac. Templates stay local."
            refreshStatus()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func savePassword(_ password: String) throws {
        try LoginPasswordKeychain.save(password)
        hasSavedPassword = true
        refreshStatus()
    }

    func eraseAllData() {
        try? templates.erase()
        try? LoginPasswordKeychain.delete()
        isEnrolled = false
        hasSavedPassword = false
        enrollmentPreview = nil
        defaults.set(false, forKey: Keys.setupDone)
        bannerMessage = "Enrollment and saved password removed."
        refreshStatus()
    }

    private var applyingLoginItem = false

    func applyLoginItem() {
        guard !applyingLoginItem else { return }
        applyingLoginItem = true
        defer { applyingLoginItem = false }
        do {
            if opensAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            bannerMessage = error.localizedDescription
            opensAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func quit() {
        stopWatchingIfUnused()
        NSApp.terminate(nil)
    }
}
