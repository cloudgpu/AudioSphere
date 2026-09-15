import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var isFileImporterPresented = false

    var body: some View {
        HSplitView {
            // MARK: - Sidebar (glass)
            LibrarySidebarView()
                .frame(minWidth: 220, idealWidth: 240)

            // MARK: - Main content
            VStack(spacing: 0) {
                HeaderView(fileName: audioEngine.currentFileName)

                ZStack {
                    // Now playing visualisation
                    NowPlayingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Floating effects card
                    VStack(spacing: 24) {
                        TransportControlsView()
                        EffectsPanelView()
                    }
                    .padding(28)
                }
            }
            .frame(minWidth: 700)
        }
        .background {
            WaveformBackground()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Open Audio", systemImage: "folder")
                }
                .help("Open an audio file")
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                audioEngine.load(url: url)
            }
        }
    }
}

// MARK: - Sidebar
struct LibrarySidebarView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Label("Library", systemImage: "music.note.list")
                .font(.title3.weight(.semibold))
                .listRowSeparator(.hidden)

            Label("Recently Played", systemImage: "clock")
            Label("Favorites", systemImage: "heart")
            Label("3D Sound", systemImage: "wave.3.right")
                .foregroundStyle(audioEngine.spatialEnabled ? Color.accentColor : Color.secondary)
            Label("Surround", systemImage: "speaker.wave.3.fill")
                .foregroundStyle(audioEngine.surroundEnabled ? Color.accentColor : Color.secondary)
        }
        .listStyle(.sidebar)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Header
struct HeaderView: View {
    let fileName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AudioSphere")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(fileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }
}

// MARK: - Transport controls
struct TransportControlsView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    private func format(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "00:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress slider
            HStack(spacing: 10) {
                Text(format(audioEngine.currentTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { audioEngine.currentTime },
                        set: { audioEngine.seek(to: $0) }
                    ),
                    in: 0...max(audioEngine.duration, 0.01)
                )
                Text(format(audioEngine.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(true)

                Button(action: { audioEngine.togglePlayPause() }) {
                    Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(audioEngine.isPlaying ? "Pause" : "Play")

                Button(action: { audioEngine.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Stop")

                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
            .padding(.top, 4)
        }
        .glassCard()
    }
}

// MARK: - Effects panel
struct EffectsPanelView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 18) {
            Text("Effects")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Reverb
            HStack(alignment: .center) {
                Toggle("", isOn: $audioEngine.reverbEnabled)
                    .labelsHidden()
                Image(systemName: "waveform.badge.plus")
                    .foregroundStyle(audioEngine.reverbEnabled ? Color.accentColor : Color.secondary)
                Text("Reverb")
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $audioEngine.reverbPreset) {
                    ForEach(ReverbPresetOption.allCases, id: \.self) { opt in
                        Text(opt.title).tag(opt.preset)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                Slider(value: $audioEngine.reverbWetDryMix, in: 0...100)
                Text("\(Int(audioEngine.reverbWetDryMix))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            Divider()

            // 3D / Spatial
            HStack(alignment: .center) {
                Toggle("", isOn: $audioEngine.spatialEnabled)
                    .labelsHidden()
                Image(systemName: "wave.3.right")
                    .foregroundStyle(audioEngine.spatialEnabled ? Color.accentColor : Color.secondary)
                Text("3D Sound")
                    .frame(width: 60, alignment: .leading)

                // Surround
                Toggle("", isOn: $audioEngine.surroundEnabled)
                    .labelsHidden()
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(audioEngine.surroundEnabled ? Color.accentColor : Color.secondary)
                Text("Surround")
                    .frame(width: 70, alignment: .leading)

                Spacer()
            }

            // Surround orbit controls
            if audioEngine.surroundEnabled {
                HStack(spacing: 16) {
                    Text("Angle")
                        .frame(width: 40, alignment: .leading)
                    Slider(value: $audioEngine.surroundAngle, in: -180...180)
                        .disabled(!audioEngine.surroundEnabled)
                    Text("\(Int(audioEngine.surroundAngle))°")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)

                    Text("Distance")
                        .frame(width: 60, alignment: .leading)
                    Slider(value: $audioEngine.surroundDistance, in: 0.5...10)
                        .disabled(!audioEngine.surroundEnabled)
                    Text(String(format: "%.1f", audioEngine.surroundDistance))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Divider()

            // Master volume
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $audioEngine.masterVolume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
        }
        .glassCard()
    }
}

// MARK: - Now playing visualisation
struct NowPlayingView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: audioEngine.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 64))
                .symbolEffect(.pulse, isActive: audioEngine.isPlaying)
                .foregroundStyle(.tint)

            Text(audioEngine.currentFileName)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(audioEngine.isPlaying ? "Now Playing" : "Ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Glass card modifier
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Reverb preset options
enum ReverbPresetOption: CaseIterable {
    case smallRoom, mediumRoom, largeRoom, mediumHall, largeHall, cathedral, plate

    var title: String {
        switch self {
        case .smallRoom: return "Small Room"
        case .mediumRoom: return "Medium Room"
        case .largeRoom: return "Large Room"
        case .mediumHall: return "Medium Hall"
        case .largeHall: return "Large Hall"
        case .cathedral: return "Cathedral"
        case .plate: return "Plate"
        }
    }

    var preset: AVAudioUnitReverbPreset {
        switch self {
        case .smallRoom: return .smallRoom
        case .mediumRoom: return .mediumRoom
        case .largeRoom: return .largeRoom
        case .mediumHall: return .mediumHall
        case .largeHall: return .largeHall
        case .cathedral: return .cathedral
        case .plate: return .plate
        }
    }
}
