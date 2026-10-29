import Foundation

/// Decides how a task is played from the words of its header and the shapes found in it (PP-013).
public enum TaskTypeClassifier {
    /// Shapes the importer found inside the task area.
    public struct Shapes: Equatable, Sendable {
        public var emptyCircles: Int
        public var answerBars: Int
        public var tickCircles: Int
        public init(emptyCircles: Int = 0, answerBars: Int = 0, tickCircles: Int = 0) {
            self.emptyCircles = emptyCircles
            self.answerBars = answerBars
            self.tickCircles = tickCircles
        }
    }

    private static let rules: [(TaskKind, [String])] = [
        (.crossword, ["crossword", "kreuzworträtsel", "kreuzwortraetsel", "kreuzwort"]),
        (.wordSearch, ["word search", "wordsearch", "wortsuche", "buchstabengitter", "find the words", "finde die wörter", "suche die wörter"]),
        (.matching, ["draw lines", "draw a line", "match", "join", "connect", "verbinde", "ordne zu", "zeichne linien"]),
        (.trueFalse, ["tick", "true or false", "correct or wrong", "richtig oder falsch", "kreuze an"]),
        (.multipleChoice, ["read and choose", "choose", "wähle", "waehle", "lies und wähle", "kreuze die richtige",
                           "circle the correct", "circle the right", "kreise das richtige", "kreise die richtige"]),
        // numbering and writing come before the open-task words: "Read, say and number the pictures" is numbering
        (.numberInOrder, ["number the", "number and", "put in order", "in order", "nummeriere", "reihenfolge"]),
        (.fillIn, ["write", "fill in", "complete", "schreibe", "ergänze", "setze ein"]),
        (.openTask, ["colour", "color", "draw", "sing", "say", "speak", "male", "zeichne", "sprich", "singe"])
    ]

    /// Colouring and drawing verbs: circles in such a task are part of the picture, not answer circles.
    private static let colouringWords: Set<String> = ["colour", "color", "draw", "male", "zeichne"]

    /// Kinds that only the words can tell; shapes never override them.
    private static let structural: Set<TaskKind> = [.crossword, .wordSearch, .matching, .multipleChoice]

    /// The header in lower case, split into words.
    private static func words(_ header: String) -> [String] {
        header.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    }

    /// Kind suggested by the header words alone, or `nil` when no rule fits. Whole words only ("stick" is not "tick").
    /// A plain "Circle ..." has no rule yet: circling gets its own kind with PP-022.
    public static func kind(forHeader header: String) -> TaskKind? {
        let tokens = Self.words(header)
        let padded = " " + tokens.joined(separator: " ") + " "
        for (kind, phrases) in rules {
            for phrase in phrases where padded.contains(" " + phrase + " ") { return kind }
        }
        return nil
    }

    /// Final kind: structural words win, then tick circles, then the writing or numbering words together with the
    /// shapes; unknown tasks become open tasks. With a colouring or drawing verb, empty circles are part of the
    /// picture and are ignored, unless the header asks for numbering.
    public static func classify(header: String, shapes: Shapes = Shapes()) -> TaskKind {
        let byWords = kind(forHeader: header)
        if let k = byWords, structural.contains(k) { return k }
        if shapes.tickCircles >= 2 { return .trueFalse }
        let colouring = Self.words(header).contains { colouringWords.contains($0) }
        let circles = colouring && byWords != .numberInOrder ? 0 : shapes.emptyCircles
        switch byWords {
        case .fillIn?:
            if shapes.answerBars >= 1 { return .fillIn }
            if circles >= 1 { return .numberInOrder }
            return colouring ? .openTask : .fillIn
        case .numberInOrder?:
            if circles >= 1 { return .numberInOrder }
            if shapes.answerBars >= 1 { return .fillIn }
            return .numberInOrder
        default:
            if circles >= 1 { return .numberInOrder }
            if shapes.answerBars >= 1 { return .fillIn }
            return byWords ?? .openTask
        }
    }
}
