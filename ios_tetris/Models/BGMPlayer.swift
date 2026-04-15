import AVFoundation
import Combine

/// Synthesises Korobeiniki in 5 different arrangements using AVAudioEngine.
/// Picks a different pattern at random after each loop.
final class BGMPlayer {
    static let shared = BGMPlayer()

    var volume: Float = 0.45

    private let engine      = AVAudioEngine()
    private let sampleRate  = 44100.0

    private var songs: [Song] = []
    private var currentSongIdx = 0

    // Render-thread state (only touched by render callback after engine starts)
    private var melody:           [(freq: Double, beats: Double)] = []
    private var bpmValue:         Double = 144.0
    private var toneBlend:        (fund: Double, oct: Double, third: Double) = (0.70, 0.20, 0.10)
    private var noteIdx:          Int    = 0
    private var phase:            Double = 0.0
    private var samplesInNote:    Double = 0.0
    private var samplePos:        Double = 0.0

    // Written by render thread, read by main-thread watcher
    private var loopFinished = false
    private var watcher: AnyCancellable?

    private init() {
        buildSongs()
        loadSong(index: 0)
        setupEngine()
        startWatcher()
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

    func stop() {
        engine.stop()
        switchToRandom(excluding: currentSongIdx)
    }

    func pause()  { engine.pause() }
    func resume() { try? engine.start() }

    // MARK: - Song model

    private struct Song {
        let name:    String
        let bpm:     Double
        let notes:   [(freq: Double, beats: Double)]
        /// Harmonic blend: (fundamental, octave-up, third-harmonic)
        let blend:   (Double, Double, Double)
    }

    // MARK: - Build 5 Korobeiniki patterns

    private func buildSongs() {
        // ── Base frequencies (standard octave) ──────────────────────────
        let A4 = 440.00, B4 = 493.88
        let C5 = 523.25, D5 = 587.33, E5 = 659.25
        let F5 = 698.46, G5 = 783.99, A5 = 880.00
        let R  = 0.0

        // One octave up
        let A5u = A4*2, B5u = B4*2
        let C6  = C5*2, D6  = D5*2, E6  = E5*2
        let F6  = F5*2, G6  = G5*2, A6  = A5*2

        func A() -> [(Double, Double)] { [
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),(R,0.5),
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ] }

        func B() -> [(Double, Double)] { [
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),(R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ] }

        // High-octave version of A
        func Ah() -> [(Double, Double)] { [
            (E6,1),(B5u,0.5),(C6,0.5),(D6,1),(C6,0.5),(B5u,0.5),
            (A5u,1),(A5u,0.5),(C6,0.5),(E6,1),(D6,0.5),(C6,0.5),
            (B5u,1.5),(C6,0.5),(D6,1),(E6,1),(C6,1),(A5u,1),(A5u,2),(R,0.5),
            (E6,1),(B5u,0.5),(C6,0.5),(D6,1),(C6,0.5),(B5u,0.5),
            (A5u,1),(A5u,0.5),(C6,0.5),(E6,1),(D6,0.5),(C6,0.5),
            (B5u,1.5),(C6,0.5),(D6,1),(E6,1),(C6,1),(A5u,1),(A5u,2),
        ] }

        // High-octave version of B
        func Bh() -> [(Double, Double)] { [
            (R,0.5),
            (D6,1.5),(F6,0.5),(A6,1),(G6,0.5),(F6,0.5),
            (E6,1.5),(C6,0.5),(E6,1),(D6,0.5),(C6,0.5),
            (B5u,1),(B5u,0.5),(C6,0.5),(D6,1),(E6,1),(C6,1),(A5u,1),(A5u,2),(R,0.5),
            (D6,1.5),(F6,0.5),(A6,1),(G6,0.5),(F6,0.5),
            (E6,1.5),(C6,0.5),(E6,1),(D6,0.5),(C6,0.5),
            (B5u,1),(B5u,0.5),(C6,0.5),(D6,1),(E6,1),(C6,1),(A5u,1),(A5u,2),
        ] }

        // ── Pattern 1: Standard — A+B, 144 BPM ──────────────────────────
        songs.append(Song(
            name:  "Standard",
            bpm:   144,
            notes: A() + B(),
            blend: (0.70, 0.20, 0.10)
        ))

        // ── Pattern 2: Presto — A+B, 176 BPM (frenetic) ─────────────────
        songs.append(Song(
            name:  "Presto",
            bpm:   176,
            notes: A() + B(),
            blend: (0.65, 0.25, 0.10)
        ))

        // ── Pattern 3: Andante — A only, 96 BPM (slow & eerie) ──────────
        songs.append(Song(
            name:  "Andante",
            bpm:   96,
            notes: A(),
            blend: (0.80, 0.15, 0.05)
        ))

        // ── Pattern 4: High Octave — Ah+Bh, 152 BPM (bright & sparkly) ──
        songs.append(Song(
            name:  "High Octave",
            bpm:   152,
            notes: Ah() + Bh(),
            blend: (0.60, 0.30, 0.10)
        ))

        // ── Pattern 5: Epic — A+B+Ah, 160 BPM (builds to high octave) ───
        songs.append(Song(
            name:  "Epic",
            bpm:   160,
            notes: A() + B() + Ah(),
            blend: (0.68, 0.22, 0.10)
        ))
    }

    // MARK: - Song loading

    private func loadSong(index: Int) {
        let song          = songs[index]
        currentSongIdx    = index
        melody            = song.notes
        bpmValue          = song.bpm
        toneBlend         = song.blend
        noteIdx           = 0
        phase             = 0
        samplePos         = 0
        samplesInNote     = beatsToSamples(melody[0].beats)
        loopFinished      = false
    }

    private func switchToRandom(excluding idx: Int) {
        guard songs.count > 1 else { return }
        var next: Int
        repeat { next = Int.random(in: 0..<songs.count) } while next == idx
        loadSong(index: next)
    }

    // MARK: - Watcher (main thread)

    private func startWatcher() {
        watcher = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.loopFinished else { return }
                let wasRunning = self.engine.isRunning
                self.engine.pause()
                self.switchToRandom(excluding: self.currentSongIdx)
                if wasRunning { try? self.engine.start() }
            }
    }

    // MARK: - Engine

    private func beatsToSamples(_ beats: Double) -> Double {
        beats * (60.0 / bpmValue) * sampleRate
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
                    self.samplePos = 0
                    self.phase     = 0
                    self.noteIdx   = (self.noteIdx + 1) % self.melody.count
                    self.samplesInNote = self.beatsToSamples(self.melody[self.noteIdx].beats)
                    if self.noteIdx == 0 { self.loopFinished = true }
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

                    let b = self.toneBlend
                    let sig = sin(self.phase)         * b.fund
                            + sin(self.phase * 2)     * b.oct
                            + sin(self.phase * 3)     * b.third
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
