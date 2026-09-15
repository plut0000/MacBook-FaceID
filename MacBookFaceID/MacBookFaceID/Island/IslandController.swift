import AppKit
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class IslandController: NSObject {
    private let model: AppModel
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        let geometry = IslandGeometry.current()
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
        panel.hasShadow = !geometry.hasNotch
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.alphaValue = model.animationsHidden ? 0 : 1
        panel.ignoresMouseEvents = model.animationsHidden

        let hosting = NSHostingView(rootView: IslandView().environmentObject(model))
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

        model.$animationsHidden
            .sink { [weak self] hidden in
                self?.applyVisibility(hidden: hidden)
            }
            .store(in: &cancellables)

        model.lockObserver.$isLocked
            .removeDuplicates()
            .sink { [weak self] locked in
                self?.panel?.level = locked
                    ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 12)
                    : .statusBar
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

    private func applyVisibility(hidden: Bool) {
        guard let panel else { return }
        panel.ignoresMouseEvents = hidden
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = hidden ? 0 : 1
        }
        if !hidden {
            panel.orderFrontRegardless()
        }
    }

    private func applyFrame(animated: Bool) {
        guard let panel else { return }
        let geometry = IslandGeometry.current()
        let frame = model.isExpanded ? geometry.expandedWindowFrame() : geometry.collapsedWindowFrame()
        panel.hasShadow = !geometry.hasNotch || model.isExpanded
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.34
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.94, 0.30, 1.0)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}
