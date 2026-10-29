import Foundation

/// Words, sentences or pictures the child drags into order (PP-025).
public struct OrderingBoard: Equatable, Sendable {
    public private(set) var itemIds: [String]

    public init(itemIds: [String]) { self.itemIds = itemIds }

    /// Starts shuffled (the same seed gives the same board). A board with two or more different items is
    /// never solved at the start: a shuffle that hits the solution is turned by one place.
    public static func start(solution: [String], seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> OrderingBoard {
        guard solution.count > 1 else { return OrderingBoard(itemIds: solution) }
        var ids = solution
        var x = seed
        for i in stride(from: ids.count - 1, to: 0, by: -1) {
            x = x &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((x >> 33) % UInt64(i + 1))
            ids.swapAt(i, j)
        }
        if ids == solution { ids = Array(ids.dropFirst()) + [ids[0]] }
        return OrderingBoard(itemIds: ids)
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
