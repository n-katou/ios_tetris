import SwiftUI
import Combine

enum GameState { case idle, playing, paused, gameOver }

struct Particle: Identifiable {
    let id = UUID()
    var col: Double; var row: Double
    var vCol: Double; var vRow: Double
    let color: Color; var alpha: Double; let size: CGFloat
}

final class GameViewModel: ObservableObject {
    // Board
    @Published var board: [[Color?]] = GameViewModel.emptyBoard()
    @Published var current: Tetromino = .random()
    @Published var next: Tetromino    = .random()
    @Published var ghost: [Cell]      = []
    // Hold
    @Published var heldPiece: Tetromino? = nil
    private var canHold = true
    // Score
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var lines: Int = 0
    @Published var combo: Int = 0
    private var comboCount = 0
    // State
    @Published var state: GameState = .idle
    // Effects
    @Published var clearingRows: Set<Int> = []
    @Published var particles: [Particle] = []

    // Timers
    private var dropTimer:    AnyCancellable?
    private var lockTimer:    AnyCancellable?
    private var particleTimer: AnyCancellable?

    private var dropInterval: TimeInterval { max(0.1, 0.8 - Double(level - 1) * 0.07) }

    // Lock delay
    private var lockResets = 0
    private let maxLockResets = 15
    private let lockDelay: TimeInterval = 0.5

    // MARK: - Public

    func startGame() {
        board = GameViewModel.emptyBoard()
        score = 0; level = 1; lines = 0; combo = 0; comboCount = 0
        heldPiece = nil; canHold = true
        current = .random(); next = .random()
        clearingRows = []; particles = []
        updateGhost(); state = .playing
        startDropTimer()
        BGMPlayer.shared.stop(); BGMPlayer.shared.play()
    }

    func togglePause() {
        switch state {
        case .playing:
            state = .paused
            dropTimer?.cancel(); lockTimer?.cancel()
            BGMPlayer.shared.pause()
        case .paused:
            state = .playing
            startDropTimer()
            BGMPlayer.shared.resume()
        default: break
        }
    }

    func moveLeft()  { move(dCol: -1) }
    func moveRight() { move(dCol:  1) }

    func softDrop() {
        guard state == .playing else { return }
        if !performMove(dRow: 1) {
            cancelLockTimer()
            executeLock()
        }
    }

    func hardDrop() {
        guard state == .playing else { return }
        while performMove(dRow: 1) {}
        cancelLockTimer()
        Haptics.hardDrop()
        executeLock()
    }

    func rotate() {
        guard state == .playing else { return }
        let rotated = current.rotated()
        var success = false
        if isValid(rotated) {
            current = rotated; success = true
        } else {
            for dc in [1, -1, 2, -2] {
                var k = rotated; k.origin.col += dc
                if isValid(k) { current = k; success = true; break }
            }
        }
        if success { updateGhost(); tryResetLockTimer(); Haptics.rotate() }
    }

    func holdPiece() {
        guard state == .playing, canHold else { return }
        canHold = false
        cancelLockTimer()
        let savedType = current.type
        if let held = heldPiece {
            heldPiece = Tetromino.spawn(savedType)
            current   = Tetromino.spawn(held.type)
        } else {
            heldPiece = Tetromino.spawn(savedType)
            current   = next
            next      = .random()
        }
        lockResets = 0
        updateGhost()
        Haptics.hold()
    }

    // MARK: - Drop timer

    private func startDropTimer() {
        dropTimer?.cancel()
        dropTimer = Timer.publish(every: dropInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.timerTick() }
    }

    private func timerTick() {
        guard state == .playing else { return }
        if canFall() {
            performMove(dRow: 1)
            cancelLockTimer()
        } else {
            startLockTimer()
        }
    }

    // MARK: - Lock delay

    private func canFall() -> Bool {
        var t = current; t.origin.row += 1; return isValid(t)
    }

    private func startLockTimer() {
        guard lockTimer == nil else { return }
        lockTimer = Timer.publish(every: lockDelay, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.cancelLockTimer()
                self.executeLock()
            }
    }

    private func cancelLockTimer() {
        lockTimer?.cancel(); lockTimer = nil
    }

    private func tryResetLockTimer() {
        guard lockTimer != nil, lockResets < maxLockResets else { return }
        lockResets += 1
        cancelLockTimer()
        if !canFall() { startLockTimer() }
    }

    // MARK: - Movement

    @discardableResult
    private func move(dCol: Int) -> Bool {
        guard state == .playing else { return false }
        let result = performMove(dCol: dCol)
        if result { tryResetLockTimer(); Haptics.move() }
        return result
    }

    @discardableResult
    private func performMove(dRow: Int = 0, dCol: Int = 0) -> Bool {
        var moved = current
        moved.origin.row += dRow
        moved.origin.col += dCol
        guard isValid(moved) else { return false }
        current = moved; updateGhost(); return true
    }

    private func isValid(_ piece: Tetromino) -> Bool {
        piece.cells.allSatisfy { c in
            c.col >= 0 && c.col < Board.columns &&
            c.row < Board.rows &&
            (c.row < 0 || board[c.row][c.col] == nil)
        }
    }

    // MARK: - Lock & clear

    private func executeLock() {
        cancelLockTimer()
        lockResets = 0

        for cell in current.cells {
            guard cell.row >= 0 else { state = .gameOver; endGame(); return }
            board[cell.row][cell.col] = current.type.color
        }

        let full = (0..<Board.rows).filter { board[$0].allSatisfy { $0 != nil } }

        if full.isEmpty {
            comboCount = 0; combo = 0
            Haptics.lock()
            spawnNext()
        } else {
            // Combo
            comboCount += 1
            combo = comboCount
            let cleared   = full.count
            Haptics.lineClear(count: cleared)
            let base      = [0, 100, 300, 500, 800][min(cleared, 4)] * level
            let comboBonus = comboCount > 1 ? (comboCount - 1) * 50 * level : 0
            score += base + comboBonus
            lines += cleared
            level  = lines / 10 + 1

            // Flash phase
            dropTimer?.cancel()
            clearingRows = Set(full)
            spawnParticles(for: full)
            SFXPlayer.shared.playClear(lines: cleared)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self else { return }
                self.clearingRows = []
                for row in full { self.board[row] = Array(repeating: nil, count: Board.columns) }
                var newBoard = GameViewModel.emptyBoard()
                var writeRow = Board.rows - 1
                for row in stride(from: Board.rows - 1, through: 0, by: -1) {
                    if !full.contains(row) { newBoard[writeRow] = self.board[row]; writeRow -= 1 }
                }
                self.board = newBoard
                self.startDropTimer()
                self.spawnNext()
            }
        }
    }

    private func spawnNext() {
        current = next; next = .random()
        canHold = true; lockResets = 0
        updateGhost()
        if !isValid(current) { state = .gameOver; endGame() }
    }

    private func endGame() {
        dropTimer?.cancel(); lockTimer?.cancel(); particleTimer?.cancel()
        BGMPlayer.shared.stop()
        Haptics.gameOver()
        ScoreStore.shared.save(score: score, level: level, lines: lines)
    }

    // MARK: - Ghost

    private func updateGhost() {
        var g = current
        while true {
            var d = g; d.origin.row += 1
            if isValid(d) { g = d } else { break }
        }
        ghost = g.cells
    }

    // MARK: - Particles

    private func spawnParticles(for rows: [Int]) {
        particles = rows.flatMap { row in
            (0..<Board.columns).flatMap { col -> [Particle] in
                let color = board[row][col] ?? .white
                return (0..<4).map { _ in
                    let angle = Double.random(in: 0..<2 * .pi)
                    let speed = Double.random(in: 5.0...14.0)
                    return Particle(col: Double(col)+0.5, row: Double(row)+0.5,
                                    vCol: cos(angle)*speed, vRow: sin(angle)*speed,
                                    color: color, alpha: 1.0,
                                    size: CGFloat.random(in: 3...8))
                }
            }
        }
        particleTimer?.cancel()
        particleTimer = Timer.publish(every: 1/60.0, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.updateParticles() }
    }

    private func updateParticles() {
        let dt = 1.0 / 60.0
        particles = particles.compactMap { p in
            var p = p
            p.col += p.vCol * dt; p.row += p.vRow * dt
            p.vRow += 22 * dt; p.alpha -= dt * 2.6
            return p.alpha > 0 ? p : nil
        }
        if particles.isEmpty { particleTimer?.cancel() }
    }

    static func emptyBoard() -> [[Color?]] {
        Array(repeating: Array(repeating: nil, count: Board.columns), count: Board.rows)
    }
}
