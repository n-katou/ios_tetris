import SwiftUI

struct ControlsView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        HStack(spacing: 14) {
            // Hold
            ControlButton(symbol: "square.on.square", label: "HOLD") { vm.holdPiece() }

            Spacer()

            // Left / Right with DAS
            HStack(spacing: 10) {
                DASButton(symbol: "arrow.left")  { vm.moveLeft() }
                DASButton(symbol: "arrow.right") { vm.moveRight() }
            }

            Spacer()

            // Rotate
            ControlButton(symbol: "arrow.counterclockwise") { vm.rotate() }

            Spacer()

            // Soft drop / Hard drop
            HStack(spacing: 10) {
                ControlButton(symbol: "arrow.down")          { vm.softDrop() }
                ControlButton(symbol: "arrow.down.to.line")  { vm.hardDrop() }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - DAS Button (Delayed Auto Shift + Auto Repeat)

private struct DASButton: View {
    let symbol: String
    let action: () -> Void

    /// Time before auto-repeat starts (ms)
    private let dasDelay: TimeInterval   = 0.15
    /// Repeat interval once DAS kicks in (ms)
    private let arrInterval: TimeInterval = 0.05

    @State private var dasTimer: Timer? = nil
    @State private var arrTimer: Timer? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard dasTimer == nil, arrTimer == nil else { return }
                        action()   // immediate first move
                        dasTimer = Timer.scheduledTimer(withTimeInterval: dasDelay, repeats: false) { _ in
                            arrTimer = Timer.scheduledTimer(withTimeInterval: arrInterval,
                                                             repeats: true) { _ in
                                DispatchQueue.main.async { action() }
                            }
                        }
                    }
                    .onEnded { _ in
                        dasTimer?.invalidate(); dasTimer = nil
                        arrTimer?.invalidate(); arrTimer = nil
                    }
            )
    }
}

// MARK: - Standard tap button

private struct ControlButton: View {
    let symbol: String
    var label: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
            }
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
        }
    }
}
