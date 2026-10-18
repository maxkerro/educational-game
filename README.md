# PagePals

A native macOS app that turns the tasks in a scanned or digital **PDF workbook** into **interactive mini-games**, so children want to do their exercises.

> Status: planning + project skeleton. See [BACKLOG.md](BACKLOG.md) for the roadmap.

## The idea in one paragraph

A parent or teacher imports a workbook PDF. PagePals finds every task on every page (fill in, tick correct/wrong, number the pictures, draw lines to match, crossword...) and rebuilds each one as a touch/click-friendly game. A friendly companion, the **Pal**, lives on a map made from the book's pages. Every finished task earns stars and food, the Pal grows, and new islands (chapters of the book) unlock. The child never sees "a PDF"; they see an adventure. The parent sees progress and can fix any task the app misread.

## Why this concept

Researched popular children's learning apps (Khan Academy Kids, Prodigy Math, Duolingo, Endless Alphabet, PBS Kids, Epic, ...). The mechanics they share: character + story, game-style progression, adaptive difficulty, instant feedback. PagePals combines a **companion that grows** and a **world map** with **instant self-checking tasks**, while keeping the child's own book as the content. Details and sources: [docs/RESEARCH.md](docs/RESEARCH.md).

## Documents

| File | Purpose |
|---|---|
| [BACKLOG.md](BACKLOG.md) | Prioritised epics, stories, acceptance criteria, milestones |
| [docs/CONCEPT.md](docs/CONCEPT.md) | Product concept, child experience, task-type catalogue |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Import pipeline, data model, tech choices |
| [docs/RESEARCH.md](docs/RESEARCH.md) | Market research and sources |

## Tech (planned)

- Swift 5.9+, SwiftUI, macOS 14+ (Apple Silicon first)
- PDFKit (render pages) + Vision (on-device OCR and layout) for import
- Optional AI-assisted task detection (cloud, opt-in) with on-device fallback
- Local-first storage (SwiftData / JSON lesson packs); no child data leaves the Mac by default

## Repository layout

```
Package.swift                 Swift package (core library + tests)
Sources/PagePalsCore/         Lesson model + answer checking (UI-independent)
Tests/PagePalsCoreTests/      Unit tests
prototype/index.html          Playable browser prototype of the child experience (open in any browser)
docs/                         Concept, architecture, research
BACKLOG.md                    Roadmap
```

The macOS app target (SwiftUI) is created in Xcode in backlog item **E0-3**; the core library is already usable from it.

## Getting started

```bash
swift build
swift test
```

Requires Xcode 15+ on macOS 14+. Note: the skeleton was written without access to a Swift compiler, so the first `swift test` run is the first compile. Fix any small errors it reports.

## Content and privacy

Workbooks are the user's own files and are processed locally; they are never committed to this repo (`samples/` is git-ignored). The app is designed for children: no ads, no tracking, no dark patterns, no guilt-trip exits.
