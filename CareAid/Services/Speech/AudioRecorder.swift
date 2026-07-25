import AVFoundation
import Foundation
import Observation

/// Captures microphone audio, publishes levels for the waveform, and hands
/// buffers to whoever is transcribing.
///
/// Writes the audio to a file as it goes, even though Apple's recogniser works
/// from the live buffers and never reads it. Two reasons: "never lose input"
/// (§8) is stronger if the recording survives a crash, and ElevenLabs needs a
/// file to upload when that key arrives.
@Observable
final class AudioRecorder {

    enum RecorderError: LocalizedError {
        case microphoneDenied
        case engineFailed(String)

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                "CareAid needs the microphone. Settings › CareAid › Microphone."
            case .engineFailed(let detail):
                "Couldn't start recording. \(detail)"
            }
        }
    }

    /// A rolling window of recent loudness, 0…1, for the waveform.
    private(set) var levels: [Float] = []
    private(set) var isRecording = false

    private let engine = AVAudioEngine()
    private let sink = Sink()
    private(set) var fileURL: URL?

    /// Called on the audio thread for every buffer — keep the work small.
    ///
    /// `@Sendable` is required, not decorative: the target builds with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a plain closure written
    /// at a call site would be main-actor isolated and assert the moment the
    /// audio thread called it.
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)? {
        get { sink.onBuffer }
        set { sink.onBuffer = newValue }
    }

    /// Everything the audio thread touches, deliberately outside actor
    /// isolation. `AVAudioPCMBuffer` is not `Sendable` and the tap runs off the
    /// main actor, so hopping each buffer to `@MainActor` would both fail to
    /// compile and be the wrong thing to do 40 times a second.
    ///
    /// `nonisolated` is what actually keeps that promise. The target sets
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it every member
    /// here is main-actor isolated — `@unchecked Sendable` waives the checking
    /// but does not change the isolation — and `receive` asserts on the audio
    /// thread the first time a buffer arrives.
    private nonisolated final class Sink: @unchecked Sendable {
        var file: AVAudioFile?
        var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
        var onLevel: (@Sendable (Float) -> Void)?

        func receive(_ buffer: AVAudioPCMBuffer) {
            try? file?.write(from: buffer)
            onBuffer?(buffer)
            onLevel?(AudioRecorder.loudness(of: buffer))
        }
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() async throws {
        guard await Self.requestPermission() else { throw RecorderError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-\(UUID().uuidString).caf")
        sink.file = try AVAudioFile(forWriting: url, settings: format.settings)
        sink.onLevel = { @Sendable [weak self] level in
            // Only the Float crosses back to the main actor, once per buffer.
            Task { @MainActor in self?.append(level) }
        }
        fileURL = url

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [sink] buffer, _ in
            sink.receive(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed(error.localizedDescription)
        }
        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        sink.file = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Throws the recording away — she cancelled, so nothing should persist.
    func discard() {
        stop()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        levels = []
    }

    private func append(_ level: Float) {
        levels.append(level)
        if levels.count > Self.windowSize { levels.removeFirst(levels.count - Self.windowSize) }
    }

    static let windowSize = 48

    /// RMS, then scaled so quiet speech still moves the bars — a waveform that
    /// barely twitches reads as "not listening".
    private nonisolated static func loudness(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0 ..< count { sum += channel[i] * channel[i] }
        let rms = (sum / Float(count)).squareRoot()
        let db = 20 * log10(max(rms, 0.000_001))
        return min(max((db + 50) / 50, 0), 1)
    }
}
