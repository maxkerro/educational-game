# PagePals

A native macOS app that turns the tasks in a scanned or digital **PDF workbook** into **interactive mini-games**, so children want to do their exercises.

> Status: planning + project skeleton. See [pp-backlog.md](pp-backlog.md) for the roadmap.

## The idea in one paragraph

A parent or teacher imports a workbook PDF. PagePals finds every task on every page (fill in, tick correct/wrong, number the pictures, draw lines to match, crossword...) and rebuilds each one as a touch/click-friendly game. A friendly companion, the **Pal**, lives on a map made from the book's pages. Every finished task earns stars and food, the Pal grows, and new islands (chapters of the book) unlock. The child never sees "a PDF"; they see an adventure. The parent sees progress and can fix any task the app misread.

## Why this concept

Researched popular children's learning apps (Khan Academy Kids, Prodigy Math, Duolingo, Endless Alphabet, PBS Kids, Epic, ...). The mechanics they share: character + story, game-style progression, adaptive difficulty, instant feedback. PagePals combines a **companion that grows** and a **world map** with **instant self-checking tasks**, while keeping the child's own book as the content. Details and sources: [docs/RESEARCH.md](docs/RESEARCH.md).

## Documents

| File | Purpose |
|---|---|
| [pp-backlog.md](pp-backlog.md) | Stories `PP-001`…, acceptance criteria, milestones (source of the board) |
| [docs/OVERVIEW.md](docs/OVERVIEW.md) | Principles, personas, test Mac, offline AI options, open questions |
| [docs/CONCEPT.md](docs/CONCEPT.md) | Product concept, child experience, task-type catalogue |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Import pipeline, data model, tech choices |
| [docs/RESEARCH.md](docs/RESEARCH.md) | Market research and sources |

## Tech (planned)

- Swift 5.9+, SwiftUI, macOS 14+ (Apple Silicon first)
- Built with Swift Package Manager and the Command Line Tools only; **full Xcode is not required**
- PDFKit (render pages) + Vision (on-device OCR and layout) for import
- Optional AI-assisted task detection (cloud, opt-in) with on-device fallback
- Local-first storage (SwiftData / JSON lesson packs); no child data leaves the Mac by default

## Repository layout

```
Package.swift                 Swift package (core library, app, checks)
Sources/PagePalsCore/         Lesson model + answer checking (UI-independent)
Sources/PagePalsImport/       PDF rendering (PDFKit) and text recognition (Vision)
Sources/PagePalsApp/          SwiftUI macOS app (Play tab, Import tab)
Sources/PagePalsChecks/       Logic checks runner (replaces XCTest, which needs Xcode)
Resources/Info.plist          App bundle metadata
build-app.sh                  Builds build/PagePals.app
prototype/index.html          Playable browser prototype of the child experience (open in any browser)
docs/                         Concept, architecture, research, picture handling
tools/picture-prototype/      Python prototype used to tune picture detection
pp-backlog.md                 Roadmap (stories and acceptance criteria)
```


## Getting started

Needs macOS 14+ and the Command Line Tools (`xcode-select --install`). No Xcode.

```bash
swift build                 # compile everything
swift run PagePalsChecks    # run the logic checks (exit code 1 on failure)
./build-app.sh              # build build/PagePals.app
open build/PagePals.app
```

Note: the Swift code was written without access to a Swift compiler, so the first build is the first compile. Fix any small errors it reports.

## Content and privacy

Workbooks are the user's own files and are processed locally; they are never committed to this repo (`samples/` is git-ignored). The app is designed for children: no ads, no tracking, no dark patterns, no guilt-trip exits.

## Pushing

- `./push.sh` stops if there are uncommitted changes, then runs `swift run PagePalsChecks` and `swift build`, then `git push`. The pre-push hook (`.githooks/pre-push`) then asks Opus to review the commits being pushed.
- A plain `git push` runs only the review hook, not the checks; use `./push.sh`. After a fresh clone run `git config core.hooksPath .githooks` once (`push.sh` also sets it).
- `./push.sh --no-verify` runs the same checks but skips the review hook.
- The review needs the Claude Code CLI to be logged in (`claude`, then `/login`). Findings are saved to `.review/last-review.md` and the push log to `.review/last-push.log`; both stay local (ignored by git). Tell Claude "Fix findings" to work through them.
- `scripts/backlog_board.py` turns `pp-backlog.md` into the data of the backlog board.
