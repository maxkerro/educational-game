import Foundation

/// The text of one imported page kept next to its picture, so the answer key can be matched again after an
/// interrupted import without reading the page a second time (PP-005).
public struct StoredPageText: Codable, Equatable, Sendable {
    public struct Line: Codable, Equatable, Sendable {
        public var text: String
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    public var aspect: Double
    public var lines: [Line]

    public init(texts: [PageText], aspect: Double) {
        self.aspect = aspect
        self.lines = texts.map { Line(text: $0.text, x: $0.box.x, y: $0.box.y, width: $0.box.width, height: $0.box.height) }
    }

    public var texts: [PageText] {
        lines.map { PageText(text: $0.text, box: PageRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)) }
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> StoredPageText? { try? JSONDecoder().decode(StoredPageText.self, from: data) }
}
