import AVFoundation
import Combine

/// Synthesises Tetris BGM using AVAudioEngine sine waves.
/// Plays one song per loop, then picks a different song at random.
final class BGMPlayer {
    static let shared = BGMPlayer()

    var volume: Float = 0.45

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100.0

    // All available songs
    private var songs: [Song] = []
    private var currentSongIdx: Int = 0

    // Render-thread playback state
    private var melody: [(freq: Double, beats: Double)] = []
    private var bpmValue: Double = 144.0
    private var noteIdx: Int = 0
    private var phase: Double = 0.0
    private var samplesInNote: Double = 0.0
    private var samplePos: Double = 0.0
    private var songTotalSamples: Double = 0.0
    private var songSamplesPlayed: Double = 0.0

    // Flag written by render thread, read by a main-thread watcher
    private var loopFinished: Bool = false
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
        } catch {
            print("BGMPlayer play error: \(error)")
        }
    }

    func stop() {
        engine.stop()
        // Reset to start of a random song so next play() starts fresh
        switchToRandom(excluding: currentSongIdx)
    }

    func pause()  { engine.pause() }
    func resume() { try? engine.start() }

    // MARK: - Song definitions

    private struct Song {
        let name: String
        let bpm: Double
        let notes: [(freq: Double, beats: Double)]
    }

    private func buildSongs() {
        // ── Shared note frequencies ──────────────────────────────────────
        let E4  = 329.63, F4  = 349.23, G4  = 392.00
        let A4  = 440.00, B4  = 493.88
        let C5  = 523.25, D5  = 587.33, E5  = 659.25
        let F5  = 698.46, G5  = 783.99, A5  = 880.00
        let B5  = 987.77, C6  = 1046.50
        let Fs4 = 369.99, Cs5 = 554.37, Fs5 = 739.99
        let R   = 0.0

        // ── Song 1: Korobeiniki (Tetris Theme A+B) ────────────────────────
        let k_A: [(Double, Double)] = [
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),(R,0.5),
            (E5,1),(B4,0.5),(C5,0.5),(D5,1),(C5,0.5),(B4,0.5),
            (A4,1),(A4,0.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]
        let k_B: [(Double, Double)] = [
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
            (R,0.5),
            (D5,1.5),(F5,0.5),(A5,1),(G5,0.5),(F5,0.5),
            (E5,1.5),(C5,0.5),(E5,1),(D5,0.5),(C5,0.5),
            (B4,1),(B4,0.5),(C5,0.5),(D5,1),(E5,1),(C5,1),(A4,1),(A4,2),
        ]
        songs.append(Song(name: "Korobeiniki", bpm: 144, notes: k_A + k_B))

        // ── Song 2: Ode to Joy (Beethoven, public domain) ─────────────────
        let ode: [(Double, Double)] = [
            // Section 1
            (E5,1),(E5,1),(F5,1),(G5,1), (G5,1),(F5,1),(E5,1),(D5,1),
            (C5,1),(C5,1),(D5,1),(E5,1), (E5,1.5),(D5,0.5),(D5,2),
            (E5,1),(E5,1),(F5,1),(G5,1), (G5,1),(F5,1),(E5,1),(D5,1),
            (C5,1),(C5,1),(D5,1),(E5,1), (D5,1.5),(C5,0.5),(C5,2),
            // Section 2
            (D5,1),(D5,1),(E5,1),(C5,1), (D5,1),(E5,0.5),(F5,0.5),(E5,1),(C5,1),
            (D5,1),(E5,0.5),(F5,0.5),(E5,1),(D5,1), (C5,1),(D5,1),(G4,2),
            // Section 3 (repeat 1)
            (E5,1),(E5,1),(F5,1),(G5,1), (G5,1),(F5,1),(E5,1),(D5,1),
            (C5,1),(C5,1),(D5,1),(E5,1), (D5,1.5),(C5,0.5),(C5,2),(R,1),
        ]
        songs.append(Song(name: "Ode to Joy", bpm: 116, notes: ode))

        // ── Song 3: D-major fast folk dance (original) ───────────────────
        // Energetic 16th-note feel in D major
        let folk: [(Double, Double)] = [
            // Phrase A
            (D5,0.5),(E5,0.5),(Fs5,1),(A5,1),(Fs5,0.5),(E5,0.5),
            (D5,1),(D5,0.5),(E5,0.5),(Fs5,0.5),(G5,0.5),(A5,1),(R,0.5),
            (A5,0.5),(G5,0.5),(Fs5,1),(E5,1),(D5,0.5),(Cs5,0.5),
            (D5,2),(R,1),
            // Phrase A repeat
            (D5,0.5),(E5,0.5),(Fs5,1),(A5,1),(Fs5,0.5),(E5,0.5),
            (D5,1),(D5,0.5),(E5,0.5),(Fs5,0.5),(G5,0.5),(A5,1),(R,0.5),
            (A5,0.5),(B5,0.5),(A5,1),(G5,1),(Fs5,0.5),(E5,0.5),
            (D5,3),(R,0.5),
            // Phrase B
            (A4,0.5),(B4,0.5),(Cs5,1),(D5,1),(E5,1),
            (Fs5,0.5),(E5,0.5),(D5,1),(Cs5,0.5),(D5,0.5),(E5,1),(R,0.5),
            (A4,0.5),(B4,0.5),(Cs5,1),(D5,1),(Fs5,1),
            (G5,1),(E5,1),(D5,1),(Cs5,1),(D5,2),(R,1),
            // Phrase A coda
            (D5,0.5),(E5,0.5),(Fs5,1),(A5,1),(Fs5,0.5),(E5,0.5),
            (D5,1),(D5,0.5),(E5,0.5),(Fs5,0.5),(G5,0.5),(A5,1),(R,0.5),
            (B5,0.5),(A5,0.5),(G5,1),(Fs5,1),(E5,0.5),(Fs5,0.5),
            (D5,3),(R,1),
            // Extra energetic run
            (D5,0.5),(E5,0.5),(Fs5,0.5),(G5,0.5),(A5,0.5),(B5,0.5),(A5,0.5),(G5,0.5),
            (Fs5,0.5),(E5,0.5),(D5,0.5),(Cs5,0.5),(D5,2),(R,2),
        ]
        songs.append(Song(name: "Folk Dance", bpm: 168, notes: folk))

        // Suppress unused-variable warnings
        _ = [E4, F4, G4, Fs4, C6]
    }

    // MARK: - Song loading (call from main thread before engine starts)

    private func loadSong(index: Int) {
        let song = songs[index]
        currentSongIdx = index
        melody   = song.notes
        bpmValue = song.bpm
        noteIdx  = 0
        phase    = 0
        samplePos = 0
        samplesInNote    = beatsToSamples(melody[0].beats, bpm: bpmValue)
        songTotalSamples = melody.reduce(0.0) { $0 + beatsToSamples($1.beats, bpm: bpmValue) }
        songSamplesPlayed = 0
        loopFinished = false
    }

    private func switchToRandom(excluding idx: Int) {
        guard songs.count > 1 else { return }
        var next: Int
        repeat { next = Int.random(in: 0..<songs.count) } while next == idx
        loadSong(index: next)
    }

    // MARK: - Loop watcher (main thread)

    private func startWatcher() {
        watcher = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.loopFinished else { return }
                let old = self.currentSongIdx
                // Pause engine so render callback stops while we update shared state
                self.engine.pause()
                self.switchToRandom(excluding: old)
                if self.engine.isRunning == false {
                    // Only restart if we were playing
                    try? self.engine.start()
                }
            }
    }

    // MARK: - Engine setup

    private func beatsToSamples(_ beats: Double, bpm: Double) -> Double {
        beats * (60.0 / bpm) * sampleRate
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let twoPi  = 2.0 * Double.pi
        let gap    = 0.12   // silence fraction at end of each note

        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ptr = UnsafeMutableAudioBufferListPointer(audioBufferList)[0]
                .mData!.bindMemory(to: Float.self, capacity: Int(frameCount))

            for frame in 0..<Int(frameCount) {
                // Advance note
                if self.samplePos >= self.samplesInNote {
                    self.samplePos = 0
                    self.phase     = 0
                    self.noteIdx   = (self.noteIdx + 1) % self.melody.count
                    self.samplesInNote = self.beatsToSamples(self.melody[self.noteIdx].beats,
                                                              bpm: self.bpmValue)
                    // Mark loop end when noteIdx wraps to 0
                    if self.noteIdx == 0 { self.loopFinished = true }
                }

                let note     = self.melody[self.noteIdx]
                let progress = self.samplePos / self.samplesInNote
                let sustain  = 1.0 - gap

                var sample: Float = 0.0
                if note.freq > 0 && progress < sustain {
                    let env: Double
                    let atk = min(0.025, sustain)
                    let rel = sustain - 0.025
                    if progress < atk        { env = progress / atk }
                    else if progress > rel   { env = max(0, (sustain - progress) / 0.025) }
                    else                     { env = 1.0 }

                    self.phase += twoPi * note.freq / self.sampleRate
                    if self.phase >= twoPi { self.phase -= twoPi }

                    let sig = sin(self.phase) * 0.70
                           + sin(self.phase * 2) * 0.20
                           + sin(self.phase * 3) * 0.10
                    sample = Float(sig * env * Double(self.volume))
                }

                ptr[frame] = sample
                self.samplePos            += 1
                self.songSamplesPlayed    += 1
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }
}
