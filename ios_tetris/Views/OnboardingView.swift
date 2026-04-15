import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var visibleStep = -1

    private let cards: [(icon: String, color: Color, title: String, desc: String)] = [
        (
            "hand.tap",
            .cyan,
            "タップ & スワイプで操作",
            "ボードをタップ→回転、左右スワイプ→移動、下スワイプ→ハードドロップ。ボタンでも同じ操作ができます。"
        ),
        (
            "arrow.left.and.right",
            .blue,
            "長押しで高速移動（DAS）",
            "左右ボタンを押し続けると約150ms後に自動連続移動が始まります。素早い位置調整に便利です。"
        ),
        (
            "square.on.square",
            .purple,
            "ホールド",
            "HOLDボタンで今のピースをストック。1ピースにつき1回使えます。ピンチのときに切り替えましょう。"
        ),
        (
            "flame.fill",
            .orange,
            "コンボでボーナス",
            "ラインを連続消去するとコンボボーナスが加算されます。連続消去数 × 50 × レベル が加点されます。"
        ),
        (
            "chart.line.uptrend.xyaxis",
            .green,
            "レベルアップ",
            "10ライン消去ごとにレベルが上がり、落下速度が増します。上を目指してハイスコアに挑戦！"
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 背景グロー
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), Color.clear],
                center: .top, startRadius: 0, endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── ロゴ ──
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.12))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(Color.cyan.opacity(0.07))
                        .frame(width: 160, height: 160)
                    // テトリミノ風アイコン
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .opacity(visibleStep >= 0 ? 1 : 0)
                .scaleEffect(visibleStep >= 0 ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: visibleStep)

                Spacer().frame(height: 20)

                // ── タイトル ──
                VStack(spacing: 6) {
                    Text("TETRIS")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("遊び方ガイド")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .opacity(visibleStep >= 0 ? 1 : 0)
                .offset(y: visibleStep >= 0 ? 0 : 16)
                .animation(.easeOut(duration: 0.45).delay(0.2), value: visibleStep)

                Spacer().frame(height: 36)

                // ── 説明カード ──
                VStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                        FeatureRow(icon: card.icon, color: card.color,
                                   title: card.title, desc: card.desc)
                            .opacity(visibleStep >= i + 1 ? 1 : 0)
                            .offset(x: visibleStep >= i + 1 ? 0 : 44)
                            .animation(.easeOut(duration: 0.38).delay(Double(i) * 0.08),
                                       value: visibleStep)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // ── はじめるボタン ──
                Button(action: onFinish) {
                    HStack(spacing: 10) {
                        Text("ゲームをはじめる")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.cyan.opacity(0.5), radius: 16, y: 6)
                }
                .padding(.horizontal, 24)
                .opacity(visibleStep >= cards.count + 1 ? 1 : 0)
                .offset(y: visibleStep >= cards.count + 1 ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: visibleStep)

                Spacer().frame(height: 48)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let total = cards.count + 2   // logo + cards + button
            for step in 0..<total {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.16) {
                    visibleStep = step
                }
            }
        }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
