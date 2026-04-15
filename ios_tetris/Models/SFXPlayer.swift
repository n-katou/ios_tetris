import AVFoundation

/// Plays synthesised sound effects (line clear arpeggio).
final class SFXPlayer {
    static let shared = SFXPlayer()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()
    }

    /// Play an ascending arpeggio scaled to the number of cleared lines (1-4).
    func playClear(lines: Int) {
        // C5, E5, G5, C6
        let allNotes: [Double] = [523.25, 659.25, 783.99, 1046.50]
        let count  = min(max(lines, 1), 4)
        let notes  = Array(allNotes.prefix(count))
        let step   = count == 4 ? 0.10 : 0.12   // delay between notes (shorter for Tetris clear)

        for (i, freq) in notes.enumerated() {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Double(i) * step) { [weak self] in
                self?.scheduleBeep(freq: freq, duration: step * 1.8, volume: 0.55)
            }
        }
    }

    // MARK: - Private

    private func scheduleBeep(freq: Double, duration: Double, volume: Float) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: AVAudioFrameCount(sampleRate * duration))
        else { return }

        buffer.frameLength = buffer.frameCapacity
        let data = buffer.floatChannelData![0]
        let twoPi = 2.0 * Double.pi
        let total = Int(buffer.frameLength)

        for i in 0..<total {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(total)

            // Short attack, longer release envelope
            let env: Double
            let attackEnd = 0.012
            let releaseStart = 0.55
            if progress < attackEnd {
                env = progress / attackEnd
            } else if progress > releaseStart {
                env = max(0, 1.0 - (progress - releaseStart) / (1.0 - releaseStart))
            } else {
                env = 1.0
            }

            // Fundamental + 2nd harmonic for a brighter, bell-like tone
            let sig = sin(twoPi * freq * t) * 0.75
                    + sin(twoPi * freq * 2 * t) * 0.20
                    + sin(twoPi * freq * 3 * t) * 0.05
            data[i] = Float(sig * env) * volume
        }

        if !engine.isRunning { try? engine.start() }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }
}
