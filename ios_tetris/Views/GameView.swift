import SwiftUI

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @State private var showHighScore = false
    @State private var comboOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Board
                ZStack(alignment: .center) {
                    BoardView(vm: vm)
                        .padding(.horizontal, 16)
                        .onTapGesture { if vm.state == .playing { vm.rotate() } }
                        .gesture(swipeGesture)

                    // Combo popup
                    if vm.combo > 1 {
                        Text("COMBO ×\(vm.combo)!")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange],
                                               startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .orange.opacity(0.8), radius: 8)
                            .opacity(comboOpacity)
                            .allowsHitTesting(false)
                    }
                }

                ControlsView(vm: vm)
                    .padding(.vertical, 12)
            }

            // Overlays
            if vm.state == .idle      { startOverlay }
            if vm.state == .paused    { pauseOverlay }
            if vm.state == .gameOver  { gameOverOverlay }
        }
        .sheet(isPresented: $showHighScore) { HighScoreView() }
        .preferredColorScheme(.dark)
        .onChange(of: vm.combo) { newCombo in
            guard newCombo > 1 else { comboOpacity = 0; return }
            comboOpacity = 1
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) { comboOpacity = 0 }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: 8) {
            // Hold
            PiecePreviewView(title: "HOLD", piece: vm.heldPiece)

            Spacer()

            // Score
            VStack(alignment: .center, spacing: 6) {
                statLabel(title: "SCORE", value: "\(vm.score)")
                statLabel(title: "LINES", value: "\(vm.lines)")
                statLabel(title: "LEVEL", value: "\(vm.level)")
            }

            Spacer()

            // Next
            PiecePreviewView(title: "NEXT", piece: vm.next)

            Spacer()

            // Pause / High score
            VStack(spacing: 10) {
                Button { showHighScore = true } label: {
                    Image(systemName: "trophy")
                        .foregroundColor(.yellow)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                Button { vm.togglePause() } label: {
                    Image(systemName: vm.state == .paused ? "play.fill" : "pause.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(vm.state == .idle || vm.state == .gameOver)
            }
        }
    }

    // MARK: - Overlays

    private var startOverlay: some View {
        overlayContainer {
            Text("TETRIS")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple],
                                                startPoint: .leading, endPoint: .trailing))
            Text("ハイスコア: \(ScoreStore.shared.highScore)")
                .foregroundColor(.gray)
            actionButton("スタート") { vm.startGame() }
        }
    }

    private var pauseOverlay: some View {
        overlayContainer {
            Text("PAUSED")
                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            actionButton("再開")     { vm.togglePause() }
            actionButton("最初から") { vm.startGame() }
        }
    }

    private var gameOverOverlay: some View {
        overlayContainer {
            Text("GAME OVER")
                .font(.system(size: 32, weight: .bold)).foregroundColor(.red)
            VStack(spacing: 4) {
                Text("スコア: \(vm.score)").foregroundColor(.white).font(.title2)
                Text("Lv.\(vm.level)  \(vm.lines) lines").foregroundColor(.gray)
            }
            actionButton("もう一度") { vm.startGame() }
            Button("ハイスコア") { showHighScore = true }.foregroundColor(.cyan)
        }
    }

    @ViewBuilder
    private func overlayContainer<C: View>(@ViewBuilder content: () -> C) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) { content() }
                .padding(32)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
        }
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline).foregroundColor(.black)
                .frame(width: 160, height: 44)
                .background(Color.cyan).cornerRadius(12)
        }
    }

    private func statLabel(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value).font(.system(.title3, design: .monospaced).bold()).foregroundColor(.white)
        }
    }

    // MARK: - Swipe (move / hard drop)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                if abs(dy) > abs(dx) { if dy > 0 { vm.hardDrop() } }
                else { if dx > 0 { vm.moveRight() } else { vm.moveLeft() } }
            }
    }
}
