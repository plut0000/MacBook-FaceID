import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchController?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel.shared
        model.start()

        if model.hasNotch {
            notchController = NotchController(model: model)
            notchController?.show()
        }

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
                    content: ScrollView {
                        SettingsView().environmentObject(AppModel.shared)
                    }
                    .frame(width: 400, height: 560)
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
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeUtilityWindow<Content: View>(title: String, content: Content) -> NSWindow {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        let fitted = hosting.view.fittingSize
        window.setContentSize(NSSize(
            width: max(fitted.width, 420),
            height: max(fitted.height, 360)
        ))
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
