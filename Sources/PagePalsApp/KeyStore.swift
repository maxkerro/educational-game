import Foundation
import PagePalsCore

/// Keeps answer keys on this Mac (UserDefaults), per book: the file name plus a fingerprint of the file (`BookID`),
/// so two different workbooks with the same name never share answers. (Keys saved under the bare file name by
/// earlier test versions are not read any more.)
/// Only answers typed in by a grown-up are stored; calculated answers (sums) are worked out again on every import.
enum KeyStore {
    private static func name(_ book: String, _ kind: String) -> String { "pagepals.keys.\(kind).\(book)" }

    static func load(book: String, kind: String = "parent") -> [String: AnswerKey] {
        let data = UserDefaults.standard.data(forKey: name(book, kind))
        guard let data, let keys = try? JSONDecoder().decode([String: AnswerKey].self, from: data) else { return [:] }
        return keys
    }

    static func clear(book: String, kind: String = "parent") {
        UserDefaults.standard.removeObject(forKey: name(book, kind))
    }

    static func save(_ keys: [String: AnswerKey], book: String, kind: String = "parent") {
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: name(book, kind))
        }
    }
}
