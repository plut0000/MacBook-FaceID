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
        case .password: return "key.fill"
        case .general: return "gearshape"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pane: SettingsPane = .face

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsPane.allCases) { item in
                    Button {
                        pane = item
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(pane == item ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 176)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Group {
                switch pane {
                case .face: FacePane()
                case .recognition: RecognitionPane()
                case .camera: CameraPane()
                case .password: PasswordPane()
                case .general: GeneralPane()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 680, minHeight: 500)
        .onAppear {
            model.session.markActivity()
            model.permissions.refresh()
            model.reloadVaultPreview()
        }
    }
}
