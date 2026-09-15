import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandController: IslandController?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel.shared
        model.start()

        islandController = IslandController(model: model)
        islandController?.show()

        model.$showOnboarding
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.setOnboardingVisible(show)
            }
            .store(in: &cancellables)

        model.$showSettings
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.setSettingsVisible(show)
            }
            .store(in: &cancellables)

        if model.showOnboarding {
            setOnboardingVisible(true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModel.shared.showSettings = true
        return false
    }

    private func setOnboardingVisible(_ show: Bool) {
        if show {
            if onboardingWindow == nil {
                onboardingWindow = makeUtilityWindow(
                    title: "Set up Face Unlock",
                    width: 460,
                    height: 640,
                    resizable: false,
                    content: OnboardingView().environmentObject(AppModel.shared)
                )
                onboardingWindow?.delegate = self
            }
            present(onboardingWindow)
        } else {
            onboardingWindow?.close()
            onboardingWindow = nil
        }
    }

    private func setSettingsVisible(_ show: Bool) {
        if show {
            if settingsWindow == nil {
                settingsWindow = makeUtilityWindow(
                    title: "Face Unlock",
                    width: 740,
                    height: 520,
                    resizable: true,
                    content: SettingsRootView().environmentObject(AppModel.shared)
                )
                settingsWindow?.delegate = self
            }
            present(settingsWindow)
        } else {
            settingsWindow?.close()
            settingsWindow = nil
        }
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeUtilityWindow<Content: View>(
        title: String,
        width: CGFloat,
        height: CGFloat,
        resizable: Bool,
        content: Content
    ) -> NSWindow {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        var mask: NSWindow.StyleMask = [.titled, .closable]
        if resizable {
            mask.insert(.resizable)
        }
        window.styleMask = mask
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: width, height: height))
        window.minSize = NSSize(width: resizable ? 640 : width, height: resizable ? 420 : height)
        return window
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            AppModel.shared.showSettings = false
            settingsWindow = nil
        }
        if notification.object as? NSWindow === onboardingWindow {
            AppModel.shared.showOnboarding = false
            onboardingWindow = nil
        }
    }
}
