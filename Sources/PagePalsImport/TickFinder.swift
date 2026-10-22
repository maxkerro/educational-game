import Foundation
import CoreGraphics
import PagePalsCore

/// Finds the small grey filled circles of "Correct or wrong? Tick." tasks.
/// Prototyped in Python on a real sample page: 8 of 8 found (2 columns x 4 rows), nothing else.
/// A tick circle is a closed ring (radius 10-24 px at 1754 px page width) whose inside is evenly light grey
/// and colourless, on clean paper.
public enum TickFinder {
    public static func find(in image: CGImage) -> [PageRect] {
        guard let bmp = WorkBitmap(image: image, targetWidth: 1754) else { return [] }
        let w = bmp.width
        let h = bmp.height
        let n = w * h

        let dilated = rankFilter(bmp.mx, w, h, radius: 20, useMax: true)
        let bg = boxBlur(dilated, w, h, radius: 25)
        var norm = [Float](repeating: 1, count: n)
        for i in 0..<n { norm[i] = Float(bmp.mx[i]) / (bg[i] + 1) }

        let rMin = 10, rMax = 24
        let peaks = HoughCircles.peaks(norm: norm, w: w, h: h, rMin: rMin, rMax: rMax, edge: 0.2, vote: 14)

        struct Disc { let x: Int; let y: Int; let r: Int }
        var discs: [Disc] = []
        for p in peaks {
            // closed ring
            var bestR = 0
            var bestCoverage = 0.0
            for r in rMin...rMax {
                var hit = 0
                for k in 0..<72 {
                    let ang = 2 * Double.pi * Double(k) / 72
                    var found = false
                    for d in -1...1 {
                        let rr = Double(r + d)
                        let px = p.x + Int((rr * cos(ang)).rounded())
                        let py = p.y + Int((rr * sin(ang)).rounded())
                        if px >= 0 && px < w && py >= 0 && py < h && norm[py * w + px] < 0.93 { found = true; break }
                    }
                    if found { hit += 1 }
                }
                let cov = Double(hit) / 72
                if cov > bestCoverage { bestCoverage = cov; bestR = r }
            }
            if bestCoverage < 0.9 || bestR == 0 { continue }

            // inside: evenly grey (not paper, not ink) and colourless
            var total = 0, grey = 0, satSum = 0
            let r2 = pow(Double(bestR) * 0.7, 2)
            for yy in max(0, p.y - bestR)...min(h - 1, p.y + bestR) {
                for xx in max(0, p.x - bestR)...min(w - 1, p.x + bestR) {
                    let dx = Double(xx - p.x), dy = Double(yy - p.y)
                    if dx * dx + dy * dy <= r2 {
                        total += 1
                        let v = norm[yy * w + xx]
                        if v > 0.6 && v < 0.95 { grey += 1 }
                        satSum += Int(bmp.sat[yy * w + xx])
                    }
                }
            }
            if total == 0 || Double(grey) / Double(total) < 0.85 || satSum / total >= 40 { continue }

            // clean paper around the ring
            var clean = 0
            for k in 0..<72 {
                let ang = 2 * Double.pi * Double(k) / 72
                let rr = Double(bestR + 7)
                let px = p.x + Int((rr * cos(ang)).rounded())
                let py = p.y + Int((rr * sin(ang)).rounded())
                if px < 0 || px >= w || py < 0 || py >= h || norm[py * w + px] > 0.9 { clean += 1 }
            }
            if Double(clean) / 72 < 0.9 { continue }

            if discs.contains(where: { hypot(Double($0.x - p.x), Double($0.y - p.y)) < Double(min($0.r, bestR)) }) { continue }
            discs.append(Disc(x: p.x, y: p.y, r: bestR))
        }

        // Same size as the others
        if discs.count >= 3 {
            let radii = discs.map { $0.r }.sorted()
            let median = Double(radii[radii.count / 2])
            discs = discs.filter { abs(Double($0.r) - median) <= max(4, median * 0.35) }
        }

        return discs.map { d in
            PageRect(
                x: Double(d.x - d.r) / Double(w),
                y: Double(d.y - d.r) / Double(h),
                width: Double(2 * d.r) / Double(w),
                height: Double(2 * d.r) / Double(h)
            )
        }
    }
}
