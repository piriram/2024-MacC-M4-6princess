import SwiftUI

struct CameraDebugOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cameraSource: CameraSourceOption = RuntimeTestingOptions.cameraSource()
    @State private var cutoutEngine: CutoutEngineOption = RuntimeTestingOptions.cutoutEngine()
    @State private var previewTopPlacement: PreviewTopPlacementOption = RuntimeTestingOptions.previewTopPlacement()
    @State private var shutterVerticalPlacement: ShutterVerticalPlacementOption = RuntimeTestingOptions.shutterVerticalPlacement()
    @State private var hitTestLoggingEnabled: Bool = RuntimeTestingOptions.isHitTestLoggingEnabled()

    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera Source") {
                    Picker("Camera Source", selection: $cameraSource) {
                        ForEach(CameraSourceOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Cutout Engine") {
                    Picker("Cutout Engine", selection: $cutoutEngine) {
                        ForEach(CutoutEngineOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Camera Preview") {
                    Picker("Top Bar Placement", selection: $previewTopPlacement) {
                        ForEach(PreviewTopPlacementOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Overlap Top Bar: preview starts from y=0 and can cover top area")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Shutter Vertical") {
                    Picker("Vertical Placement", selection: $shutterVerticalPlacement) {
                        ForEach(ShutterVerticalPlacementOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Top Overflow: shutter top is 4pt above bottom bar. Center Y: shutter is centered vertically in filter area.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Interaction Debug") {
                    Toggle("Enable Hit Test Log", isOn: $hitTestLoggingEnabled)
                    Text("Logs tap location + hit-tested view, and whether the New Frame button area actually receives touch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug Testing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        RuntimeTestingOptions.setCameraSource(cameraSource)
                        RuntimeTestingOptions.setCutoutEngine(cutoutEngine)
                        RuntimeTestingOptions.setPreviewTopPlacement(previewTopPlacement)
                        RuntimeTestingOptions.setShutterVerticalPlacement(shutterVerticalPlacement)
                        RuntimeTestingOptions.setHitTestLoggingEnabled(hitTestLoggingEnabled)
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}
