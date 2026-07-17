@preconcurrency import AVFoundation
import Speech
import SwiftUI

enum TimedAnswerState: Equatable {
    case idle
    case ready
    case preparing
    case recording
    case transcribing
    case readyToAnalyze
    case failed(String)

    var title: String {
        switch self {
        case .idle, .ready: return "Ready when you are"
        case .preparing: return "Preparing Apple speech recognition"
        case .recording: return "Recording your answer"
        case .transcribing: return "Turning speech into text"
        case .readyToAnalyze: return "Review before sending"
        case .failed: return "Recording needs attention"
        }
    }

    var detail: String {
        switch self {
        case .idle, .ready: return "Tap the circle to begin. You have up to 1 minute 30 seconds."
        case .preparing: return "Loading the on-device speech model. This may take a moment the first time."
        case .recording: return "Speak naturally, then tap the circle again to finish."
        case .transcribing: return "Finishing the transcript so you can review and correct it."
        case .readyToAnalyze: return "Edit the transcript if needed, then send it for AI analysis."
        case .failed(let message): return message
        }
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private final class AppleNativeSpeechSession: @unchecked Sendable {
    private let requestedLocale: Locale
    private let onTranscript: @Sendable (String) -> Void

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var analyzerInputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var microphoneInputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var conversionTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private let converter = AppleNativeSpeechBufferConverter()

    private var finalizedTranscript = ""
    private var volatileTranscript = ""

    init(
        locale: Locale = Locale(identifier: "en-US"),
        onTranscript: @escaping @Sendable (String) -> Void
    ) {
        requestedLocale = locale
        self.onTranscript = onTranscript
    }

    func prepare() async throws {
        guard SpeechTranscriber.isAvailable,
              let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw AppleNativeSpeechError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )
        self.transcriber = transcriber

        // AssetInventory owns the Apple on-device language model. The request
        // automatically reserves the locale and only downloads when needed.
        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installationRequest.downloadAndInstall()
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AppleNativeSpeechError.noCompatibleAudioFormat
        }
        self.analyzerFormat = analyzerFormat

        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)
        )
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (analyzerInputs, analyzerInputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.analyzerInputContinuation = analyzerInputContinuation

        let (microphoneInputs, microphoneInputContinuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
        self.microphoneInputContinuation = microphoneInputContinuation

        conversionTask = Task { [weak self] in
            guard let self else { return }
            for await buffer in microphoneInputs {
                guard !Task.isCancelled else { break }
                do {
                    let converted = try self.converter.convert(buffer, to: analyzerFormat)
                    analyzerInputContinuation.yield(AnalyzerInput(buffer: converted))
                } catch {
                    #if DEBUG
                    print("Apple SpeechAnalyzer audio conversion failed: \(error.localizedDescription)")
                    #endif
                }
            }
            analyzerInputContinuation.finish()
        }

        resultTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self, !Task.isCancelled else { break }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.finalizedTranscript += text
                        self.volatileTranscript = ""
                    } else {
                        self.volatileTranscript = text
                    }
                    self.onTranscript(self.finalizedTranscript + self.volatileTranscript)
                }
            } catch {
                #if DEBUG
                print("Apple SpeechAnalyzer transcription stopped: \(error.localizedDescription)")
                #endif
            }
        }

        try await analyzer.start(inputSequence: analyzerInputs)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        microphoneInputContinuation?.yield(buffer)
    }

    func finish() async {
        microphoneInputContinuation?.finish()
        await conversionTask?.value

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            #if DEBUG
            print("Apple SpeechAnalyzer finalization failed: \(error.localizedDescription)")
            #endif
        }

        await resultTask?.value
        clearReferences()
    }

    func cancel() async {
        microphoneInputContinuation?.finish()
        analyzerInputContinuation?.finish()
        conversionTask?.cancel()
        resultTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        clearReferences()
    }

    private func clearReferences() {
        microphoneInputContinuation = nil
        analyzerInputContinuation = nil
        conversionTask = nil
        resultTask = nil
        analyzer = nil
        transcriber = nil
        analyzerFormat = nil
    }
}

@available(iOS 26.0, *)
private final class AppleNativeSpeechBufferConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != outputFormat else { return buffer }

        if converter == nil
            || converter?.inputFormat != inputFormat
            || converter?.outputFormat != outputFormat {
            converter = AVAudioConverter(from: inputFormat, to: outputFormat)
            converter?.primeMethod = .none
        }

        guard let converter else {
            throw AppleNativeSpeechError.converterUnavailable
        }

        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw AppleNativeSpeechError.conversionBufferUnavailable
        }

        var conversionError: NSError?
        var suppliedInput = false
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error else {
            throw conversionError ?? AppleNativeSpeechError.conversionFailed
        }
        return converted
    }
}
#endif

private enum AppleNativeSpeechError: LocalizedError {
    case unsupportedLocale
    case noCompatibleAudioFormat
    case converterUnavailable
    case conversionBufferUnavailable
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale: return "Apple speech recognition does not support this language on this device."
        case .noCompatibleAudioFormat: return "Apple speech recognition could not prepare an audio format."
        case .converterUnavailable: return "The speech audio converter could not start."
        case .conversionBufferUnavailable: return "The speech audio buffer could not be created."
        case .conversionFailed: return "The speech audio could not be converted."
        }
    }
}

/// Keeps a compact copy of the spoken answer for the server-side Vivid
/// transcription pass. The app streams only 16 kHz mono PCM (about 2.9 MB for
/// the 90-second limit), then wraps it in a standard WAV container on demand.
private final class VividAnswerAudioCapture: @unchecked Sendable {
    private static let maximumPCMBytes = 3_600_000
    private let lock = NSLock()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    private var converter: AVAudioConverter?
    private var pcmData = Data()

    func reset() {
        lock.lock()
        pcmData.removeAll(keepingCapacity: true)
        converter = nil
        lock.unlock()
    }

    func append(_ input: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard pcmData.count < Self.maximumPCMBytes, input.frameLength > 0 else { return }

        if converter == nil
            || converter?.inputFormat != input.format
            || converter?.outputFormat != targetFormat {
            converter = AVAudioConverter(from: input.format, to: targetFormat)
            converter?.primeMethod = .none
        }
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / input.format.sampleRate
        let frameCapacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up)) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error,
              let samples = converted.int16ChannelData?.pointee,
              converted.frameLength > 0 else { return }

        let byteCount = Int(converted.frameLength) * MemoryLayout<Int16>.size
        let remainingBytes = Self.maximumPCMBytes - pcmData.count
        guard remainingBytes > 0 else { return }
        pcmData.append(Data(bytes: samples, count: min(byteCount, remainingBytes)))
    }

    func wavData() -> Data? {
        lock.lock()
        let pcm = pcmData
        lock.unlock()
        guard !pcm.isEmpty else { return nil }

        var wav = Data()
        wav.append("RIFF".data(using: .ascii)!)
        Self.appendLittleEndian(UInt32(36 + pcm.count), to: &wav)
        wav.append("WAVEfmt ".data(using: .ascii)!)
        Self.appendLittleEndian(UInt32(16), to: &wav)
        Self.appendLittleEndian(UInt16(1), to: &wav)
        Self.appendLittleEndian(UInt16(1), to: &wav)
        Self.appendLittleEndian(UInt32(16_000), to: &wav)
        Self.appendLittleEndian(UInt32(32_000), to: &wav)
        Self.appendLittleEndian(UInt16(2), to: &wav)
        Self.appendLittleEndian(UInt16(16), to: &wav)
        wav.append("data".data(using: .ascii)!)
        Self.appendLittleEndian(UInt32(pcm.count), to: &wav)
        wav.append(pcm)
        return wav
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

/// Keeps potentially blocking AVAudioSession work off the SwiftUI main actor.
/// AVAudioSession's activation API is synchronous in the current Xcode SDK,
/// even on newer iOS runtimes, so `await session.setActive(...)` does not
/// actually move the work away from the UI thread.
private enum QuestionAudioSessionCoordinator {
    private static let queue = DispatchQueue(
        label: "app.careervivid.mobile.question-audio-session",
        qos: .userInitiated
    )

    static func activateForRecording() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    // `.record` can leave Simulator without an active input route
                    // even after microphone permission is granted. Keep the
                    // short-answer flow aligned with the live interview session.
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try? session.setPreferredSampleRate(44_100)
                    try? session.setPreferredIOBufferDuration(0.02)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func deactivateWhenIdle() {
        queue.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

@MainActor
final class TimedAnswerSession: ObservableObject {
    @Published private(set) var state: TimedAnswerState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var audioLevel: CGFloat = 0

    let maximumDuration = 90

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var finalizationTask: Task<Void, Never>?
    private var startedAt: Date?
    private var activeAttemptID: UUID?
    private var activeAudioRouteID: UUID?
    private var isInputTapInstalled = false
    private var appleNativeSpeechSession: AnyObject?
    private var usesAppleNativeSpeech = false
    private let vividAudioCapture = VividAnswerAudioCapture()

    var progress: CGFloat {
        min(CGFloat(elapsedSeconds) / CGFloat(maximumDuration), 1)
    }

    var formattedDuration: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var vividAudioWAV: Data? {
        vividAudioCapture.wavData()
    }

    func replaceTranscript(with text: String) {
        transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startRecording() async {
        guard state != .preparing && state != .recording && state != .transcribing else { return }
        reset()
        let attemptID = UUID()
        activeAttemptID = attemptID
        state = .idle

        guard await microphonePermissionGranted() else {
            state = .failed("Allow microphone access to record your answer, or type it instead.")
            return
        }
        // Apple Speech supplies only the live, on-screen preview. The final
        // transcript is produced by the authenticated Vivid service
        // function, so a Speech permission denial must not block recording.
        let appleSpeechAuthorized = await speechPermissionGranted()
        state = .preparing

        do {
            try await configureAudioSession()
            let inputNode = audioEngine.inputNode
            let format = await usableInputFormat(from: inputNode)

            // The Simulator (and a device with no usable input route) can report
            // a zero-Hz format while Core Audio is switching to the selected
            // input. AVAudioEngine aborts the app if a tap is installed with
            // that format, so wait briefly for the route before giving up.
            guard let format else {
                stopAudioEngine()
                activeAttemptID = nil
                state = .failed("No microphone input is available. Check your device microphone, then try again.")
                return
            }

            var appleNativeBufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?

            #if compiler(>=6.2)
            if appleSpeechAuthorized,
               #available(iOS 26.0, *), SpeechTranscriber.isAvailable {
                do {
                    let nativeSession = AppleNativeSpeechSession { [weak self] text in
                        Task { @MainActor [weak self] in
                            guard let self,
                                  self.activeAttemptID == attemptID,
                                  self.state == .recording || self.state == .transcribing else { return }
                            self.transcript = text
                        }
                    }
                    try await nativeSession.prepare()
                    appleNativeSpeechSession = nativeSession
                    usesAppleNativeSpeech = true
                    appleNativeBufferHandler = { [weak nativeSession] buffer in
                        nativeSession?.append(buffer)
                    }
                } catch {
                    #if DEBUG
                    print("Apple SpeechAnalyzer unavailable; using SFSpeechRecognizer fallback: \(error.localizedDescription)")
                    #endif
                    appleNativeSpeechSession = nil
                    usesAppleNativeSpeech = false
                }
            }
            #endif

            var legacyRequest: SFSpeechAudioBufferRecognitionRequest?
            if !usesAppleNativeSpeech, appleSpeechAuthorized {
                guard speechRecognizer?.isAvailable == true else {
                    stopAudioEngine()
                    activeAttemptID = nil
                    state = .failed("Speech recognition is unavailable right now. You can type your answer instead.")
                    return
                }

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.taskHint = .dictation
                request.addsPunctuation = true
                #if !targetEnvironment(simulator)
                if speechRecognizer?.supportsOnDeviceRecognition == true {
                    request.requiresOnDeviceRecognition = true
                }
                #endif
                recognitionRequest = request
                legacyRequest = request

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                    Task { @MainActor [weak self] in
                        self?.handleRecognition(result: result, error: error, attemptID: attemptID)
                    }
                }
            }

            let vividAudioCapture = self.vividAudioCapture
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self, weak legacyRequest] buffer, _ in
                let level = Self.normalizedAudioLevel(from: buffer)
                Task { @MainActor [weak self] in
                    guard self?.state == .recording else { return }
                    self?.audioLevel = level
                }
                if let appleNativeBufferHandler {
                    appleNativeBufferHandler(buffer)
                } else {
                    legacyRequest?.append(buffer)
                }
                vividAudioCapture.append(buffer)
            }
            isInputTapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            startedAt = Date()
            state = .recording
            startTimer()
            QuestionRecordingCue.play(.started)
            QuestionHaptic.play(.medium)
        } catch {
            stopAudioEngine()
            state = .failed("The microphone could not start. Check your device input, then try again.")
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        guard let attemptID = activeAttemptID else {
            state = .failed("The recording session ended unexpectedly. Please try again.")
            return
        }
        stopTimer()
        updateElapsedSeconds()
        stopAudioEngine()
        state = .transcribing
        QuestionRecordingCue.play(.stopped)
        QuestionHaptic.play(.light)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *),
           usesAppleNativeSpeech,
           let nativeSession = appleNativeSpeechSession as? AppleNativeSpeechSession {
            finalizationTask?.cancel()
            finalizationTask = Task { [weak self] in
                await nativeSession.finish()
                await MainActor.run {
                    guard let self,
                          self.state == .transcribing,
                          self.activeAttemptID == attemptID else { return }
                    self.finishTranscriptionIfPossible(for: attemptID)
                }
            }
            return
        }
        #endif

        recognitionRequest?.endAudio()

        finalizationTask?.cancel()
        finalizationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                guard let self,
                      self.state == .transcribing,
                      self.activeAttemptID == attemptID else { return }
                self.finishTranscriptionIfPossible(for: attemptID)
            }
        }
    }

    func reset() {
        activeAttemptID = nil
        finalizationTask?.cancel()
        finalizationTask = nil
        stopTimer()
        stopAudioEngine()
        cancelAppleNativeSpeechSession()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        startedAt = nil
        elapsedSeconds = 0
        transcript = ""
        audioLevel = 0
        vividAudioCapture.reset()
        state = .ready
    }

    private func handleRecognition(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        attemptID: UUID
    ) {
        // A canceled Speech task can deliver a final callback after a new attempt
        // begins. Ignore anything that does not belong to the active recording.
        guard activeAttemptID == attemptID else { return }
        guard state == .recording || state == .transcribing else { return }

        if let result {
            transcript = result.bestTranscription.formattedString
            if result.isFinal, state == .transcribing {
                finishTranscriptionIfPossible(for: attemptID)
                return
            }
        }

        if let error {
            #if DEBUG
            let speechError = error as NSError
            print("Speech recognition stopped: \(speechError.domain) code=\(speechError.code) \(speechError.localizedDescription)")
            #endif
            if state == .transcribing {
                finishTranscriptionIfPossible(for: attemptID)
            }
            // A transient Speech service failure must not cancel an active
            // microphone capture. Keeping the recording state alive ensures
            // the press-and-hold gesture can still finish normally and lets
            // us use any partial transcript already delivered by the service.
        }
    }

    private func finishTranscriptionIfPossible(for attemptID: UUID) {
        guard activeAttemptID == attemptID, state == .transcribing else { return }
        activeAttemptID = nil
        finalizationTask?.cancel()
        finalizationTask = nil
        stopTimer()
        stopAudioEngine()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        appleNativeSpeechSession = nil
        usesAppleNativeSpeech = false

        // Always give the candidate a review step. Speech recognition can
        // legitimately return an empty or imperfect result even when audio was
        // captured; the candidate can correct it before explicitly sending it.
        state = .readyToAnalyze
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateElapsedSeconds()
                if self.elapsedSeconds >= self.maximumDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedSeconds() {
        guard let startedAt else { return }
        elapsedSeconds = min(maximumDuration, max(Int(Date().timeIntervalSince(startedAt)), 1))
    }

    private func stopAudioEngine() {
        audioLevel = 0
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // Accessing `audioEngine.inputNode` creates the Simulator RemoteIO
        // unit. During reset this runs before AVAudioSession is active, which
        // can permanently bind the engine to a zero-Hz host device. Only touch
        // the node after this session has actually installed a tap.
        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }
        #if os(iOS)
        // Deactivating the session synchronously on the main actor causes the
        // AVAudioSession warning seen in Simulator and can interrupt a new
        // attempt that starts immediately after this one. Deactivate off the
        // current UI turn, but only while no newer recording owns the route.
        activeAudioRouteID = nil
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, self.activeAudioRouteID == nil else { return }
            QuestionAudioSessionCoordinator.deactivateWhenIdle()
        }
        #endif
    }

    private func cancelAppleNativeSpeechSession() {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *),
           let nativeSession = appleNativeSpeechSession as? AppleNativeSpeechSession {
            Task { await nativeSession.cancel() }
        }
        #endif
        appleNativeSpeechSession = nil
        usesAppleNativeSpeech = false
    }

    nonisolated private static func normalizedAudioLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let samples = buffer.floatChannelData?.pointee else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for index in 0..<frameCount {
            let sample = samples[index]
            sumOfSquares += sample * sample
        }

        let rootMeanSquare = sqrt(sumOfSquares / Float(frameCount))
        let decibels = 20 * log10(max(rootMeanSquare, 0.000_1))
        return CGFloat(min(max((decibels + 55) / 55, 0), 1))
    }

    private func configureAudioSession() async throws {
        #if os(iOS)
        activeAudioRouteID = UUID()
        try await QuestionAudioSessionCoordinator.activateForRecording()
        #endif
    }

    private func usableInputFormat(from inputNode: AVAudioInputNode) async -> AVAudioFormat? {
        // Activating a newly-selected Simulator audio input is asynchronous.
        // Retrying the same node keeps real-device recording immediate while
        // allowing the macOS route time to expose its hardware format.
        for delay in [0, 120_000_000, 400_000_000] {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay))
            }

            let format = inputNode.outputFormat(forBus: 0)
            if format.sampleRate > 0, format.channelCount > 0 {
                return format
            }
        }

        return nil
    }

    private func microphonePermissionGranted() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func speechPermissionGranted() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Report copy

@MainActor
enum QuestionRecordingCue {
    enum Cue {
        case started
        case stopped
    }

    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    private static var isConfigured = false

    static func play(_ cue: Cue) {
        #if os(iOS)
        configureIfNeeded()
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              let buffer = makeBuffer(
                frequencies: cue == .started ? [660, 880] : [880, 660],
                format: format
              ) else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            #if DEBUG
            print("Recording cue could not play: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    private static func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        engine.prepare()
        isConfigured = true
    }

    private static func makeBuffer(
        frequencies: [Double],
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let noteDuration = 0.085
        let gapDuration = 0.025
        let framesPerNote = Int(format.sampleRate * noteDuration)
        let gapFrames = Int(format.sampleRate * gapDuration)
        let frameCount = framesPerNote * frequencies.count + gapFrames * max(frequencies.count - 1, 0)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ), let samples = buffer.floatChannelData else { return nil }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        for channel in 0..<Int(format.channelCount) {
            let output = samples[channel]
            for (noteIndex, frequency) in frequencies.enumerated() {
                let start = noteIndex * (framesPerNote + gapFrames)
                for frame in 0..<framesPerNote {
                    let progress = Double(frame) / Double(max(framesPerNote - 1, 1))
                    let envelope = min(progress / 0.16, (1 - progress) / 0.22, 1)
                    let phase = 2 * Double.pi * frequency * Double(frame) / format.sampleRate
                    output[start + frame] = Float(sin(phase) * envelope * 0.13)
                }
            }
        }
        return buffer
    }
}

