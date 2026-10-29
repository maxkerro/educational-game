import Foundation

/// The folder name of an imported book in the library (PP-004). The name of the file alone is not enough:
/// two different workbooks are often both called "Activity Book.pdf". The id also holds a short fingerprint
/// of the file, so a second book never shares a folder (or a half-finished import) with the first.
public enum BookID {
    /// Letters, digits and dashes of the file name, then the fingerprint. Safe as a file name.
    public static func make(fileName: String, fingerprint: UInt64) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let cleaned = String(stem.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let hex = String(fingerprint, radix: 16)
        let tail = String(repeating: "0", count: max(0, 16 - hex.count)) + hex
        let name = cleaned.isEmpty ? "book" : String(cleaned.prefix(60))
        return name + "-" + tail.suffix(10)
    }

    /// What the grown-up sees in the library: the file name without ".pdf".
    public static func title(fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return stem.isEmpty ? "Book" : stem
    }

    /// FNV-1a over some bytes; the app feeds it the start, the end and the size of the file.
    public static func fingerprint(_ parts: [Data]) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for part in parts {
            for byte in part {
                h ^= UInt64(byte)
                h = h &* 0x100000001b3
            }
            h ^= 0xff
            h = h &* 0x100000001b3
        }
        return h
    }
}
