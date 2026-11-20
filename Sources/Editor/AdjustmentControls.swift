import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case tone = "TONE"
    case color = "COLOR"
    case grain = "GRAIN"
    case optics = "OPTICS"

    var id: String { rawValue }
}

struct AdjustmentControls: View {
    @Binding var parameters: FilterParameters
    @State private var selectedTab: EditorTab = .tone

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(EditorTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(RetroTheme.monoLabel(11, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? RetroTheme.amberAccent : RetroTheme.mutedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(RetroTheme.amberAccent)
                                        .frame(height: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(RetroTheme.hairline).frame(height: 1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case .tone:
                        TactileSlider(label: "INTENSITY", value: $parameters.intensity, range: 0...1, format: "%.2f")
                        TactileSlider(label: "EXPOSURE", value: $parameters.exposure, range: -2...2, format: "%+.2f")
                        TactileSlider(label: "CONTRAST", value: $parameters.contrast, range: 0.5...1.6, format: "%.2f")
                        TactileSlider(label: "HIGHLIGHTS", value: $parameters.highlights, range: -1...1, format: "%+.2f")
                        TactileSlider(label: "SHADOWS", value: $parameters.shadows, range: -1...1, format: "%+.2f")
                        TactileSlider(label: "FADE", value: $parameters.fade, range: 0...0.35, format: "%.2f")

                    case .color:
                        TactileSlider(label: "SATURATION", value: $parameters.saturation, range: 0...1.8, format: "%.2f")
                        TactileSlider(label: "TEMP (K)", value: $parameters.temperature, range: -1500...1500, format: "%+.0f")
                        TactileSlider(label: "TINT", value: $parameters.tint, range: -50...50, format: "%+.0f")

                    case .grain:
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GRAIN EMULATION")
                                .font(RetroTheme.monoLabel(10))
                                .foregroundColor(RetroTheme.mutedText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(GrainStyle.allCases) { style in
                                        Button {
                                            parameters.grainStyle = style
                                        } label: {
                                            Text(style.rawValue.uppercased())
                                                .font(RetroTheme.monoLabel(10, weight: .semibold))
                                                .foregroundColor(parameters.grainStyle == style ? .black : .white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(parameters.grainStyle == style ? RetroTheme.amberAccent : RetroTheme.surface)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        TactileSlider(label: "GRAIN AMOUNT", value: $parameters.grainIntensity, range: 0...1, format: "%.2f")
                        TactileSlider(label: "GRAIN SIZE", value: $parameters.grainSize, range: 0.5...2.5, format: "%.2f")
                        TactileSlider(label: "COLOR NOISE", value: $parameters.colorNoise, range: 0...1, format: "%.2f")
                        TactileSlider(label: "ROUGHNESS", value: $parameters.grainRoughness, range: 0...1, format: "%.2f")

                    case .optics:
                        TactileSlider(label: "BLOOM", value: $parameters.bloom, range: 0...1, format: "%.2f")
                        TactileSlider(label: "HALATION", value: $parameters.halation, range: 0...1, format: "%.2f")
                        TactileSlider(label: "VIGNETTE", value: $parameters.vignette, range: 0...1, format: "%.2f")
                        TactileSlider(label: "SHARPNESS", value: $parameters.sharpness, range: -1...1, format: "%+.2f")
                        TactileSlider(label: "CHROMATIC AB.", value: $parameters.chromaticAberration, range: 0...1, format: "%.2f")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
