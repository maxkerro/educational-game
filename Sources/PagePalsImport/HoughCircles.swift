import Foundation

/// Circle centres by gradient Hough voting, shared by `CircleFinder` (empty circles) and `TickFinder` (grey tick circles).
/// Every edge pixel votes for the points at distance r along its gradient, for r in the radius range.
enum HoughCircles {
    /// - Parameters:
    ///   - norm: brightness relative to paper (1 = paper), `w * h` values
    ///   - edge: minimum Sobel gradient strength of a voting pixel
    ///   - vote: minimum smoothed vote count of a peak
    static func peaks(norm: [Float], w: Int, h: Int, rMin: Int, rMax: Int, edge: Float, vote: Float) -> [(x: Int, y: Int)] {
        guard w >= 4, h >= 4 else { return [] }
        var acc = [Float](repeating: 0, count: w * h)
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let a = norm[i - w - 1], b = norm[i - w], c = norm[i - w + 1]
                let d = norm[i - 1], f = norm[i + 1]
                let g = norm[i + w - 1], hh = norm[i + w], k = norm[i + w + 1]
                let gx = (c + 2 * f + k) - (a + 2 * d + g)
                let gy = (g + 2 * hh + k) - (a + 2 * b + c)
                let mag = (gx * gx + gy * gy).squareRoot()
                if mag < edge { continue }
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

        // Local maxima in a 25 x 25 window above the vote threshold
        var peaks: [(x: Int, y: Int)] = []
        for y in 0..<h {
            for x in 0..<w where smooth[y * w + x] > vote {
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
        return peaks
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
