import Foundation
import SwiftUI

@MainActor
final class FilterLibrary: ObservableObject {
    @Published var presets: [FilterPreset] = []
    @Published var selectedPresetID: String = "iphone_5s"
    @Published var activeParameters: FilterParameters

    private let customStorageKey = "digicam.custom.presets.v2"

    static let builtInPresets: [FilterPreset] = [
        // Signature iPhone 5S Sensor Profile
        FilterPreset(
            id: "iphone_5s",
            name: "iPhone 5S",
            code: "5S",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: -0.04,
                contrast: 1.05,
                saturation: 0.96,
                temperature: 240,
                tint: 4,
                highlights: -0.18,
                shadows: -0.10,
                fade: 0.02,
                grainStyle: .digitalSensor,
                grainIntensity: 0.14,
                grainSize: 0.85,
                colorNoise: 0.08,
                grainRoughness: 0.35,
                bloom: 0.05,
                halation: 0.0,
                vignette: 0.10,
                sharpness: -0.06,
                chromaticAberration: 0.03,
                classicStyle: .none
            )
        ),
        // Classic iOS 7 / iOS 8 Camera Filters
        FilterPreset(
            id: "ios_none",
            name: "None",
            code: "NONE",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.0,
                contrast: 1.0,
                saturation: 1.0,
                temperature: 0,
                tint: 0,
                highlights: 0.0,
                shadows: 0.0,
                fade: 0.0,
                grainStyle: .digitalSensor,
                grainIntensity: 0.05,
                grainSize: 0.8,
                colorNoise: 0.0,
                grainRoughness: 0.3,
                bloom: 0.0,
                halation: 0.0,
                vignette: 0.0,
                sharpness: 0.0,
                chromaticAberration: 0.0,
                classicStyle: .none
            )
        ),
        FilterPreset(
            id: "ios_chrome",
            name: "Chrome",
            code: "CHRM",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.04,
                contrast: 1.16,
                saturation: 1.22,
                temperature: 140,
                tint: 4,
                highlights: 0.12,
                shadows: -0.14,
                fade: 0.0,
                grainStyle: .digitalSensor,
                grainIntensity: 0.12,
                grainSize: 0.9,
                colorNoise: 0.06,
                grainRoughness: 0.4,
                bloom: 0.06,
                halation: 0.0,
                vignette: 0.08,
                sharpness: 0.05,
                chromaticAberration: 0.0,
                classicStyle: .chrome
            )
        ),
        FilterPreset(
            id: "ios_fade",
            name: "Fade",
            code: "FADE",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.06,
                contrast: 0.86,
                saturation: 0.78,
                temperature: 80,
                tint: 2,
                highlights: -0.15,
                shadows: 0.12,
                fade: 0.16,
                grainStyle: .fine35mm,
                grainIntensity: 0.18,
                grainSize: 0.95,
                colorNoise: 0.05,
                grainRoughness: 0.4,
                bloom: 0.08,
                halation: 0.0,
                vignette: 0.06,
                sharpness: -0.05,
                chromaticAberration: 0.0,
                classicStyle: .fade
            )
        ),
        FilterPreset(
            id: "ios_instant",
            name: "Instant",
            code: "INST",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.05,
                contrast: 0.94,
                saturation: 0.92,
                temperature: 420,
                tint: 10,
                highlights: -0.12,
                shadows: 0.08,
                fade: 0.10,
                grainStyle: .fine35mm,
                grainIntensity: 0.22,
                grainSize: 1.05,
                colorNoise: 0.10,
                grainRoughness: 0.45,
                bloom: 0.14,
                halation: 0.08,
                vignette: 0.22,
                sharpness: -0.08,
                chromaticAberration: 0.05,
                classicStyle: .instant
            )
        ),
        FilterPreset(
            id: "ios_process",
            name: "Process",
            code: "PROC",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: -0.02,
                contrast: 1.14,
                saturation: 1.08,
                temperature: -280,
                tint: 12,
                highlights: 0.10,
                shadows: -0.16,
                fade: 0.04,
                grainStyle: .digitalSensor,
                grainIntensity: 0.16,
                grainSize: 0.95,
                colorNoise: 0.12,
                grainRoughness: 0.45,
                bloom: 0.06,
                halation: 0.0,
                vignette: 0.14,
                sharpness: 0.04,
                chromaticAberration: 0.04,
                classicStyle: .process
            )
        ),
        FilterPreset(
            id: "ios_transfer",
            name: "Transfer",
            code: "TRNS",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.05,
                contrast: 1.04,
                saturation: 1.06,
                temperature: 360,
                tint: 6,
                highlights: -0.10,
                shadows: 0.06,
                fade: 0.07,
                grainStyle: .fine35mm,
                grainIntensity: 0.18,
                grainSize: 1.0,
                colorNoise: 0.08,
                grainRoughness: 0.42,
                bloom: 0.12,
                halation: 0.05,
                vignette: 0.12,
                sharpness: -0.05,
                chromaticAberration: 0.02,
                classicStyle: .transfer
            )
        ),
        FilterPreset(
            id: "ios_mono",
            name: "Mono",
            code: "MONO",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.0,
                contrast: 1.06,
                saturation: 0.0,
                temperature: 0,
                tint: 0,
                highlights: -0.08,
                shadows: -0.04,
                fade: 0.02,
                grainStyle: .fine35mm,
                grainIntensity: 0.20,
                grainSize: 0.95,
                colorNoise: 0.0,
                grainRoughness: 0.45,
                bloom: 0.04,
                halation: 0.0,
                vignette: 0.10,
                sharpness: 0.0,
                chromaticAberration: 0.0,
                classicStyle: .mono
            )
        ),
        FilterPreset(
            id: "ios_tonal",
            name: "Tonal",
            code: "TONL",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.04,
                contrast: 0.92,
                saturation: 0.0,
                temperature: 0,
                tint: 0,
                highlights: -0.18,
                shadows: 0.12,
                fade: 0.08,
                grainStyle: .fine35mm,
                grainIntensity: 0.22,
                grainSize: 1.0,
                colorNoise: 0.0,
                grainRoughness: 0.45,
                bloom: 0.08,
                halation: 0.0,
                vignette: 0.12,
                sharpness: -0.06,
                chromaticAberration: 0.0,
                classicStyle: .tonal
            )
        ),
        FilterPreset(
            id: "ios_noir",
            name: "Noir",
            code: "NOIR",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: -0.08,
                contrast: 1.38,
                saturation: 0.0,
                temperature: 0,
                tint: 0,
                highlights: 0.14,
                shadows: -0.32,
                fade: 0.0,
                grainStyle: .coarseFilm,
                grainIntensity: 0.28,
                grainSize: 1.15,
                colorNoise: 0.0,
                grainRoughness: 0.65,
                bloom: 0.06,
                halation: 0.0,
                vignette: 0.28,
                sharpness: 0.08,
                chromaticAberration: 0.0,
                classicStyle: .noir
            )
        ),
        // Retro CCD & Film Profiles
        FilterPreset(
            id: "ccd_flash",
            name: "CCD Flash",
            code: "CCD",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.12,
                contrast: 1.24,
                saturation: 1.14,
                temperature: -220,
                tint: -6,
                highlights: 0.22,
                shadows: -0.26,
                fade: 0.0,
                grainStyle: .ccdChroma,
                grainIntensity: 0.34,
                grainSize: 1.15,
                colorNoise: 0.45,
                grainRoughness: 0.65,
                bloom: 0.18,
                halation: 0.04,
                vignette: 0.28,
                sharpness: 0.15,
                chromaticAberration: 0.18,
                classicStyle: .none
            )
        ),
        FilterPreset(
            id: "digicam_2005",
            name: "Digicam 2005",
            code: "2005",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.05,
                contrast: 1.18,
                saturation: 1.22,
                temperature: 140,
                tint: 12,
                highlights: 0.25,
                shadows: -0.18,
                fade: 0.01,
                grainStyle: .ccdLuminance,
                grainIntensity: 0.44,
                grainSize: 1.35,
                colorNoise: 0.52,
                grainRoughness: 0.78,
                bloom: 0.22,
                halation: 0.08,
                vignette: 0.22,
                sharpness: 0.22,
                chromaticAberration: 0.26,
                classicStyle: .none
            )
        ),
        FilterPreset(
            id: "golden_haze",
            name: "Golden Haze",
            code: "GOLD",
            isBuiltIn: true,
            parameters: FilterParameters(
                intensity: 1.0,
                exposure: 0.08,
                contrast: 0.88,
                saturation: 1.08,
                temperature: 620,
                tint: 10,
                highlights: 0.16,
                shadows: 0.08,
                fade: 0.07,
                grainStyle: .fine35mm,
                grainIntensity: 0.22,
                grainSize: 1.05,
                colorNoise: 0.12,
                grainRoughness: 0.45,
                bloom: 0.48,
                halation: 0.32,
                vignette: 0.18,
                sharpness: -0.18,
                chromaticAberration: 0.10,
                classicStyle: .none
            )
        )
    ]

    init() {
        let initial = Self.builtInPresets[0]
        self.activeParameters = initial.parameters
        reloadPresets()
    }

    var currentPreset: FilterPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? Self.builtInPresets[0]
    }

    func selectPreset(_ preset: FilterPreset) {
        selectedPresetID = preset.id
        activeParameters = preset.parameters
    }

    func resetCurrentPreset() {
        activeParameters = currentPreset.parameters
    }

    func saveCustomPreset(name: String, parameters: FilterParameters) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var customList = loadCustomFilters()
        let entry = CustomFilter(id: UUID(), name: trimmed, createdAt: Date(), parameters: parameters)
        customList.append(entry)
        persistCustomFilters(customList)
        reloadPresets()
        selectedPresetID = entry.id.uuidString
        activeParameters = parameters
    }

    private func reloadPresets() {
        let customPresets = loadCustomFilters().map { $0.asPreset() }
        presets = Self.builtInPresets + customPresets
    }

    private func loadCustomFilters() -> [CustomFilter] {
        guard let data = UserDefaults.standard.data(forKey: customStorageKey),
              let decoded = try? JSONDecoder().decode([CustomFilter].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistCustomFilters(_ list: [CustomFilter]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: customStorageKey)
        }
    }
}
