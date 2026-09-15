import SwiftUI

@main
struct MacBookFaceIDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra(
            AppConstants.featureName,
            systemImage: model.status.symbolName
        ) {
            MenuBarContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environmentObject(model)
        }
    }
}
