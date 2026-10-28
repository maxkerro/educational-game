import Foundation

/// Where a dragged line ends when the child matches pictures and words (PP-020).
public enum LineMatching {
    public struct Target: Equatable, Sendable {
        public var id: String
        public var region: PageRect
        public init(id: String, region: PageRect) {
            self.id = id
            self.region = region
        }
    }

    public enum Drop: Equatable, Sendable {
        case snapped(String)   // line snaps to this target
        case wrong(String)     // line ends on a target that does not belong; it wiggles back
        case missed            // ends on nothing; it goes back
    }

    /// Nearest target whose region (grown by `slack`) contains the point.
    public static func target(atX x: Double, y: Double, in targets: [Target], slack: Double = 0.015) -> Target? {
        var best: (Target, Double)?
        for t in targets {
            let r = t.region
            guard x >= r.x - slack, x <= r.x + r.width + slack, y >= r.y - slack, y <= r.y + r.height + slack else { continue }
            let dx = x - (r.x + r.width / 2)
            let dy = y - (r.y + r.height / 2)
            let d = dx * dx + dy * dy
            if best == nil || d < best!.1 { best = (t, d) }
        }
        return best?.0
    }

    /// Judges a drop. Without a key every drop on a target snaps and a grown-up checks later.
    public static func drop(from source: String, atX x: Double, y: Double, targets: [Target], key: AnswerKey?, slack: Double = 0.015) -> Drop {
        guard let hit = target(atX: x, y: y, in: targets.filter { $0.id != source }, slack: slack) else { return .missed }
        guard let expected = key?.pairs[source] else { return .snapped(hit.id) }
        return hit.id == expected ? .snapped(hit.id) : .wrong(hit.id)
    }
}
