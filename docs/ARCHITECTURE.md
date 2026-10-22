# Architecture

## Overview

```
PDF  ->  Page images  ->  OCR + layout  ->  Task detection  ->  Lesson Pack (JSON)  ->  Parent review  ->  Interactive player
         (PDFKit)         (Vision)          (rules + optional AI)   (PagePalsCore)        (SwiftUI)          (SwiftUI + SpriteKit/Canvas)
```

The **Lesson Pack** is the contract between import and play. It is plain Codable JSON, so imports can be inspected, corrected, versioned and shared.

## Modules

| Module | Responsibility | Depends on |
|---|---|---|
| `PagePalsCore` | Lesson model, answer evaluation, progress rules. Pure Swift, no UI, fully unit-tested | Foundation |
| `PagePalsImport` (planned) | PDF rendering, spread splitting, OCR, region/task detection | PDFKit, Vision, Core |
| `PagePalsPlayer` (planned) | One SwiftUI view per task kind, shared feedback/animation layer | SwiftUI, Core |
| `PagePalsWorld` (planned) | Map, Pal, rewards, streaks, persistence | SwiftData, Core |
| `PagePalsApp` (planned) | macOS app target, navigation, parent area | all |

## Import pipeline

1. **Render**: PDFKit renders each page at ~200 dpi. Scans may contain two book pages per PDF page (as in the sample); detect the gutter and split.
2. **OCR**: Vision `VNRecognizeTextRequest` (accurate mode, languages en/de/ru configurable) returns text with bounding boxes. Handwritten-style fonts in books are the weak spot, so the parent review step is a first-class feature.
3. **Layout analysis**: group text lines into blocks; find task headers by pattern (leading number + imperative such as "Write", "Tick", "Draw lines", "Number", "Crossword"); find blanks (underscores / empty boxes), tick circles and numbered bubbles with Vision rectangle detection.
4. **Task detection**:
   - Rule-based classifier maps header keywords + detected shapes to a `TaskKind`.
   - Optional AI assist: send the page image to a vision-capable model to propose tasks and answers (opt-in, shown to the parent before sending). Rule-based result is always the offline fallback.
5. **Answer keys**: books often have no answers printed. Options in priority order: (a) answer key pages in the PDF, (b) AI-proposed key, marked "unverified", (c) parent enters/approves. Unverified tasks are playable in "parent confirms" mode.
6. **Lesson Pack**: write tasks, regions (normalised 0-1 coordinates over the page image), items and keys to JSON, with a confidence score per task.
7. **Review UI**: parent sees the page with detected regions, can retype text, redraw boxes, change task kind, or mark "skip".

## Data model (see `Sources/PagePalsCore`)

- `LessonPack` -> `Page[]` -> `PlayTask[]` -> `TaskItem[]`
- `PlayTask.kind`: `fillIn`, `trueFalse`, `numberInOrder`, `matching`, `crossword`, `multipleChoice`
- `AnswerKey`: dictionaries keyed by item id (text, boolean, order, pair)
- `TaskResponse`: the child's answers, same shape as the key
- `TaskEvaluator.evaluate(task:response:)` returns per-item correctness, so the UI can give targeted hints

## Player

- Page image is the background; each task is an overlay positioned by its normalised region.
- Interaction components are reused across task kinds (draggable token, drop target, text slot, rope line).
- Feedback layer: confetti, Pal reactions, sound, text-to-speech (AVSpeechSynthesizer).
- Accessibility: VoiceOver labels, large hit targets, reduced-motion option.

## Persistence

- Lesson packs: JSON files in the app container (`Application Support/PagePals/Books/<id>/`) with the page images.
- Progress, Pal state, settings: SwiftData.
- No network access required for normal play.

## Quality and safety

- Unit tests for the evaluator and pack encoding (CI via GitHub Actions on macOS runner).
- Golden-file tests for import: a small set of synthetic pages with expected detection output (real books are never committed).
- Privacy: no analytics SDKs; any AI call is opt-in and sends only the page image the parent approved.

## Key risks

| Risk | Mitigation |
|---|---|
| OCR/detection errors on decorative book layouts | Parent review editor; confidence scores; fall back to "open task" |
| No answer key | Unverified mode + parent confirm; AI-suggested keys flagged |
| Copyright of books | Local processing of the user's own file only; nothing redistributed |
| Child over-engagement | Calm session limits, no streak punishment |

## Build tooling (no Xcode)

The project builds with the Command Line Tools only:

- Swift Package Manager builds the library and the SwiftUI app as an executable target; `build-app.sh` wraps the binary in `PagePals.app` (Info.plist + ad-hoc codesign).
- PDFKit, Vision, SwiftUI and AVFoundation are part of the macOS SDK and available without Xcode.
- XCTest ships only with Xcode, so logic checks run as the `PagePalsChecks` executable instead. If Xcode becomes available, they can be ported to XCTest or Swift Testing.
- Not available without Xcode: Interface Builder, asset catalogs compiled by `actool` (use plain PNG/ICNS files in Resources), the SwiftUI previews canvas, and the iOS simulator.
