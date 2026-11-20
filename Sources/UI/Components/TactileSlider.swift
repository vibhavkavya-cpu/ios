import SwiftUI
import UIKit

struct TactileSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    @State private var lastTickBucket: Int = -1
    private let feedback = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(label)
                    .font(RetroTheme.monoLabel(10, weight: .medium))
                    .foregroundColor(RetroTheme.mutedText)
                Spacer()
                Text(String(format: format, value))
                    .font(RetroTheme.monoLabel(10, weight: .semibold))
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let progress = max(0, min(1, (value - range.lowerBound) / max(0.0001, range.upperBound - range.lowerBound)))
                let thumbX = progress * width

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<21, id: \.self) { idx in
                            Rectangle()
                                .fill(idx % 5 == 0 ? Color.white.opacity(0.45) : Color.white.opacity(0.18))
                                .frame(width: 1, height: idx % 5 == 0 ? 10 : 6)
                            if idx < 20 { Spacer() }
                        }
                    }

                    Rectangle()
                        .fill(RetroTheme.amberAccent)
                        .frame(width: thumbX, height: 2)

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 18)
                        .offset(x: max(0, min(width - 3, thumbX - 1.5)))
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let ratio = max(0, min(1, gesture.location.x / width))
                            let updated = range.lowerBound + (ratio * (range.upperBound - range.lowerBound))
                            value = updated

                            let bucket = Int(ratio * 20)
                            if bucket != lastTickBucket {
                                lastTickBucket = bucket
                                feedback.selectionChanged()
                            }
                        }
                )
            }
            .frame(height: 22)
        }
    }
}
