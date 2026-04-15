import AVFoundation

/// Synthesised sound effects for line clears.
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

    // MARK: - Public

    /// Play a punchy arpeggio scaled to lines cleared (1–4).
    func playClear(lines: Int) {
        let count = min(max(lines, 1), 4)

        // Bass kick — immediate impact
        schedule(gen: bassDrum(), delay: 0)

        // Ascending arpeggio: E5 G5 B5 E6
        let freqs: [Double] = [659.25, 783.99, 987.77, 1318.51]
        let step: Double = count == 4 ? 0.065 : 0.095
        for i in 0..<count {
            let duration = (count == 4 ? 0.18 : 0.22)
            schedule(gen: beep(freq: freqs[i], duration: duration, volume: count == 4 ? 0.58 : 0.50),
                     delay: 0.03 + Double(i) * step)
        }

        // 4-line (Tetris): dramatic upward sweep after the arpeggio
        if count == 4 {
            schedule(gen: sweep(from: 350, to: 2200, duration: 0.38, volume: 0.32),
                     delay: 0.35)
        }
    }

    // MARK: - Generators

    private func bassDrum() -> AVAudioPCMBuffer? {
        let dur = 0.12
        return generate(duration: dur) { t, _ in
            let freq = 90.0 * exp(-t * 28)           // pitch drops fast
            let amp  = exp(-t * 26)                   // very quick decay
            return Float(sin(2 * .pi * freq * t) * amp * 0.75)
        }
    }

    private func beep(freq: Double, duration: Double, volume: Float) -> AVAudioPCMBuffer? {
        generate(duration: duration) { t, progress in
            let attackEnd    = 0.010
            let releaseStart = 0.50
            let env: Double
            if progress < attackEnd {
                env = progress / attackEnd
            } else if progress > releaseStart {
                env = max(0, 1 - (progress - releaseStart) / (1 - releaseStart))
            } else {
                env = 1.0
            }
            // Fundamental + harmonics for bright, bell-like tone
            let sig = sin(2 * .pi * freq * t)       * 0.70
                    + sin(2 * .pi * freq * 2 * t)   * 0.20
                    + sin(2 * .pi * freq * 3 * t)   * 0.07
                    + sin(2 * .pi * freq * 0.5 * t) * 0.03
            return Float(sig * env) * volume
        }
    }

    private func sweep(from startFreq: Double, to endFreq: Double,
                       duration: Double, volume: Float) -> AVAudioPCMBuffer? {
        var phase = 0.0
        return generate(duration: duration) { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            phase += 2 * .pi * freq / 44100.0
            let env = sin(.pi * progress)            // bell-shaped amplitude
            return Float(sin(phase) * env) * volume
        }
    }

    // MARK: - Engine helpers

    private func generate(duration: Double,
                           sample: (Double, Double) -> Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(sampleRate * duration))
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        let data  = buffer.floatChannelData![0]
        let total = Int(buffer.frameLength)
        for i in 0..<total {
            let t        = Double(i) / sampleRate
            let progress = Double(i) / Double(total)
            data[i] = sample(t, progress)
        }
        return buffer
    }

    private func schedule(gen buffer: AVAudioPCMBuffer?, delay: Double) {
        guard let buffer else { return }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if !self.engine.isRunning { try? self.engine.start() }
            self.playerNode.scheduleBuffer(buffer, completionHandler: nil)
            if !self.playerNode.isPlaying { self.playerNode.play() }
        }
    }
}
