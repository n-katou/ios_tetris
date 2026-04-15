import SwiftUI

struct NextPieceView: View {
    let piece: Tetromino

    private let cellSize: CGFloat = 22
    private let previewCols = 4
    private let previewRows = 4

    var body: some View {
        VStack(spacing: 6) {
            Text("NEXT")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(2)

            Canvas { ctx, _ in
                for cell in piece.cells {
                    let rect = CGRect(
                        x: CGFloat(cell.col) * cellSize + 2,
                        y: CGFloat(cell.row) * cellSize + 2,
                        width: cellSize - 4,
                        height: cellSize - 4
                    )
                    ctx.fill(Path(rect), with: .color(piece.type.color))
                    // highlight
                    var hl = Path()
                    hl.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    hl.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    hl.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    ctx.stroke(hl, with: .color(.white.opacity(0.45)), lineWidth: 2)
                }
            }
            .frame(width: CGFloat(previewCols) * cellSize,
                   height: CGFloat(previewRows) * cellSize)
        }
        .padding(10)
        .background(Color.white.opacity(0.07))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
