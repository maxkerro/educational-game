import Foundation

// MARK: - PP-054 Review editor

/// Undo and redo for any value that is edited in steps.
public struct EditHistory<Value: Equatable>: Equatable {
    public private(set) var current: Value
    private var undoStack: [Value] = []
    private var redoStack: [Value] = []

    public init(_ value: Value) { current = value }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Applies a change; a change that changes nothing is not recorded.
    public mutating func apply(_ change: (inout Value) -> Void) {
        var next = current
        change(&next)
        guard next != current else { return }
        undoStack.append(current)
        current = next
        redoStack.removeAll()
    }

    public mutating func undo() {
        guard let before = undoStack.popLast() else { return }
        redoStack.append(current)
        current = before
    }

    public mutating func redo() {
        guard let after = redoStack.popLast() else { return }
        undoStack.append(current)
        current = after
    }
}

/// One correction a grown-up makes to a recognised task.
public enum TaskEdit: Equatable, Sendable {
    case moveItem(id: String, to: PageRect)
    case setKind(TaskKind)
    case setPrompt(String)
    case setAnswer(itemId: String, text: String)
    case assignPicture(itemId: String, imageFile: String?)

    public func apply(to task: inout PlayTask) {
        switch self {
        case let .moveItem(id, rect):
            if let i = task.items.firstIndex(where: { $0.id == id }) { task.items[i].region = rect }
        case let .setKind(kind):
            task.kind = kind
        case let .setPrompt(prompt):
            task.prompt = prompt
        case let .setAnswer(id, text):
            var key = task.key ?? AnswerKey()
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            key.text[id] = t.isEmpty ? nil : t
            if key.isEmpty {
                // clearing the last answer leaves no key, so the task goes back to the grown-up
                task.key = nil
                task.keySource = nil
                task.confirmed = nil
            } else {
                task.key = key
                task.keySource = .parent
                task.confidence = 1
            }
        case let .assignPicture(id, file):
            if let i = task.items.firstIndex(where: { $0.id == id }) { task.items[i].imageFile = file }
        }
    }
}

// MARK: - PP-055 Adult gate

/// A sum a young child cannot do in the head: a two-digit number times a one-digit number.
public struct AdultGate: Equatable, Sendable {
    public let question: String
    public let answer: Int

    public init(seed: UInt64) {
        var x = seed &* 6364136223846793005 &+ 1442695040888963407
        let a = Int((x >> 33) % 18) + 12
        x = x &* 6364136223846793005 &+ 1442695040888963407
        let b = Int((x >> 33) % 7) + 3
        question = "\(a) × \(b) = ?"
        answer = a * b
    }

    public func accepts(_ typed: String) -> Bool {
        Int(typed.trimmingCharacters(in: .whitespacesAndNewlines)) == answer
    }
}

/// Three wrong answers lock the gate for a minute.
public struct GateLock: Equatable, Sendable {
    public static let lockSeconds: Double = 60
    public private(set) var wrong = 0
    public private(set) var lockedUntil: Double?

    public init() {}

    public mutating func record(correct: Bool, now: Double) {
        if correct {
            wrong = 0
            lockedUntil = nil
        } else {
            wrong += 1
            if wrong >= 3 {
                lockedUntil = now + Self.lockSeconds
                wrong = 0
            }
        }
    }

    public func isLocked(now: Double) -> Bool { (lockedUntil ?? 0) > now }
}

// MARK: - PP-056 Progress

public struct Attempt: Codable, Equatable, Sendable {
    public var child: String
    public var book: String
    public var taskId: String
    public var itemId: String
    public var kind: TaskKind
    public var correct: Bool

    public init(child: String, book: String, taskId: String, itemId: String, kind: TaskKind, correct: Bool) {
        self.child = child
        self.book = book
        self.taskId = taskId
        self.itemId = itemId
        self.kind = kind
        self.correct = correct
    }
}

public struct Accuracy: Equatable, Sendable {
    public var right: Int
    public var total: Int
    public var share: Double { total == 0 ? 0 : Double(right) / Double(total) }
}

public enum ProgressReport {
    static func group<K: Hashable>(_ attempts: [Attempt], child: String, by key: (Attempt) -> K) -> [K: Accuracy] {
        var result: [K: Accuracy] = [:]
        for a in attempts where a.child == child {
            var acc = result[key(a)] ?? Accuracy(right: 0, total: 0)
            acc.total += 1
            if a.correct { acc.right += 1 }
            result[key(a)] = acc
        }
        return result
    }

    public static func byBook(_ attempts: [Attempt], child: String) -> [String: Accuracy] {
        group(attempts, child: child) { $0.book }
    }

    public static func byKind(_ attempts: [Attempt], child: String) -> [TaskKind: Accuracy] {
        group(attempts, child: child) { $0.kind }
    }

    /// Items tried at least `minimumTries` times and answered right less than half the time, hardest first.
    public static func hardItems(_ attempts: [Attempt], child: String, minimumTries: Int = 3, limit: Int = 10) -> [String] {
        let items = group(attempts, child: child) { "\($0.book)/\($0.taskId)/\($0.itemId)" }
        return items
            .filter { $0.value.total >= minimumTries && $0.value.share < 0.5 }
            .sorted { $0.value.share != $1.value.share ? $0.value.share < $1.value.share : $0.key < $1.key }
            .prefix(limit)
            .map { $0.key }
    }
}

// MARK: - PP-057 Daily time limit

public enum SessionPhase: Equatable, Sendable {
    case play, windDown, goodbye
}

public struct SessionLimit: Codable, Equatable, Sendable {
    /// `nil` or 0 means no limit.
    public var minutes: Int?
    public static let windDownMinutes = 2.0

    public init(minutes: Int? = nil) { self.minutes = minutes }

    /// The Pal starts saying goodbye shortly before the limit; a task that is in progress is always finished first.
    public func phase(elapsedMinutes: Double, inTask: Bool) -> SessionPhase {
        guard let m = minutes, m > 0 else { return .play }
        let limit = Double(m)
        if elapsedMinutes >= limit { return inTask ? .windDown : .goodbye }
        if elapsedMinutes >= limit - Self.windDownMinutes { return .windDown }
        return .play
    }
}

// MARK: - PP-058 Several children

public struct ChildProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

/// Local profiles on this Mac; no accounts.
public struct ProfileList: Codable, Equatable, Sendable {
    public private(set) var profiles: [ChildProfile] = []

    public init() {}

    static func clean(_ name: String) -> String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    func isTaken(_ name: String, except id: String? = nil) -> Bool {
        profiles.contains { $0.id != id && $0.name.lowercased() == name.lowercased() }
    }

    /// Adds a child; empty names and names already used (ignoring case) are refused.
    @discardableResult
    public mutating func add(name: String) -> ChildProfile? {
        let n = Self.clean(name)
        guard !n.isEmpty, !isTaken(n) else { return nil }
        let p = ChildProfile(name: n)
        profiles.append(p)
        return p
    }

    @discardableResult
    public mutating func rename(id: String, to name: String) -> Bool {
        let n = Self.clean(name)
        guard !n.isEmpty, !isTaken(n, except: id), let i = profiles.firstIndex(where: { $0.id == id }) else { return false }
        profiles[i].name = n
        return true
    }

    public mutating func remove(id: String) { profiles.removeAll { $0.id == id } }

    public func save(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    public static func load(from url: URL) -> ProfileList {
        guard let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode(ProfileList.self, from: data) else { return ProfileList() }
        return list
    }
}

// MARK: - PP-002 Recent books

public struct RecentBooks: Codable, Equatable, Sendable {
    public static let limit = 5
    public private(set) var paths: [String]

    public init(paths: [String] = []) { self.paths = Array(paths.prefix(Self.limit)) }

    public mutating func opened(_ path: String) {
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > Self.limit { paths.removeLast(paths.count - Self.limit) }
    }

    public mutating func forget(_ path: String) { paths.removeAll { $0 == path } }

    /// Only PDF files are opened when dropped on the window.
    public static func isPDF(_ name: String) -> Bool { name.lowercased().hasSuffix(".pdf") }
}

// MARK: - PP-028 Read aloud

public struct SpeechSettings: Codable, Equatable, Sendable {
    /// 0.5 slow ... 1.5 fast; 1 is normal speed.
    public var speed: Double

    public init(speed: Double = 0.9) { self.speed = speed }

    /// Voice language for the Mac's installed (offline) voices.
    public func voiceLanguage(for language: BookLanguage) -> String {
        switch language {
        case .english: return "en-GB"
        case .german: return "de-DE"
        case .russian: return "ru-RU"
        }
    }

    /// Rate for the system speech synthesiser (0...1, where 0.5 is its normal speed).
    public var utteranceRate: Float { Float(min(1.5, max(0.5, speed)) * 0.5) }
}
