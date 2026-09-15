import SwiftUI

/// A subtle, animated waveform gradient background for the main window.
struct WaveformBackground: View {
    @EnvironmentObject var audioEngine: AudioEngine

    private let bars = 40

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.blue.opacity(0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                HStack(spacing: 6) {
                    ForEach(0..<bars, id: \.self) { i in
                        WaveBar(
                            height: barHeight(i, width: geo.size.width),
                            animating: audioEngine.isPlaying
                        )
                    }
                }
                .padding(.horizontal, 30)
                .opacity(0.18)
            }
        }
        .ignoresSafeArea()
    }

    private func barHeight(_ i: Int, width: CGFloat) -> CGFloat {
        // Pseudo-random but deterministic heights.
        let n = Double((i * 37) % 13)
        return CGFloat(40 + (n * 14).truncatingRemainder(dividingBy: 90))
    }
}

private struct WaveBar: View {
    let height: CGFloat
    let animating: Bool
    @State private var phase = false

    var body: some View {
        Capsule()
            .fill(.white)
            .frame(width: 6, height: height)
            .scaleEffect(y: animating ? (phase ? 0.5 : 1.0) : 1.0, anchor: .center)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...0.4)),
                value: phase
            )
            .onAppear { phase = true }
    }
}
