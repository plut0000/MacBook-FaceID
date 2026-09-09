import SwiftUI

@main
struct MacBookFaceIDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra(
            AppConstants.featureName,
            systemImage: model.status.symbolName,
            isInserted: Binding(
                get: { !model.hasNotch },
                set: { _ in }
            )
        ) {
            MenuBarContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        // Keeps a Settings scene so the app has a SwiftUI lifecycle target.
        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
