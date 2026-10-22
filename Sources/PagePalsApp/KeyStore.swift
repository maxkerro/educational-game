import Foundation
import PagePalsCore

/// Keeps answer keys on this Mac (UserDefaults), per book file name.
/// Only answers typed in by a grown-up are stored; calculated answers (sums) are worked out again on every import.
enum KeyStore {
    private static func name(_ book: String, _ kind: String) -> String { "pagepals.keys.\(kind).\(book)" }

    static func load(book: String, kind: String = "parent") -> [String: AnswerKey] {
        let old = kind == "parent" ? "pagepals.keys.\(book)" : nil   // keys saved by the first version
        let data = UserDefaults.standard.data(forKey: name(book, kind))
            ?? old.flatMap { UserDefaults.standard.data(forKey: $0) }
        guard let data, let keys = try? JSONDecoder().decode([String: AnswerKey].self, from: data) else { return [:] }
        return keys
    }

    static func save(_ keys: [String: AnswerKey], book: String, kind: String = "parent") {
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: name(book, kind))
        }
    }
}
