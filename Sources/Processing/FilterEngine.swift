import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

final class FilterEngine {
    private let grainEngine = GrainEngine()
    private let bloomEngine = BloomEngine()

    func render(
        source: CIImage,
        parameters: FilterParameters,
        seed: UInt64,
        isRealtimePreview: Bool,
        cropToSquare: Bool = false
    ) -> CIImage {
        var img = source
        if cropToSquare {
            let side = min(img.extent.width, img.extent.height)
            let cropRect = CGRect(
                x: img.extent.midX - (side * 0.5),
                y: img.extent.midY - (side * 0.5),
                width: side,
                height: side
            )
            img = img.cropped(to: cropRect)
        }

        let extent = img.extent
        guard !extent.isEmpty else { return img }

        let mix = max(0.0, min(1.0, parameters.intensity))
        if mix <= 0.001 { return img }

        // Optional iOS 7/8 Classic Color Matrix Base
        switch parameters.classicStyle {
        case .none:
            break
        case .mono:
            img = img.applyingFilter("CIPhotoEffectMono")
        case .tonal:
            img = img.applyingFilter("CIPhotoEffectTonal")
        case .noir:
            img = img.applyingFilter("CIPhotoEffectNoir")
        case .fade:
            img = img.applyingFilter("CIPhotoEffectFade")
        case .chrome:
            img = img.applyingFilter("CIPhotoEffectChrome")
        case .process:
            img = img.applyingFilter("CIPhotoEffectProcess")
        case .transfer:
            img = img.applyingFilter("CIPhotoEffectTransfer")
        case .instant:
            img = img.applyingFilter("CIPhotoEffectInstant")
        }

        // 1. Exposure
        if abs(parameters.exposure) > 0.005 {
            img = img.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: parameters.exposure * mix
            ])
        }

        // 2. White Balance (Temperature & Tint)
        if abs(parameters.temperature) > 1.0 || abs(parameters.tint) > 0.1 {
            let targetTemp = 6500.0 - (parameters.temperature * mix)
            let targetTint = -(parameters.tint * mix)
            img = img.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: CGFloat(targetTemp), y: CGFloat(targetTint))
            ])
        }

        // 3. Highlights & Shadows Roll-off
        if abs(parameters.highlights) > 0.005 || abs(parameters.shadows) > 0.005 {
            let highlightAmount = 1.0 - (parameters.highlights * 0.45 * mix)
            let shadowAmount = parameters.shadows * 0.45 * mix
            img = img.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": max(0.2, min(1.5, highlightAmount)),
                "inputShadowAmount": max(-0.6, min(0.8, shadowAmount))
            ])
        }

        // 4. Contrast, Saturation & Fade
        let contrast = 1.0 + ((parameters.contrast - 1.0) * mix)
        let saturation = parameters.classicStyle == .mono || parameters.classicStyle == .tonal || parameters.classicStyle == .noir
            ? 0.0
            : 1.0 + ((parameters.saturation - 1.0) * mix)

        img = img.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: contrast,
            kCIInputSaturationKey: saturation
        ])

        let fade = parameters.fade * mix
        if fade > 0.002 {
            let tone = CIFilter.toneCurve()
            tone.inputImage = img
            tone.point0 = CGPoint(x: 0.0, y: fade * 0.35)
            tone.point1 = CGPoint(x: 0.25, y: 0.25 + (fade * 0.14))
            tone.point2 = CGPoint(x: 0.50, y: 0.50)
            tone.point3 = CGPoint(x: 0.78, y: 0.78 - (fade * 0.05))
            tone.point4 = CGPoint(x: 1.0, y: 1.0 - (fade * 0.08))
            if let out = tone.outputImage { img = out }
        }

        // 5. Lateral Chromatic Aberration
        let caAmount = parameters.chromaticAberration * mix
        if caAmount > 0.01 && !isRealtimePreview {
            let shiftScale = 1.0 + (CGFloat(caAmount) * 0.0045)
            let centerX = extent.midX
            let centerY = extent.midY
            let redTransform = CGAffineTransform(translationX: centerX, y: centerY)
                .scaledBy(x: shiftScale, y: shiftScale)
                .translatedBy(x: -centerX, y: -centerY)

            let shiftedRed = img
                .transformed(by: redTransform)
                .cropped(to: extent)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ])

            let greenBlue = img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0)
            ])

            img = shiftedRed.applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: greenBlue
            ]).cropped(to: extent)
        }

        // 6. Sharpness / Softness
        let sharp = parameters.sharpness * mix
        if sharp > 0.01 {
            img = img.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: sharp * 0.65
            ])
        } else if sharp < -0.01 {
            let radius = abs(sharp) * (isRealtimePreview ? 0.8 : 1.4)
            img = img.clampedToExtent()
                .applyingGaussianBlur(sigma: radius)
                .cropped(to: extent)
        }

        // 7. Bloom & Halation
        img = bloomEngine.applyBloomAndHalation(to: img, params: parameters)

        // 8. Custom Grain Engine
        img = grainEngine.applyGrain(to: img, params: parameters, seed: seed)

        // 9. Lens Vignette
        let vig = parameters.vignette * mix
        if vig > 0.01 {
            img = img.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: vig * 1.4,
                kCIInputRadiusKey: 1.35
            ])
        }

        return img.cropped(to: extent)
    }
}
