import Foundation

/// The page numbers printed in the margin of a scanned page. Answer keys refer to tasks by
/// "page 10, task 1", so a task needs the printed number of the page it sits on.
public enum PageNumbers {
    /// Numbers (1...999) that stand alone on a line in the top 7% or the bottom 10% of the page.
    /// `x` is the middle of the line (0...1).
    public static func find(_ lines: [PageText]) -> [(number: Int, x: Double)] {
        var result: [(number: Int, x: Double)] = []
        for line in lines {
            guard line.box.y < 0.07 || line.box.y + line.box.height > 0.90 else { continue }
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-\u{2013}\u{2014}.")))
            guard !text.isEmpty, text.count <= 3, text.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(text), number > 0 else { continue }
            result.append((number, line.box.x + line.box.width / 2))
        }
        return result
    }

    /// The printed number of the page that holds something at horizontal position `x`. A single page
    /// (narrower than `PageSplit.spreadAspect`) needs exactly one distinct number in the margin; a two-page spread needs exactly
    /// one distinct number in the half that contains `x`. Anything unclear gives nil.
    public static func number(atX x: Double, lines: [PageText], pageAspect: Double) -> Int? {
        let isSpread = PageSplit.isSpread(aspect: pageAspect)
        let candidates = find(lines).filter { found in
            isSpread ? (found.x < 0.5) == (x < 0.5) : true
        }
        let distinct = Set(candidates.map { $0.number })
        return distinct.count == 1 ? distinct.first : nil
    }
}

/// Answer keys of a whole book: finds the key pages, reads them and gives the answers to the tasks of
/// the other pages. Pure text work; the app does the OCR of every page.
public enum BookKeys {
    /// The entries of every page that is an answer key.
    public static func entries(pages: [[PageText]]) -> [AnswerPages.Entry] {
        var all: [AnswerPages.Entry] = []
        for lines in pages where AnswerPages.isKeyPage(lines) {
            all += AnswerPages.parse(lines)
        }
        return all
    }

    /// Gives each task its answers from the book key. A task is matched by its number and the printed number of
    /// the page it sits on. A key that was already calculated is compared with the book key
    /// (see `AnswerReconciler`): when they agree the answer is trusted, when they differ it is left to a grown-up.
    public static func apply(_ entries: [AnswerPages.Entry], to tasks: [PlayTask], lines: [PageText], pageAspect: Double) -> [PlayTask] {
        guard !entries.isEmpty else { return tasks }
        return tasks.map { task in
            let x = task.region.map { $0.x + $0.width / 2 } ?? 0.5
            guard let page = PageNumbers.number(atX: x, lines: lines, pageAspect: pageAspect) else { return task }
            var bare = task
            bare.key = nil
            bare.keySource = nil
            let fromKey = AnswerPages.apply(entries, to: bare, group: page, pageGroupsOnly: true)
            return AnswerReconciler.merge(task, fromKey)
        }
    }
}
