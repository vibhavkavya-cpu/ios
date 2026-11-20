import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

final class GrainEngine {
    func applyGrain(to image: CIImage, params: FilterParameters, seed: UInt64) -> CIImage {
        let effectiveAmount = params.grainIntensity * params.intensity
        guard effectiveAmount > 0.005 else { return image }

        let extent = image.extent
        guard !extent.isEmpty else { return image }

        let offsetX = CGFloat((seed & 0xFFFF) % 4096) - 2048.0
        let offsetY = CGFloat(((seed >> 16) & 0xFFFF) % 4096) - 2048.0

        guard let randomFilter = CIFilter(name: "CIRandomGenerator"),
              var rawNoise = randomFilter.outputImage else {
            return image
        }

        let baseScale: CGFloat
        switch params.grainStyle {
        case .fine35mm:      baseScale = 0.85
        case .coarseFilm:    baseScale = 1.65
        case .ccdLuminance:  baseScale = 1.15
        case .ccdChroma:     baseScale = 1.35
        case .organicRandom: baseScale = 1.25
        case .digitalSensor: baseScale = 0.95
        }

        let scale = max(0.4, CGFloat(params.grainSize) * baseScale)
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
        rawNoise = rawNoise.transformed(by: transform).cropped(to: extent)

        let styleChromaBias: Double = {
            switch params.grainStyle {
            case .ccdChroma:     return 0.70
            case .digitalSensor: return 0.35
            case .ccdLuminance:  return 0.15
            case .organicRandom: return 0.20
            case .fine35mm:      return 0.08
            case .coarseFilm:    return 0.12
            }
        }()

        let chromaMix = min(1.0, max(0.0, (params.colorNoise * 0.75) + (styleChromaBias * 0.5)))

        let monoNoise = rawNoise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputGVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputBVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        let mixedNoise = monoNoise.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: rawNoise,
            kCIInputTimeKey: chromaMix
        ])

        let roughnessContrast = 1.0 + (params.grainRoughness * 1.4)
        let shapedNoise = mixedNoise.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: roughnessContrast,
            kCIInputBrightnessKey: 0.0
        ])

        let lumaMask = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.15
            ])
            .applyingFilter("CIColorInvert")

        let opacity = CGFloat(min(0.42, effectiveAmount * 0.38))
        let weightedNoise = shapedNoise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
        ])

        let softLight = weightedNoise.applyingFilter("CISoftLightBlendMode", parameters: [
            kCIInputBackgroundImageKey: image
        ])

        return softLight.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: lumaMask
        ]).cropped(to: extent)
    }
}
