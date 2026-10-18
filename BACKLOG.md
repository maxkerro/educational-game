# PagePals Backlog

Priority: **P0** must have for MVP, **P1** important, **P2** later. Size: S (<1 day), M (1-3 days), L (3-7 days), XL (>1 week).
Status legend: `[ ]` todo, `[x]` done.

## Milestones

| Milestone | Goal | Epics |
|---|---|---|
| **M0 Foundations** | Repo, CI, Xcode app shell, core model | E0 |
| **M1 Walking skeleton** | One real book page -> one working interactive task, end to end | E1, E2 (partial), E3 (fill-in only) |
| **M2 MVP** | All catalogue task types play correctly from an imported book, with parent review | E1-E4 |
| **M3 Game layer** | World map, Pal, stars, streaks | E5 |
| **M4 Parent features** | Progress, time limits, answer keys | E6 |
| **M5 Polish and release** | Accessibility, sound/voice, notarised build | E7, E8 |

---

## E0 Foundations (M0)

- [x] **E0-1 Concept, architecture, research docs** (P0, S) - this repo.
- [x] **E0-2 Swift package with core model + evaluator + tests** (P0, S) - `PagePalsCore`. *First compile still to be verified on a Mac.*
- [ ] **E0-3 Create macOS SwiftUI app target in Xcode** (P0, S). AC: app launches, shows empty library, depends on `PagePalsCore`.
- [ ] **E0-4 GitHub Actions CI (macOS runner: build + test)** (P0, S). AC: green badge on README.
- [ ] **E0-5 SwiftLint/swift-format config** (P2, S).
- [ ] **E0-6 Synthetic sample pages for tests** (P0, M). AC: 5+ generated pages covering each task type, no copyrighted content.

## E1 Import pipeline (M1-M2)

- [ ] **E1-1 PDF picker + page rendering at 200 dpi** (P0, M). AC: drop a PDF on the window, thumbnails of all pages appear.
- [ ] **E1-2 Spread splitting** (P1, M). Detect gutter in two-page scans and split into logical pages. AC: sample book spreads become single pages with correct page numbers.
- [ ] **E1-3 OCR with Vision (en/de/ru)** (P0, M). AC: text blocks with normalised bounding boxes stored per page; language configurable.
- [ ] **E1-4 Task header detection** (P0, M). Numbered headers + instruction keywords ("Write", "Tick", "Draw lines", "Number", "Crossword", "Read and ..."). AC: >=80% of headers found on the sample book (measured by golden test).
- [ ] **E1-5 Blank / checkbox / bubble detection** (P0, L). Vision rectangle + contour detection for write-in lines, tick circles, numbered bubbles. AC: regions attached to the right task.
- [ ] **E1-6 Task kind classifier (rules)** (P0, M). Maps header + shapes to `TaskKind`; unknown -> `openTask`.
- [ ] **E1-7 Lesson Pack writer/reader (JSON, versioned)** (P0, S).
- [ ] **E1-8 Optional AI-assisted detection (opt-in)** (P1, L). Vision model proposes tasks + answers from page image; parent sees exactly what will be sent; offline fallback always works. AC: toggle in settings, off by default.
- [ ] **E1-9 Answer key extraction from key pages** (P1, M).
- [ ] **E1-10 Import progress UI + cancel + resume** (P1, M).
- [ ] **E1-11 Crossword grid detection** (P1, L).

## E2 Parent review editor (M1-M2)

- [ ] **E2-1 Page view with detected regions overlay** (P0, M).
- [ ] **E2-2 Edit task: kind, prompt, expected answers** (P0, M).
- [ ] **E2-3 Draw/move/resize regions** (P0, M).
- [ ] **E2-4 Confidence indicator + "needs review" queue** (P1, S).
- [ ] **E2-5 Mark task as skip / as "parent-checked"** (P1, S).
- [ ] **E2-6 Undo/redo** (P2, M).

## E3 Interactive task players (M1-M2)

- [ ] **E3-1 Player shell: page background + overlay + feedback bar** (P0, M).
- [ ] **E3-2 Fill-in player** (P0, M). Tap blank, type or pick tiles; instant check with hint after 2 misses. *(M1 target)*
- [ ] **E3-3 True/False (tick) player** (P0, S).
- [ ] **E3-4 Number-in-order player** (P0, M). Drag numbers onto pictures.
- [ ] **E3-5 Matching (draw lines) player** (P0, L). Rope drag, snap, wiggle on wrong.
- [ ] **E3-6 Multiple-choice (read and choose) player** (P1, M). Text read aloud.
- [ ] **E3-7 Crossword player** (P1, L).
- [ ] **E3-8 Open-task player (parent confirms)** (P0, M). Fallback for anything undetected.
- [ ] **E3-9 Hint system** (P1, M). Progressive: highlight area -> first letter -> reveal.
- [ ] **E3-10 Handwriting input (trackpad / Apple Pencil via Sidecar)** (P2, XL).
- [ ] **E3-11 Reduced-motion and large-target modes** (P1, S).

## E4 Evaluation and adaptive difficulty (M2)

- [x] **E4-1 Evaluator for all kinds** (P0, M) - in `PagePalsCore` (text, boolean, order, pair).
- [ ] **E4-2 Per-item attempt tracking** (P0, S).
- [ ] **E4-3 Spaced repetition: re-offer missed items later as mini-review** (P1, L).
- [ ] **E4-4 Adaptive hints/difficulty from error history** (P2, L).

## E5 Game layer (M3)

- [ ] **E5-1 Pal selection and 3 growth stages (original art)** (P0, L).
- [ ] **E5-2 Stars and food rewards per task** (P0, M).
- [ ] **E5-3 World map: chapters = islands, pages = stops, locks** (P0, L).
- [ ] **E5-4 Pal reactions (cheer, comfort, nap)** (P1, M).
- [ ] **E5-5 Room/wardrobe with collectibles** (P1, L).
- [ ] **E5-6 Gentle daily streak (no loss framing)** (P1, S).
- [ ] **E5-7 Sound effects and music with mute** (P1, M).
- [ ] **E5-8 Text-to-speech for target-language phrases** (P1, M).
- [ ] **E5-9 Mini bonus games from mastered vocabulary** (P2, XL).

## E6 Parent area (M4)

- [ ] **E6-1 Parent gate (simple adult challenge)** (P0, S).
- [ ] **E6-2 Progress dashboard: pages done, accuracy, hard items** (P1, M).
- [ ] **E6-3 Daily time limit and calm end-of-session** (P1, M).
- [ ] **E6-4 Multiple children profiles (local)** (P1, M).
- [ ] **E6-5 Export progress (PDF/CSV)** (P2, S).
- [ ] **E6-6 Library management: import, rename, delete books** (P0, S).

## E7 Quality, accessibility, ethics (M5)

- [ ] **E7-1 VoiceOver labels and keyboard navigation** (P1, M).
- [ ] **E7-2 Localisation: UI in en/de/ru** (P1, M).
- [ ] **E7-3 Privacy review: no analytics, no accounts, data stays local** (P0, S).
- [ ] **E7-4 Ethical-design checklist (no dark patterns) and read the gamification papers in RESEARCH.md** (P1, S).
- [ ] **E7-5 Usability tests with 3-5 children and parents** (P1, L).
- [ ] **E7-6 Import golden tests on synthetic pages** (P0, M).

## E8 Distribution (M5)

- [ ] **E8-1 App icon, name check, trademark check for "PagePals"** (P1, S).
- [ ] **E8-2 Code signing, notarisation, DMG** (P1, M).
- [ ] **E8-3 Decide on Mac App Store (Kids category rules, privacy labels)** (P2, M).
- [ ] **E8-4 Landing page** (P2, M).

---

## First sprint proposal (reach M1)

1. E0-3 app target, E0-4 CI
2. E1-1 render pages, E1-3 OCR
3. E3-1 player shell + E3-2 fill-in player
4. E1-7 pack JSON, hand-authored pack for one page of the sample book as the first end-to-end demo
5. E2-1 region overlay (read-only), to see what OCR found

Definition of done: a child can open one page of the sample book and fill in "three + one = ..." as an interactive task with instant feedback.

## Open questions

1. Primary language pair and age range to tune first? (Assumed: English workbook, German-speaking child, ages 6-8.)
2. Is AI-assisted detection acceptable for the user's privacy stance, or on-device only?
3. Mac only, or iPad later (the SwiftUI code is designed to port)?
4. Do the books come with answer keys?
