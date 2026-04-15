import SwiftUI
import Combine

enum GameState {
    case idle, playing, paused, gameOver
}

final class GameViewModel: ObservableObject {
    // Board: nil = empty, non-nil = locked color
    @Published var board: [[Color?]] = GameViewModel.emptyBoard()
    @Published var current: Tetromino = .random()
    @Published var next: Tetromino = .random()
    @Published var ghost: [Cell] = []
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var lines: Int = 0
    @Published var state: GameState = .idle
    @Published var flashRows: Set<Int> = []

    private var timer: AnyCancellable?
    private var dropInterval: TimeInterval { max(0.1, 0.8 - Double(level - 1) * 0.07) }

    // MARK: - Public interface

    func startGame() {
        board = GameViewModel.emptyBoard()
        score = 0; level = 1; lines = 0
        current = .random()
        next = .random()
        updateGhost()
        state = .playing
        startTimer()
    }

    func togglePause() {
        switch state {
        case .playing:
            state = .paused
            timer?.cancel()
        case .paused:
            state = .playing
            startTimer()
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
            // Wall-kick: try offsets ±1, ±2
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

    // MARK: - Movement helpers

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
        clearLines()
        spawnNext()
    }

    private func clearLines() {
        let full = (0..<Board.rows).filter { row in
            board[row].allSatisfy { $0 != nil }
        }
        guard !full.isEmpty else { return }

        let cleared = full.count
        let points = [0, 100, 300, 500, 800][min(cleared, 4)] * level
        score += points
        lines += cleared
        level = lines / 10 + 1

        for row in full { board[row] = Array(repeating: nil, count: Board.columns) }
        // Collapse
        var newBoard = GameViewModel.emptyBoard()
        var writeRow = Board.rows - 1
        for row in stride(from: Board.rows - 1, through: 0, by: -1) {
            if !full.contains(row) {
                newBoard[writeRow] = board[row]
                writeRow -= 1
            }
        }
        board = newBoard
        startTimer() // reset interval after level change
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

    // MARK: - Factory

    static func emptyBoard() -> [[Color?]] {
        Array(repeating: Array(repeating: nil, count: Board.columns), count: Board.rows)
    }
}
