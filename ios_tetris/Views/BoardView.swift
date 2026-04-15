import SwiftUI

struct BoardView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(Board.columns)
            Canvas { ctx, size in
                // Background grid
                for row in 0..<Board.rows {
                    for col in 0..<Board.columns {
                        let rect = cellRect(row: row, col: col, size: cellSize)
                        ctx.fill(Path(rect), with: .color(Color.white.opacity(0.04)))
                        ctx.stroke(Path(rect), with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)
                    }
                }

                // Locked cells
                for row in 0..<Board.rows {
                    for col in 0..<Board.columns {
                        if let color = vm.board[row][col] {
                            drawCell(ctx: ctx, row: row, col: col, color: color, size: cellSize)
                        }
                    }
                }

                // Ghost piece
                for cell in vm.ghost {
                    if cell.row >= 0 {
                        let rect = cellRect(row: cell.row, col: cell.col, size: cellSize).insetBy(dx: 1, dy: 1)
                        ctx.stroke(Path(rect), with: .color(vm.current.type.color.opacity(0.4)), lineWidth: 2)
                    }
                }

                // Active piece
                for cell in vm.current.cells {
                    if cell.row >= 0 {
                        drawCell(ctx: ctx, row: cell.row, col: cell.col, color: vm.current.type.color, size: cellSize)
                    }
                }
            }
            .frame(width: CGFloat(Board.columns) * cellSize,
                   height: CGFloat(Board.rows) * cellSize)
        }
        .aspectRatio(CGFloat(Board.columns) / CGFloat(Board.rows), contentMode: .fit)
        .background(Color.black)
        .border(Color.white.opacity(0.3), width: 1)
    }

    private func cellRect(row: Int, col: Int, size: CGFloat) -> CGRect {
        CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size)
    }

    private func drawCell(ctx: GraphicsContext, row: Int, col: Int, color: Color, size: CGFloat) {
        let rect = cellRect(row: row, col: col, size: size).insetBy(dx: 1, dy: 1)
        // Fill
        ctx.fill(Path(rect), with: .color(color))
        // Highlight top-left
        var highlight = Path()
        highlight.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        highlight.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        highlight.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.stroke(highlight, with: .color(Color.white.opacity(0.5)), lineWidth: 2)
        // Shadow bottom-right
        var shadow = Path()
        shadow.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        shadow.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        shadow.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.stroke(shadow, with: .color(Color.black.opacity(0.4)), lineWidth: 2)
    }
}
