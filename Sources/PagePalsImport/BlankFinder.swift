import Foundation
import CoreGraphics
import PagePalsCore

/// Finds the grey answer bars printed in workbooks ("write the answer here").
///
/// Prototyped in Python on a real sample page: 8 of 8 bars of a sums task found, nothing else on the spread.
/// A bar is a pale grey, colourless, wide and low shape: width >= 70 px, height 8-45 px,
/// at least 3.5 times wider than high and mostly filled (page scaled to 1754 px wide).
public enum BlankFinder {
    public static func find(in image: CGImage) -> [PageRect] {
        guard let bmp = WorkBitmap(image: image, targetWidth: 1754) else { return [] }
        let w = bmp.width
        let h = bmp.height
        let n = w * h

        let dilated = rankFilter(bmp.mx, w, h, radius: 20, useMax: true)
        let bg = boxBlur(dilated, w, h, radius: 25)

        var mask = [UInt8](repeating: 0, count: n)
        for i in 0..<n {
            let norm = Float(bmp.mx[i]) / (bg[i] + 1)
            if norm > 0.70 && norm < 0.94 && bmp.sat[i] < 35 { mask[i] = 255 }
        }
        // remove specks, then close small gaps
        mask = rankFilter(rankFilter(mask, w, h, radius: 1, useMax: false), w, h, radius: 1, useMax: true)
        mask = rankFilter(rankFilter(mask, w, h, radius: 3, useMax: true), w, h, radius: 3, useMax: false)

        var bars: [PageRect] = []
        for c in labelComponents(mask, w, h).comps {
            let cw = c.width, ch = c.height
            guard cw >= 70, ch >= 8, ch <= 45, Double(cw) / Double(ch) >= 3.5 else { continue }
            guard Double(c.area) / Double(cw * ch) > 0.55 else { continue }
            bars.append(PageRect(
                x: Double(c.minX) / Double(w),
                y: Double(c.minY) / Double(h),
                width: Double(cw) / Double(w),
                height: Double(ch) / Double(h)
            ))
        }
        return bars.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }
}
