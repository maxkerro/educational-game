import Foundation
import CoreGraphics
import PagePalsCore

/// An area of a page that is not running text: either a picture or a structure (word list, letter grid).
public struct PageRegion: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case picture
        case structure
    }

    public let id: UUID
    public let kind: Kind
    public let box: PageRect

    public init(kind: Kind, box: PageRect) {
        self.id = UUID()
        self.kind = kind
        self.box = box
    }
}

/// Finds the pictures on a page so they can be cut out and reused in the interactive tasks.
///
/// Two passes are combined (prototyped and checked on the sample book):
///  - solid pass: coloured or dark blobs after thin lines (crossword grids, outlines) are removed
///  - line-art pass: everything that is not paper, minus text words, writing lines and specks
/// Boxes that hold a word list or a letter grid are reported as `.structure`.
public enum PictureFinder {
    /// - Parameters:
    ///   - image: the rendered page (one book page or a two-page spread)
    ///   - textWords: boxes of recognised words (see `PageOCR`), used to ignore text
    public static func find(in image: CGImage, textWords: [PageRect]) -> [PageRegion] {
        guard let bmp = WorkBitmap(image: image, targetWidth: 1754) else { return [] }
        let w = bmp.width
        let h = bmp.height
        let n = w * h

        // Paper brightness estimate, then "how dark is this pixel compared to paper".
        let dilated = rankFilter(bmp.mx, w, h, radius: 20, useMax: true)
        let bg = boxBlur(dilated, w, h, radius: 25)
        var norm = [Float](repeating: 1, count: n)
        for i in 0..<n { norm[i] = Float(bmp.mx[i]) / (bg[i] + 1) }

        // Pass A: solid pictures
        var inkA = [UInt8](repeating: 0, count: n)
        for i in 0..<n where norm[i] < 0.82 || bmp.sat[i] > 60 { inkA[i] = 255 }
        inkA = rankFilter(rankFilter(inkA, w, h, radius: 3, useMax: false), w, h, radius: 3, useMax: true)
        inkA = rankFilter(rankFilter(inkA, w, h, radius: 7, useMax: true), w, h, radius: 7, useMax: false)
        let boxesA = labelComponents(inkA, w, h).comps.filter { $0.area >= 350 }.map { $0.rect }

        // Pass B: line art
        var inkB = [UInt8](repeating: 0, count: n)
        for i in 0..<n where norm[i] < 0.86 || bmp.sat[i] > 45 { inkB[i] = 255 }

        let textRects: [IRect] = textWords.map {
            IRect(x: Int($0.x * Double(w)), y: Int($0.y * Double(h)),
                  w: Int($0.width * Double(w)), h: Int($0.height * Double(h)))
        }
        for r in textRects {
            let x0 = max(0, r.x - 4), y0 = max(0, r.y - 4)
            let x1 = min(w, r.x + r.w + 4), y1 = min(h, r.y + r.h + 4)
            if x0 >= x1 || y0 >= y1 { continue }
            for y in y0..<y1 {
                for x in x0..<x1 { inkB[y * w + x] = 0 }
            }
        }

        let labeledB = labelComponents(inkB, w, h)
        var drop = [Bool](repeating: false, count: labeledB.comps.count)
        for (i, c) in labeledB.comps.enumerated() {
            let longSide = max(c.width, c.height)
            let shortSide = min(c.width, c.height)
            let thinAndLong = longSide > 110 && Double(longSide) / Double(max(1, shortSide)) > 6
            if thinAndLong || c.area < 260 { drop[i] = true }
        }
        for i in 0..<n {
            let l = labeledB.labels[i]
            if l >= 0 && drop[Int(l)] { inkB[i] = 0 }
        }
        let mergedB = rankFilter(inkB, w, h, radius: 5, useMax: true)
        var boxesB: [IRect] = []
        for c in labelComponents(mergedB, w, h).comps {
            let r = c.rect
            if r.area < 1500 { continue }
            if inkCount(inkB, w, r) < 300 { continue }
            boxesB.append(r)
        }

        // Plausibility filter (header bands, page edges, huge blobs)
        func plausible(_ r: IRect, minArea: Int) -> Bool {
            if r.area < minArea || Double(r.area) > 0.125 * Double(n) { return false }
            if Double(r.w) > 0.4 * Double(w) && Double(r.h) < 0.12 * Double(h) { return false }
            if r.x <= 2 || r.y <= 2 || r.x + r.w >= w - 2 || r.y + r.h >= h - 2 { return false }
            return true
        }
        let A = boxesA.filter { plausible($0, minArea: 600) }
        let B = boxesB.filter { plausible($0, minArea: 1200) }

        // Combine: a line-art box that merges several solid pictures is replaced by those pictures.
        var chosen: [IRect] = []
        for b in B {
            let inside = A.filter { b.contains($0) }
            if inside.count >= 2 { continue }
            chosen.append(b)
        }
        for a in A {
            if chosen.contains(where: { $0.contains(a) || a.iou($0) > 0.3 }) { continue }
            if chosen.contains(where: { B.contains($0) && a.contains($0) }) { continue }
            chosen.append(a)
        }

        // Structures: boxes full of text or of letter-sized specks (word lists, letter grids)
        var maskC = [UInt8](repeating: 0, count: n)
        for i in 0..<n where norm[i] < 0.7 { maskC[i] = 255 }
        let specks = labelComponents(maskC, w, h).comps.filter {
            $0.width >= 6 && $0.width <= 40 && $0.height >= 8 && $0.height <= 40 && $0.area < 400
        }

        var pictures: [IRect] = []
        var structures: [IRect] = []
        for r in chosen {
            var textArea = 0
            for t in textRects where r.contains(t, tol: 4) { textArea += t.area }
            let ratio = Double(textArea) / Double(max(1, r.area))
            var speckCount = 0
            for s in specks {
                let cx = (s.minX + s.maxX) / 2
                let cy = (s.minY + s.maxY) / 2
                if cx >= r.x && cx < r.x + r.w && cy >= r.y && cy < r.y + r.h { speckCount += 1 }
            }
            if ratio > 0.08 || speckCount > 60 { structures.append(r) } else { pictures.append(r) }
        }
        pictures = pictures.filter { p in !structures.contains(where: { $0.contains(p, tol: 10) }) }

        func region(_ r: IRect, _ kind: PageRegion.Kind) -> PageRegion {
            PageRegion(kind: kind, box: PageRect(
                x: Double(r.x) / Double(w), y: Double(r.y) / Double(h),
                width: Double(r.w) / Double(w), height: Double(r.h) / Double(h)))
        }
        let all = pictures.map { region($0, .picture) } + structures.map { region($0, .structure) }
        return all.sorted { ($0.box.y, $0.box.x) < ($1.box.y, $1.box.x) }
    }
}

// MARK: - Helpers

private struct IRect: Equatable {
    var x: Int
    var y: Int
    var w: Int
    var h: Int

    var area: Int { w * h }

    func contains(_ o: IRect, tol: Int = 6) -> Bool {
        o.x >= x - tol && o.y >= y - tol && o.x + o.w <= x + w + tol && o.y + o.h <= y + h + tol
    }

    func iou(_ o: IRect) -> Double {
        let ix = max(0, min(x + w, o.x + o.w) - max(x, o.x))
        let iy = max(0, min(y + h, o.y + o.h) - max(y, o.y))
        let inter = ix * iy
        let union = area + o.area - inter
        return union > 0 ? Double(inter) / Double(union) : 0
    }
}

private struct Component {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    var area: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var rect: IRect { IRect(x: minX, y: minY, w: width, h: height) }
}

/// The page scaled to a fixed width, reduced to brightness and colourfulness per pixel.
struct WorkBitmap {
    let width: Int
    let height: Int
    let mx: [UInt8]    // brightest colour channel
    let sat: [UInt8]   // colourfulness 0...255

    init?(image: CGImage, targetWidth: Int) {
        let scale = Double(targetWidth) / Double(image.width)
        let w = targetWidth
        let h = max(1, Int((Double(image.height) * scale).rounded()))
        var data = [UInt8](repeating: 255, count: w * h * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        if !drawn { return nil }

        var mxOut = [UInt8](repeating: 0, count: w * h)
        var satOut = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let r = data[i * 4]
            let g = data[i * 4 + 1]
            let b = data[i * 4 + 2]
            let hi = max(r, max(g, b))
            let lo = min(r, min(g, b))
            mxOut[i] = hi
            satOut[i] = hi == 0 ? 0 : UInt8(Int(hi - lo) * 255 / Int(hi))
        }
        self.width = w
        self.height = h
        self.mx = mxOut
        self.sat = satOut
    }
}

/// Square max (dilate) or min (erode) filter, separable.
func rankFilter(_ src: [UInt8], _ w: Int, _ h: Int, radius r: Int, useMax: Bool) -> [UInt8] {
    if r <= 0 { return src }
    var tmp = [UInt8](repeating: 0, count: w * h)
    for y in 0..<h {
        let row = y * w
        for x in 0..<w {
            let lo = max(0, x - r)
            let hi = min(w - 1, x + r)
            var m: UInt8 = useMax ? 0 : 255
            var i = lo
            while i <= hi {
                let v = src[row + i]
                if useMax { if v > m { m = v } } else { if v < m { m = v } }
                i += 1
            }
            tmp[row + x] = m
        }
    }
    var out = [UInt8](repeating: 0, count: w * h)
    for x in 0..<w {
        for y in 0..<h {
            let lo = max(0, y - r)
            let hi = min(h - 1, y + r)
            var m: UInt8 = useMax ? 0 : 255
            var j = lo
            while j <= hi {
                let v = tmp[j * w + x]
                if useMax { if v > m { m = v } } else { if v < m { m = v } }
                j += 1
            }
            out[y * w + x] = m
        }
    }
    return out
}

/// Average over a square window, separable, using running sums.
func boxBlur(_ src: [UInt8], _ w: Int, _ h: Int, radius r: Int) -> [Float] {
    var tmp = [Float](repeating: 0, count: w * h)
    var prefix = [Float](repeating: 0, count: max(w, h) + 1)
    for y in 0..<h {
        let row = y * w
        prefix[0] = 0
        for x in 0..<w { prefix[x + 1] = prefix[x] + Float(src[row + x]) }
        for x in 0..<w {
            let lo = max(0, x - r)
            let hi = min(w - 1, x + r)
            tmp[row + x] = (prefix[hi + 1] - prefix[lo]) / Float(hi - lo + 1)
        }
    }
    var out = [Float](repeating: 0, count: w * h)
    for x in 0..<w {
        prefix[0] = 0
        for y in 0..<h { prefix[y + 1] = prefix[y] + tmp[y * w + x] }
        for y in 0..<h {
            let lo = max(0, y - r)
            let hi = min(h - 1, y + r)
            out[y * w + x] = (prefix[hi + 1] - prefix[lo]) / Float(hi - lo + 1)
        }
    }
    return out
}

/// 8-connected component labelling. Background pixels get label -1.
private func labelComponents(_ mask: [UInt8], _ w: Int, _ h: Int) -> (labels: [Int32], comps: [Component]) {
    var labels = [Int32](repeating: -1, count: w * h)
    var comps: [Component] = []
    var stack: [Int] = []
    for start in 0..<(w * h) {
        if mask[start] == 0 || labels[start] >= 0 { continue }
        let id = Int32(comps.count)
        var c = Component(minX: w, minY: h, maxX: 0, maxY: 0, area: 0)
        labels[start] = id
        stack.append(start)
        while let p = stack.popLast() {
            let x = p % w
            let y = p / w
            c.area += 1
            if x < c.minX { c.minX = x }
            if x > c.maxX { c.maxX = x }
            if y < c.minY { c.minY = y }
            if y > c.maxY { c.maxY = y }
            for dy in -1...1 {
                let ny = y + dy
                if ny < 0 || ny >= h { continue }
                for dx in -1...1 {
                    if dx == 0 && dy == 0 { continue }
                    let nx = x + dx
                    if nx < 0 || nx >= w { continue }
                    let q = ny * w + nx
                    if mask[q] != 0 && labels[q] < 0 {
                        labels[q] = id
                        stack.append(q)
                    }
                }
            }
        }
        comps.append(c)
    }
    return (labels, comps)
}

private func inkCount(_ mask: [UInt8], _ w: Int, _ r: IRect) -> Int {
    var count = 0
    for y in r.y..<(r.y + r.h) {
        let row = y * w
        for x in r.x..<(r.x + r.w) where mask[row + x] != 0 { count += 1 }
    }
    return count
}
