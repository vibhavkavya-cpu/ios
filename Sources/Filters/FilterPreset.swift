import Foundation

enum GrainStyle: String, Codable, CaseIterable, Identifiable {
    case fine35mm = "35mm Fine"
    case coarseFilm = "Coarse Film"
    case ccdLuminance = "CCD Luma"
    case ccdChroma = "CCD Chroma"
    case organicRandom = "Organic"
    case digitalSensor = "Sensor"

    var id: String { rawValue }
}

enum ClassicLUTStyle: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case mono = "MONO"
    case tonal = "TONAL"
    case noir = "NOIR"
    case fade = "FADE"
    case chrome = "CHROME"
    case process = "PROCESS"
    case transfer = "TRANSFER"
    case instant = "INSTANT"

    var id: String { rawValue }
}

struct FilterParameters: Codable, Equatable {
    var intensity: Double
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var temperature: Double
    var tint: Double
    var highlights: Double
    var shadows: Double
    var fade: Double
    var grainStyle: GrainStyle
    var grainIntensity: Double
    var grainSize: Double
    var colorNoise: Double
    var grainRoughness: Double
    var bloom: Double
    var halation: Double
    var vignette: Double
    var sharpness: Double
    var chromaticAberration: Double
    var classicStyle: ClassicLUTStyle = .none

    static let neutral = FilterParameters(
        intensity: 1.0,
        exposure: 0.0,
        contrast: 1.0,
        saturation: 1.0,
        temperature: 0.0,
        tint: 0.0,
        highlights: 0.0,
        shadows: 0.0,
        fade: 0.0,
        grainStyle: .digitalSensor,
        grainIntensity: 0.0,
        grainSize: 1.0,
        colorNoise: 0.0,
        grainRoughness: 0.5,
        bloom: 0.0,
        halation: 0.0,
        vignette: 0.0,
        sharpness: 0.0,
        chromaticAberration: 0.0,
        classicStyle: .none
    )
}

struct FilterPreset: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var code: String
    var isBuiltIn: Bool
    var parameters: FilterParameters
}
