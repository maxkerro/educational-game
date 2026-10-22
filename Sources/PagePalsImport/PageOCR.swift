import Foundation
import Vision
import CoreGraphics
import PagePalsCore

/// One line of text found on a page, with its position in normalised page coordinates (origin top-left).
public struct RecognizedLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let box: PageRect
    public let confidence: Float
    /// Boxes of the single words (2+ characters) inside this line.
    public let words: [PageRect]

    public init(text: String, box: PageRect, confidence: Float, words: [PageRect] = []) {
        self.id = UUID()
        self.text = text
        self.box = box
        self.confidence = confidence
        self.words = words
    }
}

public enum PageOCR {
    /// Reads text from a page bitmap with Apple's Vision framework (on-device).
    /// Vision reports boxes with a bottom-left origin; they are converted to top-left here.
    public static func recognize(
        _ image: CGImage,
        languages: [String] = ["en-US", "de-DE"]
    ) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        var lines: [RecognizedLine] = []
        for observation in observations {
            guard let best = observation.topCandidates(1).first else { continue }
            let b = observation.boundingBox
            let box = PageRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)

            var wordBoxes: [PageRect] = []
            let s = best.string
            s.enumerateSubstrings(in: s.startIndex..<s.endIndex, options: .byWords) { substring, range, _, _ in
                guard let word = substring, word.count >= 2 else { return }
                if let found = try? best.boundingBox(for: range) {
                    let wb = found.boundingBox
                    wordBoxes.append(PageRect(x: wb.minX, y: 1 - wb.maxY, width: wb.width, height: wb.height))
                }
            }

            lines.append(RecognizedLine(text: s, box: box, confidence: best.confidence, words: wordBoxes))
        }
        // Reading order: top to bottom, then left to right.
        return lines.sorted {
            if abs($0.box.y - $1.box.y) > 0.01 { return $0.box.y < $1.box.y }
            return $0.box.x < $1.box.x
        }
    }
}
