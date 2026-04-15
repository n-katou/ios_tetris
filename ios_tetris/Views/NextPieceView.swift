import SwiftUI

/// Shared preview box used for both HOLD and NEXT displays.
struct PiecePreviewView: View {
    let title: String
    let piece: Tetromino?   // nil → show empty box

    private let cellSize:    CGFloat = 22
    private let previewCols: Int     = 4
    private let previewRows: Int     = 4

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(2)

            Canvas { ctx, _ in
                guard let piece else { return }
                let rawCells = piece.type.rotations[piece.rotation]
                let minR = rawCells.map(\.row).min() ?? 0
                let maxR = rawCells.map(\.row).max() ?? 0
                let minC = rawCells.map(\.col).min() ?? 0
                let maxC = rawCells.map(\.col).max() ?? 0
                let rowOff = (previewRows - (maxR - minR + 1)) / 2 - minR
                let colOff = (previewCols - (maxC - minC + 1)) / 2 - minC

                for cell in rawCells {
                    let rect = CGRect(
                        x: CGFloat(cell.col + colOff) * cellSize + 2,
                        y: CGFloat(cell.row + rowOff) * cellSize + 2,
                        width:  cellSize - 4,
                        height: cellSize - 4
                    )
                    ctx.fill(Path(rect), with: .color(piece.type.color))
                    var hl = Path()
                    hl.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    hl.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    hl.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    ctx.stroke(hl, with: .color(.white.opacity(0.45)), lineWidth: 2)
                }
            }
            .frame(width:  CGFloat(previewCols) * cellSize,
                   height: CGFloat(previewRows) * cellSize)
        }
        .padding(10)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}
