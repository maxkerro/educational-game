import Foundation
import PagePalsCore

/// Keeps the stars a child earned on this Mac (PP-026, PP-046). Stars are never spent or taken away.
enum StarStore {
    private static var file: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("PagePals", isDirectory: true).appendingPathComponent("stars.json")
    }

    static func load() -> StarLedger {
        guard let file, let data = try? Data(contentsOf: file),
              let ledger = try? JSONDecoder().decode(StarLedger.self, from: data) else { return StarLedger() }
        return ledger
    }

    /// Adds stars for a task (the best result of a task counts). Returns the new Pal stage when the Pal grew.
    @discardableResult
    static func award(_ stars: Int, task id: String) -> PalStage? {
        var ledger = load()
        let grown = ledger.award(stars, task: id)
        if let file, let data = try? JSONEncoder().encode(ledger) {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
        return grown
    }
}
