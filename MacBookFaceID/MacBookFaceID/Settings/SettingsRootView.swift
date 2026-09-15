import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case face
    case recognition
    case camera
    case password
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .face: return "Your Face"
        case .recognition: return "Recognition"
        case .camera: return "Camera"
        case .password: return "Password"
        case .general: return "General"
        }
    }

    var symbol: String {
        switch self {
        case .face: return "person.crop.circle"
        case .recognition: return "waveform"
        case .camera: return "camera"
        case .password: return "key"
        case .general: return "gearshape"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pane: SettingsPane = .face

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 180, max: 220)
        } detail: {
            Group {
                switch pane {
                case .face: FacePane()
                case .recognition: RecognitionPane()
                case .camera: CameraPane()
                case .password: PasswordPane()
                case .general: GeneralPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(pane.title)
        }
        .frame(minWidth: 680, minHeight: 480)
        .onAppear {
            model.session.markActivity()
            model.permissions.refresh()
            model.reloadVaultPreview()
        }
    }
}
