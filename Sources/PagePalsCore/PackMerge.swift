import Foundation

/// How an import writes into a book that already exists in the library (PP-004, PP-005): the pages of one PDF
/// page are replaced, answers a grown-up typed are kept, and typed answers beat the answer pages of the book.
public enum PackMerge {
    /// The PDF page a book page came from: "p12", "p12a" and "p12b" are all PDF page 12.
    public static func pdfPage(of pageID: String) -> Int {
        Int(pageID.dropFirst().prefix { $0.isNumber }) ?? 0
    }

    /// Replaces the book pages of one PDF page (1-based) with `made`. Answers a grown-up typed on the old pages
    /// are carried over to tasks with the same id. Pages stay in PDF order.
    public static func replacePage(in pack: LessonPack, pdfPage number: Int, with made: [BookPage]) -> LessonPack {
        let old = pack.pages.filter { pdfPage(of: $0.id) == number }.flatMap { $0.tasks }
        let typed = Dictionary(old.compactMap { t in t.keySource == .parent ? t.key.map { (t.id, $0) } : nil },
                               uniquingKeysWith: { first, _ in first })
        var next = pack
        next.pages.removeAll { pdfPage(of: $0.id) == number }
        next.pages.append(contentsOf: made.map { page in
            var page = page
            page.tasks = overlay(typed, on: page.tasks).tasks
            return page
        })
        next.pages.sort { pdfPage(of: $0.id) == pdfPage(of: $1.id) ? $0.id < $1.id : pdfPage(of: $0.id) < pdfPage(of: $1.id) }
        return next
    }

    /// Puts typed answers on the tasks with the same id (source: grown-up). Also says which ids found a task.
    public static func overlay(_ typed: [String: AnswerKey], on tasks: [PlayTask]) -> (tasks: [PlayTask], matched: Set<String>) {
        var matched = Set<String>()
        let result = tasks.map { task -> PlayTask in
            guard let key = typed[task.id] else { return task }
            matched.insert(task.id)
            var task = task
            task.key = key
            task.keySource = .parent
            return task
        }
        return (result, matched)
    }

    /// The key under which stars are kept: task ids repeat in every book, so the book comes first.
    public static func starKey(scope: String, task: String) -> String { scope + "/" + task }
}
