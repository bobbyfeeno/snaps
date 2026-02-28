import SwiftUI
import Speech
import AVFoundation

// MARK: - Voice Score Entry
// "4", "birdie", "par", "bogey", "double" → sets score for current player/hole

@MainActor
@Observable
class VoiceScoreManager: NSObject {
    var isListening = false
    var transcript = ""
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onScoreRecognized: ((Int) -> Void)?

    func requestPermission() async -> Bool {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        return status == .authorized
    }

    func startListening(par: Int) {
        guard !isListening else { stopListening(); return }

        Task { @MainActor in
            let hasPermission = await requestPermission()
            guard hasPermission else {
                errorMessage = "Microphone permission required"
                return
            }
            startRecognition(par: par)
        }
    }

    private func startRecognition(par: Int) {
        recognitionTask?.cancel()
        recognitionTask = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let text = result?.bestTranscription.formattedString.lowercased() ?? ""
            let isFinal = result?.isFinal == true
            let hasError = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !text.isEmpty {
                    self.transcript = text
                    if let score = self.parseScore(text, par: par) {
                        self.onScoreRecognized?(score)
                        self.stopListening()
                        return
                    }
                }
                if hasError || isFinal { self.stopListening() }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        try? audioEngine.start()
        isListening = true
        transcript = "Listening..."

        // Auto-stop after 4 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            self?.stopListening()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.transcript = ""
        }
    }

    private func parseScore(_ text: String, par: Int) -> Int? {
        // Named scores
        if text.contains("ace") || text.contains("hole in one") { return 1 }
        if text.contains("albatross") || text.contains("double eagle") { return par - 3 }
        if text.contains("eagle") { return par - 2 }
        if text.contains("birdie") { return par - 1 }
        if text.contains("par") { return par }
        if text.contains("bogey") && !text.contains("double") && !text.contains("triple") { return par + 1 }
        if text.contains("double bogey") || text.contains("double") { return par + 2 }
        if text.contains("triple") { return par + 3 }

        // Number words
        let wordToNum = ["one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10]
        for (word, num) in wordToNum {
            if text.contains(word) { return num }
        }

        // Digit
        let words = text.split(separator: " ")
        for word in words {
            if let num = Int(word), num >= 1 && num <= 15 {
                return num
            }
        }
        return nil
    }
}

// MARK: - Voice Button Component

struct VoiceScoreButton: View {
    @Bindable var voice: VoiceScoreManager
    let par: Int
    let onScore: (Int) -> Void

    init(par: Int, onScore: @escaping (Int) -> Void) {
        self.voice = VoiceScoreManager()
        self.par = par
        self.onScore = onScore
        voice.onScoreRecognized = onScore
    }

    var body: some View {
        Button {
            voice.startListening(par: par)
        } label: {
            ZStack {
                Circle()
                    .fill(voice.isListening ?
                          Color(hex: "#ff4444").opacity(0.2) :
                          Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(voice.isListening ? Color(hex: "#ff4444") : Color.white.opacity(0.15), lineWidth: 1.5)
                    )

                Image(systemName: voice.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(voice.isListening ? Color(hex: "#ff4444") : .gray)

                if voice.isListening {
                    Circle()
                        .strokeBorder(Color(hex: "#ff4444").opacity(0.4), lineWidth: 2)
                        .frame(width: 54, height: 54)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voice.isListening)
                }
            }
        }
        .buttonStyle(SpringButtonStyle())
        .overlay(alignment: .top) {
            if !voice.transcript.isEmpty {
                Text(voice.transcript)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.black.opacity(0.8), in: Capsule())
                    .offset(y: -30)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: voice.transcript)
    }
}
