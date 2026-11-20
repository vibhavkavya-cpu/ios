import AVFoundation
import CoreImage
import Photos
import SwiftUI
import UIKit

final class CameraManager: NSObject, ObservableObject {
    enum PermissionState {
        case unknown, authorized, denied
    }

    @Published var permissionState: PermissionState = .unknown
    @Published var isSessionRunning: Bool = false
    @Published var isInterrupted: Bool = false
    @Published var isCapturing: Bool = false

    // Top bar & capture modes
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isRawCaptureEnabled: Bool = false
    @Published var isSquareAspect: Bool = false
    @Published var timerOption: SelfTimerOption = .off
    @Published var timerCountdown: Int? = nil
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var capabilities = HardwareCapabilities()

    // Manual & persistent exposure controls
    @Published var isAutoExposure: Bool = true
    @Published var isoValue: Float = 100
    @Published var shutterSeconds: Double = 1.0 / 60.0
    @Published var exposureBias: Float = 0.0
    @Published var isAutoFocus: Bool = true
    @Published var lensPosition: Float = 0.5
    @Published var whiteBalancePreset: WhiteBalancePreset = .auto
    @Published var zoomFactor: CGFloat = 1.0

    // Live telemetry
    @Published var liveISO: Float = 100
    @Published var liveShutterSeconds: Double = 1.0 / 60.0
    @Published var focusIndicatorPoint: CGPoint?
    @Published var captureToastMessage: String?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.retro.digicam.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.retro.digicam.video", qos: .userInteractive)

    private var videoInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private var telemetryTimer: Timer?
    private var countdownTimer: Timer?

    private weak var previewView: MetalPreviewView?
    private weak var filterLibrary: FilterLibrary?
    private weak var libraryManager: PhotoLibraryManager?

    private var cachedParameters: FilterParameters = FilterLibrary.builtInPresets[0].parameters
    private var cachedPresetName: String = "iPhone 5S"
    private var cachedSquareCrop: Bool = false
    private var frameCounter: UInt64 = 1

    // Temporary storage pairing Bayer RAW DNG + Processed JPEG during dual capture
    private var pendingRawData: Data?
    private var pendingProcessedJPEGData: Data?

    override init() {
        super.init()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        telemetryTimer?.invalidate()
        countdownTimer?.invalidate()
    }

    func bindFilterLibrary(_ library: FilterLibrary) {
        self.filterLibrary = library
    }

    func bindLibraryManager(_ manager: PhotoLibraryManager) {
        self.libraryManager = manager
    }

    func syncFilterState(parameters: FilterParameters, presetName: String) {
        videoOutputQueue.async { [weak self] in
            self?.cachedParameters = parameters
            self?.cachedPresetName = presetName
        }
    }

    func setSquareCrop(_ isSquare: Bool) {
        DispatchQueue.main.async { self.isSquareAspect = isSquare }
        videoOutputQueue.async { [weak self] in
            self?.cachedSquareCrop = isSquare
        }
    }

    func attachPreviewView(_ view: MetalPreviewView) {
        self.previewView = view
    }

    // MARK: - Permissions & Lifecycle

    func checkPermissionsAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionState = .authorized }
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionState = granted ? .authorized : .denied
                }
                if granted {
                    self?.configureAndStartSession()
                }
            }
        default:
            DispatchQueue.main.async { self.permissionState = .denied }
        }
    }

    func resumeSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.permissionState == .authorized, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                self.startTelemetryTimer()
            }
        }
    }

    func pauseSession() {
        DispatchQueue.main.async {
            self.telemetryTimer?.invalidate()
            self.telemetryTimer = nil
            self.countdownTimer?.invalidate()
            self.timerCountdown = nil
        }
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            if let existing = self.videoInput {
                self.session.removeInput(existing)
                self.videoInput = nil
            }

            guard let device = self.discoverCamera(for: self.cameraPosition),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            self.videoInput = input
            self.currentDevice = device

            if !self.session.outputs.contains(self.photoOutput), self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .speed
            }

            if !self.session.outputs.contains(self.videoDataOutput), self.session.canAddOutput(self.videoDataOutput) {
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
                self.session.addOutput(self.videoDataOutput)
            }

            if let connection = self.videoDataOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (self.cameraPosition == .front)
                }
            }

            self.session.commitConfiguration()
            self.readHardwareCapabilities(for: device)

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                self.startTelemetryTimer()
            }
        }
    }

    private func discoverCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return wide
        }
        return AVCaptureDevice.default(for: .video)
    }

    private func readHardwareCapabilities(for device: AVCaptureDevice) {
        let format = device.activeFormat
        let clampedMinISO = max(50, format.minISO)
        let clampedMaxISO = min(3200, format.maxISO)
        let minSec = max(1.0 / 8000.0, CMTimeGetSeconds(format.minExposureDuration))
        let maxSec = min(1.0, CMTimeGetSeconds(format.maxExposureDuration))
        let maxZoomCap = min(8.0, device.activeFormat.videoMaxZoomFactor)

        let rawFormats = photoOutput.availableRawPhotoPixelFormatTypes
        let bayerSupported = rawFormats.contains(where: { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) })

        let caps = HardwareCapabilities(
            minISO: clampedMinISO,
            maxISO: max(clampedMinISO + 10, clampedMaxISO),
            minExposureSeconds: minSec,
            maxExposureSeconds: max(minSec * 2, maxSec),
            minExposureBias: device.minExposureTargetBias,
            maxExposureBias: device.maxExposureTargetBias,
            minZoom: 1.0,
            maxZoom: max(1.0, maxZoomCap),
            supportsManualISO: device.isExposureModeSupported(.custom),
            supportsManualShutter: device.isExposureModeSupported(.custom),
            supportsManualFocus: device.isFocusModeSupported(.locked),
            supportsWhiteBalanceGains: device.isLockingWhiteBalanceWithCustomDeviceGainsSupported,
            supportsFlash: device.hasFlash,
            supportsTorch: device.hasTorch,
            supportsBayerRAW: bayerSupported
        )

        DispatchQueue.main.async {
            self.capabilities = caps
            if !bayerSupported {
                self.isRawCaptureEnabled = false
            }
            self.isoValue = max(caps.minISO, min(caps.maxISO, device.iso))
            self.shutterSeconds = max(caps.minExposureSeconds, min(caps.maxExposureSeconds, CMTimeGetSeconds(device.exposureDuration)))
            self.exposureBias = 0.0
            self.zoomFactor = 1.0
            self.isAutoExposure = true
            self.isAutoFocus = true
            self.whiteBalancePreset = .auto
        }
    }

    // MARK: - Controls

    func switchCamera() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        configureAndStartSession()
    }

    func cycleFlashMode() {
        guard capabilities.supportsFlash else {
            flashMode = .off
            return
        }
        switch flashMode {
        case .off:  flashMode = .on
        case .on:   flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    func cycleTimerOption() {
        switch timerOption {
        case .off:   timerOption = .three
        case .three: timerOption = .ten
        case .ten:   timerOption = .off
        }
    }

    func toggleRawCapture() {
        guard capabilities.supportsBayerRAW else {
            showToast("BAYER RAW UNSUPPORTED ON THIS LENS")
            isRawCaptureEnabled = false
            return
        }
        isRawCaptureEnabled.toggle()
        showToast(isRawCaptureEnabled ? "12-BIT BAYER DNG RAW ON" : "ZERO-HDR JPEG MODE")
    }

    func tapToFocus(viewPoint: CGPoint, devicePoint: CGPoint) {
        DispatchQueue.main.async {
            self.focusIndicatorPoint = viewPoint
            self.isAutoFocus = true
        }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if self.isAutoExposure && device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setZoom(_ newZoom: CGFloat) {
        let clamped = max(capabilities.minZoom, min(capabilities.maxZoom, newZoom))
        DispatchQueue.main.async { self.zoomFactor = clamped }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setExposureBias(_ bias: Float) {
        let clamped = max(capabilities.minExposureBias, min(capabilities.maxExposureBias, bias))
        DispatchQueue.main.async { self.exposureBias = clamped }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.exposureMode == .custom && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    DispatchQueue.main.async { self.isAutoExposure = true }
                }
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setManualExposure(iso: Float?, shutterSeconds: Double?) {
        guard capabilities.supportsManualISO || capabilities.supportsManualShutter else { return }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            let targetISO = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, iso ?? device.iso))
            let targetSec = max(
                CMTimeGetSeconds(device.activeFormat.minExposureDuration),
                min(CMTimeGetSeconds(device.activeFormat.maxExposureDuration), shutterSeconds ?? CMTimeGetSeconds(device.exposureDuration))
            )
            let duration = CMTimeMakeWithSeconds(targetSec, preferredTimescale: 1_000_000_000)

            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: duration, iso: targetISO) { _ in
                    DispatchQueue.main.async {
                        self.isAutoExposure = false
                        self.isoValue = targetISO
                        self.shutterSeconds = targetSec
                    }
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func resetAutoExposure() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.setExposureTargetBias(0, completionHandler: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isAutoExposure = true
                    self.exposureBias = 0
                }
            } catch {}
        }
    }

    func setManualFocus(_ position: Float) {
        guard capabilities.supportsManualFocus else { return }
        let clamped = max(0.0, min(1.0, position))
        DispatchQueue.main.async {
            self.isAutoFocus = false
            self.lensPosition = clamped
        }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func resetAutoFocus() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isAutoFocus = true
                }
            } catch {}
        }
    }

    func setWhiteBalance(_ preset: WhiteBalancePreset) {
        DispatchQueue.main.async { self.whiteBalancePreset = preset }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if let pair = preset.kelvinAndTint, device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
                    let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                        temperature: pair.kelvin,
                        tint: pair.tint
                    )
                    var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                    let maxGain = device.maxWhiteBalanceGain
                    gains.redGain = max(1.0, min(maxGain, gains.redGain))
                    gains.greenGain = max(1.0, min(maxGain, gains.greenGain))
                    gains.blueGain = max(1.0, min(maxGain, gains.blueGain))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: - Capture (With Self-Timer & Bayer RAW Support)

    func triggerShutterWithTimer(onFire: @escaping () -> Void) {
        guard isSessionRunning, !isCapturing else { return }

        if let existing = countdownTimer {
            existing.invalidate()
            countdownTimer = nil
            timerCountdown = nil
            return
        }

        if timerOption == .off {
            onFire()
            capturePhoto()
            return
        }

        var remaining = timerOption.rawValue
        timerCountdown = remaining
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.timerCountdown = nil
                onFire()
                self.capturePhoto()
            } else {
                self.timerCountdown = remaining
            }
        }
    }

    func capturePhoto() {
        guard isSessionRunning, !isCapturing else { return }
        DispatchQueue.main.async { self.isCapturing = true }

        let captureRaw = isRawCaptureEnabled && capabilities.supportsBayerRAW

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRawData = nil
            self.pendingProcessedJPEGData = nil

            let settings: AVCapturePhotoSettings
            if captureRaw,
               let rawFormat = self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }) {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawFormat,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                )
            } else {
                settings = AVCapturePhotoSettings()
            }

            settings.photoQualityPrioritization = .speed
            if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func showToast(_ text: String) {
        DispatchQueue.main.async {
            self.captureToastMessage = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                if self?.captureToastMessage == text {
                    self?.captureToastMessage = nil
                }
            }
        }
    }

    // MARK: - Telemetry & Notifications

    private func startTelemetryTimer() {
        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self, let device = self.currentDevice else { return }
            self.liveISO = device.iso
            self.liveShutterSeconds = CMTimeGetSeconds(device.exposureDuration)
            if self.isAutoFocus {
                self.lensPosition = device.lensPosition
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.isInterrupted = true
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.isInterrupted = false
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCounter &+= 1
        let liveSeed = (frameCounter / 2) &* 2654435761
        let processed = ImageProcessor.shared.processPreviewFrame(
            pixelBuffer,
            parameters: cachedParameters,
            frameSeed: liveSeed,
            cropToSquare: cachedSquareCrop
        )
        previewView?.enqueueFrame(processed)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        if photo.isRawPhoto {
            pendingRawData = data
        } else {
            pendingProcessedJPEGData = data
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        defer {
            DispatchQueue.main.async { self.isCapturing = false }
        }

        guard error == nil, let baseJPEG = pendingProcessedJPEGData else { return }
        let rawDNG = pendingRawData
        pendingRawData = nil
        pendingProcessedJPEGData = nil

        let activeParams = cachedParameters
        let filterName = rawDNG != nil ? "RAW + \(cachedPresetName)" : cachedPresetName
        let squareCrop = cachedSquareCrop
        let capturedISO = currentDevice?.iso ?? liveISO
        let capturedShutter = CMTimeGetSeconds(currentDevice?.exposureDuration ?? CMTime(seconds: liveShutterSeconds, preferredTimescale: 1000))
        let usedFlash = (flashMode == .on)
        let uniqueSeed = UInt64(Date().timeIntervalSince1970 * 1_000_000) ^ UInt64.random(in: 1...UInt64.max)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let rendered = ImageProcessor.shared.renderFullResolution(
                from: baseJPEG,
                parameters: activeParams,
                seed: uniqueSeed,
                cropToSquare: squareCrop
            ) else { return }

            let metadata = PhotoEXIFMetadata(
                filterName: filterName,
                iso: Int(round(capturedISO)),
                shutterSpeed: ShutterSpeedFormatter.format(seconds: capturedShutter),
                capturedAt: Date(),
                flashFired: usedFlash,
                isRawDNG: rawDNG != nil,
                lensModel: self?.cameraPosition == .front ? "Front 2.2mm f/2.2" : "iSight 4.15mm f/2.2",
                seed: uniqueSeed,
                appliedParameters: activeParams
            )

            Task { @MainActor in
                self?.libraryManager?.saveCapture(
                    originalJPEG: baseJPEG,
                    processedJPEG: rendered.processedJPEG,
                    thumbnailJPEG: rendered.thumbnailJPEG,
                    rawDNGData: rawDNG,
                    metadata: metadata
                )
            }
        }
    }
}
