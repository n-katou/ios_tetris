import AVFoundation

/// Synthesises Korobeiniki (Tetris Theme A+B) using AVAudioEngine sine waves.
/// Loops indefinitely at standard tempo (144 BPM).
final class BGMPlayer {
    static let shared = BGMPlayer()

    var volume: Float = 0.45

    private let engine     = AVAudioEngine()
    private let sampleRate = 44100.0

    // Render-thread state
    private var melody:        [(freq: Double, beats: Double)] = []
    private var noteIdx:       Int    = 0
    private var phase:         Double = 0.0
    private var samplesInNote: Double = 0.0
    private var samplePos:     Double = 0.0
    private let bpm:           Double = 144.0

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
        } catch { print("BGMPlayer: \(error)") }
    }

    func stop()   { engine.stop() }
    func pause()  { engine.pause() }
    func resume() { try? engine.start() }

    // MARK: - Melody (Korobeiniki Theme A + B)

    private func buildMelody() {
        let A4 = 440.00, B4 = 493.88
        let C5 = 523.25, D5 = 587.33, E5 = 659.25
        let F5 = 698.46, G5 = 783.99, A5 = 880.00
        let R  = 0.0

        let partA: [(Double, Double)] = [
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),(R,0.5),
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]
        let partB: [(Double, Double)] = [
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),(R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]

        melody = partA + partB
        samplesInNote = beatsToSamples(melody[0].beats)
    }

    // MARK: - Engine

    private func beatsToSamples(_ beats: Double) -> Double {
        beats * (60.0 / bpm) * sampleRate
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let twoPi  = 2.0 * Double.pi
        let gap    = 0.12

        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ptr = UnsafeMutableAudioBufferListPointer(audioBufferList)[0]
                .mData!.bindMemory(to: Float.self, capacity: Int(frameCount))

            for frame in 0..<Int(frameCount) {
                if self.samplePos >= self.samplesInNote {
                    self.samplePos    = 0
                    self.phase        = 0
                    self.noteIdx      = (self.noteIdx + 1) % self.melody.count
                    self.samplesInNote = self.beatsToSamples(self.melody[self.noteIdx].beats)
                }

                let note     = self.melody[self.noteIdx]
                let progress = self.samplePos / self.samplesInNote
                let sustain  = 1.0 - gap

                var sample: Float = 0.0
                if note.freq > 0 && progress < sustain {
                    let atk = min(0.025, sustain)
                    let rel = sustain - 0.025
                    let env: Double
                    if progress < atk      { env = progress / atk }
                    else if progress > rel { env = max(0, (sustain - progress) / 0.025) }
                    else                   { env = 1.0 }

                    self.phase += twoPi * note.freq / self.sampleRate
                    if self.phase >= twoPi { self.phase -= twoPi }

                    let sig = sin(self.phase)     * 0.70
                            + sin(self.phase * 2) * 0.20
                            + sin(self.phase * 3) * 0.10
                    sample = Float(sig * env * Double(self.volume))
                }

                ptr[frame] = sample
                self.samplePos += 1
            }
            return noErr
        }

        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }
}
