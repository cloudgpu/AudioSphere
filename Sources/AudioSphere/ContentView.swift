import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        HSplitView {
            // MARK: - Sidebar (glass)
            LibrarySidebarView()
                .frame(minWidth: 220, idealWidth: 240)

            // MARK: - Main content
            VStack(spacing: 0) {
                HeaderView()

                ZStack {
                    // Now capturing visualisation
                    NowPlayingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Floating effects card
                    VStack(spacing: 24) {
                        CaptureControlsView()
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
                    audioEngine.toggleCapture()
                } label: {
                    Label(
                        audioEngine.isCapturing ? "Stop Capture" : "Start Capture",
                        systemImage: audioEngine.isCapturing ? "stop.circle.fill" : "record.circle"
                    )
                }
                .help(audioEngine.isCapturing ? "Stop capturing system audio" : "Start capturing system audio")
            }
        }
    }
}

// MARK: - Sidebar
struct LibrarySidebarView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Label("AudioSphere", systemImage: "music.note.list")
                .font(.title3.weight(.semibold))
                .listRowSeparator(.hidden)

            Label("System Audio", systemImage: "speaker.wave.2.fill")
                .foregroundStyle(audioEngine.isCapturing ? Color.accentColor : Color.secondary)
            Label("Reverb", systemImage: "waveform.badge.plus")
                .foregroundStyle(audioEngine.reverbEnabled ? Color.accentColor : Color.secondary)
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
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AudioSphere")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(audioEngine.statusMessage)
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

// MARK: - Capture controls
struct CaptureControlsView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { audioEngine.toggleCapture() }) {
                Label(
                    audioEngine.isCapturing ? "Stop Capture" : "Start Capture",
                    systemImage: audioEngine.isCapturing ? "stop.circle.fill" : "record.circle.fill"
                )
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help(audioEngine.isCapturing ? "Stop" : "Start")

            if let error = audioEngine.captureError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
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

            // Spatial / Pan
            HStack(alignment: .center) {
                Toggle("", isOn: $audioEngine.spatialEnabled)
                    .labelsHidden()
                Image(systemName: "wave.3.right")
                    .foregroundStyle(audioEngine.spatialEnabled ? Color.accentColor : Color.secondary)
                Text("3D Pan")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $audioEngine.pan, in: -1...1)
                    .disabled(!audioEngine.spatialEnabled)
                Text(panLabel)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 40, alignment: .trailing)
            }

            // Surround
            HStack(alignment: .center) {
                Toggle("", isOn: $audioEngine.surroundEnabled)
                    .labelsHidden()
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(audioEngine.surroundEnabled ? Color.accentColor : Color.secondary)
                Text("Surround")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $audioEngine.surroundWidth, in: 0.5...3.0)
                    .disabled(!audioEngine.surroundEnabled)
                Text(String(format: "%.1f", audioEngine.surroundWidth))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 40, alignment: .trailing)
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

    private var panLabel: String {
        switch audioEngine.pan {
        case ..<(-0.33): return "L"
        case -0.33...0.33: return "C"
        default: return "R"
        }
    }
}

// MARK: - Now capturing visualisation
struct NowPlayingView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: audioEngine.isCapturing ? "waveform" : "speaker.wave.2")
                .font(.system(size: 64))
                .symbolEffect(.pulse, isActive: audioEngine.isCapturing)
                .foregroundStyle(.tint)

            Text(audioEngine.isCapturing ? "Capturing System Audio" : "System Audio")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(audioEngine.isCapturing ? "Effects Applied in Real Time" : "Press Start to capture the default audio sink")
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
