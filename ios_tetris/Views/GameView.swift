import SwiftUI

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @State private var showHighScore = false
    @State private var showSettings  = false
    @State private var comboOpacity: Double = 0
    @State private var popupOpacity: Double = 0
    @State private var popupOffset: CGFloat = 0
    @State private var spinTimer: Timer? = nil

    var body: some View {
        ZStack {
            // Level-based background gradient
            levelBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: vm.level)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Board
                ZStack(alignment: .center) {
                    BoardView(vm: vm)
                        .padding(.horizontal, 16)
                        .onTapGesture { if vm.state == .playing { vm.rotate() } }
                        .onLongPressGesture(minimumDuration: 0.3, pressing: { isPressing in
                            if !isPressing { spinTimer?.invalidate(); spinTimer = nil }
                        }, perform: {
                            let gameVM = vm
                            spinTimer?.invalidate()
                            spinTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                DispatchQueue.main.async { if gameVM.state == .playing { gameVM.rotate() } }
                            }
                        })
                        .gesture(swipeGesture)

                    // Score popup
                    if let text = vm.scorePopupText {
                        Text(text)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange],
                                               startPoint: .top, endPoint: .bottom))
                            .shadow(color: .orange.opacity(0.8), radius: 8)
                            .opacity(popupOpacity)
                            .offset(y: popupOffset)
                            .allowsHitTesting(false)
                    }

                    // Combo popup
                    if vm.combo > 1 {
                        Text("COMBO ×\(vm.combo)!")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange],
                                               startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .orange.opacity(0.8), radius: 8)
                            .opacity(comboOpacity)
                            .offset(y: 40)
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
        .sheet(isPresented: $showSettings)  { SettingsView() }
        .preferredColorScheme(.dark)
        .onChange(of: vm.combo) { newCombo in
            guard newCombo > 1 else { comboOpacity = 0; return }
            comboOpacity = 1
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) { comboOpacity = 0 }
        }
        .onChange(of: vm.scorePopupText) { text in
            guard text != nil else { return }
            popupOpacity = 1; popupOffset = 0
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                popupOpacity = 0; popupOffset = -30
            }
        }
    }

    // MARK: - Level background

    private var levelBackground: some View {
        let colors: [Color] = levelGradientColors(level: vm.level)
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func levelGradientColors(level: Int) -> [Color] {
        switch level {
        case 1...2:  return [Color(red:0.02, green:0.02, blue:0.10), Color.black]
        case 3...4:  return [Color(red:0.00, green:0.10, blue:0.12), Color.black]
        case 5...6:  return [Color(red:0.05, green:0.12, blue:0.00), Color.black]
        case 7...8:  return [Color(red:0.14, green:0.06, blue:0.00), Color.black]
        case 9...10: return [Color(red:0.14, green:0.00, blue:0.00), Color.black]
        default:     return [Color(red:0.16, green:0.00, blue:0.16), Color.black]
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

            // Pause / High score / Settings
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
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
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
            if vm.isNewRecord {
                Text("NEW RECORD!")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .orange.opacity(0.9), radius: 10)
            }
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
