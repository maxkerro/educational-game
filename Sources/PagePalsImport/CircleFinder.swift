import Foundation
import CoreGraphics
import PagePalsCore

/// Finds empty circles (for example the answer circles of a "write the number" task).
///
/// Method (prototyped in Python on two real sample pages: all 9 empty answer circles found, printed numbered circles and grey tick circles ignored; circle radius there is 14-15 px at 1754 px page width):
///  1. page brightness relative to the paper (same normalisation as `PictureFinder`)
///  2. edge pixels with their gradient direction; each edge pixel votes for circle centres
///     at distance r along the gradient, for r in a radius range
///  3. every peak is checked: the ring is closed (>= 95% of directions have ink), the inside is paper and the
///     outside is clean paper (>= 90% of directions); this removes loops in scribbled lines
///  4. circles whose size differs a lot from the typical size are dropped (buttons, eyes in drawings)
public enum CircleFinder {
    public static func findEmpty(in image: CGImage, textWords: [PageRect] = []) -> [PageRect] {
        guard let bmp = WorkBitmap(image: image, targetWidth: 1754) else { return [] }
        let w = bmp.width
        let h = bmp.height
        let n = w * h

        // Brightness compared to paper
        let dilated = rankFilter(bmp.mx, w, h, radius: 20, useMax: true)
        let bg = boxBlur(dilated, w, h, radius: 25)
        var norm = [Float](repeating: 1, count: n)
        for i in 0..<n { norm[i] = Float(bmp.mx[i]) / (bg[i] + 1) }

        let rMin = 10, rMax = 36
        let peaks = HoughCircles.peaks(norm: norm, w: w, h: h, rMin: rMin, rMax: rMax, edge: 0.35, vote: 16)

        // Verify each peak: closed ring, empty inside
        struct Circle { let x: Int; let y: Int; let r: Int; let coverage: Double }
        var circles: [Circle] = []
        for p in peaks {
            var bestR = 0
            var bestCoverage = 0.0
            for r in rMin...rMax {
                var hit = 0
                for k in 0..<72 {
                    let ang = 2 * Double.pi * Double(k) / 72
                    var found = false
                    for d in -2...2 {
                        let rr = Double(r + d)
                        let px = p.x + Int((rr * cos(ang)).rounded())
                        let py = p.y + Int((rr * sin(ang)).rounded())
                        if px >= 0 && px < w && py >= 0 && py < h && norm[py * w + px] < 0.88 { found = true; break }
                    }
                    if found { hit += 1 }
                }
                let cov = Double(hit) / 72
                if cov > bestCoverage { bestCoverage = cov; bestR = r }
            }
            if bestCoverage < 0.8 || bestR == 0 { continue }

            // Inside (70% of the radius) must be paper
            var total = 0
            var dark = 0
            let inner = Double(bestR) * 0.7
            let r2 = inner * inner
            for yy in max(0, p.y - bestR)...min(h - 1, p.y + bestR) {
                for xx in max(0, p.x - bestR)...min(w - 1, p.x + bestR) {
                    let dx = Double(xx - p.x), dy = Double(yy - p.y)
                    if dx * dx + dy * dy <= r2 {
                        total += 1
                        if norm[yy * w + xx] < 0.9 { dark += 1 }
                    }
                }
            }
            if total == 0 || Double(dark) / Double(total) > 0.03 { continue }

            // A real answer circle is closed and stands on clean paper (apart from a pointer line);
            // loops in scribbled lines have gaps and ink right outside the ring.
            if bestCoverage < 0.95 { continue }
            var clean = 0
            for k in 0..<72 {
                let ang = 2 * Double.pi * Double(k) / 72
                var paper = true
                for d in 5...8 {
                    let rr = Double(bestR + d)
                    let px = p.x + Int((rr * cos(ang)).rounded())
                    let py = p.y + Int((rr * sin(ang)).rounded())
                    if px >= 0 && px < w && py >= 0 && py < h && norm[py * w + px] < 0.9 { paper = false; break }
                }
                if paper { clean += 1 }
            }
            if Double(clean) / 72 < 0.9 { continue }
            circles.append(Circle(x: p.x, y: p.y, r: bestR, coverage: bestCoverage))
        }

        // Remove duplicates (keep the better ring) and words' interiors
        circles.sort { $0.coverage > $1.coverage }
        var kept: [Circle] = []
        for c in circles {
            if kept.contains(where: { hypot(Double($0.x - c.x), Double($0.y - c.y)) < Double(min($0.r, c.r)) }) { continue }
            let nx = Double(c.x) / Double(w), ny = Double(c.y) / Double(h)
            if textWords.contains(where: { nx >= $0.x && nx <= $0.x + $0.width && ny >= $0.y && ny <= $0.y + $0.height }) { continue }
            kept.append(c)
        }

        // Typical size: drop circles far from the median radius
        if kept.count >= 3 {
            let radii = kept.map { $0.r }.sorted()
            let median = Double(radii[radii.count / 2])
            kept = kept.filter { abs(Double($0.r) - median) <= median * 0.25 }
        }

        return kept.map { c in
            PageRect(
                x: Double(c.x - c.r) / Double(w),
                y: Double(c.y - c.r) / Double(h),
                width: Double(2 * c.r) / Double(w),
                height: Double(2 * c.r) / Double(h)
            )
        }
    }
}
