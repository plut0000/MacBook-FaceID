import SwiftUI

struct CameraPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Camera")
                .font(.title2.weight(.semibold))
            Text("Pick which camera to use on the built-in display versus an external monitor.")
                .font(.callout)
                .foregroundStyle(.secondary)

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

            if let error = model.camera.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button("Refresh cameras") {
                model.camera.refreshDevices()
            }
        }
        .onAppear {
            model.camera.refreshDevices()
        }
    }
}
