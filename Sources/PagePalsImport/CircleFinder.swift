import Foundation
import CoreGraphics
import PagePalsCore

/// Finds empty circles (for example the answer circles of a "write the number" task).
///
/// Method (prototyped in Python on two real sample pages: all 9 empty answer circles found, printed numbered circles and grey tick circles ignored; circle radius there is 14-15 px at 1754 px page width):
///  1. page brightness relative to the paper (same normalisation as `PictureFinder`)
///  2. edge pixels with their gradient direction; each edge pixel votes for circle centres
///     at distance r along the gradient, for r in a radius range
///  3. every peak is checked: the ring is closed (>= 80% of directions have ink) and the inside is paper
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

        // Sobel gradient
        let rMin = 10, rMax = 36
        var acc = [Float](repeating: 0, count: n)
        if w < 4 || h < 4 { return [] }
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let a = norm[i - w - 1], b = norm[i - w], c = norm[i - w + 1]
                let d = norm[i - 1], f = norm[i + 1]
                let g = norm[i + w - 1], hh = norm[i + w], k = norm[i + w + 1]
                let gx = (c + 2 * f + k) - (a + 2 * d + g)
                let gy = (g + 2 * hh + k) - (a + 2 * b + c)
                let mag = (gx * gx + gy * gy).squareRoot()
                if mag < 0.35 { continue }
                let ux = gx / mag, uy = gy / mag
                var r = rMin
                while r <= rMax {
                    let fr = Float(r)
                    for sign: Float in [1, -1] {
                        let cx = Int((Float(x) + sign * ux * fr).rounded())
                        let cy = Int((Float(y) + sign * uy * fr).rounded())
                        if cx >= 0 && cx < w && cy >= 0 && cy < h { acc[cy * w + cx] += 1 }
                    }
                    r += 2
                }
            }
        }
        let smooth = blur5(acc, w, h)

        // Peaks: local maxima in a 25 x 25 window above a vote threshold
        var peaks: [(x: Int, y: Int)] = []
        let voteThreshold: Float = 16
        for y in 0..<h {
            for x in 0..<w where smooth[y * w + x] > voteThreshold {
                let v = smooth[y * w + x]
                var isMax = true
                search: for yy in max(0, y - 12)...min(h - 1, y + 12) {
                    for xx in max(0, x - 12)...min(w - 1, x + 12) {
                        let o = smooth[yy * w + xx]
                        if o > v || (o == v && (yy < y || (yy == y && xx < x))) { isMax = false; break search }
                    }
                }
                if isMax { peaks.append((x, y)) }
            }
        }

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

    /// 5 x 5 box average, separable.
    private static func blur5(_ src: [Float], _ w: Int, _ h: Int) -> [Float] {
        var tmp = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            let row = y * w
            for x in 0..<w {
                var s: Float = 0
                for dx in -2...2 {
                    let xx = x + dx
                    if xx >= 0 && xx < w { s += src[row + xx] }
                }
                tmp[row + x] = s / 5
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var s: Float = 0
                for dy in -2...2 {
                    let yy = y + dy
                    if yy >= 0 && yy < h { s += tmp[yy * w + x] }
                }
                out[y * w + x] = s / 5
            }
        }
        return out
    }
}
