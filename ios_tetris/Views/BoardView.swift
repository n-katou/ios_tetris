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

                // Locked cells (skip clearing rows — replaced by flash)
                for row in 0..<Board.rows {
                    guard !vm.clearingRows.contains(row) else { continue }
                    for col in 0..<Board.columns {
                        if let color = vm.board[row][col] {
                            drawCell(ctx: ctx, row: row, col: col, color: color, size: cellSize)
                        }
                    }
                }

                // Ghost piece
                if AppSettings.shared.ghostEnabled {
                    for cell in vm.ghost {
                        if cell.row >= 0 {
                            let rect = cellRect(row: cell.row, col: cell.col, size: cellSize).insetBy(dx: 1, dy: 1)
                            ctx.stroke(Path(rect), with: .color(vm.current.type.color.opacity(0.4)), lineWidth: 2)
                        }
                    }
                }

                // Active piece
                for cell in vm.current.cells {
                    if cell.row >= 0 {
                        drawCell(ctx: ctx, row: cell.row, col: cell.col, color: vm.current.type.color, size: cellSize)
                    }
                }

                // Flash overlay — clearing rows glow bright white
                for row in vm.clearingRows {
                    // Outer glow
                    let glowRect = CGRect(
                        x: 0,
                        y: CGFloat(row) * cellSize - cellSize * 0.15,
                        width: CGFloat(Board.columns) * cellSize,
                        height: cellSize * 1.3
                    )
                    ctx.fill(Path(glowRect), with: .color(Color.white.opacity(0.25)))
                    // Core flash
                    let flashRect = CGRect(
                        x: 0, y: CGFloat(row) * cellSize,
                        width: CGFloat(Board.columns) * cellSize,
                        height: cellSize
                    )
                    ctx.fill(Path(flashRect), with: .color(Color.white.opacity(0.88)))
                }

                // Particles
                for p in vm.particles {
                    let px = CGFloat(p.col) * cellSize - p.size / 2
                    let py = CGFloat(p.row) * cellSize - p.size / 2
                    let rect = CGRect(x: px, y: py, width: p.size, height: p.size)
                    // Glow pass (larger, semi-transparent)
                    let glowRect = rect.insetBy(dx: -p.size * 0.6, dy: -p.size * 0.6)
                    ctx.fill(Path(glowRect), with: .color(p.color.opacity(p.alpha * 0.35)))
                    // Core particle
                    ctx.fill(Path(rect), with: .color(p.color.opacity(p.alpha)))
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
        ctx.fill(Path(rect), with: .color(color))
        var highlight = Path()
        highlight.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        highlight.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        highlight.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.stroke(highlight, with: .color(Color.white.opacity(0.5)), lineWidth: 2)
        var shadow = Path()
        shadow.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        shadow.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        shadow.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.stroke(shadow, with: .color(Color.black.opacity(0.4)), lineWidth: 2)
    }
}
