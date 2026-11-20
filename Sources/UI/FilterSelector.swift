import SwiftUI

struct FilterSelector: View {
    @ObservedObject var filterLibrary: FilterLibrary
    let onFilterChanged: (FilterPreset) -> Void
    let onOpenEditor: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Classic iOS 7/8 horizontal filmstrip / preset strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterLibrary.presets) { preset in
                        let isSelected = preset.id == filterLibrary.selectedPresetID
                        Button {
                            filterLibrary.selectPreset(preset)
                            onFilterChanged(preset)
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.code)
                                    .font(RetroTheme.monoLabel(11, weight: .bold))
                                    .foregroundColor(isSelected ? .black : .white)
                                    .frame(width: 54, height: 34)
                                    .background(isSelected ? RetroTheme.amberAccent : RetroTheme.elevatedSurface)
                                    .overlay(
                                        Rectangle()
                                            .stroke(isSelected ? RetroTheme.amberAccent : RetroTheme.hairline, lineWidth: 1)
                                    )

                                Text(preset.name.uppercased())
                                    .font(RetroTheme.monoLabel(8.5, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? RetroTheme.amberAccent : RetroTheme.mutedText)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }

            HStack(spacing: 12) {
                TactileSlider(
                    label: "INTENSITY",
                    value: $filterLibrary.activeParameters.intensity,
                    range: 0...1,
                    format: "%.2f"
                )

                TactileSlider(
                    label: "GRAIN",
                    value: $filterLibrary.activeParameters.grainIntensity,
                    range: 0...1,
                    format: "%.2f"
                )
            }
            .padding(.horizontal, 14)

            HStack {
                Button {
                    filterLibrary.resetCurrentPreset()
                    onFilterChanged(filterLibrary.currentPreset)
                } label: {
                    Text("RESET")
                        .font(RetroTheme.monoLabel(10, weight: .semibold))
                        .foregroundColor(RetroTheme.mutedText)
                }

                Spacer()

                Button {
                    onOpenEditor()
                } label: {
                    Label("PRO RECIPE & GRAIN", systemImage: "slider.horizontal.3")
                        .font(RetroTheme.monoLabel(10, weight: .semibold))
                        .foregroundColor(RetroTheme.amberAccent)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.92))
    }
}
