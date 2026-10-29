import Foundation

public enum LibraryError: Error, Equatable {
    case badName
    case missing
    case tooNew(Int)
    case unreadable
}

/// Imported books kept on the Mac: one folder per book with `pack.json` and the picture files (PP-004).
public struct LessonLibrary: Sendable {
    public struct Entry: Equatable, Identifiable, Sendable {
        public var id: String
        public var title: String
        public var language: String
        public var pageCount: Int
    }

    public let root: URL
    public init(root: URL) { self.root = root }

    static let packFile = "pack.json"

    /// Book ids and picture names are plain file names, never paths.
    static func isSafe(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), name.count <= 120 else { return false }
        return name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0) }
    }

    func folder(_ id: String) throws -> URL {
        guard Self.isSafe(id) else { throw LibraryError.badName }
        return root.appendingPathComponent(id, isDirectory: true)
    }

    public func save(_ pack: LessonPack, id: String) throws {
        let dir = try folder(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var current = pack
        current.version = LessonPack.currentVersion
        try encoder.encode(current).write(to: dir.appendingPathComponent(Self.packFile), options: .atomic)
    }

    public func load(id: String) throws -> LessonPack {
        let file = try folder(id).appendingPathComponent(Self.packFile)
        guard let data = try? Data(contentsOf: file) else { throw LibraryError.missing }
        return try Self.decode(data)
    }

    /// Reads a pack of any known version. Older packs get the fields that were added later.
    public static func decode(_ data: Data) throws -> LessonPack {
        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw LibraryError.unreadable }
        let version = (json["version"] as? Int) ?? 0
        if version > LessonPack.currentVersion { throw LibraryError.tooNew(version) }
        if version < 1 {
            json["version"] = 1
            if json["language"] == nil { json["language"] = "en" }
            let pages = (json["pages"] as? [[String: Any]]) ?? []
            json["pages"] = pages.map { page -> [String: Any] in
                var p = page
                let tasks = (p["tasks"] as? [[String: Any]]) ?? []
                p["tasks"] = tasks.map { task -> [String: Any] in
                    var t = task
                    if t["items"] == nil { t["items"] = [Any]() }
                    if t["confidence"] == nil { t["confidence"] = 1.0 }
                    return t
                }
                return p
            }
        }
        guard let fixed = try? JSONSerialization.data(withJSONObject: json),
              let pack = try? JSONDecoder().decode(LessonPack.self, from: fixed) else { throw LibraryError.unreadable }
        return pack
    }

    /// All readable books, sorted by title. A broken folder is skipped, not fatal.
    public func list() -> [Entry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        var entries: [Entry] = []
        for name in names where Self.isSafe(name) {
            guard let pack = try? load(id: name) else { continue }
            entries.append(Entry(id: name, title: pack.title, language: pack.language, pageCount: pack.pages.count))
        }
        return entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func rename(id: String, to title: String) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LibraryError.badName }
        var pack = try load(id: id)
        pack.title = clean
        try save(pack, id: id)
    }

    public func delete(id: String) throws {
        let dir = try folder(id)
        guard FileManager.default.fileExists(atPath: dir.path) else { throw LibraryError.missing }
        try FileManager.default.removeItem(at: dir)
    }

    /// Cut-out pictures are written once and read back later instead of being cut again.
    public func writeImage(_ data: Data, named name: String, book id: String) throws {
        guard Self.isSafe(name) else { throw LibraryError.badName }
        let dir = try folder(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(name), options: .atomic)
    }

    public func imageURL(named name: String, book id: String) -> URL? {
        guard Self.isSafe(name), let dir = try? folder(id) else { return nil }
        let url = dir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
