import SwiftUI
import UniformTypeIdentifiers
import PagePalsCore
import PagePalsImport

/// Import tab: open a workbook PDF, see each page with what the app found.
/// Blue boxes are pictures (cut out and kept), green dashed boxes are word lists or letter grids,
/// thin boxes are text (green = confident, orange = check), purple circles are empty answer circles.
struct ImportView: View {
    @StateObject private var model = ImportModel()
    @State private var showImporter = false
    @State private var playing: PlayTask?
    @State private var showAISettings = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                pagePane
                Divider()
                sidePane
                    .frame(width: 300)
            }
        }
        .sheet(item: $playing) { task in
            if let page = model.pageBitmap {
                TaskPlayerView(task: task, page: page) { model.saveKey($0, for: task.id) }
            }
        }
        .sheet(isPresented: $showAISettings) { AISettingsView() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { model.open(url: url) }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Open PDF\u{2026}") { showImporter = true }
            Button("Previous") { model.previous() }.disabled(!model.canGoBack)
            Button("Next") { model.next() }.disabled(!model.canGoForward)
            Button("AI answers\u{2026}") { showAISettings = true }
            if model.isWorking || !model.solving.isEmpty { ProgressView().controlSize(.small) }
            Text(model.status)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(12)
    }

    private var pagePane: some View {
        Group {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            ForEach(model.lines) { line in
                                outline(line.box, in: geo.size)
                                    .stroke(textColor(line), lineWidth: 1)
                            }
                            ForEach(Array(model.circles.enumerated()), id: \.offset) { _, circle in
                                outline(circle, in: geo.size)
                                    .stroke(Color.purple, lineWidth: 2.5)
                            }
                            ForEach(Array(model.blanks.enumerated()), id: \.offset) { _, bar in
                                outline(bar, in: geo.size)
                                    .stroke(Color.teal, lineWidth: 2)
                            }
                            ForEach(model.regions) { region in
                                if region.kind == .picture {
                                    outline(region.box, in: geo.size)
                                        .stroke(Color.blue, lineWidth: 2.5)
                                } else {
                                    outline(region.box, in: geo.size)
                                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
                                }
                            }
                        }
                    })
                    .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("No page yet").foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks (\(model.tasks.count))").font(.headline)
                    if model.tasks.isEmpty {
                        Text("Found tasks appear here.").foregroundStyle(.secondary)
                    }
                    ForEach(model.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.prompt).fontWeight(.medium)
                            Text(taskSummary(task)).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Play") { playing = task }
                                    .disabled(task.kind != .numberInOrder && task.kind != .fillIn && task.kind != .trueFalse)
                                if model.canSolve(task) {
                                    Button("Find answers (AI)") {
                                        if AISettings.shared.isReady { model.solve(task) } else { showAISettings = true }
                                    }
                                    .disabled(model.solving.contains(task.id))
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pictures (\(model.crops.count))").font(.headline)
                    if model.crops.isEmpty {
                        Text("Cut-out pictures appear here.").foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(model.crops) { crop in
                            Image(nsImage: crop.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 72)
                                .padding(4)
                                .background(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.5)))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Text").font(.headline)
                    if model.lines.isEmpty {
                        Text("Recognised text appears here.").foregroundStyle(.secondary)
                    }
                    ForEach(model.lines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle().fill(textColor(line)).frame(width: 8, height: 8)
                            Text(line.text).textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func outline(_ box: PageRect, in size: CGSize) -> Path {
        Path(CGRect(
            x: box.x * size.width,
            y: box.y * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        ))
    }

    private func keyNote(_ task: PlayTask) -> String {
        switch task.keySource {
        case .calculated: return " (answers calculated)"
        case .ai: return " (answers: AI guess, please check)"
        case .parent: return " (answers set by a grown-up)"
        case nil: return " (answers not set)"
        }
    }

    private func taskSummary(_ task: PlayTask) -> String {
        switch task.kind {
        case .numberInOrder:
            return "Numbers into \(task.items.count) circles" + keyNote(task)
        case .trueFalse:
            return "Tick correct or wrong in \(task.items.count) rows" + keyNote(task)
        case .fillIn:
            return "Fill in \(task.items.count) answers" + keyNote(task)
        default:
            return "Not recognised yet: a grown-up confirms"
        }
    }

    private func textColor(_ line: RecognizedLine) -> Color {
        line.confidence >= 0.8 ? .green : .orange
    }
}

/// Opt-in switch and key for AI-found answers. Off by default.
struct AISettingsView: View {
    @ObservedObject private var settings = AISettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI answers").font(.title2.weight(.semibold))
            Text("PagePals can find the correct answers of a task by itself, so a grown-up does not have to type them. "
                 + "When this is on, the picture of one task (a part of one book page, with letters drawn into the empty fields) "
                 + "and its instruction text are sent to Anthropic's API using your key. Nothing else is sent. "
                 + "Answers found this way are marked as an AI guess and a grown-up can correct them. "
                 + "Sums such as \"three + one =\" are always calculated on this Mac, without AI.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Let the AI find answers while importing", isOn: $settings.enabled)

            VStack(alignment: .leading, spacing: 4) {
                Text("Anthropic API key").font(.headline)
                SecureField("sk-ant-...", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Kept in the macOS Keychain. If empty, the ANTHROPIC_API_KEY environment variable is used.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model").font(.headline)
                TextField("claude-sonnet-5-5", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
