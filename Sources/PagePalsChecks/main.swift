import Foundation
import PagePalsCore

// A tiny test runner that needs no XCTest. Run with: swift run PagePalsChecks

var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("PASS  \(name)")
    } else {
        print("FAIL  \(name)")
        failures += 1
    }
}

func fillInTask() -> PlayTask {
    PlayTask(
        id: "t1",
        kind: .fillIn,
        prompt: "How much is it? Write.",
        items: [TaskItem(id: "a"), TaskItem(id: "b")],
        key: AnswerKey(text: ["a": "four", "b": "seven"])
    )
}

// All correct answers complete the task, ignoring case and spaces
do {
    let r = TaskEvaluator.evaluate(task: fillInTask(), response: AnswerKey(text: ["a": " Four ", "b": "SEVEN"]))
    check(r.isComplete, "fill-in: all correct is complete")
    check(r.correct == ["a", "b"], "fill-in: both items correct")
}

// Wrong and missing are reported separately
do {
    let r = TaskEvaluator.evaluate(task: fillInTask(), response: AnswerKey(text: ["a": "five"]))
    check(!r.isComplete, "fill-in: wrong answer is not complete")
    check(r.incorrect == ["a"], "fill-in: wrong item reported")
    check(r.missing == ["b"], "fill-in: unanswered item reported as missing")
}

// Text normalisation
check(TaskEvaluator.normalize("  Café  Au   Lait ") == "cafe au lait", "normalize: case, diacritics, spaces")

// True / false
do {
    let task = PlayTask(
        id: "t2",
        kind: .trueFalse,
        prompt: "Correct or wrong? Tick.",
        items: [TaskItem(id: "s1"), TaskItem(id: "s2")],
        key: AnswerKey(booleans: ["s1": true, "s2": false])
    )
    let r = TaskEvaluator.evaluate(task: task, response: AnswerKey(booleans: ["s1": true, "s2": true]))
    check(r.correct == ["s1"], "true/false: correct item")
    check(r.incorrect == ["s2"], "true/false: incorrect item")
    check(!r.isComplete, "true/false: not complete with a mistake")
}

// Matching
do {
    let task = PlayTask(
        id: "t3",
        kind: .matching,
        prompt: "Draw lines.",
        key: AnswerKey(pairs: ["word1": "pic1", "word2": "pic2"])
    )
    let r = TaskEvaluator.evaluate(task: task, response: AnswerKey(pairs: ["word1": "pic1", "word2": "pic2"]))
    check(r.isComplete, "matching: all pairs correct is complete")
}

// Task without a key needs a parent
do {
    let task = PlayTask(id: "t4", kind: .openTask, prompt: "Draw a picture.")
    let r = TaskEvaluator.evaluate(task: task, response: AnswerKey())
    check(r.needsParentCheck, "open task: needs parent check")
    check(!r.isComplete, "open task: never auto-complete")
}

// Lesson pack JSON round trip
do {
    let pack = LessonPack(
        title: "Sample",
        language: "en",
        pages: [BookPage(id: "p1", number: 10, imageFile: "p10.png", tasks: [fillInTask()])]
    )
    do {
        let data = try JSONEncoder().encode(pack)
        let decoded = try JSONDecoder().decode(LessonPack.self, from: data)
        check(decoded == pack, "lesson pack: JSON round trip")
    } catch {
        print("FAIL  lesson pack: JSON round trip threw \(error)")
        failures += 1
    }
}

// Task grouping: one header + nine empty circles = one "numbers into circles" task
do {
    let lines = [
        PageText(text: "1. Number.", box: PageRect(x: 0.03, y: 0.01, width: 0.12, height: 0.04)),
        PageText(text: "schoolbag", box: PageRect(x: 0.65, y: 0.14, width: 0.1, height: 0.03)),
        PageText(text: "2. Write.", box: PageRect(x: 0.03, y: 0.80, width: 0.1, height: 0.04))
    ]
    check(TaskBuilder.headerParts("1. Number.")?.number == 1, "header: number and dot")
    check(TaskBuilder.headerParts("schoolbag") == nil, "header: plain word is not a header")
    check(TaskBuilder.headerParts("3) Read and write.")?.title == "Read and write.", "header: bracket form")
    check(TaskBuilder.zones(from: lines).count == 2, "zones: one per header")

    let circles = (0..<9).map { PageRect(x: 0.1 + Double($0) * 0.05, y: 0.2 + Double($0 % 3) * 0.1, width: 0.04, height: 0.06) }
    let tasks = TaskBuilder.buildTasks(lines: lines, emptyCircles: circles, idPrefix: "p1")
    check(tasks.count == 2, "tasks: two zones give two tasks")
    check(tasks[0].kind == .numberInOrder && tasks[0].items.count == 9, "tasks: nine circles form one number task")
    check(tasks[1].kind == .openTask, "tasks: zone without circles is an open task")

    var task = tasks[0]
    task.key = AnswerKey(order: Dictionary(uniqueKeysWithValues: task.items.enumerated().map { ($0.element.id, $0.offset + 1) }))
    let right = AnswerKey(order: Dictionary(uniqueKeysWithValues: task.items.enumerated().map { ($0.element.id, $0.offset + 1) }))
    check(TaskEvaluator.evaluate(task: task, response: right).isComplete, "number task: correct numbers complete it")
    var wrong = right
    wrong.order[task.items[0].id] = 7
    check(TaskEvaluator.evaluate(task: task, response: wrong).incorrect == [task.items[0].id], "number task: wrong number flagged")

    let noHeader = TaskBuilder.buildTasks(lines: [], emptyCircles: circles, idPrefix: "p2")
    check(noHeader.count == 1 && noHeader[0].kind == .numberInOrder, "tasks: page without header still gives a task")
}

// Tick tasks are not number tasks
do {
    let lines = [PageText(text: "6. Correct or wrong? Tick.", box: PageRect(x: 0.05, y: 0.1, width: 0.3, height: 0.03))]
    let circles = (0..<4).map { PageRect(x: 0.3, y: 0.3 + Double($0) * 0.1, width: 0.03, height: 0.04) }
    let tasks = TaskBuilder.buildTasks(lines: lines, emptyCircles: circles, idPrefix: "p1")
    check(tasks.count == 1 && tasks[0].kind == .openTask, "tick task: not treated as number circles")
}

// Spreads and longer headers
do {
    check(TaskBuilder.headerParts("4. How many lollies? Trace the lines and write.")?.number == 4, "header: long instruction")
    check(TaskBuilder.headerParts("/ 2. Count and write.")?.number == 2, "header: stray icon characters in front")
    let lines = [
        PageText(text: "1. Write the numbers in the correct order.", box: PageRect(x: 0.08, y: 0.20, width: 0.3, height: 0.03)),
        PageText(text: "2. Count and write.", box: PageRect(x: 0.08, y: 0.52, width: 0.15, height: 0.03)),
        PageText(text: "3. Do you know the word? Write.", box: PageRect(x: 0.56, y: 0.19, width: 0.25, height: 0.03)),
        PageText(text: "4. How many lollies? Trace the lines and write.", box: PageRect(x: 0.56, y: 0.43, width: 0.3, height: 0.03))
    ]
    let zones = TaskBuilder.zones(from: lines, pageAspect: 1.4)
    check(zones.count == 4, "spread: four tasks over two pages")
    check(zones.filter { $0.box.x >= 0.5 }.count == 2, "spread: two tasks on the right page")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
