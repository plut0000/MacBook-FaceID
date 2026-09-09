import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchController: NSObject {
    private let model: AppModel
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        let geometry = NotchGeometry.current()
        let panel = NSPanel(
            contentRect: geometry.collapsedWindowFrame(),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingView(rootView: NotchPanelView().environmentObject(model))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.panel = panel
        panel.orderFrontRegardless()
        applyFrame(animated: false)

        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyFrame(animated: true)
            }
            .store(in: &cancellables)

        model.lockObserver.$isLocked
            .removeDuplicates()
            .sink { [weak self] locked in
                self?.panel?.level = locked ? .screenSaver : .statusBar
            }
            .store(in: &cancellables)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.model.refreshGeometry()
                self?.applyFrame(animated: false)
            }
        }
    }

    private func applyFrame(animated: Bool) {
        guard let panel else { return }
        let geometry = NotchGeometry.current()
        let frame = model.isExpanded ? geometry.expandedWindowFrame() : geometry.collapsedWindowFrame()
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}
