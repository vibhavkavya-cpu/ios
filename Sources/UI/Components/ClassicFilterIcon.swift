import SwiftUI

/// Classic iOS 7/8 three-overlapping-circles filter button icon
struct ClassicFilterIcon: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? RetroTheme.amberAccent.opacity(0.75) : Color.white.opacity(0.45))
                .frame(width: 11, height: 11)
                .offset(y: -3.5)

            Circle()
                .fill(isActive ? RetroTheme.amberAccent.opacity(0.85) : Color.white.opacity(0.65))
                .frame(width: 11, height: 11)
                .offset(x: -3.5, y: 2.5)

            Circle()
                .fill(isActive ? RetroTheme.amberAccent : Color.white.opacity(0.85))
                .frame(width: 11, height: 11)
                .offset(x: 3.5, y: 2.5)
        }
        .frame(width: 24, height: 24)
    }
}
