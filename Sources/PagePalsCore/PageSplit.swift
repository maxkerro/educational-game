import Foundation

/// Cuts a two-page spread at the gutter into two book pages (PP-003).
public enum PageSplit {
    /// A scan wider than this (width / height) is a spread.
    public static let spreadAspect = 1.2

    public static func isSpread(aspect: Double) -> Bool { aspect >= spreadAspect }

    /// Gutter position 0...1 from the mean darkness of each pixel column (0 white ... 1 black), left to right.
    /// Looks in the middle fifth for the column that differs most from the typical page; falls back to the centre.
    public static func gutter(profile: [Double]) -> Double {
        let n = profile.count
        guard n >= 20 else { return 0.5 }
        let radius = max(1, n / 200)
        func smooth(_ i: Int) -> Double {
            let lo = max(0, i - radius), hi = min(n - 1, i + radius)
            return profile[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
        let sorted = profile.sorted()
        let median = sorted[n / 2]
        let from = Int(Double(n) * 0.4), to = Int(Double(n) * 0.6)
        var best = (index: n / 2, deviation: 0.0)
        for i in from...to {
            let d = abs(smooth(i) - median)
            if d > best.deviation { best = (i, d) }
        }
        return best.deviation >= 0.05 ? (Double(best.index) + 0.5) / Double(n) : 0.5
    }

    /// The left and right page as rectangles of the whole scan.
    public static func halves(gutter: Double) -> (left: PageRect, right: PageRect) {
        let g = min(max(gutter, 0.3), 0.7)
        return (PageRect(x: 0, y: 0, width: g, height: 1), PageRect(x: g, y: 0, width: 1 - g, height: 1))
    }

    /// A rectangle of the whole scan in the coordinates of one half, or `nil` when its centre is on the other half.
    public static func local(_ rect: PageRect, rightHalf: Bool, gutter: Double) -> PageRect? {
        let g = min(max(gutter, 0.3), 0.7)
        let centre = rect.x + rect.width / 2
        if rightHalf {
            guard centre >= g else { return nil }
            let w = 1 - g
            return PageRect(x: (rect.x - g) / w, y: rect.y, width: rect.width / w, height: rect.height)
        }
        guard centre < g else { return nil }
        return PageRect(x: rect.x / g, y: rect.y, width: rect.width / g, height: rect.height)
    }
}
