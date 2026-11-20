import CoreImage
import MetalKit
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    let onTap: (_ viewPoint: CGPoint, _ normalizedDevicePoint: CGPoint) -> Void
    let onPinch: (_ scaleDelta: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(cameraManager: cameraManager, onTap: onTap, onPinch: onPinch)
    }

    func makeUIView(context: Context) -> MetalPreviewView {
        let view = MetalPreviewView(frame: .zero, device: ImageProcessor.shared.mtlDevice)
        cameraManager.attachPreviewView(view)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: MetalPreviewView, context: Context) {}

    final class Coordinator: NSObject {
        private let cameraManager: CameraManager
        private let onTap: (CGPoint, CGPoint) -> Void
        private let onPinch: (CGFloat) -> Void
        private var lastPinchScale: CGFloat = 1.0

        init(cameraManager: CameraManager, onTap: @escaping (CGPoint, CGPoint) -> Void, onPinch: @escaping (CGFloat) -> Void) {
            self.cameraManager = cameraManager
            self.onTap = onTap
            self.onPinch = onPinch
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let normX = max(0, min(1, location.y / max(1, view.bounds.height)))
            let normY = max(0, min(1, 1.0 - (location.x / max(1, view.bounds.width))))
            onTap(location, CGPoint(x: normX, y: normY))
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                lastPinchScale = 1.0
            }
            let delta = gesture.scale / max(0.01, lastPinchScale)
            lastPinchScale = gesture.scale
            onPinch(delta)
        }
    }
}

private final class FrameBufferBox: @unchecked Sendable {
    private let lock = NSLock()
    private var image: CIImage?

    func set(_ newImage: CIImage) {
        lock.lock()
        image = newImage
        lock.unlock()
    }

    func take() -> CIImage? {
        lock.lock()
        let current = image
        lock.unlock()
        return current
    }
}

final class MetalPreviewView: MTKView {
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext
    private let frameBox = FrameBufferBox()

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        self.commandQueue = device?.makeCommandQueue()
        self.ciContext = ImageProcessor.shared.ciContext
        super.init(frame: frameRect, device: device)
        self.framebufferOnly = false
        self.isPaused = true
        self.enableSetNeedsDisplay = false
        self.backgroundColor = .black
        self.contentMode = .scaleAspectFill
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    nonisolated func enqueueFrame(_ image: CIImage) {
        frameBox.set(image)
        DispatchQueue.main.async { [weak self] in
            self?.draw()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let image = frameBox.take(),
              let drawable = currentDrawable,
              let commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let targetSize = drawableSize
        guard targetSize.width > 0, targetSize.height > 0 else { return }

        let srcExtent = image.extent
        let scaleX = targetSize.width / srcExtent.width
        let scaleY = targetSize.height / srcExtent.height
        let scale = max(scaleX, scaleY)

        let scaledW = srcExtent.width * scale
        let scaledH = srcExtent.height * scale
        let offsetX = (targetSize.width - scaledW) * 0.5
        let offsetY = (targetSize.height - scaledH) * 0.5

        let transformed = image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: offsetX / scale, y: offsetY / scale))
            .cropped(to: CGRect(origin: .zero, size: targetSize))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        ciContext.render(
            transformed,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: targetSize),
            colorSpace: colorSpace
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
