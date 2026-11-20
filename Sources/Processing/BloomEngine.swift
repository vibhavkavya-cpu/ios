import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

final class BloomEngine {
    func applyBloomAndHalation(to image: CIImage, params: FilterParameters) -> CIImage {
        var result = image
        let extent = image.extent
        let intensity = params.intensity

        let bloomAmount = params.bloom * intensity
        if bloomAmount > 0.01 {
            let radius = max(4.0, min(extent.width, extent.height) * 0.018)
            let bloomed = result.applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: radius,
                kCIInputIntensityKey: bloomAmount * 0.85
            ]).cropped(to: extent)
            result = bloomed
        }

        let halationAmount = params.halation * intensity
        if halationAmount > 0.01 {
            let highlights = result
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.4, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.35, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.05, w: 0),
                    "inputBiasVector": CIVector(x: -0.75, y: -0.75, z: -0.75, w: 0)
                ])
                .clampedToExtent()
                .applyingGaussianBlur(sigma: max(6.0, min(extent.width, extent.height) * 0.014))
                .cropped(to: extent)

            let tintedHalo = highlights.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: halationAmount * 0.75, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: halationAmount * 0.22, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: halationAmount * 0.04, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])

            result = tintedHalo.applyingFilter("CIScreenBlendMode", parameters: [
                kCIInputBackgroundImageKey: result
            ]).cropped(to: extent)
        }

        return result
    }
}
