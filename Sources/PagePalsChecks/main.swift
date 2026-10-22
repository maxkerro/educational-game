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

// Sums: answers are calculated, "4" and "four" both count
do {
    check(NumberWords.answer(forSum: "three + one =") == "four", "sums: words")
    check(NumberWords.answer(forSum: "ten \u{2013} seven =") == "three", "sums: en dash minus")
    check(NumberWords.answer(forSum: "10 - 4 =") == "6", "sums: digits")
    check(NumberWords.answer(forSum: "How much is it? Write.") == nil, "sums: sentence is not a sum")
    check(NumberWords.answer(forSum: "two - five =") == nil, "sums: negative result is rejected")
    check(TaskEvaluator.sameText("4", "four"), "text: digit equals word")
    check(TaskEvaluator.sameText("vier", "four"), "text: German word equals English word")
    check(!TaskEvaluator.sameText("5", "four"), "text: wrong number differs")

    let lines = [
        PageText(text: "5. How much is it? Write.", box: PageRect(x: 0.04, y: 0.12, width: 0.25, height: 0.03)),
        PageText(text: "three + one =", box: PageRect(x: 0.05, y: 0.20, width: 0.08, height: 0.03)),
        PageText(text: "two + five =", box: PageRect(x: 0.05, y: 0.26, width: 0.08, height: 0.03)),
        PageText(text: "ten \u{2013} seven =", box: PageRect(x: 0.20, y: 0.20, width: 0.08, height: 0.03))
    ]
    let bars = [
        PageRect(x: 0.15, y: 0.205, width: 0.07, height: 0.012),
        PageRect(x: 0.15, y: 0.265, width: 0.07, height: 0.012),
        PageRect(x: 0.30, y: 0.205, width: 0.07, height: 0.012)
    ]
    let tasks = TaskBuilder.buildTasks(lines: lines, emptyCircles: [], blanks: bars, idPrefix: "p1", pageAspect: 1.4)
    check(tasks.first?.kind == .fillIn && tasks.first?.items.count == 3, "sums task: three sums with bars become a fill-in task")
    if let task = tasks.first {
        let answers = Dictionary(uniqueKeysWithValues: task.items.map { ($0.id, $0.label ?? "") })
        let right = AnswerKey(text: answers.mapValues { NumberWords.answer(forSum: $0) ?? "" })
        check(TaskEvaluator.evaluate(task: task, response: right).isComplete, "sums task: calculated answers complete it")
    }
}

// Answer bars without sums: a write-the-answer task with an unknown key
do {
    let lines = [
        PageText(text: "4. How many lollies? Trace the lines and write.", box: PageRect(x: 0.05, y: 0.05, width: 0.5, height: 0.03)),
        PageText(text: "lollies", box: PageRect(x: 0.40, y: 0.80, width: 0.06, height: 0.03))
    ]
    let bars = [
        PageRect(x: 0.15, y: 0.80, width: 0.25, height: 0.02),
        PageRect(x: 0.15, y: 0.90, width: 0.25, height: 0.02)
    ]
    let tasks = TaskBuilder.buildTasks(lines: lines, emptyCircles: [], blanks: bars, idPrefix: "p1")
    check(tasks.count == 1 && tasks[0].kind == .fillIn && tasks[0].items.count == 2, "answer bars: fill-in task")
    check(tasks.first?.key == nil, "answer bars: key is not known")
    check(tasks.first?.items.first?.label == "lollies", "answer bars: word right of the bar is the label")
}


// Tick task: two columns of grey circles, header words decide which column is "correct"
do {
    let lines = [
        PageText(text: "6. Correct or wrong? Tick.", box: PageRect(x: 0.05, y: 0.45, width: 0.2, height: 0.03)),
        PageText(text: "correct", box: PageRect(x: 0.33, y: 0.70, width: 0.04, height: 0.02)),
        PageText(text: "wrong", box: PageRect(x: 0.38, y: 0.70, width: 0.03, height: 0.02)),
        PageText(text: "There are two", box: PageRect(x: 0.20, y: 0.80, width: 0.08, height: 0.02)),
        PageText(text: "There is one", box: PageRect(x: 0.20, y: 0.85, width: 0.07, height: 0.02))
    ]
    func circle(_ x: Double, _ y: Double) -> PageRect { PageRect(x: x, y: y, width: 0.012, height: 0.017) }
    let ticks = [circle(0.34, 0.80), circle(0.34, 0.85), circle(0.39, 0.80), circle(0.39, 0.85)]
    let tasks = TaskBuilder.buildTasks(lines: lines, emptyCircles: [], tickCircles: ticks, idPrefix: "p2")
    check(tasks.count == 1 && tasks[0].kind == .trueFalse && tasks[0].items.count == 2, "tick task: two rows")
    if let task = tasks.first {
        check(task.items[0].label == "There are two", "tick task: sentence found left of the row")
        check(task.items[0].region?.x == 0.34 && task.items[0].secondRegion?.x == 0.39, "tick task: left column is correct")
        var withKey = task
        withKey.key = AnswerKey(booleans: [task.items[0].id: false, task.items[1].id: true])
        let r = TaskEvaluator.evaluate(task: withKey, response: AnswerKey(booleans: [task.items[0].id: false, task.items[1].id: false]))
        check(r.correct == [task.items[0].id] && r.incorrect == [task.items[1].id], "tick task: rows are judged separately")
    }
    let swapped = [circle(0.34, 0.80), circle(0.34, 0.85), circle(0.39, 0.80), circle(0.39, 0.85)]
    let flipped = [lines[0], PageText(text: "wrong", box: PageRect(x: 0.33, y: 0.70, width: 0.04, height: 0.02)),
                   PageText(text: "correct", box: PageRect(x: 0.38, y: 0.70, width: 0.04, height: 0.02)), lines[3], lines[4]]
    let other = TaskBuilder.buildTasks(lines: flipped, emptyCircles: [], tickCircles: swapped, idPrefix: "p2")
    check(other.first?.items.first?.region?.x == 0.39, "tick task: header 'correct' over the right column swaps the columns")

}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
