import AVFoundation
import Foundation

enum SelfTimerOption: Int, CaseIterable, Identifiable {
    case off = 0
    case three = 3
    case ten = 10

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .off:   return "OFF"
        case .three: return "3s"
        case .ten:   return "10s"
        }
    }
}

enum WhiteBalancePreset: String, CaseIterable, Identifiable {
    case auto = "AUTO"
    case daylight = "DAY"
    case cloudy = "CLOUDY"
    case shade = "SHADE"
    case tungsten = "TUNG"
    case fluorescent = "FLUOR"

    var id: String { rawValue }

    var kelvinAndTint: (kelvin: Float, tint: Float)? {
        switch self {
        case .auto:        return nil
        case .daylight:    return (5500, 0)
        case .cloudy:      return (6500, 8)
        case .shade:       return (7500, 10)
        case .tungsten:    return (3200, -4)
        case .fluorescent: return (4100, 14)
        }
    }
}

struct HardwareCapabilities: Equatable {
    var minISO: Float = 50
    var maxISO: Float = 3200
    var minExposureSeconds: Double = 1.0 / 8000.0
    var maxExposureSeconds: Double = 0.5
    var minExposureBias: Float = -2.0
    var maxExposureBias: Float = 2.0
    var minZoom: CGFloat = 1.0
    var maxZoom: CGFloat = 5.0
    var supportsManualISO: Bool = false
    var supportsManualShutter: Bool = false
    var supportsManualFocus: Bool = false
    var supportsWhiteBalanceGains: Bool = false
    var supportsFlash: Bool = false
    var supportsTorch: Bool = false
    var supportsBayerRAW: Bool = false
}
