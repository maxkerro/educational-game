import Foundation
import AppKit
import PagePalsCore

enum SolverError: LocalizedError {
    case noImage
    case tooManyItems
    case http(Int, String)
    case badReply(String)
    case incomplete

    var errorDescription: String? {
        switch self {
        case .noImage: return "could not cut out the task image"
        case .tooManyItems: return "too many answer fields for one request"
        case .http(let code, let text): return "the AI service answered \(code): \(text)"
        case .badReply(let text): return "unexpected reply: \(text.prefix(120))"
        case .incomplete: return "the AI did not give an answer for every field"
        }
    }
}

/// Asks Claude to work out the answers of one task by looking at it.
///
/// Only the image of this one task is sent (the zone of the page), with a red letter drawn into every
/// empty field, plus the task's instruction text. The reply is a small JSON object: letter -> answer.
/// The result is a guess: it is marked `KeySource.ai` and a grown-up can correct it.
struct ClaudeAnswerSolver {
    let apiKey: String
    let model: String

    func solve(task: PlayTask, page: CGImage) async throws -> AnswerKey {
        guard task.items.count <= 26 else { throw SolverError.tooManyItems }
        guard let jpeg = Self.annotatedJPEG(task: task, page: page) else { throw SolverError.noImage }
        let letters = task.items.enumerated().map { (AnswerParser.letter($0.offset), $0.element) }

        let text = Self.prompt(task: task, letters: letters)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": text]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw SolverError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]],
              let reply = content.compactMap({ $0["text"] as? String }).first else {
            throw SolverError.badReply(String(data: data, encoding: .utf8) ?? "")
        }
        return try Self.parse(reply: reply, task: task, letters: letters)
    }

    // MARK: Prompt and reply

    static func prompt(task: PlayTask, letters: [(String, TaskItem)]) -> String {
        var text = "This image is one task from a children's workbook. The task says: \"\(task.prompt)\". "
        text += "Every field the child has to fill in is marked with a red letter. "
        if task.kind == .numberInOrder {
            text += "Each marked circle must get the number of the printed word list entry that its picture belongs to. "
            text += "Follow each circle's line to the object it points to, then read the numbered word list in the image. "
            text += "Every number is used once. Answer with whole numbers."
        } else {
            text += "Work out the correct answer for each marked field (count things, follow lines, calculate). "
            text += "Write each answer as the book asks: a number word such as \"four\" when it says to write words, otherwise digits."
        }
        let labelled = letters.compactMap { letter, item in item.label.map { "Field \(letter) is followed by the word \"\($0)\"." } }
        if !labelled.isEmpty { text += "\n" + labelled.joined(separator: " ") }
        let example = letters.prefix(2).map { "\"\($0.0)\": " + (task.kind == .numberInOrder ? "1" : "\"four\"") }.joined(separator: ", ")
        text += "\nReply with ONLY a JSON object that maps each letter to its answer, for example {\(example)}. No other text."
        return text
    }

    static func parse(reply: String, task: PlayTask, letters: [(String, TaskItem)]) throws -> AnswerKey {
        do {
            return try AnswerParser.parse(reply: reply, kind: task.kind, items: letters.map { $0.1 })
        } catch AnswerParseError.incomplete {
            throw SolverError.incomplete
        } catch {
            throw SolverError.badReply(reply)
        }
    }

    // MARK: Annotated picture

    /// The task zone of the page with a red letter (A, B, C ...) drawn into each answer field, as JPEG.
    static func annotatedJPEG(task: PlayTask, page: CGImage) -> Data? {
        let zone = task.region ?? PageRect(x: 0, y: 0, width: 1, height: 1)
        let pageW = Double(page.width), pageH = Double(page.height)
        let zoneRect = CGRect(x: zone.x * pageW, y: zone.y * pageH, width: zone.width * pageW, height: zone.height * pageH)
            .integral.intersection(CGRect(x: 0, y: 0, width: pageW, height: pageH))
        guard !zoneRect.isEmpty, let piece = page.cropping(to: zoneRect) else { return nil }

        let scale = min(1.0, 1600.0 / Double(max(piece.width, piece.height)))
        let w = max(1, Int(Double(piece.width) * scale)), h = max(1, Int(Double(piece.height) * scale))
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(piece, in: CGRect(x: 0, y: 0, width: w, height: h))

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        for (index, item) in task.items.enumerated() {
            guard let r = item.region else { continue }
            let x = (r.x * pageW - zoneRect.minX) * scale
            let yTop = (r.y * pageH - zoneRect.minY) * scale
            let rw = r.width * pageW * scale, rh = r.height * pageH * scale
            let box = CGRect(x: x, y: Double(h) - yTop - rh, width: rw, height: rh)

            let letter = AnswerParser.letter(index)
            let fontSize = max(14, min(box.height * 0.85, 34))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.red
            ]
            let size = (letter as NSString).size(withAttributes: attributes)
            (letter as NSString).draw(
                at: NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2),
                withAttributes: attributes
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let annotated = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: annotated).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
