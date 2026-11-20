import AVFoundation
import Foundation

enum ShutterSpeedFormatter {
    static func format(seconds: Double) -> String {
        guard seconds > 0 else { return "AUTO" }
        if seconds >= 0.4 {
            return String(format: "%.1fs", seconds)
        }
        let reciprocal = Int(round(1.0 / seconds))
        return "1/\(max(1, reciprocal))"
    }

    static func seconds(fromNormalized t: Double, min: Double, max: Double) -> Double {
        let clamped = Swift.max(0.0, Swift.min(1.0, t))
        guard min > 0, max > min else { return min }
        return min * pow(max / min, clamped)
    }

    static func normalized(fromSeconds s: Double, min: Double, max: Double) -> Double {
        guard min > 0, max > min, s > 0 else { return 0.5 }
        let ratio = Swift.max(min, Swift.min(max, s)) / min
        return log(ratio) / log(max / min)
    }
}
