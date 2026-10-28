import Foundation

/// A rectangle in normalised page coordinates (0...1, origin top-left).
public struct PageRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// The interactive form a book task is rebuilt as.
public enum TaskKind: String, Codable, Sendable, CaseIterable {
    case fillIn          // write text into blanks
    case trueFalse       // tick correct / wrong
    case numberInOrder   // number pictures or sentences
    case matching        // draw lines between pairs
    case crossword       // grid with picture clues
    case wordSearch      // find the words in a letter grid, then fill in
    case multipleChoice  // read and choose one
    case openTask        // fallback: parent confirms
}

/// One answerable element inside a task (a blank, a statement, a picture, ...).
public struct TaskItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String?
    public var region: PageRect?
    /// Picture cut out of the book page for this item (file name inside the pack). Shown as in the book.
    public var imageFile: String?
    /// Tick tasks: `region` is the "correct" circle of a row and this is its "wrong" circle.
    public var secondRegion: PageRect?

    public init(id: String, label: String? = nil, region: PageRect? = nil, imageFile: String? = nil, secondRegion: PageRect? = nil) {
        self.secondRegion = secondRegion
        self.id = id
        self.label = label
        self.region = region
        self.imageFile = imageFile
    }
}

/// Expected answers, keyed by item id. Only the dictionaries relevant to the task kind are used.
public struct AnswerKey: Codable, Equatable, Sendable {
    public var text: [String: String]
    public var booleans: [String: Bool]
    public var order: [String: Int]
    public var pairs: [String: String]   // item id -> target item id
    public var choice: String?           // chosen item id for multipleChoice

    public init(
        text: [String: String] = [:],
        booleans: [String: Bool] = [:],
        order: [String: Int] = [:],
        pairs: [String: String] = [:],
        choice: String? = nil
    ) {
        self.text = text
        self.booleans = booleans
        self.order = order
        self.pairs = pairs
        self.choice = choice
    }
}

/// The child's answers; same shape as the key.
public typealias TaskResponse = AnswerKey

/// Where a task's answer key came from.
public enum KeySource: String, Codable, Sendable {
    case calculated   // worked out from the page text, e.g. "three + one ="
    case parent       // typed in by a grown-up
    case answerPage   // read from the answer key printed in the book
    case model        // found by an on-device model
}

public struct PlayTask: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: TaskKind
    public var prompt: String
    public var region: PageRect?
    public var items: [TaskItem]
    /// `nil` means the key is unknown (task must be confirmed by a parent).
    public var key: AnswerKey?
    /// Import confidence 0...1; low values go to the parent review queue.
    public var confidence: Double
    /// How `key` was found; `nil` when there is no key.
    public var keySource: KeySource?

    public init(
        id: String,
        kind: TaskKind,
        prompt: String,
        region: PageRect? = nil,
        items: [TaskItem] = [],
        key: AnswerKey? = nil,
        confidence: Double = 1.0,
        keySource: KeySource? = nil
    ) {
        self.keySource = keySource
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.region = region
        self.items = items
        self.key = key
        self.confidence = confidence
    }
}

public struct BookPage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var number: Int
    public var imageFile: String
    public var tasks: [PlayTask]

    public init(id: String, number: Int, imageFile: String, tasks: [PlayTask] = []) {
        self.id = id
        self.number = number
        self.imageFile = imageFile
        self.tasks = tasks
    }
}

public struct LessonPack: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var title: String
    public var language: String
    public var pages: [BookPage]

    public init(
        version: Int = LessonPack.currentVersion,
        title: String,
        language: String,
        pages: [BookPage] = []
    ) {
        self.version = version
        self.title = title
        self.language = language
        self.pages = pages
    }
}
