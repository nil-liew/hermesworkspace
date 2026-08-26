import SwiftUI
import Speech
import AVFoundation

/// Voice command recognition — listens for "next" and "previous".
/// Uses Apple's on-device Speech framework; requires microphone permission.
final class VoiceController: ObservableObject {
    @Published var isListening = false
    @Published var statusText = ""
    @Published var isAvailable = false
    
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkAvailability()
    }
    
    private func checkAvailability() {
        if let recognizer = speechRecognizer {
            isAvailable = recognizer.isAvailable
        }
    }
    
    /// Request permissions then start listening
    func startListening() {
        guard !isListening else { return }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] speechAuth in
            guard let self else { return }
            guard speechAuth == .authorized else {
                DispatchQueue.main.async {
                    self.statusText = "Speech recognition not authorized"
                }
                return
            }
            
            AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                DispatchQueue.main.async {
                    guard micGranted else {
                        self.statusText = "Microphone access denied"
                        return
                    }
                    self.beginSession()
                }
            }
        }
    }
    
    private func beginSession() {
        do {
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
            
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            recognitionRequest = request
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }
            
            try audioEngine.start()
            isListening = true
            statusText = "Listening… say \"next\" or \"previous\""
            
            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    self.handleTranscript(text)
                }
                if error != nil {
                    // Recognition sessions time out after ~1 min; restart automatically
                    DispatchQueue.main.async {
                        if self.isListening { self.restartSession() }
                    }
                }
            }
        } catch {
            statusText = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    /// Match the LAST spoken word against command vocabulary
    private func handleTranscript(_ text: String) {
        let words = text.split(separator: " ").map(String.init)
        guard let last = words.last else { return }
        
        if last.contains("next") || last == "next" {
            onNext?()
        } else if last.contains("previous") || last.contains("prev") {
            onPrevious?()
        }
    }
    
    private func restartSession() {
        stopListening()
        startListening()
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        statusText = ""
    }
    
    func toggle() {
        isListening ? stopListening() : startListening()
    }
}
