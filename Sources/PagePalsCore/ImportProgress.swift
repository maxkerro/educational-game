import Foundation

/// How far an import is, so it can be shown, cancelled and resumed without redoing pages (PP-005).
public struct ImportProgress: Codable, Equatable, Sendable {
    public var pageCount: Int
    public var finished: Set<Int>
    public var cancelled: Bool

    public init(pageCount: Int, finished: Set<Int> = [], cancelled: Bool = false) {
        self.pageCount = max(0, pageCount)
        self.finished = finished.filter { $0 >= 0 && $0 < max(0, pageCount) }
        self.cancelled = cancelled
    }

    public var fraction: Double {
        pageCount == 0 ? 1 : Double(finished.count) / Double(pageCount)
    }

    public var isDone: Bool { finished.count == pageCount }

    /// First page that is not finished, or `nil` when all are.
    public var nextPage: Int? {
        (0..<pageCount).first { !finished.contains($0) }
    }

    public mutating func finish(_ page: Int) {
        if page >= 0 && page < pageCount { finished.insert(page) }
    }

    public mutating func cancel() { cancelled = true }
    public mutating func resume() { cancelled = false }

    public func save(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    /// A saved state for a book with the same page count, otherwise a fresh start.
    public static func load(from url: URL, pageCount: Int) -> ImportProgress {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(ImportProgress.self, from: data),
              saved.pageCount == pageCount else { return ImportProgress(pageCount: pageCount) }
        // rebuilt through init, so page numbers outside the book are dropped and the cancel is cleared
        return ImportProgress(pageCount: pageCount, finished: saved.finished)
    }
}
