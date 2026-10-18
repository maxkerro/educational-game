import XCTest
@testable import PagePalsCore

final class TaskEvaluatorTests: XCTestCase {

    private func fillInTask() -> PlayTask {
        PlayTask(
            id: "t1",
            kind: .fillIn,
            prompt: "How much is it? Write.",
            items: [TaskItem(id: "a"), TaskItem(id: "b")],
            key: AnswerKey(text: ["a": "four", "b": "seven"])
        )
    }

    func testAllCorrectIsComplete() {
        let r = TaskEvaluator.evaluate(task: fillInTask(), response: AnswerKey(text: ["a": " Four ", "b": "SEVEN"]))
        XCTAssertTrue(r.isComplete)
        XCTAssertEqual(r.correct, ["a", "b"])
    }

    func testWrongAndMissingAreReportedSeparately() {
        let r = TaskEvaluator.evaluate(task: fillInTask(), response: AnswerKey(text: ["a": "five"]))
        XCTAssertFalse(r.isComplete)
        XCTAssertEqual(r.incorrect, ["a"])
        XCTAssertEqual(r.missing, ["b"])
    }

    func testDiacriticsAndCaseAreIgnored() {
        XCTAssertEqual(TaskEvaluator.normalize("  Café  Au   Lait "), "cafe au lait")
    }

    func testTrueFalse() {
        let task = PlayTask(
            id: "t2",
            kind: .trueFalse,
            prompt: "Correct or wrong? Tick.",
            items: [TaskItem(id: "s1"), TaskItem(id: "s2")],
            key: AnswerKey(booleans: ["s1": true, "s2": false])
        )
        let r = TaskEvaluator.evaluate(task: task, response: AnswerKey(booleans: ["s1": true, "s2": true]))
        XCTAssertEqual(r.correct, ["s1"])
        XCTAssertEqual(r.incorrect, ["s2"])
        XCTAssertFalse(r.isComplete)
    }

    func testMatchingPairs() {
        let task = PlayTask(
            id: "t3",
            kind: .matching,
            prompt: "Draw lines.",
            key: AnswerKey(pairs: ["word1": "pic1", "word2": "pic2"])
        )
        let r = TaskEvaluator.evaluate(task: task, response: AnswerKey(pairs: ["word1": "pic1", "word2": "pic2"]))
        XCTAssertTrue(r.isComplete)
    }

    func testTaskWithoutKeyNeedsParentCheck() {
        let task = PlayTask(id: "t4", kind: .openTask, prompt: "Draw a picture.")
        let r = TaskEvaluator.evaluate(task: task, response: AnswerKey())
        XCTAssertTrue(r.needsParentCheck)
        XCTAssertFalse(r.isComplete)
    }

    func testLessonPackRoundTripsThroughJSON() throws {
        let pack = LessonPack(
            title: "Sample",
            language: "en",
            pages: [BookPage(id: "p1", number: 10, imageFile: "p10.png", tasks: [fillInTask()])]
        )
        let data = try JSONEncoder().encode(pack)
        let decoded = try JSONDecoder().decode(LessonPack.self, from: data)
        XCTAssertEqual(decoded, pack)
    }
}
