import SwiftUI
import AppKit
import PagePalsCore

/// Plays the tasks that are not numbers, sums or ticks, on the original book page:
///  - `multipleChoice`: tap the right answer (PP-021)
///  - `matching`: drag a line from a picture to its word (PP-020)
///  - `ordering`: drag the lines into order, then check (PP-025)
///  - `openTask`: do it on paper, a grown-up confirms and the child gets the star (PP-026)
/// A grown-up does choose, matching and ordering tasks once ("Set answers"); the result is kept as the answer key.
struct InteractiveTaskView: View {
    let task: PlayTask
    let page: CGImage
    let language: BookLanguage
    /// Which book the task is in: task ids repeat from book to book, so stars are kept per book.
    let scope: String
    let onSaveKey: (AnswerKey) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key: AnswerKey?
    @State private var authoring = false
    @State private var choice: String?
    @State private var pairs: [String: String] = [:]
    @State private var board: OrderingBoard
    @State private var checked = false
    @State private var wrongTries = 0
    @State private var starsGiven = false
    @State private var drag: DragLine?
    @State private var wiggle: String?
    @State private var gate = AdultGate(seed: UInt64.random(in: 1...UInt64.max))
    @State private var gateAnswer = ""
    @State private var confirming = false

    struct DragLine: Equatable {
        var source: String
        var point: CGPoint
    }

    init(task: PlayTask, page: CGImage, language: BookLanguage, scope: String, onSaveKey: @escaping (AnswerKey) -> Void) {
        self.task = task
        self.page = page
        self.language = language
        self.scope = scope
        self.onSaveKey = onSaveKey
        _key = State(initialValue: task.key)
        // the printed order is the scrambled one; if a key exists and the print is already in order, start shuffled
        var start = OrderingBoard(itemIds: task.items.map(\.id))
        if let order = task.key?.order, !order.isEmpty {
            let solution = order.sorted { $0.value < $1.value }.map(\.key)
            if start.response() == OrderingBoard.key(solution: solution) { start = OrderingBoard.start(solution: solution) }
        }
        _board = State(initialValue: start)
    }

    private var zone: PageRect { task.region ?? PageRect(x: 0, y: 0, width: 1, height: 1) }
    private var sources: [TaskItem] { task.items.filter { $0.isTarget != true && $0.region != nil } }
    private var targets: [TaskItem] { task.items.filter { $0.isTarget == true && $0.region != nil } }
    private func item(_ id: String) -> TaskItem? { task.items.first { $0.id == id } }

    private var response: AnswerKey {
        switch task.kind {
        case .multipleChoice: return AnswerKey(choice: choice)
        case .matching: return AnswerKey(pairs: pairs)
        case .ordering: return board.response()
        default: return AnswerKey()
        }
    }

    private var evaluation: EvaluationResult? {
        guard !authoring, let key, task.kind != .openTask else { return nil }
        if task.kind == .ordering && !checked { return nil }
        var playable = task
        playable.key = key
        return TaskEvaluator.evaluate(task: playable, response: response)
    }

    private var canSave: Bool {
        switch task.kind {
        case .multipleChoice: return choice != nil
        case .matching: return pairs.count == sources.count && !sources.isEmpty
        case .ordering: return !task.items.isEmpty
        default: return false
        }
    }

    private var zoneImage: NSImage? {
        let rect = CGRect(
            x: zone.x * Double(page.width), y: zone.y * Double(page.height),
            width: zone.width * Double(page.width), height: zone.height * Double(page.height)
        ).integral.intersection(CGRect(x: 0, y: 0, width: page.width, height: page.height))
        guard !rect.isEmpty, let piece = page.cropping(to: rect) else { return nil }
        return NSImage(cgImage: piece, size: NSSize(width: piece.width, height: piece.height))
    }

    // MARK: - Layout

    private func point(_ r: PageRect, _ size: CGSize) -> CGPoint {
        CGPoint(x: (r.x + r.width / 2 - zone.x) / zone.width * size.width, y: (r.y + r.height / 2 - zone.y) / zone.height * size.height)
    }

    private func pageUnits(_ p: CGPoint, _ size: CGSize) -> (x: Double, y: Double) {
        (zone.x + Double(p.x / size.width) * zone.width, zone.y + Double(p.y / size.height) * zone.height)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let image = zoneImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(GeometryReader { geo in overlay(in: geo.size) })
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("This task has no picture of the page.").frame(maxHeight: .infinity)
            }
            if task.kind == .ordering { orderList }
            Divider()
            footer
        }
        .frame(minWidth: 1000, minHeight: 800)
        .environment(\.colorScheme, .light)
        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Text(task.prompt).font(.title2.weight(.semibold))
            Spacer()
            if let e = evaluation {
                Text("\(e.correct.count) right").foregroundStyle(.secondary)
            }
            Button("Close") { dismiss() }
        }
        .padding(12)
    }

    // MARK: - On the page

    @ViewBuilder
    private func overlay(in size: CGSize) -> some View {
        ZStack {
            switch task.kind {
            case .multipleChoice:
                ForEach(task.items) { it in
                    if let r = it.region {
                        let w = r.width / zone.width * size.width, h = r.height / zone.height * size.height
                        let state = choiceState(it.id)
                        Button {
                            choose(it)
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(fill(state))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(stroke(state), lineWidth: state == .neutral ? 2 : 4))
                                .frame(width: w + 16, height: h + 12)
                        }
                        .buttonStyle(.plain)
                        .position(point(r, size))
                    }
                }
            case .matching:
                matchingOverlay(in: size)
            default:
                EmptyView()
            }
        }
        .coordinateSpace(name: "zone")
    }

    private enum Look { case neutral, chosen, correct, wrong, authoring }

    private func choiceState(_ id: String) -> Look {
        guard choice == id else { return .neutral }
        if authoring { return .authoring }
        guard let e = evaluation else { return .chosen }
        return e.correct.contains("choice") ? .correct : .wrong
    }

    private func fill(_ l: Look) -> Color {
        switch l {
        case .neutral: return Color.white.opacity(0.01)
        case .chosen: return Color.accentColor.opacity(0.15)
        case .correct: return Color(red: 0.80, green: 0.95, blue: 0.80).opacity(0.8)
        case .wrong: return Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.8)
        case .authoring: return Color(red: 0.92, green: 0.86, blue: 0.98).opacity(0.8)
        }
    }

    private func stroke(_ l: Look) -> Color {
        switch l {
        case .neutral: return Color.accentColor.opacity(0.35)
        case .chosen: return .accentColor
        case .correct: return .green
        case .wrong: return .orange
        case .authoring: return .purple
        }
    }

    private func choose(_ it: TaskItem) {
        choice = it.id
        if let label = it.label { Speaker.shared.say(label, language: language) }
        if let key, !authoring, key.choice != it.id { wrongTries += 1 }
        awardIfDone()
    }

    @ViewBuilder
    private func matchingOverlay(in size: CGSize) -> some View {
        // lines already drawn
        ForEach(Array(pairs.keys.sorted()), id: \.self) { sourceID in
            if let a = item(sourceID)?.region, let t = pairs[sourceID], let b = item(t)?.region {
                Path { p in
                    p.move(to: point(a, size))
                    p.addLine(to: point(b, size))
                }
                .stroke(authoring ? Color.purple : Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
        // the line being drawn
        if let d = drag, let a = item(d.source)?.region {
            Path { p in
                p.move(to: point(a, size))
                p.addLine(to: d.point)
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6]))
        }
        ForEach(targets) { it in
            if let r = it.region {
                Circle().stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .position(point(r, size))
            }
        }
        ForEach(sources) { it in
            if let r = it.region {
                Circle()
                    .fill(Color.accentColor.opacity(wiggle == it.id ? 0.9 : 0.35))
                    .frame(width: 30, height: 30)
                    .offset(x: wiggle == it.id ? 6 : 0)
                    .animation(.easeInOut(duration: 0.12).repeatCount(3, autoreverses: true), value: wiggle)
                    .position(point(r, size))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("zone"))
                            .onChanged { drag = DragLine(source: it.id, point: $0.location) }
                            .onEnded { dropLine(from: it.id, at: $0.location, size: size) }
                    )
            }
        }
    }

    private func dropLine(from source: String, at location: CGPoint, size: CGSize) {
        drag = nil
        let u = pageUnits(location, size)
        let boxes = targets.compactMap { t in t.region.map { LineMatching.Target(id: t.id, region: $0) } }
        switch LineMatching.drop(from: source, atX: u.x, y: u.y, targets: boxes, key: authoring ? nil : key) {
        case .snapped(let target):
            for (s, t) in pairs where t == target { pairs[s] = nil }
            pairs[source] = target
            awardIfDone()
        case .wrong:
            wrongTries += 1
            wiggle = source
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { wiggle = nil }
        case .missed:
            break
        }
    }

    // MARK: - Ordering

    private var orderList: some View {
        List {
            ForEach(board.itemIds, id: \.self) { id in
                HStack {
                    Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                    Text(item(id)?.label ?? id).font(.title3)
                    Spacer()
                    if let e = evaluation {
                        Image(systemName: e.correct.contains(id) ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                            .foregroundStyle(e.correct.contains(id) ? Color.green : Color.orange)
                    }
                }
                .padding(.vertical, 4)
            }
            .onMove { from, to in
                checked = false
                var ids = board.itemIds
                ids.move(fromOffsets: from, toOffset: to)
                board = OrderingBoard(itemIds: ids)
            }
        }
        .frame(height: min(CGFloat(board.itemIds.count) * 44 + 20, 300))
    }

    // MARK: - Footer

    private func awardIfDone() {
        guard !starsGiven, !authoring, let e = evaluation, e.isComplete else { return }
        starsGiven = true
        StarStore.award(StarLedger.stars(complete: true, wrongTries: wrongTries), task: PackMerge.starKey(scope: scope, task: task.id))
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            if task.kind == .openTask {
                openFooter
            } else if authoring {
                Text(authoringHint)
                Spacer()
                Button("Cancel") { authoring = false; choice = nil; pairs = [:] }
                Button("Save answers") { saveKey() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            } else if let e = evaluation, e.isComplete {
                Text("\u{2B50} All correct. Well done!").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            } else if key == nil {
                Text("The correct answers are not saved yet. A grown-up can set them once.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set answers (grown-up)") { startAuthoring() }
            } else {
                Text(playHint).foregroundStyle(.secondary)
                Spacer()
                if task.kind == .ordering { Button("Check") { checked = true; awardOrderingOrCount() }.buttonStyle(.borderedProminent) }
                Button("Change answers (grown-up)") { startAuthoring() }
            }
        }
        .padding(12)
    }

    private func awardOrderingOrCount() {
        if let e = evaluation, !e.isComplete { wrongTries += 1 }
        awardIfDone()
    }

    private var authoringHint: String {
        switch task.kind {
        case .multipleChoice: return "Grown-up: tap the right answer, then save."
        case .matching: return "Grown-up: draw a line from every picture to its word, then save."
        default: return "Grown-up: drag the lines into the right order, then save."
        }
    }

    private var playHint: String {
        switch task.kind {
        case .multipleChoice: return "Tap the right answer."
        case .matching: return "Draw a line from each picture to its word."
        default: return "Drag the lines into the right order, then press Check."
        }
    }

    private func startAuthoring() {
        authoring = true
        choice = nil
        pairs = [:]
        checked = false
    }

    private func saveKey() {
        let newKey = response
        key = newKey
        onSaveKey(newKey)
        authoring = false
        choice = nil
        pairs = [:]
        board = OrderingBoard(itemIds: task.items.map(\.id))
    }

    @ViewBuilder
    private var openFooter: some View {
        if starsGiven {
            Text("\u{2B50} Well done!").font(.title3.weight(.semibold))
            Spacer()
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
        } else if confirming {
            Text("Grown-up: what is \(gate.question)")
            TextField("", text: $gateAnswer).frame(width: 80).textFieldStyle(.roundedBorder)
            Button("Confirm") {
                if gate.accepts(gateAnswer) {
                    starsGiven = true
                    StarStore.award(3, task: PackMerge.starKey(scope: scope, task: task.id))
                } else {
                    gateAnswer = ""
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Button("Cancel") { confirming = false; gateAnswer = "" }
        } else {
            Text("Do this task in your book. Press Done when you have finished.").foregroundStyle(.secondary)
            Spacer()
            Button("Done") { confirming = true }.buttonStyle(.borderedProminent)
        }
    }
}
