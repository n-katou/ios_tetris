import SwiftUI
import Combine

enum GameState {
    case idle, playing, paused, gameOver
}

struct Particle: Identifiable {
    let id = UUID()
    var col: Double
    var row: Double
    var vCol: Double
    var vRow: Double
    let color: Color
    var alpha: Double
    let size: CGFloat
}

final class GameViewModel: ObservableObject {
    @Published var board: [[Color?]] = GameViewModel.emptyBoard()
    @Published var current: Tetromino = .random()
    @Published var next: Tetromino = .random()
    @Published var ghost: [Cell] = []
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var lines: Int = 0
    @Published var state: GameState = .idle
    @Published var clearingRows: Set<Int> = []
    @Published var particles: [Particle] = []

    private var timer: AnyCancellable?
    private var particleTimer: AnyCancellable?
    private var dropInterval: TimeInterval { max(0.1, 0.8 - Double(level - 1) * 0.07) }

    // MARK: - Public interface

    func startGame() {
        board = GameViewModel.emptyBoard()
        score = 0; level = 1; lines = 0
        current = .random()
        next = .random()
        clearingRows = []
        particles = []
        updateGhost()
        state = .playing
        startTimer()
        BGMPlayer.shared.stop()
        BGMPlayer.shared.play()
    }

    func togglePause() {
        switch state {
        case .playing:
            state = .paused
            timer?.cancel()
            BGMPlayer.shared.pause()
        case .paused:
            state = .playing
            startTimer()
            BGMPlayer.shared.resume()
        default: break
        }
    }

    func moveLeft()  { move(dCol: -1) }
    func moveRight() { move(dCol: 1) }

    func softDrop() {
        if !move(dRow: 1) { lock() }
    }

    func hardDrop() {
        while move(dRow: 1) {}
        lock()
    }

    func rotate() {
        guard state == .playing else { return }
        let rotated = current.rotated()
        if isValid(rotated) {
            current = rotated
            updateGhost()
        } else {
            for dc in [1, -1, 2, -2] {
                var kicked = rotated
                kicked.origin.col += dc
                if isValid(kicked) {
                    current = kicked
                    updateGhost()
                    return
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: dropInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.timerTick() }
    }

    private func timerTick() {
        guard state == .playing else { return }
        if !move(dRow: 1) { lock() }
    }

    // MARK: - Movement

    @discardableResult
    private func move(dRow: Int = 0, dCol: Int = 0) -> Bool {
        guard state == .playing else { return false }
        var moved = current
        moved.origin.row += dRow
        moved.origin.col += dCol
        guard isValid(moved) else { return false }
        current = moved
        updateGhost()
        return true
    }

    private func isValid(_ piece: Tetromino) -> Bool {
        for cell in piece.cells {
            if cell.col < 0 || cell.col >= Board.columns { return false }
            if cell.row >= Board.rows { return false }
            if cell.row >= 0 && board[cell.row][cell.col] != nil { return false }
        }
        return true
    }

    // MARK: - Lock & clear

    private func lock() {
        for cell in current.cells {
            guard cell.row >= 0 else { state = .gameOver; endGame(); return }
            board[cell.row][cell.col] = current.type.color
        }

        let full = (0..<Board.rows).filter { board[$0].allSatisfy { $0 != nil } }

        guard !full.isEmpty else {
            spawnNext()
            return
        }

        // Score update immediately
        let cleared = full.count
        score += [0, 100, 300, 500, 800][min(cleared, 4)] * level
        lines += cleared
        level = lines / 10 + 1

        // Phase 1: flash + particles + SFX
        timer?.cancel()
        clearingRows = Set(full)
        spawnParticles(for: full)
        SFXPlayer.shared.playClear(lines: cleared)

        // Phase 2: actually remove rows after flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self else { return }
            self.clearingRows = []

            for row in full {
                self.board[row] = Array(repeating: nil, count: Board.columns)
            }
            var newBoard = GameViewModel.emptyBoard()
            var writeRow = Board.rows - 1
            for row in stride(from: Board.rows - 1, through: 0, by: -1) {
                if !full.contains(row) {
                    newBoard[writeRow] = self.board[row]
                    writeRow -= 1
                }
            }
            self.board = newBoard
            self.startTimer()
            self.spawnNext()
        }
    }

    private func spawnNext() {
        current = next
        next = .random()
        updateGhost()
        if !isValid(current) {
            state = .gameOver
            endGame()
        }
    }

    private func endGame() {
        timer?.cancel()
        particleTimer?.cancel()
        BGMPlayer.shared.stop()
        ScoreStore.shared.save(score: score, level: level, lines: lines)
    }

    // MARK: - Ghost

    private func updateGhost() {
        var g = current
        while true {
            var dropped = g
            dropped.origin.row += 1
            if isValid(dropped) { g = dropped } else { break }
        }
        ghost = g.cells
    }

    // MARK: - Particles

    private func spawnParticles(for rows: [Int]) {
        var newParticles: [Particle] = []
        for row in rows {
            for col in 0..<Board.columns {
                let color = board[row][col] ?? .white
                for _ in 0..<4 {
                    let angle = Double.random(in: 0..<2 * .pi)
                    let speed = Double.random(in: 5.0...14.0)
                    newParticles.append(Particle(
                        col: Double(col) + 0.5,
                        row: Double(row) + 0.5,
                        vCol: cos(angle) * speed,
                        vRow: sin(angle) * speed,
                        color: color,
                        alpha: 1.0,
                        size: CGFloat.random(in: 3.0...8.0)
                    ))
                }
            }
        }
        particles = newParticles

        particleTimer?.cancel()
        particleTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateParticles() }
    }

    private func updateParticles() {
        let dt = 1.0 / 60.0
        particles = particles.compactMap { p in
            var p = p
            p.col   += p.vCol * dt
            p.row   += p.vRow * dt
            p.vRow  += 22.0 * dt   // gravity
            p.alpha -= dt * 2.6
            return p.alpha > 0 ? p : nil
        }
        if particles.isEmpty { particleTimer?.cancel() }
    }

    // MARK: - Factory

    static func emptyBoard() -> [[Color?]] {
        Array(repeating: Array(repeating: nil, count: Board.columns), count: Board.rows)
    }
}
