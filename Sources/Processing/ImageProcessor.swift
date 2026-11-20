import CoreImage
import Metal
import UIKit

final class ImageProcessor {
    static let shared = ImageProcessor()

    let mtlDevice: MTLDevice?
    let ciContext: CIContext
    private let filterEngine = FilterEngine()

    private init() {
        let device = MTLCreateSystemDefaultDevice()
        self.mtlDevice = device
        if let device {
            self.ciContext = CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,
                .priorityRequestLow: false
            ])
        } else {
            self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    func processPreviewFrame(
        _ pixelBuffer: CVPixelBuffer,
        parameters: FilterParameters,
        frameSeed: UInt64,
        cropToSquare: Bool
    ) -> CIImage {
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        return filterEngine.render(
            source: source,
            parameters: parameters,
            seed: frameSeed,
            isRealtimePreview: true,
            cropToSquare: cropToSquare
        )
    }

    func renderFullResolution(
        from originalData: Data,
        parameters: FilterParameters,
        seed: UInt64,
        cropToSquare: Bool = false
    ) -> (processedJPEG: Data, thumbnailJPEG: Data)? {
        guard let source = CIImage(data: originalData, options: [.applyOrientationProperty: true]) else {
            return nil
        }

        let rendered = filterEngine.render(
            source: source,
            parameters: parameters,
            seed: seed,
            isRealtimePreview: false,
            cropToSquare: cropToSquare
        )

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let processedJPEG = ciContext.jpegRepresentation(
            of: rendered,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.94]
        ) else {
            return nil
        }

        let maxDim = max(rendered.extent.width, rendered.extent.height)
        let scale = maxDim > 0 ? min(1.0, 320.0 / maxDim) : 1.0
        let thumbCI = rendered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let thumbnailJPEG = ciContext.jpegRepresentation(
            of: thumbCI,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.82]
        ) ?? processedJPEG

        return (processedJPEG, thumbnailJPEG)
    }
}
