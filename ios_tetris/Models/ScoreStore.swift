import Foundation

struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    let score: Int
    let level: Int
    let lines: Int
    let date: Date

    init(score: Int, level: Int, lines: Int) {
        self.id = UUID()
        self.score = score
        self.level = level
        self.lines = lines
        self.date = Date()
    }
}

final class ScoreStore: ObservableObject {
    static let shared = ScoreStore()
    private let key = "tetris_scores"

    @Published private(set) var entries: [ScoreEntry] = []

    private init() {
        load()
    }

    var highScore: Int { entries.first?.score ?? 0 }

    func save(score: Int, level: Int, lines: Int) {
        let entry = ScoreEntry(score: score, level: level, lines: lines)
        entries.append(entry)
        entries.sort { $0.score > $1.score }
        if entries.count > 10 { entries = Array(entries.prefix(10)) }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ScoreEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
