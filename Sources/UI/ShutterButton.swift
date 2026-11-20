import SwiftUI
import UIKit

/// Classic iOS 7/8 concentric white ring + solid inner disk shutter button
struct ShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    @State private var isPressed = false
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            impact.prepare()
            impact.impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3.2)
                    .frame(width: 68, height: 68)

                Circle()
                    .fill(isCapturing ? RetroTheme.amberAccent : Color.white)
                    .frame(width: 56, height: 56)
                    .scaleEffect(isPressed ? 0.90 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = false }
                }
        )
        .disabled(isCapturing)
    }
}
