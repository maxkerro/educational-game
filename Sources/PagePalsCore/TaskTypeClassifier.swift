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
        (.multipleChoice, ["read and choose", "choose", "wähle", "waehle", "lies und wähle", "kreuze die richtige"]),
        (.openTask, ["colour", "color", "draw", "sing", "say", "speak", "male", "zeichne", "sprich", "singe"]),
        (.numberInOrder, ["number the", "put in order", "in order", "nummeriere", "reihenfolge"]),
        (.fillIn, ["write", "fill in", "complete", "schreibe", "ergänze", "setze ein"])
    ]

    /// Kinds that only the words can tell; shapes never override them.
    private static let structural: Set<TaskKind> = [.crossword, .wordSearch, .matching, .multipleChoice]

    /// Kind suggested by the header words alone, or `nil` when no rule fits. Whole words only ("stick" is not "tick").
    public static func kind(forHeader header: String) -> TaskKind? {
        let words = header.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        let padded = " " + words.joined(separator: " ") + " "
        for (kind, phrases) in rules {
            for phrase in phrases where padded.contains(" " + phrase + " ") { return kind }
        }
        return nil
    }

    /// Final kind: structural words win, then shapes, then the other words; unknown tasks become open tasks.
    public static func classify(header: String, shapes: Shapes = Shapes()) -> TaskKind {
        let byWords = kind(forHeader: header)
        if let k = byWords, structural.contains(k) { return k }
        // "Colour the balloons": circles in a colouring picture are not answer circles
        if byWords == .openTask && shapes.tickCircles < 2 && shapes.answerBars == 0 { return .openTask }
        if shapes.tickCircles >= 2 { return .trueFalse }
        if shapes.emptyCircles >= 1 { return .numberInOrder }
        if shapes.answerBars >= 1 { return .fillIn }
        return byWords ?? .openTask
    }
}
