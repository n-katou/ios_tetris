import SwiftUI

struct NextPieceView: View {
    let piece: Tetromino

    private let cellSize: CGFloat = 14
    private let previewCols = 4
    private let previewRows = 4

    var body: some View {
        Canvas { ctx, _ in
            for cell in piece.cells {
                let rect = CGRect(
                    x: CGFloat(cell.col) * cellSize + 1,
                    y: CGFloat(cell.row) * cellSize + 1,
                    width: cellSize - 2,
                    height: cellSize - 2
                )
                ctx.fill(Path(rect), with: .color(piece.type.color))
            }
        }
        .frame(width: CGFloat(previewCols) * cellSize,
               height: CGFloat(previewRows) * cellSize)
        .background(Color.black.opacity(0.5))
        .cornerRadius(4)
    }
}
