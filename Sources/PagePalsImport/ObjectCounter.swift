import Foundation
import CoreGraphics
import PagePalsCore

/// Counts the separate objects of similar size in a part of the page (ladybirds, balloons, lollies).
///
/// A classical method without any model: ink pixels (dark or coloured) are grouped into blobs, tiny specks
/// are dropped, and the count is only reported when the blobs have similar sizes. A picture of different
/// things, or objects that touch, gives nil so that a grown-up decides.
public enum ObjectCounter {
    /// - Returns: the number of objects, or nil when the region does not look like a row of similar objects.
    public static func count(in page: CGImage, region: PageRect) -> Int? {
        let width = Double(page.width)
        let height = Double(page.height)
        let rect = CGRect(x: region.x * width, y: region.y * height, width: region.width * width, height: region.height * height)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width >= 24, rect.height >= 24, let piece = page.cropping(to: rect),
              let bitmap = WorkBitmap(image: piece, targetWidth: min(piece.width, 480)) else { return nil }

        let w = bitmap.width
        let h = bitmap.height
        var mask = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) where bitmap.mx[i] < 170 || bitmap.sat[i] > 70 { mask[i] = 255 }
        // close one-pixel gaps inside an object
        mask = rankFilter(rankFilter(mask, w, h, radius: 1, useMax: true), w, h, radius: 1, useMax: false)

        let areas = labelComponents(mask, w, h).comps.map { $0.area }.filter { $0 >= 40 }.sorted()
        guard !areas.isEmpty else { return nil }
        let median = areas[areas.count / 2]
        let similar = areas.filter { Double($0) >= 0.3 * Double(median) && Double($0) <= 3.0 * Double(median) }
        // most blobs must be of the same kind, otherwise this is not a row of equal objects
        guard Double(similar.count) >= 0.8 * Double(areas.count) else { return nil }
        return similar.count
    }
}
