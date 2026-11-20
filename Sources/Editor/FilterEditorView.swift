import CoreImage
import SwiftUI

struct FilterEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var draftParameters: FilterParameters
    @State private var presetNameInput: String = ""
    @State private var showSavePrompt: Bool = false
    @State private var previewImage: UIImage?

    private let sampleOriginalData: Data?
    private let reEditTargetItem: CapturedPhotoItem?
    private let previewEngine = FilterEngine()

    init(
        initialParameters: FilterParameters,
        sampleOriginalData: Data? = nil,
        reEditTargetItem: CapturedPhotoItem? = nil
    ) {
        _draftParameters = State(initialValue: initialParameters)
        self.sampleOriginalData = sampleOriginalData
        self.reEditTargetItem = reEditTargetItem
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    ZStack {
                        Color.black
                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text("LIVE SENSOR PREVIEW")
                                .font(RetroTheme.monoLabel(11))
                                .foregroundColor(RetroTheme.mutedText)
                        }
                    }
                    .frame(height: 250)
                    .overlay(Rectangle().stroke(RetroTheme.hairline, lineWidth: 1))

                    AdjustmentControls(parameters: $draftParameters)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("CANCEL") { dismiss() }
                        .font(RetroTheme.monoLabel(11, weight: .semibold))
                        .foregroundColor(RetroTheme.mutedText)
                }
                ToolbarItem(placement: .principal) {
                    Text(reEditTargetItem == nil ? "CUSTOM RECIPE" : "RE-EDIT EXPOSURE")
                        .font(RetroTheme.monoLabel(12, weight: .semibold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("SAVE") {
                            showSavePrompt = true
                        }
                        .font(RetroTheme.monoLabel(11, weight: .semibold))
                        .foregroundColor(.white)

                        Button("APPLY") {
                            applyChanges()
                            dismiss()
                        }
                        .font(RetroTheme.monoLabel(11, weight: .bold))
                        .foregroundColor(RetroTheme.amberAccent)
                    }
                }
            }
            .toolbarBackground(RetroTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Save Custom Preset", isPresented: $showSavePrompt) {
                TextField("e.g. Tokyo 2004", text: $presetNameInput)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    appState.filterLibrary.saveCustomPreset(name: presetNameInput, parameters: draftParameters)
                    appState.cameraManager.syncFilterState(
                        parameters: draftParameters,
                        presetName: presetNameInput.isEmpty ? "Custom" : presetNameInput
                    )
                    dismiss()
                }
            } message: {
                Text("Save this color & grain recipe to your filter dial.")
            }
            .onAppear {
                renderPreview()
            }
            .onChange(of: draftParameters) { _, newValue in
                if reEditTargetItem == nil {
                    appState.filterLibrary.activeParameters = newValue
                    appState.cameraManager.syncFilterState(
                        parameters: newValue,
                        presetName: appState.filterLibrary.currentPreset.name
                    )
                }
                renderPreview()
            }
        }
    }

    private func applyChanges() {
        if let target = reEditTargetItem {
            appState.libraryManager.updateReEditedPhoto(
                itemID: target.id,
                newParameters: draftParameters,
                newFilterName: "Edited (\(target.metadata.filterName))"
            )
        } else {
            appState.filterLibrary.activeParameters = draftParameters
            appState.cameraManager.syncFilterState(
                parameters: draftParameters,
                presetName: appState.filterLibrary.currentPreset.name
            )
        }
    }

    private func renderPreview() {
        let params = draftParameters
        let sourceData = sampleOriginalData
            ?? appState.libraryManager.items.first.flatMap { appState.libraryManager.loadOriginalData(for: $0) }

        DispatchQueue.global(qos: .userInitiated).async {
            let baseCI: CIImage
            if let sourceData, let loaded = CIImage(data: sourceData, options: [.applyOrientationProperty: true]) {
                let scale = min(1.0, 720.0 / max(loaded.extent.width, loaded.extent.height))
                baseCI = loaded.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            } else {
                baseCI = Self.generateCalibrationChart()
            }

            let outCI = previewEngine.render(
                source: baseCI,
                parameters: params,
                seed: 200505,
                isRealtimePreview: false
            )

            if let cg = ImageProcessor.shared.ciContext.createCGImage(outCI, from: outCI.extent) {
                let ui = UIImage(cgImage: cg)
                DispatchQueue.main.async {
                    self.previewImage = ui
                }
            }
        }
    }

    private static func generateCalibrationChart() -> CIImage {
        let size = CGSize(width: 480, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let colors: [UIColor] = [
                UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
                UIColor(red: 0.85, green: 0.72, blue: 0.58, alpha: 1),
                UIColor(red: 0.22, green: 0.48, blue: 0.65, alpha: 1),
                UIColor(red: 0.78, green: 0.28, blue: 0.24, alpha: 1),
                UIColor(red: 0.34, green: 0.56, blue: 0.36, alpha: 1),
                UIColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1)
            ]
            let stripeW = size.width / CGFloat(colors.count)
            for (idx, color) in colors.enumerated() {
                color.setFill()
                ctx.fill(CGRect(x: CGFloat(idx) * stripeW, y: 0, width: stripeW, height: size.height))
            }
        }
        return CIImage(image: img) ?? CIImage(color: .gray).cropped(to: CGRect(origin: .zero, size: size))
    }
}
