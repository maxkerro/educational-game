import Foundation

/// Words, sentences or pictures the child drags into order (PP-025).
public struct OrderingBoard: Equatable, Sendable {
    public private(set) var itemIds: [String]

    public init(itemIds: [String]) { self.itemIds = itemIds }

    /// Starts with the solution turned by one place, so a board with two or more different items is never solved at the start.
    public static func start(solution: [String]) -> OrderingBoard {
        guard solution.count > 1 else { return OrderingBoard(itemIds: solution) }
        return OrderingBoard(itemIds: Array(solution.dropFirst()) + [solution[0]])
    }

    /// Moves one item to a new place; other items keep their order. Out-of-range indexes do nothing.
    public mutating func move(from: Int, to: Int) {
        guard itemIds.indices.contains(from), itemIds.indices.contains(to), from != to else { return }
        let id = itemIds.remove(at: from)
        itemIds.insert(id, at: to)
    }

    /// Positions counted from 1, the same shape as `AnswerKey.order`.
    public func response() -> TaskResponse {
        var order: [String: Int] = [:]
        for (index, id) in itemIds.enumerated() { order[id] = index + 1 }
        return AnswerKey(order: order)
    }

    /// The key for a task whose items are listed in the right order.
    public static func key(solution: [String]) -> AnswerKey {
        var order: [String: Int] = [:]
        for (index, id) in solution.enumerated() { order[id] = index + 1 }
        return AnswerKey(order: order)
    }
}
