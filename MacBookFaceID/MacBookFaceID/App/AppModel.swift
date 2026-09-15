import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    private let spacebar = SpacebarTrigger()
    private let defaults = UserDefaults.standard

    @Published var status: AppStatus = .needsSetup
    @Published var isExpanded = false
    @Published var isHovering = false
    @Published var animationPhase: UnlockAnimationPhase = .idle
    @Published var isEnrolled = false
    @Published var hasSavedPassword = false
    @Published var bannerMessage: String?
    @Published var hasNotch = false
    @Published var notchHeight: CGFloat = 32
    @Published var notchWidth: CGFloat = 180
    @Published var showOnboarding = false
    @Published var showSettings = false
    @Published var identities: [IdentityRecord] = []
    @Published var lastSimilarity: Float = 0
    @Published var lastLiveness = LivenessVerdict.skipped
    @Published var aboutClicks = 0
    @Published var showProbe = false

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    @Published var animationStyle: AnimationStyle {
        didSet { defaults.set(animationStyle.rawValue, forKey: Keys.style) }
    }

    @Published var animationsHidden: Bool {
        didSet { defaults.set(animationsHidden, forKey: Keys.hideAnimations) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    @Published var livenessMode: LivenessMode {
        didSet { defaults.set(livenessMode.rawValue, forKey: Keys.liveness) }
    }

    @Published var matchThreshold: Double {
        didSet { defaults.set(matchThreshold, forKey: Keys.threshold) }
    }

    @Published var sessionIdleLimit: SessionIdleLimit {
        didSet { defaults.set(sessionIdleLimit.rawValue, forKey: Keys.idle) }
    }

    @Published var triggerOnLock: Bool {
        didSet { defaults.set(triggerOnLock, forKey: Keys.triggerLock) }
    }

    @Published var triggerOnWake: Bool {
        didSet { defaults.set(triggerOnWake, forKey: Keys.triggerWake) }
    }

    @Published var triggerOnSpace: Bool {
        didSet {
            defaults.set(triggerOnSpace, forKey: Keys.triggerSpace)
            if triggerOnSpace {
                spacebar.start()
            } else {
                spacebar.stop()
            }
        }
    }

    @Published var cameraIDBuiltIn: String {
        didSet { defaults.set(cameraIDBuiltIn, forKey: Keys.camBuiltIn) }
    }

    @Published var cameraIDExternal: String {
        didSet { defaults.set(cameraIDExternal, forKey: Keys.camExternal) }
    }

    @Published var opensAtLogin: Bool {
        didSet { applyLoginItem() }
    }

    let camera = CameraManager()
    let permissions = PermissionMonitor()
    let lockObserver = ScreenLockObserver()
    let vault = IdentityVault()
    let session = SessionGate()
    let unlock = UnlockPipeline()
    let enrollment = EnrollmentSession()
    let liveness = LivenessEngine()

    private var collapseTask: Task<Void, Never>?
    private var consecutiveHits = 0
    private var cameraRetainCount = 0
    private var isWatching = false
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let enabled = "faceUnlockEnabled"
        static let style = "animationStyle"
        static let hideAnimations = "hideAnimations"
        static let haptics = "hapticsEnabled"
        static let liveness = "livenessMode"
        static let threshold = "matchThreshold"
        static let idle = "sessionIdleLimit"
        static let triggerLock = "triggerOnLock"
        static let triggerWake = "triggerOnWake"
        static let triggerSpace = "triggerOnSpace"
        static let camBuiltIn = "cameraIDBuiltIn"
        static let camExternal = "cameraIDExternal"
        static let setupDone = "didCompleteSetup"
    }

    private init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        animationStyle = AnimationStyle(rawValue: defaults.string(forKey: Keys.style) ?? "") ?? .minimal
        animationsHidden = defaults.bool(forKey: Keys.hideAnimations)
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        livenessMode = LivenessMode(rawValue: defaults.string(forKey: Keys.liveness) ?? "") ?? .light
        matchThreshold = defaults.object(forKey: Keys.threshold) as? Double ?? Double(AppConstants.defaultMatchThreshold)
        sessionIdleLimit = SessionIdleLimit(rawValue: defaults.string(forKey: Keys.idle) ?? "") ?? .fifteenMinutes
        triggerOnLock = defaults.object(forKey: Keys.triggerLock) as? Bool ?? true
        triggerOnWake = defaults.object(forKey: Keys.triggerWake) as? Bool ?? true
        triggerOnSpace = defaults.object(forKey: Keys.triggerSpace) as? Bool ?? true
        cameraIDBuiltIn = defaults.string(forKey: Keys.camBuiltIn) ?? ""
        cameraIDExternal = defaults.string(forKey: Keys.camExternal) ?? ""
        opensAtLogin = SMAppService.mainApp.status == .enabled
        let geometry = IslandGeometry.current()
        hasNotch = geometry.hasNotch
        notchHeight = geometry.notchHeight
        notchWidth = geometry.notchWidth
    }

    func start() {
        refreshGeometry()
        permissions.refresh()
        camera.refreshDevices()
        applyPreferredCamera()

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

        spacebar.onSpace = { [weak self] in
            Task { @MainActor in self?.handleSpace() }
        }
        if triggerOnSpace {
            spacebar.start()
        }

        permissions.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshStatus() }
            }
            .store(in: &cancellables)

        session.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.reloadVaultPreview(); self?.refreshStatus() }
            }
            .store(in: &cancellables)

        if !defaults.bool(forKey: Keys.setupDone) || !isSetupComplete {
            showOnboarding = true
        } else {
            Task { await session.authorize(prompt: "Start Face Unlock") }
        }

        refreshStatus()
    }

    var isSetupComplete: Bool {
        isEnrolled && hasSavedPassword && permissions.allRequiredGranted
    }

    var embeddingEngineName: String {
        CoreMLFaceModel.shared == nil ? "Vision-aligned 512-d (DCT + LBP + landmarks)" : "Core ML model (FaceEmbedder)"
    }

    func completeSetup() {
        defaults.set(true, forKey: Keys.setupDone)
        showOnboarding = false
        refreshStatus()
    }

    func refreshGeometry() {
        let geometry = IslandGeometry.current()
        hasNotch = geometry.hasNotch
        notchHeight = geometry.notchHeight
        notchWidth = geometry.notchWidth
    }

    func setHovering(_ hovering: Bool) {
        let began = hovering && !isHovering
        isHovering = hovering
        if hovering {
            collapseTask?.cancel()
            isExpanded = true
            if began {
                if hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                if animationPhase == .failure, lockObserver.isLocked {
                    retryFromIsland()
                }
            }
        } else if !showSettings {
            scheduleCollapse()
        }
    }

    func toggleExpanded() {
        isExpanded.toggle()
        collapseTask?.cancel()
    }

    func retryFromIsland() {
        session.markActivity()
        if !isSetupComplete {
            showOnboarding = true
            return
        }
        if !session.isAuthorized {
            Task { await session.authorize() }
            return
        }
        if lockObserver.isLocked {
            animationPhase = .scanning
            liveness.reset()
            consecutiveHits = 0
            beginWatching()
        } else {
            showSettings = true
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 480_000_000)
            if !isHovering && !showSettings {
                isExpanded = false
            }
        }
    }

    func reloadVaultPreview() {
        guard let key = session.key else {
            vault.invalidateCache()
            identities = []
            isEnrolled = vault.boxExists
            return
        }
        do {
            let payload = try vault.load(using: key)
            identities = payload.identities
            isEnrolled = payload.identities.contains { !$0.embeddings.isEmpty }
            hasSavedPassword = payload.passwordUTF8?.isEmpty == false
        } catch {
            identities = []
        }
    }

    func refreshStatus() {
        permissions.refresh()
        reloadVaultPreview()

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
        if !session.isAuthorized {
            status = .sessionLocked
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
        liveness.reset()
        consecutiveHits = 0
        applyPreferredCamera()
        if isEnabled && isSetupComplete && session.isAuthorized && triggerOnLock {
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
                try? await Task.sleep(nanoseconds: 1_500_000_000)
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
        if lockObserver.isLocked && isEnabled && isSetupComplete && session.isAuthorized && triggerOnWake {
            applyPreferredCamera()
            animationPhase = .scanning
            beginWatching()
        }
    }

    func handleSpace() {
        guard triggerOnSpace, lockObserver.isLocked, isEnabled, isSetupComplete, session.isAuthorized else { return }
        animationPhase = .scanning
        liveness.reset()
        beginWatching()
    }

    func beginWatching() {
        guard isEnabled, isSetupComplete, session.isAuthorized else { return }
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
        if cameraRetainCount == 0 && !enrollment.isRunning {
            camera.stop()
        }
    }

    func applyPreferredCamera() {
        camera.refreshDevices()
        let screen = NSScreen.main
        let hasNotch = screen.map { IslandGeometry.geometry(on: $0).hasNotch } ?? false
        let usingBuiltIn = hasNotch || NSScreen.screens.count <= 1
        let preferred = usingBuiltIn ? cameraIDBuiltIn : cameraIDExternal
        if !preferred.isEmpty {
            camera.selectedDeviceID = preferred
        }
    }

    private func considerFrame(_ image: CGImage) async {
        guard isEnabled, isSetupComplete, session.isAuthorized, lockObserver.isLocked else { return }
        guard unlock.canAttempt() else { return }
        session.markActivity()

        do {
            let analysis = try await Task.detached(priority: .userInitiated) {
                try FaceEmbedder.analyze(image)
            }.value

            let verdict = liveness.observe(analysis, mode: livenessMode)
            lastLiveness = verdict
            if !verdict.passed {
                consecutiveHits = 0
                return
            }

            guard let key = session.key else { return }
            let gallery = try vault.enabledEmbeddings(using: key)
            let result = try MatchEngine.bestMatch(
                live: analysis.embedding,
                gallery: gallery,
                threshold: Float(matchThreshold)
            )
            lastSimilarity = result.similarity

            if result.similarity >= Float(matchThreshold) + AppConstants.tightMatchBoost {
                consecutiveHits += 2
            } else if result.passed {
                consecutiveHits += 1
            } else {
                consecutiveHits = 0
            }

            if consecutiveHits >= AppConstants.requiredConsecutiveHits {
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
        guard session.isAuthorized, lockObserver.isLocked, permissions.accessibilityTrusted else {
            animationPhase = .failure
            status = .failed
            bannerMessage = UnlockPipelineError.notReady.localizedDescription
            return
        }
        guard let key = session.key else { return }
        do {
            let password = try vault.password(using: key)
            try await unlock.performUnlock(password: password)
            animationPhase = .success
            status = .unlocked
        } catch {
            animationPhase = .failure
            status = .failed
            bannerMessage = error.localizedDescription
            consecutiveHits = 0
            if (error as? UnlockPipelineError) == .stillLocked {
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

    func savePassword(_ password: String) async throws {
        if !session.isAuthorized {
            await session.authorize(prompt: "Save your Mac password")
        }
        guard let key = session.key else { throw VaultError.locked }
        try vault.setPassword(password, using: key)
        hasSavedPassword = true
        refreshStatus()
    }

    func saveIdentity(_ identity: IdentityRecord) throws {
        guard let key = session.key else { throw VaultError.locked }
        try vault.upsertIdentity(identity, using: key)
        reloadVaultPreview()
        refreshStatus()
    }

    func setIdentityEnabled(_ identity: IdentityRecord, enabled: Bool) {
        guard let key = session.key else { return }
        var next = identity
        next.enabled = enabled
        try? vault.upsertIdentity(next, using: key)
        reloadVaultPreview()
    }

    func renameIdentity(_ identity: IdentityRecord, name: String) {
        guard let key = session.key else { return }
        var next = identity
        next.name = name
        try? vault.upsertIdentity(next, using: key)
        reloadVaultPreview()
    }

    func deleteIdentity(_ identity: IdentityRecord) {
        guard let key = session.key else { return }
        try? vault.deleteIdentity(id: identity.id, using: key)
        reloadVaultPreview()
        refreshStatus()
    }

    func eraseAllData() {
        try? vault.eraseAll()
        try? SessionKeychain.delete()
        session.lock()
        identities = []
        isEnrolled = false
        hasSavedPassword = false
        defaults.set(false, forKey: Keys.setupDone)
        bannerMessage = "Enrollment and saved password removed."
        refreshStatus()
    }

    func registerAboutClick() {
        aboutClicks += 1
        if aboutClicks >= 5 {
            showProbe = true
        }
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
        spacebar.stop()
        NSApp.terminate(nil)
    }
}
