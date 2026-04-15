import SwiftUI

// MARK: - Board constants
enum Board {
    static let columns = 10
    static let rows = 20
}

// MARK: - Cell position
struct Cell: Equatable {
    var row: Int
    var col: Int
}

// MARK: - Tetromino type
enum TetrominoType: CaseIterable {
    case I, O, T, S, Z, J, L

    var color: Color {
        switch self {
        case .I: return Color.cyan
        case .O: return Color.yellow
        case .T: return Color.purple
        case .S: return Color.green
        case .Z: return Color.red
        case .J: return Color.blue
        case .L: return Color.orange
        }
    }

    // 4 rotation states, each is array of (row, col) offsets
    var rotations: [[Cell]] {
        switch self {
        case .I:
            return [
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:0,col:3)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:2,col:0),Cell(row:3,col:0)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:0,col:3)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:2,col:0),Cell(row:3,col:0)],
            ]
        case .O:
            return [
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1)],
            ]
        case .T:
            return [
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:2,col:0),Cell(row:1,col:1)],
                [Cell(row:1,col:0),Cell(row:0,col:1),Cell(row:1,col:1),Cell(row:1,col:2)],
                [Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:2,col:1)],
            ]
        case .S:
            return [
                [Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:1,col:0),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:2,col:1)],
                [Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:1,col:0),Cell(row:1,col:1)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:2,col:1)],
            ]
        case .Z:
            return [
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:1),Cell(row:1,col:2)],
                [Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:2,col:0)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:1),Cell(row:1,col:2)],
                [Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:2,col:0)],
            ]
        case .J:
            return [
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:1,col:2)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:0),Cell(row:2,col:0)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:1,col:2)],
                [Cell(row:0,col:1),Cell(row:1,col:1),Cell(row:2,col:0),Cell(row:2,col:1)],
            ]
        case .L:
            return [
                [Cell(row:0,col:2),Cell(row:1,col:0),Cell(row:1,col:1),Cell(row:1,col:2)],
                [Cell(row:0,col:0),Cell(row:1,col:0),Cell(row:2,col:0),Cell(row:2,col:1)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:0,col:2),Cell(row:1,col:0)],
                [Cell(row:0,col:0),Cell(row:0,col:1),Cell(row:1,col:1),Cell(row:2,col:1)],
            ]
        }
    }
}

// MARK: - Active piece
struct Tetromino {
    let type: TetrominoType
    var rotation: Int = 0
    var origin: Cell  // top-left anchor

    var cells: [Cell] {
        type.rotations[rotation].map {
            Cell(row: origin.row + $0.row, col: origin.col + $0.col)
        }
    }

    mutating func rotated() -> Tetromino {
        var copy = self
        copy.rotation = (rotation + 1) % 4
        return copy
    }

    static func spawn(_ type: TetrominoType) -> Tetromino {
        let startCol: Int
        switch type {
        case .I: startCol = 3
        case .O: startCol = 4
        default: startCol = 3
        }
        return Tetromino(type: type, rotation: 0, origin: Cell(row: 0, col: startCol))
    }

    static func random() -> Tetromino {
        spawn(TetrominoType.allCases.randomElement()!)
    }
}
