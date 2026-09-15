import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        Form {
            Section("Capture") {
                Toggle("Enable spatial audio", isOn: $audioEngine.spatialEnabled)
                Toggle("Enable virtual surround", isOn: $audioEngine.surroundEnabled)
            }

            Section("Reverb") {
                Toggle("Enable reverb", isOn: $audioEngine.reverbEnabled)
                Picker("Reverb preset", selection: $audioEngine.reverbPreset) {
                    ForEach(ReverbPresetOption.allCases, id: \.self) { opt in
                        Text(opt.title).tag(opt.preset)
                    }
                }
            }

            Section("Volume") {
                Slider(value: $audioEngine.masterVolume, in: 0...1) {
                    Text("Master Volume")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
