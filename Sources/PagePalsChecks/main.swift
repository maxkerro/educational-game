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

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
