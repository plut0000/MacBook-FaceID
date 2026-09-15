import SwiftUI

struct CameraPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Built-in display", selection: Binding(
                    get: { model.cameraIDBuiltIn },
                    set: { model.cameraIDBuiltIn = $0 }
                )) {
                    Text("Automatic").tag("")
                    ForEach(model.camera.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                Picker("External display", selection: Binding(
                    get: { model.cameraIDExternal },
                    set: { model.cameraIDExternal = $0 }
                )) {
                    Text("Automatic").tag("")
                    ForEach(model.camera.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
            } footer: {
                Text("Pick which camera to use on the built-in display versus an external monitor.")
            }

            if let error = model.camera.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Button("Refresh cameras") {
                    model.camera.refreshDevices()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            model.camera.refreshDevices()
        }
    }
}
