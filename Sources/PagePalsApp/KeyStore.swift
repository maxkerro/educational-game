import Foundation
import PagePalsCore

/// Keeps parent-entered answer keys on this Mac (UserDefaults), per book file name.
enum KeyStore {
    private static func name(_ book: String) -> String { "pagepals.keys.\(book)" }

    static func load(book: String) -> [String: AnswerKey] {
        guard let data = UserDefaults.standard.data(forKey: name(book)),
              let keys = try? JSONDecoder().decode([String: AnswerKey].self, from: data) else { return [:] }
        return keys
    }

    static func save(_ keys: [String: AnswerKey], book: String) {
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: name(book))
        }
    }
}
