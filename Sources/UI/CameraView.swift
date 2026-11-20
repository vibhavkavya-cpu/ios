import AVFoundation
import SwiftUI

struct CameraView: View {
    @EnvironmentObject private var appState: AppState
    @State private var shutterFlashOpacity: Double = 0.0
    @State private var focusHideTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            RetroTheme.background.ignoresSafeArea()

            if appState.cameraManager.permissionState == .denied {
                permissionDeniedView
            } else {
                VStack(spacing: 0) {
                    // Authentic iOS 7/8 5-icon Top Bar: Flash | HDR-Off/RAW | Bypass | Timer | 3-Circle Filter
                    ios7TopBar

                    // Viewfinder (4:3 or 1:1 Square like classic iPhone 5s Camera)
                    ZStack {
                        CameraPreview(
                            cameraManager: appState.cameraManager,
                            onTap: { viewPoint, devicePoint in
                                appState.cameraManager.tapToFocus(viewPoint: viewPoint, devicePoint: devicePoint)
                                scheduleFocusReticleHide()
                            },
                            onPinch: { delta in
                                let nextZoom = appState.cameraManager.zoomFactor * delta
                                appState.cameraManager.setZoom(nextZoom)
                            }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 28)
                                .onEnded { value in
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        cyclePreset(direction: value.translation.width < 0 ? 1 : -1)
                                    }
                                }
                        )

                        // Square crop mask when SQUARE mode is selected
                        if appState.isSquareAspect {
                            GeometryReader { geo in
                                let side = min(geo.size.width, geo.size.height)
                                let barHeight = max(0, (geo.size.height - side) * 0.5)
                                VStack(spacing: 0) {
                                    Color.black.frame(height: barHeight)
                                    Spacer()
                                    Color.black.frame(height: barHeight)
                                }
                            }
                            .allowsHitTesting(false)
                        }

                        // Tap-to-focus yellow reticle + sun slider
                        if let point = appState.cameraManager.focusIndicatorPoint {
                            FocusReticleView(
                                point: point,
                                exposureBias: Binding(
                                    get: { appState.cameraManager.exposureBias },
                                    set: { appState.cameraManager.setExposureBias($0) }
                                ),
                                minBias: appState.cameraManager.capabilities.minExposureBias,
                                maxBias: appState.cameraManager.capabilities.maxExposureBias,
                                onBiasChanged: { newBias in
                                    appState.cameraManager.setExposureBias(newBias)
                                    scheduleFocusReticleHide()
                                }
                            )
                        }

                        // Timer countdown overlay
                        if let count = appState.cameraManager.timerCountdown {
                            Text("\(count)")
                                .font(.system(size: 76, weight: .thin, design: .default))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 6)
                        }

                        // Toast notification (e.g. 12-BIT BAYER DNG RAW ON)
                        if let toast = appState.cameraManager.captureToastMessage {
                            VStack {
                                Text(toast)
                                    .font(RetroTheme.monoLabel(10, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(RetroTheme.amberAccent)
                                    .padding(.top, 12)
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        }

                        // Mechanical shutter blackout blink
                        Color.black
                            .opacity(shutterFlashOpacity)
                            .allowsHitTesting(false)

                        // Persistent Always-On EV Exposure Bar + Live Telemetry at bottom of viewfinder
                        VStack(spacing: 6) {
                            Spacer()

                            // Always-available Exposure Control Strip for every shot
                            persistentExposureBar

                            HStack(spacing: 10) {
                                Text(appState.filterLibrary.currentPreset.name.uppercased())
                                    .foregroundColor(RetroTheme.amberAccent)
                                if appState.cameraManager.isRawCaptureEnabled {
                                    Text("DNG RAW")
                                        .foregroundColor(RetroTheme.amberAccent)
                                }
                                Text("ISO \(Int(round(appState.cameraManager.liveISO)))")
                                Text(ShutterSpeedFormatter.format(seconds: appState.cameraManager.liveShutterSeconds))
                                if appState.cameraManager.zoomFactor > 1.05 {
                                    Text(String(format: "%.1fx", appState.cameraManager.zoomFactor))
                                }
                            }
                            .font(RetroTheme.monoLabel(9.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3.5)
                            .background(Color.black.opacity(0.6))
                            .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    // Contextual Panels: Filter Strip OR Manual Pro Controls
                    if appState.isFilterDrawerOpen {
                        FilterSelector(
                            filterLibrary: appState.filterLibrary,
                            onFilterChanged: { preset in
                                appState.cameraManager.syncFilterState(
                                    parameters: preset.parameters,
                                    presetName: preset.name
                                )
                            },
                            onOpenEditor: {
                                appState.isEditorPresented = true
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if appState.activeMode == .manual {
                        ManualControlsView(cameraManager: appState.cameraManager)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Classic iOS 7/8 Bottom Deck: Mode Strip -> Thumbnail | Shutter | Flip Camera
                    ios7BottomDeck
                }
            }
        }
        .onAppear {
            appState.cameraManager.checkPermissionsAndStart()
            appState.cameraManager.syncFilterState(
                parameters: appState.filterLibrary.activeParameters,
                presetName: appState.filterLibrary.currentPreset.name
            )
        }
        .onChange(of: appState.filterLibrary.activeParameters) { _, newParams in
            appState.cameraManager.syncFilterState(
                parameters: newParams,
                presetName: appState.filterLibrary.currentPreset.name
            )
        }
        .fullScreenCover(isPresented: $appState.isGalleryPresented) {
            GalleryView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.isEditorPresented) {
            FilterEditorView(initialParameters: appState.filterLibrary.activeParameters)
                .environmentObject(appState)
        }
    }

    // MARK: - Persistent Exposure Strip (Available on Every Shot)

    private var persistentExposureBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12))
                .foregroundColor(RetroTheme.amberAccent)

            Slider(
                value: Binding(
                    get: { Double(appState.cameraManager.exposureBias) },
                    set: { appState.cameraManager.setExposureBias(Float($0)) }
                ),
                in: Double(appState.cameraManager.capabilities.minExposureBias)...Double(appState.cameraManager.capabilities.maxExposureBias)
            )
            .tint(RetroTheme.amberAccent)
            .frame(width: 155, height: 20)

            Button {
                appState.cameraManager.setExposureBias(0.0)
            } label: {
                Text(String(format: "%+.1f EV", appState.cameraManager.exposureBias))
                    .font(RetroTheme.monoLabel(9.5, weight: .bold))
                    .foregroundColor(abs(appState.cameraManager.exposureBias) > 0.05 ? RetroTheme.amberAccent : .white.opacity(0.8))
                    .frame(width: 52, alignment: .trailing)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.55))
    }

    // MARK: - Classic iOS 7/8 5-Element Top Bar

    private var ios7TopBar: some View {
        HStack {
            // 1. Flash Toggle
            Button {
                appState.cameraManager.cycleFlashMode()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: flashIconName)
                        .font(.system(size: 16, weight: .light))
                    if appState.cameraManager.flashMode != .off {
                        Text(appState.cameraManager.flashMode == .on ? "On" : "Auto")
                            .font(RetroTheme.uiLabel(11, weight: .regular))
                    }
                }
                .foregroundColor(appState.cameraManager.flashMode == .on ? RetroTheme.amberAccent : .white)
                .opacity(appState.cameraManager.capabilities.supportsFlash ? 1.0 : 0.35)
                .frame(width: 54, alignment: .leading)
            }
            .disabled(!appState.cameraManager.capabilities.supportsFlash)

            Spacer()

            // 2. HDR Off / RAW Indicator (Matches crossed-out HDR in iOS 7/8 screenshot)
            Button {
                appState.cameraManager.toggleRawCapture()
            } label: {
                Text(appState.cameraManager.isRawCaptureEnabled ? "RAW" : "HDR")
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(!appState.cameraManager.isRawCaptureEnabled, color: .white.opacity(0.85))
                    .foregroundColor(appState.cameraManager.isRawCaptureEnabled ? RetroTheme.amberAccent : .white)
            }

            Spacer()

            // 3. Center Zero-HDR / Sensor Status Ring
            Button {
                appState.isEditorPresented = true
            } label: {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            // 4. Self-Timer Icon (Matches clock/timer icon in iOS 7/8 screenshot)
            Button {
                appState.cameraManager.cycleTimerOption()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .light))
                    if appState.cameraManager.timerOption != .off {
                        Text(appState.cameraManager.timerOption.label)
                            .font(RetroTheme.uiLabel(11))
                    }
                }
                .foregroundColor(appState.cameraManager.timerOption != .off ? RetroTheme.amberAccent : .white)
            }

            Spacer()

            // 5. Classic 3-Circle Venn Filter Toggle (Top-Right in iOS 7/8 screenshot)
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isFilterDrawerOpen.toggle()
                }
            } label: {
                ClassicFilterIcon(isActive: appState.isFilterDrawerOpen)
                    .frame(width: 54, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }

    // MARK: - Classic iOS 7/8 Bottom Deck

    private var ios7BottomDeck: some View {
        VStack(spacing: 12) {
            // Mode Selector Strip above shutter: RAW | MANUAL | PHOTO | SQUARE
            HStack(spacing: 22) {
                ForEach(CameraMode.allCases) { mode in
                    let isSelected = appState.activeMode == mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            appState.activeMode = mode
                            appState.setSquareCrop(mode == .square)
                            if mode == .raw && !appState.cameraManager.isRawCaptureEnabled {
                                appState.cameraManager.toggleRawCapture()
                            }
                            if mode == .manual {
                                appState.isFilterDrawerOpen = false
                            }
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? RetroTheme.amberAccent : .white.opacity(0.85))
                            .tracking(0.8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)

            // Bottom Row: Thumbnail (Left) | Concentric Shutter (Center) | Flip Camera (Right)
            HStack {
                Button {
                    appState.isGalleryPresented = true
                } label: {
                    if let thumb = appState.libraryManager.latestThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(RetroTheme.surface)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RetroTheme.hairline, lineWidth: 0.8))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                ShutterButton(isCapturing: appState.cameraManager.isCapturing) {
                    appState.cameraManager.triggerShutterWithTimer {
                        triggerShutterAnimation()
                    }
                }

                Spacer()

                // Classic iOS 7/8 Bottom-Right Camera Flip Icon
                Button {
                    appState.cameraManager.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 14)
        }
        .background(Color.black)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundColor(RetroTheme.amberAccent)
            Text("CAMERA ACCESS REQUIRED")
                .font(RetroTheme.monoLabel(13, weight: .bold))
                .foregroundColor(.white)
            Text("Enable camera access in iOS Settings to use Digicam.")
                .font(RetroTheme.uiLabel(13))
                .foregroundColor(RetroTheme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(RetroTheme.monoLabel(12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(RetroTheme.amberAccent)
        }
    }

    private var flashIconName: String {
        switch appState.cameraManager.flashMode {
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.a"
        case .off:  return "bolt.slash"
        @unknown default: return "bolt.slash"
        }
    }

    private func triggerShutterAnimation() {
        withAnimation(.easeOut(duration: 0.06)) {
            shutterFlashOpacity = 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.14)) {
                shutterFlashOpacity = 0.0
            }
        }
    }

    private func scheduleFocusReticleHide() {
        focusHideTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                appState.cameraManager.focusIndicatorPoint = nil
            }
        }
        focusHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: task)
    }

    private func cyclePreset(direction: Int) {
        let all = appState.filterLibrary.presets
        guard let currentIndex = all.firstIndex(where: { $0.id == appState.filterLibrary.selectedPresetID }) else { return }
        let nextIndex = (currentIndex + direction + all.count) % all.count
        let next = all[nextIndex]
        appState.filterLibrary.selectPreset(next)
        appState.cameraManager.syncFilterState(parameters: next.parameters, presetName: next.name)
    }
}
