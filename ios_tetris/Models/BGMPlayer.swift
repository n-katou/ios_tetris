import AVFoundation

/// Synthesises the classic Tetris theme (Korobeiniki) using AVAudioEngine sine waves.
final class BGMPlayer {
    static let shared = BGMPlayer()

    var volume: Float = 0.45

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100.0
    private let bpm: Double = 144.0

    // Render-thread state (only written before engine starts, then read-only in render)
    private var melody: [(freq: Double, beats: Double)] = []

    // Mutable render state — accessed only from the real-time render callback
    private var noteIdx: Int = 0
    private var phase: Double = 0.0
    private var samplesInNote: Double = 0.0
    private var samplePos: Double = 0.0

    private init() {
        buildMelody()
        setupEngine()
    }

    // MARK: - Public

    var isPlaying: Bool { engine.isRunning }

    func play() {
        guard !engine.isRunning else { return }
        do {
            #if canImport(UIKit)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            #endif
            try engine.start()
        } catch {
            print("BGMPlayer: start failed – \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    func pause() { engine.pause() }
    func resume() { try? engine.start() }

    // MARK: - Melody definition

    private func buildMelody() {
        // Standard equal-temperament frequencies
        let B3  = 246.94
        let C4  = 261.63, D4 = 293.66, E4 = 329.63
        let F4  = 349.23, G4 = 392.00, A4 = 440.00, B4 = 493.88
        let C5  = 523.25, D5 = 587.33, E5 = 659.25
        let F5  = 698.46, G5 = 783.99, A5 = 880.00
        let R   = 0.0   // rest

        // Korobeiniki – Theme A (×2) + Theme B (×2)
        let A: [(Double, Double)] = [
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
            (R,0.5),
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]
        let B: [(Double, Double)] = [
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]
        // Bass accompaniment cadence (simplified, appended after A+B for one pass)
        let _ = [B3, C4, D4, E4, F4, G4, A4, B4] // unused but keep for reference

        melody = A + B
        if let first = melody.first {
            samplesInNote = beatsToSamples(first.beats)
        }
    }

    // MARK: - Engine setup

    private func beatsToSamples(_ beats: Double) -> Double {
        beats * (60.0 / bpm) * sampleRate
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let twoPi = 2.0 * Double.pi
        let gapFraction = 0.12   // silence at end of each note (avoids clicks, gives staccato feel)

        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ptr = UnsafeMutableAudioBufferListPointer(audioBufferList)[0]
                .mData!.bindMemory(to: Float.self, capacity: Int(frameCount))

            for frame in 0..<Int(frameCount) {
                if self.samplePos >= self.samplesInNote {
                    self.samplePos = 0
                    self.phase = 0
                    self.noteIdx = (self.noteIdx + 1) % self.melody.count
                    self.samplesInNote = self.beatsToSamples(self.melody[self.noteIdx].beats)
                }

                let note = self.melody[self.noteIdx]
                let progress = self.samplePos / self.samplesInNote
                let sustainEnd = 1.0 - gapFraction

                var sample: Float = 0.0
                if note.freq > 0 && progress < sustainEnd {
                    // Simple linear attack/release envelope
                    let attackLen = min(0.025, sustainEnd)
                    let releaseStart = sustainEnd - 0.025
                    let env: Double
                    if progress < attackLen {
                        env = progress / attackLen
                    } else if progress > releaseStart {
                        env = max(0, (sustainEnd - progress) / 0.025)
                    } else {
                        env = 1.0
                    }

                    self.phase += twoPi * note.freq / self.sampleRate
                    if self.phase >= twoPi { self.phase -= twoPi }
                    // Mix fundamental + slight overtone for richer tone
                    let sig = sin(self.phase) * 0.7 + sin(self.phase * 2) * 0.2 + sin(self.phase * 3) * 0.1
                    sample = Float(sig * env * Double(self.volume))
                }

                ptr[frame] = sample
                self.samplePos += 1
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }
}
