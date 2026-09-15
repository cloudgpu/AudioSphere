import AVFoundation
import Combine

/// Manages the AVAudioEngine graph:
/// Player -> Reverb -> Environment(3D/surround) -> MainMixer -> Output
@MainActor
final class AudioEngine: ObservableObject {

    // MARK: - Published state
    @Published var isPlaying = false
    @Published var currentFileName = "No File Loaded"
    @Published var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0

    // Reverb
    @Published var reverbEnabled = true
    @Published var reverbWetDryMix: Float = 30 { didSet { applyReverb() } }
    @Published var reverbPreset: AVAudioUnitReverbPreset = .cathedral { didSet { applyReverb() } }

    // 3D / Spatial
    @Published var spatialEnabled = true { didSet { applySpatial() } }
    @Published var listenerPosition = SIMD3<Float>(0, 0, 0) { didSet { applySpatial() } }

    // Virtual surround
    @Published var surroundEnabled = false { didSet { applySurround() } }
    @Published var surroundAngle: Float = 0 { didSet { applySurround() } }
    @Published var surroundDistance: Float = 2 { didSet { applySurround() } }

    // Master
    @Published var masterVolume: Float = 0.8 { didSet { applyMaster() } }

    // MARK: - Audio nodes
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let environment = AVAudioEnvironmentNode()
    private var playerFile: AVAudioFile?
    private var timer: Timer?

    // MARK: - Init
    init() {
        configureEngine()
        observePlaybackPosition()
    }

    private func configureEngine() {
        engine.attach(playerNode)
        engine.attach(reverb)
        engine.attach(environment)

        // Player -> Reverb
        engine.connect(playerNode, to: reverb, format: nil)
        // Reverb -> Environment
        engine.connect(reverb, to: environment, format: nil)
        // Environment -> MainMixer
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        reverb.loadFactoryPreset(reverbPreset)
        reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0

        applySpatial()
        applyMaster()

        do {
            try engine.start()
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }

    // MARK: - File loading
    func load(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("No security-scoped access for \(url)")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let file = try AVAudioFile(forReading: url)
            playerFile = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            currentFileName = url.lastPathComponent
            currentTime = 0

            if engine.isRunning == false {
                try engine.start()
            }
        } catch {
            currentFileName = "Failed to load: \(error.localizedDescription)"
        }
    }

    // MARK: - Transport
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let playerFile else { return }
        playerNode.scheduleFile(playerFile, at: nil) { [weak self] in
            Task { @MainActor in self?.isPlaying = false }
        }
        playerNode.play()
        isPlaying = true
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
    }

    func seek(to time: TimeInterval) {
        guard let playerFile else { return }
        let wasPlaying = isPlaying
        playerNode.stop()
        let sampleRate = playerFile.processingFormat.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        playerNode.scheduleSegment(
            playerFile,
            startingFrame: frame,
            frameCount: AVAudioFrameCount(playerFile.length - frame),
            at: nil
        ) { [weak self] in
            Task { @MainActor in self?.isPlaying = false }
        }
        if wasPlaying { playerNode.play() }
    }

    // MARK: - Effect application
    private func applyReverb() {
        reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0
    }

    private func applySpatial() {
        environment.listenerPosition = AVAudio3DPoint(
            x: listenerPosition.x,
            y: listenerPosition.y,
            z: listenerPosition.z
        )
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 1
        environment.distanceAttenuationParameters.maximumDistance = 20

        // Position the source in 3D space via AVAudio3DMixing on the player node.
        playerNode.position = AVAudio3DPoint(
            x: sourcePosition.x,
            y: sourcePosition.y,
            z: sourcePosition.z
        )
        playerNode.renderingAlgorithm = surroundEnabled ? .HRTF : .equalPowerPanning
        playerNode.reverbBlend = reverbEnabled ? 0.4 : 0
    }

    private func applySurround() {
        // Virtual surround: orbit the source around the listener.
        let radians = surroundAngle * .pi / 180
        let radius = surroundDistance
        let pos = SIMD3<Float>(
            sin(radians) * radius,
            0,
            cos(radians) * radius
        )
        sourcePosition = pos
        applySpatial()
    }

    @Published var sourcePosition = SIMD3<Float>(0, 0, 2) { didSet { applySpatial() } }

    private func applyMaster() {
        engine.mainMixerNode.outputVolume = masterVolume
    }

    // MARK: - Playback position observation
    private func observePlaybackPosition() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else {
                return
            }
            let t = Double(playerTime.sampleTime) / playerTime.sampleRate
            Task { @MainActor in self.currentTime = t }
        }
    }
}
