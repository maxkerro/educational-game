import Foundation

// MARK: - PP-046 Pal and stars

public enum PalStage: Int, Codable, CaseIterable, Sendable {
    case little = 0, growing, big
}

/// Stars earned per task. A task counts once, with its best result, so stars cannot be farmed.
public struct StarLedger: Codable, Equatable, Sendable {
    public private(set) var best: [String: Int]

    public init(best: [String: Int] = [:]) {
        self.best = best.mapValues { min(3, max(0, $0)) }
    }

    /// Stars needed for each stage, in the order of `PalStage`.
    public static let stageStars = [0, 15, 45]

    public var total: Int { best.values.reduce(0, +) }

    public var stage: PalStage {
        var reached = PalStage.little
        for s in PalStage.allCases where total >= Self.stageStars[s.rawValue] { reached = s }
        return reached
    }

    public var starsToNextStage: Int? {
        let next = stage.rawValue + 1
        guard next < Self.stageStars.count else { return nil }
        return Self.stageStars[next] - total
    }

    /// Stars for one task: 3 without wrong tries, 2 with one or two, 1 with more; 0 when not finished.
    public static func stars(complete: Bool, wrongTries: Int) -> Int {
        guard complete else { return 0 }
        if wrongTries <= 0 { return 3 }
        return wrongTries <= 2 ? 2 : 1
    }

    /// Records stars for a task and keeps the best. Returns the new stage when the Pal grows.
    @discardableResult
    public mutating func award(_ stars: Int, task id: String) -> PalStage? {
        let before = stage
        best[id] = max(best[id] ?? 0, min(3, max(0, stars)))
        return stage.rawValue > before.rawValue ? stage : nil
    }
}

// MARK: - PP-047 World map

public enum WorldMap {
    public struct Chapter: Equatable, Sendable {
        public var name: String
        public var pageIds: [String]
        public init(name: String, pageIds: [String]) {
            self.name = name
            self.pageIds = pageIds
        }
    }

    public struct Stop: Equatable, Sendable {
        public var pageId: String
        public var done: Bool
    }

    public struct Island: Equatable, Sendable {
        public var name: String
        public var stops: [Stop]
        public var unlocked: Bool
        public var doneCount: Int { stops.filter { $0.done }.count }
        public var isDone: Bool { !stops.isEmpty && doneCount == stops.count }
    }

    /// Chapters become islands and pages become stops. Calm unlocking: the first island is open, and the next one opens
    /// when half of the stops of the island before are done, so a child is never stuck on one hard page.
    public static func islands(_ chapters: [Chapter], finished: Set<String>) -> [Island] {
        var result: [Island] = []
        for (index, chapter) in chapters.enumerated() {
            let stops = chapter.pageIds.map { Stop(pageId: $0, done: finished.contains($0)) }
            var open = true
            if index > 0 {
                let before = result[index - 1]
                open = before.unlocked && (before.stops.isEmpty || before.doneCount * 2 >= before.stops.count)
            }
            result.append(Island(name: chapter.name, stops: stops, unlocked: open))
        }
        return result
    }
}

// MARK: - PP-048 Gentle streak

/// Days on which the child played. Greetings only cheer; they never mention missed days.
public struct VisitLog: Codable, Equatable, Sendable {
    public private(set) var days: Set<Int>

    public init(days: Set<Int> = []) { self.days = days }

    /// Local calendar day number, for `visit(day:)`.
    public static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }

    public func run(endingAt day: Int) -> Int {
        var n = 0
        while days.contains(day - n) { n += 1 }
        return n
    }

    public mutating func visit(day: Int) -> String {
        let first = days.isEmpty
        let cameBack = !first && !days.contains(day) && !days.contains(day - 1)
        days.insert(day)
        if first { return "Hello! Let's play." }
        if cameBack { return "Welcome back! Nice to see you." }
        let n = run(endingAt: day)
        return n >= 2 ? "\(n) days in a row. Great!" : "Hello again!"
    }
}

// MARK: - PP-049 Pal reacts

public enum PalMood: String, Codable, Sendable {
    case happy, cheer, comfort, nap
}

public enum PalReaction {
    /// Seconds without any action before the Pal takes a nap.
    public static let napAfter: Double = 120

    public static func mood(lastAnswerCorrect: Bool?, secondsIdle: Double) -> PalMood {
        if secondsIdle >= napAfter { return .nap }
        switch lastAnswerCorrect {
        case true?: return .cheer
        case false?: return .comfort
        case nil: return .happy
        }
    }

    /// What the Pal says. Comfort never blames the child.
    public static func line(_ mood: PalMood, language: BookLanguage) -> String {
        switch (mood, language) {
        case (.happy, .english): return "Let's go!"
        case (.cheer, .english): return "Yes! Well done!"
        case (.comfort, .english): return "Not yet. Try again, you can do it."
        case (.nap, .english): return "Zzz… tap me when you are back."
        case (.happy, .german): return "Los geht's!"
        case (.cheer, .german): return "Ja! Super gemacht!"
        case (.comfort, .german): return "Noch nicht. Versuch es noch einmal, du schaffst das."
        case (.nap, .german): return "Zzz… tipp mich an, wenn du wieder da bist."
        case (.happy, .russian): return "Поехали!"
        case (.cheer, .russian): return "Да! Молодец!"
        case (.comfort, .russian): return "Пока нет. Попробуй ещё раз, у тебя получится."
        case (.nap, .russian): return "Хрр… нажми на меня, когда вернёшься."
        }
    }
}

// MARK: - PP-050 Sounds

public struct SoundSettings: Codable, Equatable, Sendable {
    public enum Kind: Sendable { case effect, music, speech }

    public var muted: Bool
    public var volume: Double
    public var effects: Bool
    public var music: Bool

    /// Music is off by default so the app stays calm.
    public init(muted: Bool = false, volume: Double = 0.6, effects: Bool = true, music: Bool = false) {
        self.muted = muted
        self.volume = volume
        self.effects = effects
        self.music = music
    }

    public func volume(for kind: Kind) -> Double {
        if muted { return 0 }
        let v = min(1, max(0, volume))
        switch kind {
        case .effect: return effects ? v : 0
        case .music: return music ? v * 0.5 : 0
        case .speech: return v
        }
    }
}

// MARK: - PP-051 Room

public struct Collectible: Equatable, Sendable {
    public var id: String
    public var name: String
    public var starsNeeded: Int
    public init(id: String, name: String, starsNeeded: Int) {
        self.id = id
        self.name = name
        self.starsNeeded = starsNeeded
    }
}

/// The child's room. Things are earned with stars and never bought; stars are not spent.
public struct Room: Codable, Equatable, Sendable {
    public struct Spot: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public static let catalog: [Collectible] = [
        Collectible(id: "plant", name: "Plant", starsNeeded: 5),
        Collectible(id: "lamp", name: "Lamp", starsNeeded: 12),
        Collectible(id: "rug", name: "Rug", starsNeeded: 20),
        Collectible(id: "bookshelf", name: "Bookshelf", starsNeeded: 30),
        Collectible(id: "telescope", name: "Telescope", starsNeeded: 45),
        Collectible(id: "rocket", name: "Toy rocket", starsNeeded: 60)
    ]

    public private(set) var placed: [String: Spot]

    public init(placed: [String: Spot] = [:]) { self.placed = placed }

    public static func earned(totalStars: Int, catalog: [Collectible] = Room.catalog) -> [Collectible] {
        catalog.filter { totalStars >= $0.starsNeeded }
    }

    /// Places an earned thing inside the room (0...1); things not earned yet cannot be placed.
    @discardableResult
    public mutating func place(_ id: String, x: Double, y: Double, totalStars: Int, catalog: [Collectible] = Room.catalog) -> Bool {
        guard Room.earned(totalStars: totalStars, catalog: catalog).contains(where: { $0.id == id }) else { return false }
        placed[id] = Spot(x: min(1, max(0, x)), y: min(1, max(0, y)))
        return true
    }

    public mutating func remove(_ id: String) { placed[id] = nil }
}
