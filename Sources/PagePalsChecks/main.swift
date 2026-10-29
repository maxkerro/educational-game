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
    // D2: every kind of maths line
    check(MathSolver.solve("6 x 7 =") == "42", "maths: times")
    check(MathSolver.solve("12 \u{00F7} 4 =") == "3", "maths: divide")
    check(MathSolver.solve("7 \u{00F7} 2 =") == nil, "maths: division with a remainder is rejected")
    check(MathSolver.solve("2 + 3 x 4 =") == "14", "maths: multiplication before addition")
    check(MathSolver.solve("3 + ___ = 7") == "4", "maths: missing second number")
    check(MathSolver.solve("___ - 2 = 5") == "7", "maths: missing first number")
    check(MathSolver.solve("8 = 5 + _") == "3", "maths: blank on the right side")
    check(MathSolver.solve("3 + 4 = ___") == "7", "maths: blank answer")
    check(MathSolver.solve("3 + 4 = 7") == nil, "maths: a finished statement has nothing to solve")
    check(MathSolver.solve("5 _ 3") == ">" && MathSolver.solve("2 + 2 _ 5") == "<" && MathSolver.solve("4 _ 2 + 2") == "=", "maths: comparing")
    check(MathSolver.solve("2, 4, _, 8") == "6", "maths: sequence gap")
    check(MathSolver.solve("10, 8, _, 4") == "6", "maths: counting down")
    check(MathSolver.solve("1, 2, _, 9") == nil, "maths: uneven sequence is rejected")
    check(MathSolver.solve("twenty-one + four =") == "twenty-five", "maths: compound number words")
    check(MathSolver.solve("einundzwanzig + vier =") == "fuenfundzwanzig", "maths: German words give a German answer")
    check(MathSolver.solve("seven x two =") == "fourteen", "maths: word multiplication")
    check(MathSolver.solve("0 x ___ = 0") == nil, "maths: several possible answers are rejected")
    check(NumberWords.value("f\u{00FC}nfzig") == 50, "words: umlaut word")
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

// D3: answer pages
do {
    let key = [
        PageText(text: "Answers", box: PageRect(x: 0.4, y: 0.05, width: 0.2, height: 0.04)),
        PageText(text: "1. 4, 5, 6", box: PageRect(x: 0.1, y: 0.15, width: 0.2, height: 0.03)),
        PageText(text: "2. four six", box: PageRect(x: 0.1, y: 0.20, width: 0.2, height: 0.03)),
        PageText(text: "Aufgabe 3: a; c; b.", box: PageRect(x: 0.1, y: 0.25, width: 0.2, height: 0.03))
    ]
    let entries = AnswerPages.parse(key)
    check(entries.count == 3 && entries[0].answers == ["4", "5", "6"], "answer page: numbers after a task number")
    check(entries[1].answers == ["four", "six"] && entries[2].answers == ["a", "c", "b"], "answer page: words, semicolons and 'Aufgabe'")
    check(AnswerPages.isKeyPage(key), "answer page: heading and entries make a key page")
    check(!AnswerPages.isKeyPage(Array(key.dropFirst())), "answer page: no heading, no key page")
    let taskPage = [PageText(text: "Answer the questions", box: PageRect(x: 0.3, y: 0.05, width: 0.4, height: 0.04))] + Array(key.dropFirst())
    check(!AnswerPages.isKeyPage(taskPage), "answer page: 'Answer the questions' is a task page, not a key")
    check(AnswerPages.isKeyPage([PageText(text: "Answer key", box: PageRect(x: 0.3, y: 0.05, width: 0.4, height: 0.04))] + Array(key.dropFirst())), "answer page: 'Answer key' heading")
    check(AnswerPages.taskNumber(of: "3. Count and write.") == 3, "answer page: task number from the prompt")

    let task = PlayTask(id: "p1-t1", kind: .numberInOrder, prompt: "1. Number.",
                        items: [TaskItem(id: "a", label: "a", region: PageRect(x: 0.1, y: 0.1, width: 0.05, height: 0.03)), TaskItem(id: "b", label: "b", region: PageRect(x: 0.1, y: 0.2, width: 0.05, height: 0.03)),
                                TaskItem(id: "c", label: "c", region: PageRect(x: 0.1, y: 0.3, width: 0.05, height: 0.03))])
    let solved = AnswerPages.apply(entries, to: task)
    check(solved.key?.order == ["a": 4, "b": 5, "c": 6] && solved.keySource == .answerPage, "answer page: key is set on a number task")
    let other = PlayTask(id: "p1-t9", kind: .numberInOrder, prompt: "9. Number.", items: task.items)
    check(AnswerPages.apply(entries, to: other).key == nil, "answer page: no entry for the task number leaves it open")
    let fillTask = PlayTask(id: "p1-t2", kind: .fillIn, prompt: "2. Write.",
                            items: [TaskItem(id: "x", label: "x", region: PageRect(x: 0.1, y: 0.1, width: 0.05, height: 0.03)),
                                    TaskItem(id: "y", label: "y", region: PageRect(x: 0.1, y: 0.2, width: 0.05, height: 0.03))])
    let filled = AnswerPages.apply(entries, to: fillTask)
    check(filled.key?.text == ["x": "four", "y": "six"] && filled.keySource == .answerPage, "answer page: key is set on a fill-in task")
    let wrongCount = PlayTask(id: "p1-t2", kind: .fillIn, prompt: "2. Write.", items: [task.items[0]])
    check(AnswerPages.apply(entries, to: wrongCount).key == nil, "answer page: different number of answers leaves it open")

    // Task numbers restart on every page: a grouped key is only used for the matching page
    let paged = [
        PageText(text: "Answers", box: PageRect(x: 0.4, y: 0.05, width: 0.2, height: 0.04)),
        PageText(text: "Page 10", box: PageRect(x: 0.1, y: 0.10, width: 0.2, height: 0.03)),
        PageText(text: "1. 4, 5, 6", box: PageRect(x: 0.1, y: 0.15, width: 0.2, height: 0.03)),
        PageText(text: "Page 11", box: PageRect(x: 0.1, y: 0.20, width: 0.2, height: 0.03)),
        PageText(text: "1. 7, 8, 9", box: PageRect(x: 0.1, y: 0.25, width: 0.2, height: 0.03)),
        PageText(text: "2. 1, 2, 3", box: PageRect(x: 0.1, y: 0.30, width: 0.2, height: 0.03))
    ]
    let pagedEntries = AnswerPages.parse(paged)
    check(pagedEntries.count == 3 && pagedEntries[0].group == 10 && pagedEntries[1].group == 11, "answer page: page headings group the entries")
    check(AnswerPages.apply(pagedEntries, to: task, group: 11).key?.order == ["a": 7, "b": 8, "c": 9], "answer page: task 1 on page 11 gets the page 11 key")
    check(AnswerPages.apply(pagedEntries, to: task, group: 10).key?.order == ["a": 4, "b": 5, "c": 6], "answer page: task 1 on page 10 gets the page 10 key")
    check(AnswerPages.apply(pagedEntries, to: task).key == nil, "answer page: no page given, no guess")
    let twice = AnswerPages.parse([PageText(text: "1. 1, 2, 3", box: PageRect(x: 0.1, y: 0.15, width: 0.2, height: 0.03)),
                                   PageText(text: "1. 4, 5, 6", box: PageRect(x: 0.1, y: 0.20, width: 0.2, height: 0.03))])
    check(AnswerPages.apply(twice, to: task).key == nil, "answer page: the same task number twice in one group is not guessed")

    // Keys in two columns: each column is read on its own, so page 10's tasks 5 and 6 do not end up under "Page 11"
    func line(_ text: String, _ x: Double, _ y: Double) -> PageText { PageText(text: text, box: PageRect(x: x, y: y, width: 0.3, height: 0.03)) }
    var columns = [line("Answers", 0.4, 0.05), line("Page 10", 0.05, 0.10), line("Page 11", 0.55, 0.30)]
    for n in 1...6 { columns.append(line("\(n). \(n), \(n + 1), \(n + 2)", 0.05, 0.10 + 0.05 * Double(n))) }
    columns.append(line("1. 7, 8, 9", 0.55, 0.35))
    let columnEntries = AnswerPages.parse(columns)
    let page10Task5 = PlayTask(id: "p10-t5", kind: .numberInOrder, prompt: "5. Number.", items: task.items)
    check(AnswerPages.apply(columnEntries, to: page10Task5, group: 10).key?.order == ["a": 5, "b": 6, "c": 7], "answer page: two columns, task 5 of page 10 keeps its key")
    check(AnswerPages.apply(columnEntries, to: page10Task5, group: 11).key == nil, "answer page: two columns, page 11 has no task 5 and gets nothing")
    check(AnswerPages.apply(columnEntries, to: task, group: 11).key?.order == ["a": 7, "b": 8, "c": 9], "answer page: two columns, page 11 task 1")

    // Headings the app cannot read start a group of their own that is never used
    let unreadable = AnswerPages.parse([line("Page 10", 0.1, 0.10), line("1. 4, 5, 6", 0.1, 0.15),
                                        line("Pages 12\u{2013}13", 0.1, 0.20), line("1. 7, 8, 9", 0.1, 0.25)])
    check(AnswerPages.apply(unreadable, to: task, group: 10).key?.order == ["a": 4, "b": 5, "c": 6], "answer page: an unreadable heading does not spoil the page before it")
    check(AnswerPages.apply(unreadable, to: task, group: 12).key == nil && AnswerPages.apply(unreadable, to: task, group: AnswerPages.unknownGroup).key == nil,
          "answer page: entries under an unreadable heading are never used")
    let short = AnswerPages.parse([line("S. 10", 0.1, 0.10), line("1. 4, 5, 6", 0.1, 0.15)])
    check(short.first?.group == 10, "answer page: 'S. 10' is a page heading")

    // Key headings
    let body = Array(key.dropFirst())
    for heading in ["L\u{00F6}sung", "Solution", "Answers Unit 1", "L\u{00F6}sungen zu Seite 10", "L\u{00F6}sungen", "Loesungen", "Answer"] {
        check(AnswerPages.isKeyPage([line(heading, 0.3, 0.02)] + body), "answer page: heading '\(heading)'")
    }
    check(AnswerPages.isKeyPage([line("Lo\u{0308}sungen", 0.3, 0.05)] + body), "answer page: heading with a decomposed umlaut")
    check(!AnswerPages.isKeyPage([line("Answer", 0.3, 0.20)] + [line("Read.", 0.1, 0.02)] + body), "answer page: a lone 'Answer' below other text is not a key heading")

    // Narrow columns that sit close together (boxes do not overlap) are still separate columns
    func narrow(_ text: String, _ x: Double, _ y: Double) -> PageText { PageText(text: text, box: PageRect(x: x, y: y, width: 0.08, height: 0.03)) }
    var threeColumns = [narrow("Page 10", 0.05, 0.10), narrow("Page 11", 0.14, 0.30), narrow("Page 12", 0.23, 0.10)]
    for n in 1...6 { threeColumns.append(narrow("\(n). \(n), \(n + 1), \(n + 2)", 0.05, 0.10 + 0.05 * Double(n))) }
    threeColumns.append(narrow("1. 7, 8, 9", 0.14, 0.35))
    threeColumns.append(narrow("1. 3, 2, 1", 0.23, 0.15))
    let threeEntries = AnswerPages.parse(threeColumns)
    check(AnswerPages.apply(threeEntries, to: page10Task5, group: 10).key?.order == ["a": 5, "b": 6, "c": 7], "answer page: three narrow columns, task 5 of page 10 keeps its key")
    check(AnswerPages.apply(threeEntries, to: page10Task5, group: 11).key == nil, "answer page: three narrow columns, page 11 has no task 5 and gets nothing")
    check(AnswerPages.apply(threeEntries, to: task, group: 12).key?.order == ["a": 3, "b": 2, "c": 1], "answer page: three narrow columns, page 12 task 1")

    // A key heading that names its page or unit groups the entries under it
    let namedPage = AnswerPages.parse([line("L\u{00F6}sungen zu Seite 10", 0.3, 0.02), line("1. 4, 5, 6", 0.1, 0.15)])
    check(namedPage.first?.group == 10, "answer page: 'L\u{00F6}sungen zu Seite 10' groups the entries under it")
    check(AnswerPages.apply(namedPage, to: task, group: 10).key?.order == ["a": 4, "b": 5, "c": 6], "answer page: that key is used for page 10")
    check(AnswerPages.apply(namedPage, to: task, group: 11).key == nil, "answer page: that key is not used for page 11")
    check(AnswerPages.parse([line("Answers Unit 1", 0.3, 0.02), line("1. 4, 5, 6", 0.1, 0.15)]).first?.group == 1, "answer page: 'Answers Unit 1' groups the entries under it")
    check(AnswerPages.parse([line("L\u{00F6}sungen Seite 10/11", 0.3, 0.02), line("1. 4, 5, 6", 0.1, 0.15)]).first?.group == AnswerPages.unknownGroup,
          "answer page: a key heading with a page range is an unknown group")
    check(AnswerPages.isKeyPage([line("Answers 1\u{2013}20", 0.3, 0.02)] + body), "answer page: heading 'Answers 1-20'")

    // More group words; any other short "word number" line must not extend the group before it
    let chapters = AnswerPages.parse([line("Unit 1", 0.1, 0.10), line("1. 4, 5, 6", 0.1, 0.15), line("Chapter 2", 0.1, 0.20), line("1. 7, 8, 9", 0.1, 0.25),
                                      line("Teil 3", 0.1, 0.30), line("1. 1, 1, 1", 0.1, 0.35)])
    check(AnswerPages.apply(chapters, to: task, group: 1).key?.order == ["a": 4, "b": 5, "c": 6], "answer page: unit 1 keeps its key")
    check(AnswerPages.apply(chapters, to: task, group: 2).key?.order == ["a": 7, "b": 8, "c": 9], "answer page: 'Chapter 2' is a group")
    check(AnswerPages.apply(chapters, to: task, group: AnswerPages.unknownGroup).key == nil, "answer page: an unknown heading ('Teil 3') is never used")
}

// D4: crosswords
do {
    // CAT across (slot 0), CAR down (slot 1) sharing the first letter, TEN down (slot 2) sharing CAT's last letter
    let crossings = [CrosswordSolver.Crossing(a: 0, aPosition: 0, b: 1, bPosition: 0),
                     CrosswordSolver.Crossing(a: 0, aPosition: 2, b: 2, bPosition: 0)]
    let solved = CrosswordSolver.solve(lengths: [3, 3, 3], crossings: crossings, words: ["TEN", "CAR", "CAT"])
    check(solved == ["CAT", "CAR", "TEN"], "crossword: words placed by length and crossing letters")
    check(CrosswordSolver.solve(lengths: [3, 3], crossings: [], words: ["DOG", "PIG"]) == nil, "crossword: two possible fits are not guessed")
    check(CrosswordSolver.solve(lengths: [3], crossings: [], words: ["HORSE"]) == nil, "crossword: no word of that length")
    check(CrosswordSolver.solve(lengths: [3, 3], crossings: [], words: ["DOG", "DOG"]) == ["DOG", "DOG"], "crossword: the same word listed twice is not a second solution")
    check(CrosswordSolver.solve(lengths: [6], crossings: [], words: ["Stra\u{00DF}e"]) == ["Stra\u{00DF}e"], "crossword: sharp s counts as one letter")
    check(CrosswordSolver.solve(lengths: [3, 3], crossings: [], words: ["Dog", "DOG"]) != nil, "crossword: 'Dog' and 'DOG' are the same word")
    check(CrosswordSolver.solve(lengths: [7], crossings: [], words: ["Stra\u{00DF}e"]) == ["Stra\u{00DF}e"], "crossword: sharp s printed as SS fills 7 cells")
}

// D5: word search
do {
    let grid: [[Character]] = [Array("CATX"), Array("XOXX"), Array("XXGX"), Array("DOGX")]
    check(WordSearch.find("cat", in: grid).count == 1, "word search: across")
    let dog = WordSearch.find("DOG", in: grid)
    check(dog.count == 1 && dog[0].columnStep == 1, "word search: DOG in the last row")
    let solved = WordSearch.solve(words: ["CAT", "COG", "FISH"], grid: grid)
    check(solved["CAT"]?.rowStep == 0 && solved["COG"]?.rowStep == 1 && solved["COG"]?.columnStep == 1, "word search: diagonal word")
    check(solved["FISH"] == nil, "word search: a missing word is left out")
    check(WordSearch.find("TAC", in: grid).first?.columnStep == -1, "word search: backwards")
    func direction(_ word: String, _ grid: [[Character]]) -> String {
        WordSearch.find(word, in: grid).first.map { "\($0.rowStep),\($0.columnStep)" } ?? "none"
    }
    let eight: [[Character]] = [Array("ABCDE"), Array("FGHIJ"), Array("KLMNO"), Array("PQRST"), Array("UVWXY")]
    check(direction("GL", eight) == "1,0", "word search: downwards")
    check(direction("LG", eight) == "-1,0", "word search: upwards")
    check(direction("GM", eight) == "1,1", "word search: diagonal down-right")
    check(direction("SM", eight) == "-1,-1", "word search: diagonal up-left")
    check(direction("HL", eight) == "1,-1", "word search: diagonal down-left")
    check(direction("LH", eight) == "-1,1", "word search: diagonal up-right")
    check(direction("AB", eight) == "0,1", "word search: across")
    check(direction("BA", eight) == "0,-1", "word search: backwards on a row")
    let twiceGrid: [[Character]] = [Array("ABX"), Array("XXX"), Array("ABX")]
    check(WordSearch.find("AB", in: twiceGrid).count == 2 && WordSearch.solve(words: ["AB"], grid: twiceGrid).isEmpty, "word search: a word found twice is left out")
    let mum: [[Character]] = [Array("MUMX"), Array("XXXX")]
    check(WordSearch.find("MUM", in: mum).count == 1 && WordSearch.solve(words: ["MUM"], grid: mum)["MUM"] != nil, "word search: a palindrome counts once")
    let strasse: [[Character]] = [Array("STRA\u{00DF}E")]
    check(WordSearch.find("Stra\u{00DF}e", in: strasse).count == 1, "word search: sharp s counts as one letter")
    let strasseCaps: [[Character]] = [Array("XSTRASSEX"), Array("XXXXXXXXX")]
    check(WordSearch.find("Stra\u{00DF}e", in: strasseCaps).count == 1, "word search: sharp s printed as SS")
    let capitalSharp: [[Character]] = [Array("STRA\u{1E9E}E")]
    check(WordSearch.find("Stra\u{00DF}e", in: capitalSharp).count == 1, "word search: capital sharp s")
}

// PP-033: answer key of the whole book, matched by printed page number
func textLine(_ text: String, _ x: Double, _ y: Double, width: Double = 0.2, height: Double = 0.03) -> PageText {
    PageText(text: text, box: PageRect(x: x, y: y, width: width, height: height))
}
do {
    let footer10 = [textLine("10", 0.45, 0.95, width: 0.05)]
    check(PageNumbers.number(atX: 0.5, lines: footer10, pageAspect: 0.7) == 10, "page number: read from the footer")
    check(PageNumbers.number(atX: 0.5, lines: [], pageAspect: 0.7) == nil, "page number: none printed")
    check(PageNumbers.number(atX: 0.5, lines: [textLine("10", 0.45, 0.95, width: 0.05), textLine("11", 0.1, 0.02, width: 0.05)], pageAspect: 0.7) == nil, "page number: two different numbers on one page are not guessed")
    check(PageNumbers.number(atX: 0.5, lines: [textLine("Page 3", 0.45, 0.95, width: 0.1)], pageAspect: 0.7) == nil, "page number: text is not a number")
    let spread = [textLine("10", 0.2, 0.95, width: 0.05), textLine("11", 0.7, 0.95, width: 0.05)]
    check(PageNumbers.number(atX: 0.25, lines: spread, pageAspect: 1.4) == 10 && PageNumbers.number(atX: 0.75, lines: spread, pageAspect: 1.4) == 11, "page number: left and right page of a spread")

    let items = [TaskItem(id: "a", region: PageRect(x: 0.1, y: 0.2, width: 0.05, height: 0.03)),
                 TaskItem(id: "b", region: PageRect(x: 0.1, y: 0.3, width: 0.05, height: 0.03)),
                 TaskItem(id: "c", region: PageRect(x: 0.1, y: 0.4, width: 0.05, height: 0.03))]
    let numberTask = PlayTask(id: "p1-t1", kind: .numberInOrder, prompt: "1. Number.", region: PageRect(x: 0, y: 0.1, width: 1, height: 0.6), items: items)
    let keyPage = [textLine("Answers", 0.4, 0.05), textLine("Page 10", 0.1, 0.10), textLine("1. 4, 5, 6", 0.1, 0.15),
                   textLine("2. 1, 2, 3", 0.1, 0.20), textLine("Page 11", 0.1, 0.30), textLine("1. 7, 8, 9", 0.1, 0.35)]
    let bookEntries = BookKeys.entries(pages: [[textLine("1. Number.", 0.05, 0.1)], keyPage])
    check(bookEntries.count == 3, "book key: only key pages are read")
    let onPage10 = BookKeys.apply(bookEntries, to: [numberTask], lines: footer10, pageAspect: 0.7)
    check(onPage10.first?.key?.order == ["a": 4, "b": 5, "c": 6] && onPage10.first?.keySource == .answerPage, "book key: task 1 on printed page 10")
    let onPage11 = BookKeys.apply(bookEntries, to: [numberTask], lines: [textLine("11", 0.45, 0.95, width: 0.05)], pageAspect: 0.7)
    check(onPage11.first?.key?.order == ["a": 7, "b": 8, "c": 9], "book key: task 1 on printed page 11")
    check(BookKeys.apply(bookEntries, to: [numberTask], lines: [], pageAspect: 0.7).first?.key == nil, "book key: no page number, no key")
    check(BookKeys.apply(bookEntries, to: [numberTask], lines: [textLine("12", 0.45, 0.95, width: 0.05)], pageAspect: 0.7).first?.key == nil, "book key: page without entries gets no key")
    let flat = AnswerPages.parse([textLine("1. 4, 5, 6", 0.1, 0.15)])
    check(AnswerPages.apply(flat, to: numberTask, group: 10).key == nil, "answer page: a key without page headings is not placed on a page")

    // reconciling two methods
    let fillItems = [TaskItem(id: "x", region: PageRect(x: 0.1, y: 0.2, width: 0.05, height: 0.03))]
    var calculated = PlayTask(id: "p1-t1", kind: .fillIn, prompt: "1. Write.", region: PageRect(x: 0, y: 0.1, width: 1, height: 0.6), items: fillItems)
    calculated.key = AnswerKey(text: ["x": "4"])
    calculated.keySource = .calculated
    calculated.confidence = 0.8
    let wordKey = AnswerPages.parse([textLine("Page 10", 0.1, 0.10), textLine("1. four", 0.1, 0.15)])
    let agreed = BookKeys.apply(wordKey, to: [calculated], lines: footer10, pageAspect: 0.7)
    check(agreed.first?.key?.text == ["x": "4"] && (agreed.first?.confidence ?? 0) >= AnswerReconciler.agreed, "reconcile: '4' and 'four' agree, the answer is trusted")
    calculated.key = AnswerKey(text: ["x": "5"])
    let disputed = BookKeys.apply(wordKey, to: [calculated], lines: footer10, pageAspect: 0.7)
    check(disputed.first?.key == nil && (disputed.first?.confidence ?? 1) <= AnswerReconciler.disputed, "reconcile: different answers are left to a grown-up")
    check(AnswerReconciler.merge(PlayTask(id: "t", kind: .fillIn, prompt: "p"), calculated).key?.text == ["x": "5"], "reconcile: one method only keeps its key")
}

// D2: units and money
do {
    check(QuantitySolver.solve("3 m + 20 cm =") == "320 cm", "units: metres and centimetres")
    check(QuantitySolver.solve("30 cm + 20 cm =") == "50 cm", "units: same unit")
    check(QuantitySolver.solve("1 kg - 250 g =") == "750 g", "units: kilograms and grams")
    check(QuantitySolver.solve("2 l - 500 ml = _") == "1500 ml", "units: litres, blank after the equals sign")
    check(QuantitySolver.solve("1 h 30 min + 45 min =") == "2 h 15 min", "time: hours and minutes")
    check(QuantitySolver.solve("2,50 \u{20AC} + 1,20 \u{20AC} =") == "3,70 \u{20AC}", "money: decimal comma, sign after the number")
    check(QuantitySolver.solve("\u{20AC} 3.50 + \u{20AC} 1.25 =") == "\u{20AC} 4.75", "money: decimal point, sign before the number")
    check(QuantitySolver.solve("3 \u{20AC} + 2 \u{20AC} =") == "5 \u{20AC}", "money: whole euros")
    check(QuantitySolver.solve("3 m _ 250 cm") == ">", "units: comparing")
    check(QuantitySolver.solve("5 cm - 8 cm =") == nil, "units: a negative result is rejected")
    check(QuantitySolver.solve("3 apples + 2 =") == nil, "units: an unknown word is not a unit")
    check(QuantitySolver.solve("3 m + 2 kg =") == nil, "units: length and mass do not mix")
    check(NumberWords.answer(forSum: "4 m + 1 m =") == "5 m", "units: used for task lines")

    // sums in a column
    let stacks = [textLine("23", 0.10, 0.30, width: 0.06), textLine("+ 45", 0.08, 0.335, width: 0.08),
                  textLine("12", 0.50, 0.30, width: 0.06), textLine("+ 30", 0.48, 0.335, width: 0.08)]
    let found = ColumnSums.find(stacks)
    check(found.count == 2 && Set(found.map { $0.expression }) == ["23 + 45 =", "12 + 30 ="], "column sums: two stacks found")
    check(MathSolver.solve("23 + 45 =") == "68", "column sums: the expression is solved")
    let bars = [PageRect(x: 0.1, y: 0.38, width: 0.08, height: 0.03), PageRect(x: 0.5, y: 0.38, width: 0.08, height: 0.03)]
    let columnTasks = TaskBuilder.buildTasks(lines: [textLine("5. Add.", 0.05, 0.1)] + stacks, emptyCircles: [], blanks: bars, idPrefix: "p1")
    check(columnTasks.first?.kind == .fillIn && Set(columnTasks.first?.key?.text.values.map { $0 } ?? []) == ["68", "42"], "column sums: a task with the answers calculated")
    check(ColumnSums.find([textLine("23", 0.10, 0.30, width: 0.06), textLine("45", 0.08, 0.335, width: 0.08)]).isEmpty, "column sums: no sign, no sum")
}

// D6 / D7 / D9: logic around the on-device models
do {
    let diagonal: [[Double]] = [[0.30, 0.10, 0.12], [0.11, 0.28, 0.10], [0.09, 0.12, 0.31]]
    let matched = PictureMatching.assign(scores: diagonal)
    check(matched?.wordForPicture == [0, 1, 2] && (matched?.confidence ?? 0) > 0.5, "pictures: clear scores give the pairing")
    let swapped: [[Double]] = [[0.10, 0.30, 0.12], [0.28, 0.11, 0.10], [0.09, 0.12, 0.31]]
    check(PictureMatching.assign(scores: swapped)?.wordForPicture == [1, 0, 2], "pictures: a different pairing is found")
    let unsure: [[Double]] = [[0.20, 0.20, 0.10], [0.20, 0.20, 0.10], [0.10, 0.10, 0.30]]
    check(PictureMatching.assign(scores: unsure) == nil, "pictures: two equally good pairings are left to a grown-up")
    check(PictureMatching.assign(scores: [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]]) == nil, "pictures: not square")
    var big = [[Double]](repeating: [Double](repeating: 0.1, count: 9), count: 9)
    for i in 0..<9 { big[i][(i + 3) % 9] = 0.4 }
    check(PictureMatching.assign(scores: big)?.wordForPicture == (0..<9).map { ($0 + 3) % 9 }, "pictures: nine pictures (greedy)")
    let circles = [TaskItem(id: "c1"), TaskItem(id: "c2"), TaskItem(id: "c3")]
    check(PictureMatching.numberKey(circles: circles, assignment: matched!)?.order == ["c1": 1, "c2": 2, "c3": 3], "pictures: numbers from the word positions")

    check(CountStatement.stated("There are two ladybirds.") == 2, "count: 'two'")
    check(CountStatement.stated("There is one") == 1 && CountStatement.stated("There is a ladybird") == 1, "count: 'one' and 'a'")
    check(CountStatement.stated("Es gibt drei Marienk\u{00E4}fer") == 3, "count: German")
    check(CountStatement.stated("The ladybirds are red") == nil, "count: no number stated")
    check(CountStatement.isCorrect("There are two ladybirds", counted: 2) == true && CountStatement.isCorrect("There is one", counted: 2) == false
          && CountStatement.isCorrect("There is one", counted: nil) == nil, "count: judged against the counted number")
    let rows = [TaskItem(id: "r1", label: "There are two ladybirds"), TaskItem(id: "r2", label: "There is one ladybird")]
    check(CountStatement.tickKey(rows: rows, counts: [2, 2])?.booleans == ["r1": true, "r2": false], "count: tick key from counts")
    check(CountStatement.tickKey(rows: rows, counts: [2, nil]) == nil, "count: an unsure row leaves the whole task to a grown-up")

    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pagepals-models-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: tmp.appendingPathComponent("clip.bin").path, contents: Data([1]))
    check(OfflineModels.locate("clip.bin", in: tmp) != nil && OfflineModels.locate("missing.bin", in: tmp) == nil, "models: found only when put in place")
    try? FileManager.default.removeItem(at: tmp)
}

// H1: no network code in the app (the app must work offline and keep everything on the Mac)
do {
    let forbidden = ["URLSession", "URLRequest", "NWConnection", "import Network", "CFSocket", "WKWebView"]
    var offenders: [String] = []
    var scanned = 0
    for folder in ["Sources/PagePalsCore", "Sources/PagePalsImport", "Sources/PagePalsApp"] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { continue }
        for name in names where name.hasSuffix(".swift") {
            guard let text = try? String(contentsOfFile: folder + "/" + name, encoding: .utf8) else { continue }
            scanned += 1
            for word in forbidden where text.contains(word) { offenders.append(name + ": " + word) }
        }
    }
    if scanned == 0 {
        print("SKIP  offline: run the checks from the package folder to scan the sources")
    } else {
        check(offenders.isEmpty, "offline: no network code in the sources \(offenders)")
    }
}

// M3 logic: PP-013 task type, PP-004 library, PP-005 progress, PP-020 line matching, PP-025 ordering, PP-003 page split
func closeTo(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }

do {
    check(TaskTypeClassifier.kind(forHeader: "2. Draw lines from the pictures to the words.") == .matching, "PP-013: draw lines is matching")
    check(TaskTypeClassifier.kind(forHeader: "Tick correct or wrong.") == .trueFalse, "PP-013: tick is true/false")
    check(TaskTypeClassifier.kind(forHeader: "Colour the stick.") == .openTask, "PP-013: 'stick' is not 'tick'")
    check(TaskTypeClassifier.kind(forHeader: "Read and choose.") == .multipleChoice, "PP-013: read and choose")
    check(TaskTypeClassifier.kind(forHeader: "Complete the crossword.") == .crossword, "PP-013: crossword before complete")
    check(TaskTypeClassifier.kind(forHeader: "Finde die Wörter im Buchstabengitter.") == .wordSearch, "PP-013: German word search")
    check(TaskTypeClassifier.kind(forHeader: "Number the pictures.") == .numberInOrder, "PP-013: number the pictures")
    check(TaskTypeClassifier.kind(forHeader: "Write the numbers.") == .fillIn, "PP-013: write the numbers is fill-in")
    check(TaskTypeClassifier.kind(forHeader: "Look at the page.") == nil, "PP-013: no rule gives nil")
    check(TaskTypeClassifier.classify(header: "1. Number.", shapes: .init(emptyCircles: 9)) == .numberInOrder, "PP-013: empty circles give numbering")
    check(TaskTypeClassifier.classify(header: "Match.", shapes: .init(tickCircles: 8)) == .matching, "PP-013: structural words beat shapes")
    check(TaskTypeClassifier.classify(header: "Look.", shapes: .init(tickCircles: 8)) == .trueFalse, "PP-013: tick circles give true/false")
    check(TaskTypeClassifier.classify(header: "Look.", shapes: .init(answerBars: 3)) == .fillIn, "PP-013: answer bars give fill-in")
    check(TaskTypeClassifier.classify(header: "Look.") == .openTask, "PP-013: unknown task is an open task")
}

do {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pp-lib-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let lib = LessonLibrary(root: tmp)
    let task = PlayTask(id: "t1", kind: .fillIn, prompt: "p", items: [TaskItem(id: "a")], key: AnswerKey(text: ["a": "4"]), confidence: 0.8, keySource: .calculated)
    let pack = LessonPack(title: "Maths 1", language: "en", pages: [BookPage(id: "p1", number: 1, imageFile: "p1.png", tasks: [task])])
    try? lib.save(pack, id: "maths-1")
    check((try? lib.load(id: "maths-1")) == pack, "PP-004: pack is read back as written")
    check(lib.list().map(\.title) == ["Maths 1"] && lib.list().first?.pageCount == 1, "PP-004: library lists the book")
    try? lib.rename(id: "maths-1", to: " Maths One ")
    check((try? lib.load(id: "maths-1"))?.title == "Maths One", "PP-004: rename keeps the rest")
    try? lib.writeImage(Data([1, 2, 3]), named: "p1-a.png", book: "maths-1")
    check(lib.imageURL(named: "p1-a.png", book: "maths-1") != nil && lib.imageURL(named: "nope.png", book: "maths-1") == nil, "PP-004: cut-out pictures are kept as files")
    var badName = false
    do { try lib.save(pack, id: "../x") } catch LibraryError.badName { badName = true } catch {}
    check(badName, "PP-004: ids with a path are refused")
    try? lib.delete(id: "maths-1")
    check(lib.list().isEmpty, "PP-004: deleted book is gone")

    let old = Data(#"{"title":"Old","pages":[{"id":"p1","number":1,"imageFile":"p1.png","tasks":[{"id":"t","kind":"fillIn","prompt":"x"}]}]}"#.utf8)
    let migrated = try? LessonLibrary.decode(old)
    check(migrated?.language == "en" && migrated?.pages.first?.tasks.first?.confidence == 1.0 && migrated?.version == 1, "PP-004: an older pack is loaded with defaults")
    var newer: LibraryError?
    do { _ = try LessonLibrary.decode(Data(#"{"version":99,"title":"x","language":"en","pages":[]}"#.utf8)) } catch let e as LibraryError { newer = e } catch {}
    check(newer == .tooNew(99), "PP-004: a pack from a newer app is refused, not misread")
}

do {
    var p = ImportProgress(pageCount: 4)
    p.finish(0); p.finish(1); p.finish(9)
    check(closeTo(p.fraction, 0.5) && p.nextPage == 2 && !p.isDone, "PP-005: progress counts finished pages, ignores bad numbers")
    p.cancel()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("pp-prog-" + UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    try? p.save(to: file)
    let back = ImportProgress.load(from: file, pageCount: 4)
    check(back.finished == [0, 1] && !back.cancelled && back.nextPage == 2, "PP-005: resume keeps finished pages and clears the cancel")
    check(ImportProgress.load(from: file, pageCount: 5).finished.isEmpty, "PP-005: a book with another page count starts fresh")
    var all = back
    [2, 3].forEach { all.finish($0) }
    check(all.isDone && all.nextPage == nil, "PP-005: all pages finished")
    check(closeTo(ImportProgress(pageCount: 0).fraction, 1), "PP-005: empty book is done")
}

do {
    let a = LineMatching.Target(id: "A", region: PageRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1))
    let b = LineMatching.Target(id: "B", region: PageRect(x: 0.6, y: 0.1, width: 0.1, height: 0.1))
    let key = AnswerKey(pairs: ["s": "A"])
    check(LineMatching.drop(from: "s", atX: 0.15, y: 0.15, targets: [a, b], key: key) == .snapped("A"), "PP-020: right target snaps")
    check(LineMatching.drop(from: "s", atX: 0.65, y: 0.15, targets: [a, b], key: key) == .wrong("B"), "PP-020: wrong target wiggles back")
    check(LineMatching.drop(from: "s", atX: 0.4, y: 0.9, targets: [a, b], key: key) == .missed, "PP-020: drop on nothing is missed")
    check(LineMatching.drop(from: "s", atX: 0.65, y: 0.15, targets: [a, b], key: nil) == .snapped("B"), "PP-020: without a key a drop snaps for the grown-up to check")
    check(LineMatching.drop(from: "s", atX: 0.209, y: 0.15, targets: [a, b], key: key) == .snapped("A"), "PP-020: a little slack around a target")
    check(LineMatching.drop(from: "A", atX: 0.15, y: 0.15, targets: [a, b], key: nil) == .missed, "PP-020: a line cannot end on its own start")
}

do {
    let solution = ["a", "b", "c"]
    var board = OrderingBoard.start(solution: solution)
    check(board.itemIds == ["b", "c", "a"] && board.itemIds != solution, "PP-025: board does not start solved")
    let task = PlayTask(id: "o", kind: .numberInOrder, prompt: "Order", items: solution.map { TaskItem(id: $0) }, key: OrderingBoard.key(solution: solution))
    check(!TaskEvaluator.evaluate(task: task, response: board.response()).isComplete, "PP-025: start is not complete")
    board.move(from: 2, to: 5)
    check(board.itemIds == ["b", "c", "a"], "PP-025: move out of range does nothing")
    board.move(from: 2, to: 0)
    check(board.itemIds == solution && TaskEvaluator.evaluate(task: task, response: board.response()).isComplete, "PP-025: dragging into order completes the task")
    check(OrderingBoard.start(solution: ["x"]).itemIds == ["x"], "PP-025: one item stays")
}

do {
    var profile = [Double](repeating: 0.1, count: 1000)
    for i in 495...505 { profile[i] = 0.8 }
    check(abs(PageSplit.gutter(profile: profile) - 0.5) < 0.01, "PP-003: dark gutter in the middle is found")
    var off = [Double](repeating: 0.1, count: 1000)
    for i in 450...460 { off[i] = 0.8 }
    check(abs(PageSplit.gutter(profile: off) - 0.4555) < 0.01, "PP-003: gutter off the centre is found")
    check(PageSplit.gutter(profile: [Double](repeating: 0.2, count: 1000)) == 0.5, "PP-003: no gutter falls back to the centre")
    check(PageSplit.gutter(profile: [0.1, 0.2]) == 0.5, "PP-003: too short a profile falls back to the centre")
    check(PageSplit.isSpread(aspect: 1.4) && !PageSplit.isSpread(aspect: 0.7), "PP-003: wide scan is a spread")
    let h = PageSplit.halves(gutter: 0.5)
    check(closeTo(h.left.width, 0.5) && closeTo(h.right.x, 0.5), "PP-003: halves meet at the gutter")
    let right = PageSplit.local(PageRect(x: 0.6, y: 0.2, width: 0.1, height: 0.1), rightHalf: true, gutter: 0.5)
    check(right.map { closeTo($0.x, 0.2) && closeTo($0.width, 0.2) } == true, "PP-003: right page rectangle in page coordinates")
    check(PageSplit.local(PageRect(x: 0.6, y: 0.2, width: 0.1, height: 0.1), rightHalf: false, gutter: 0.5) == nil, "PP-003: a box on the other page is not on this one")
    let left = PageSplit.local(PageRect(x: 0.1, y: 0.2, width: 0.2, height: 0.1), rightHalf: false, gutter: 0.5)
    check(left.map { closeTo($0.x, 0.2) && closeTo($0.width, 0.4) } == true, "PP-003: left page rectangle in page coordinates")
}

// PP-006: book language
do {
    check(BookLanguage.detect(from: ["Write the words.", "How many lollies are there?"]) == .english, "PP-006: English page")
    check(BookLanguage.detect(from: ["Schreibe die Wörter.", "Was ist das? Ergänze den Satz."]) == .german, "PP-006: German page")
    check(BookLanguage.detect(from: ["Der Hund ist groß", "Straße"]) == .german, "PP-006: German by words and sharp s")
    check(BookLanguage.detect(from: ["Напиши слова.", "Сколько яблок?"]) == .russian, "PP-006: Russian page")
    check(BookLanguage.detect(from: ["1. Number.", "2. Match."]) == .english, "PP-006: no clue gives English")
    check(BookLanguage.detect(from: ["Write the words.", "Напиши", "Der Hund ist ein Tier und die Katze"]) == .german, "PP-006: mixed page decided by the common words")
    check(BookLanguage.russian.recognitionLanguages.first == "ru-RU" && BookLanguage.german.recognitionLanguages.first == "de-DE", "PP-006: own language is read first")
    check(BookLanguage.allCases.map(\.rawValue) == ["en", "de", "ru"], "PP-006: pack language codes")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
