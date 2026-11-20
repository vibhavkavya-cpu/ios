import SwiftUI

struct FocusReticleView: View {
    let point: CGPoint
    @Binding var exposureBias: Float
    let minBias: Float
    let maxBias: Float
    let onBiasChanged: (Float) -> Void

    @State private var pulseScale: CGFloat = 1.25
    @State private var dragStartBias: Float = 0.0

    var body: some View {
        HStack(spacing: 10) {
            // Classic iOS 7/8 square yellow focus reticle with 4 inward tick marks
            ZStack {
                Rectangle()
                    .stroke(RetroTheme.amberAccent, lineWidth: 1.1)
                    .frame(width: 78, height: 78)

                VStack {
                    Rectangle().fill(RetroTheme.amberAccent).frame(width: 1, height: 6)
                    Spacer()
                    Rectangle().fill(RetroTheme.amberAccent).frame(width: 1, height: 6)
                }
                .frame(height: 78)

                HStack {
                    Rectangle().fill(RetroTheme.amberAccent).frame(width: 6, height: 1)
                    Spacer()
                    Rectangle().fill(RetroTheme.amberAccent).frame(width: 6, height: 1)
                }
                .frame(width: 78)
            }
            .scaleEffect(pulseScale)

            // Vertical Sun Exposure Bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let norm = CGFloat((exposureBias - minBias) / max(0.01, maxBias - minBias))
                    let yPos = (1.0 - max(0, min(1, norm))) * geo.size.height

                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(RetroTheme.amberAccent.opacity(0.45))
                            .frame(width: 1, height: geo.size.height)
                            .frame(maxWidth: .infinity)

                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 14))
                            .foregroundColor(RetroTheme.amberAccent)
                            .background(Color.black.opacity(0.4))
                            .offset(y: max(0, min(geo.size.height - 14, yPos - 7)))
                    }
                }
                .frame(width: 20, height: 84)
            }
        }
        .position(x: point.x + 15, y: point.y)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let delta = Float(-value.translation.height / 90.0) * (maxBias - minBias) * 0.5
                    let next = max(minBias, min(maxBias, dragStartBias + delta))
                    onBiasChanged(next)
                }
                .onEnded { _ in
                    dragStartBias = exposureBias
                }
        )
        .onAppear {
            dragStartBias = exposureBias
            withAnimation(.easeOut(duration: 0.2)) {
                pulseScale = 1.0
            }
        }
    }
}
