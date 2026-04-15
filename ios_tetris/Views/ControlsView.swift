import SwiftUI

struct ControlsView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Left / Right
            HStack(spacing: 12) {
                ControlButton(symbol: "arrow.left") { vm.moveLeft() }
                ControlButton(symbol: "arrow.right") { vm.moveRight() }
            }

            Spacer()

            // Rotate
            ControlButton(symbol: "arrow.counterclockwise") { vm.rotate() }

            Spacer()

            // Soft drop / Hard drop
            HStack(spacing: 12) {
                ControlButton(symbol: "arrow.down") { vm.softDrop() }
                ControlButton(symbol: "arrow.down.to.line") { vm.hardDrop() }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ControlButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }
}
