import AVFoundation

@MainActor final class SpeechRenderer {
    private let synthesizer = AVSpeechSynthesizer()
    private var sink: SpeechSink?
    func render(_ text: String, choice: VoiceChoice) async throws -> (Data, Double) {
        let utterance = try VoiceCatalog.utterance(text, choice: choice)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let sink = SpeechSink(continuation: continuation)
                self.sink = sink
                synthesizer.write(utterance) { buffer in sink.consume(buffer) }
            }
        }, onCancel: { Task { @MainActor in self.cancel() } })
    }
    func cancel() { synthesizer.stopSpeaking(at: .immediate); sink?.fail(CancellationError()); sink = nil }
}
private final class SpeechSink: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(Data, Double), Error>?
    private var file: AVAudioFile?
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent("RomanVoice-audio-" + UUID().uuidString + ".caf")
    private var frames: Int64 = 0
    private var rate: Double = 44100
    init(continuation: CheckedContinuation<(Data, Double), Error>) { self.continuation = continuation }
    func consume(_ buffer: AVAudioBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard continuation != nil else { return }
        guard let pcm = buffer as? AVAudioPCMBuffer else { finish(.failure(RomanError.message("Kein verwendbarer Audiopuffer."))); return }
        do {
            if pcm.frameLength == 0 {
                file = nil
                guard frames > 0 else { throw RomanError.message("Die Stimme hat keine Audiodaten erzeugt.") }
                finish(.success((try Data(contentsOf: url), Double(frames) / rate)))
            } else {
                if file == nil {
                    rate = pcm.format.sampleRate
                    file = try AVAudioFile(forWriting: url, settings: pcm.format.settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
                }
                try file?.write(from: pcm); frames += Int64(pcm.frameLength)
            }
        } catch { finish(.failure(error)) }
    }
    func fail(_ error: Error) { lock.lock(); defer { lock.unlock() }; finish(.failure(error)) }
    private func finish(_ result: Result<(Data, Double), Error>) {
        let callback = continuation; continuation = nil; file = nil
        try? FileManager.default.removeItem(at: url)
        callback?.resume(with: result)
    }
}
