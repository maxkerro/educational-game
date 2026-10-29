import Foundation

/// Compares what the importer found with what is really on a test page (PP-016, PP-062).
public enum RecognitionScore {
    public struct Result: Equatable, Sendable {
        public var expected: Int
        public var hits: Int
        /// Found shapes that match nothing that is really there.
        public var extras: Int

        public init(expected: Int, hits: Int, extras: Int) {
            self.expected = expected
            self.hits = hits
            self.extras = extras
        }

        public var missed: Int { expected - hits }
        /// Share of the real shapes that were found; 1 when there was nothing to find.
        public var recall: Double { expected == 0 ? 1 : Double(hits) / Double(expected) }
        /// Share of the found shapes that are real; 1 when nothing was found.
        public var precision: Double { hits + extras == 0 ? 1 : Double(hits) / Double(hits + extras) }

        public static func + (a: Result, b: Result) -> Result {
            Result(expected: a.expected + b.expected, hits: a.hits + b.hits, extras: a.extras + b.extras)
        }
    }

    /// A found box is a hit when its centre is within `tolerance` (page units) of the centre of a real box in x and y.
    /// Every real box and every found box is used at most once.
    public static func match(expected: [PageRect], found: [PageRect], tolerance: Double = 0.02) -> Result {
        var used = Set<Int>()
        var hits = 0
        for e in expected {
            let ex = e.x + e.width / 2, ey = e.y + e.height / 2
            var best: (index: Int, distance: Double)?
            for (i, f) in found.enumerated() where !used.contains(i) {
                let dx = abs(f.x + f.width / 2 - ex), dy = abs(f.y + f.height / 2 - ey)
                guard dx <= tolerance, dy <= tolerance else { continue }
                let d = max(dx, dy)
                if best == nil || d < best!.distance { best = (i, d) }
            }
            if let b = best {
                used.insert(b.index)
                hits += 1
            }
        }
        return Result(expected: expected.count, hits: hits, extras: found.count - hits)
    }
}
