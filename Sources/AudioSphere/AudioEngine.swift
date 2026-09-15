import AVFoundation
import Combine
import ScreenCaptureKit
import CoreMedia

/// Captures the default macOS audio sink in real time (via ScreenCaptureKit's
/// SCAudioStream) and routes it through the effect chain:
///   Capture -> Panner(Spatial/Surround) -> Reverb -> MainMixer -> Output
///
/// No virtual audio driver (BlackHole) is required — SCAudioStream taps the
/// system output directly on macOS 14+.
@MainActor
final class AudioEngine: ObservableObject {

    // MARK: - Published state
    @Published var isCapturing = false
    @Published var statusMessage = "Not Capturing"
    @Published var captureError: String?

    // Reverb
    @Published var reverbEnabled = true
    @Published var reverbWetDryMix: Float = 30 { didSet { applyReverb() } }
    @Published var reverbPreset: AVAudioUnitReverbPreset = .cathedral { didSet { applyReverb() } }

    // Spatial (pan) — -1 (left) ... +1 (right)
    @Published var spatialEnabled = true { didSet { applySpatial() } }
    @Published var pan: Float = 0 { didSet { applySpatial() } }

    // Virtual surround — widens the stereo image
    @Published var surroundEnabled = false { didSet { applySurround() } }
    @Published var surroundWidth: Float = 1.0 { didSet { applySurround() } }

    // Master
    @Published var masterVolume: Float = 0.8 { didSet { applyMaster() } }

    // MARK: - Audio nodes
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode!
    private var ringBuffer: RingBuffer!

    // MARK: - Capture
    private var captureSession: SCStream?
    private var isCaptureConfigured = false

    // MARK: - Init
    init() {
        configureEngine()
    }

    // MARK: - Engine config
    private func configureEngine() {
        ringBuffer = RingBuffer(capacity: 48000 * 2 * 2) // ~2s of stereo float32

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let first = ablPointer.first else { return noErr }

            let channelCount = Int(ablPointer.count)
            let frames = Int(frameCount)
            let buffer = first.mData!.assumingMemoryBound(to: Float.self)
            let available = self.ringBuffer.read(into: buffer, count: frames * channelCount)

            // Fill any remaining frames with silence.
            if available < frames * channelCount {
                memset(buffer + available, 0, (frames * channelCount - available) * MemoryLayout<Float>.size)
            }

            // Apply spatial pan (equal-power) and surround width.
            if channelCount == 2 {
                let pan = self.panEnabled ? self.pan : 0
                let width = self.surroundEnabled ? self.surroundWidth : 1.0

                // Equal-power pan gains.
                let angle = (pan + 1) * Float.pi / 4  // 0..pi/2
                let leftGain = cos(angle)
                let rightGain = sin(angle)
                // Width: expand via mid/side.
                let mid = width
                let side = width

                for i in 0..<frames {
                    let l = buffer[i*2]
                    let r = buffer[i*2+1]
                    // Mid/side with width.
                    let m = (l + r) * 0.5
                    let s = (l - r) * 0.5
                    let wl = m + s * side
                    let wr = m - s * side
                    // Apply pan.
                    buffer[i*2] = wl * leftGain
                    buffer[i*2+1] = wr * rightGain
                    _ = mid
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.attach(reverb)

        // Source -> Reverb
        engine.connect(sourceNode, to: reverb, format: nil)
        // Reverb -> MainMixer
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        reverb.loadFactoryPreset(reverbPreset)
        reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0

        applyMaster()
    }

    // MARK: - Capture control
    func toggleCapture() {
        isCapturing ? stopCapture() : startCapture()
    }

    func startCapture() {
        captureError = nil
        Task {
            do {
                try await setupCapture()
                try engine.start()
                captureSession?.startCapture()
                isCapturing = true
                statusMessage = "Capturing system audio"
            } catch {
                captureError = error.localizedDescription
                statusMessage = "Capture failed"
                print("AudioEngine capture start error: \(error)")
            }
        }
    }

    func stopCapture() {
        captureSession?.stopCapture()
        captureSession = nil
        isCaptureConfigured = false
        if engine.isRunning {
            engine.stop()
        }
        ringBuffer.clear()
        isCapturing = false
        statusMessage = "Not Capturing"
    }

    private func setupCapture() async throws {
        guard !isCaptureConfigured else { return }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "AudioSphere", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No display available for audio capture"])
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 48000
        config.channelCount = 2
        config.showsCursor = false
        config.width = 2
        config.height = 2

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.captureSession = stream
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream.startCapture()
        isCaptureConfigured = true
    }
}

// MARK: - SCAudioStreamOutput
extension AudioEngine: SCAudioStreamOutput {
    nonisolated func audioStream(_ audioStream: SCAudioStream,
                                 didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                                 of type: SCAudioStreamOutputType) {
        guard type == .audio else { return }
        guard let formatDesc = sampleBuffer.formatDescription,
              let asbd = formatDesc.audioStreamBasicDescription,
              let blockBuffer = sampleBuffer.dataBuffer else { return }

        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        let byteCount = blockBuffer.dataLength
        let frameCount = byteCount / bytesPerFrame
        guard frameCount > 0 else { return }

        var dataPointer: UnsafeMutablePointer<Int8>?
        _ = blockBuffer.withUnsafeMutableBytes { ptr in
            dataPointer = ptr.baseAddress?.assumingMemoryBound(to: Int8.self)
            return true
        }
        guard let dataPointer else { return }

        let outFormat = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: 2)!
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0, asbd.mBitsPerChannel == 32 {
            memcpy(pcmBuffer.floatChannelData![0], dataPointer, byteCount)
        } else if asbd.mBitsPerChannel == 16 {
            // Convert SInt16 -> Float32
            let count = frameCount * Int(asbd.mChannelsPerFrame)
            let src = dataPointer.withMemoryRebound(to: Int16.self, capacity: count) { $0 }
            let dst = pcmBuffer.floatChannelData![0]
            for i in 0..<count {
                dst[i] = Float(src[i]) / 32768.0
            }
        } else {
            return // Unsupported format
        }

        // Push float32 interleaved into ring buffer.
        if let interleaved = pcmBuffer.floatChannelData {
            let count = Int(pcmBuffer.frameLength) * 2
            self.ringBuffer.write(interleaved[0], count: count)
        }
    }
}

// MARK: - Effect application
extension AudioEngine {
    // Thread-safe accessors read by the render callback.
    private var panEnabled: Bool { spatialEnabled }
    private var panValue: Float { pan }
    private var widthValue: Float { surroundWidth }
    private var surroundOn: Bool { surroundEnabled }

    private func applyReverb() {
        reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0
    }

    private func applySpatial() {
        // Values are read live by the render callback.
    }

    private func applySurround() {
        // Values are read live by the render callback.
    }

    private func applyMaster() {
        engine.mainMixerNode.outputVolume = masterVolume
    }
}

// MARK: - Simple thread-safe ring buffer
/// A small thread-safe ring buffer for interleaved Float32 samples.
/// Producer: SCAudioStream output thread. Consumer: AVAudioSourceNode render thread.
final class RingBuffer {
    private var buffer: [Float]
    private let capacity: Int
    private var readIndex = 0
    private var writeIndex = 0
    private var filled = 0
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    func write(_ data: UnsafePointer<Float>, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<count {
            buffer[(writeIndex + i) % capacity] = data[i]
        }
        writeIndex = (writeIndex + count) % capacity
        filled += count
        if filled > capacity { filled = capacity }
    }

    func read(into dest: UnsafeMutablePointer<Float>, count: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let toRead = min(count, filled)
        for i in 0..<toRead {
            dest[i] = buffer[(readIndex + i) % capacity]
        }
        readIndex = (readIndex + toRead) % capacity
        filled -= toRead
        return toRead
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        readIndex = 0
        writeIndex = 0
        filled = 0
    }
}
