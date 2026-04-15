import SwiftUI

struct HighScoreView: View {
    @ObservedObject var store = ScoreStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Group {
                    if store.entries.isEmpty {
                        Text("まだスコアがありません")
                            .foregroundColor(.gray)
                    } else {
                        List {
                            ForEach(Array(store.entries.enumerated()), id: \.element.id) { idx, entry in
                                HStack {
                                    Text("\(idx + 1)")
                                        .foregroundColor(rankColor(idx))
                                        .frame(width: 28, alignment: .leading)
                                        .bold()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(entry.score) pt")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                        Text("Lv.\(entry.level)  \(entry.lines)lines")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text(entry.date, style: .date)
                                        .foregroundColor(.gray)
                                        .font(.caption2)
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("ハイスコア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rankColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return .yellow
        case 1: return Color(white: 0.75)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .white
        }
    }
}
