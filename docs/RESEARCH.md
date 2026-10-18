# Research notes (October 2026)

## What popular kids' learning apps do

From a 2026 roundup of children's educational apps ([Outschool: best educational apps for kids in 2026](https://outschool.com/articles/best-educational-apps-for-kids)); the article is a curated list, not a usage ranking:

| App | Main engagement mechanic |
|---|---|
| Khan Academy Kids | Structured skill path, stories, interactive exercises |
| PBS Kids Games | Mini-games with familiar characters, difficulty adapts |
| Endless Alphabet | Drag-the-letter puzzles with animated characters acting out meaning |
| Prodigy Math | RPG quest; answering questions drives progress; cosmetic rewards |
| Epic | Large library, read-aloud, comprehension quizzes |
| Duolingo | Streaks, gamified practice, speech exercises |
| Scratch | Creation instead of consumption |
| BrainPOP | Short videos then quizzes |

Common threads: **a character**, **game-style progression** (quests, streaks, rewards), **adaptive difficulty**, **instant feedback**, and making the child *think* rather than just tap.

## Interactive-worksheet tools (closest competitors)

Tools such as Liveworksheets and Wizer.me let a teacher turn a worksheet into an online, self-checking exercise (drag and drop, matching, fill in). Gap PagePals targets: they need **manual authoring per worksheet** and have **little game/progression layer**; PagePals does the conversion automatically from a whole book and wraps it in a companion/world loop. (Competitor feature set is from general knowledge; the search run for this document returned no reliable source to cite, so verify before making marketing claims.)

## Ethical design

Gamified apps for children can use manipulative exit patterns (guilt-tripping characters, hard-to-find close buttons) - see [Deceptive Patterns: children's vulnerability to exit dark patterns in gamified educational apps](https://deceptive.design/articles/the-evil-bird-and-the-right-to-disconnect-children-s-vulnerability-to-exit-dark-patterns-in-gamified-educational-apps). PagePals commits to avoiding these (see CONCEPT.md, design principle 4).

Academic work on gamification design features for children's learning apps: [Design Features of Learning Apps for Mobile Gamification](https://journals.uc.edu/index.php/vl/article/view/6394) and [Design patterns to support gamification-based learning activities](https://riull.ull.es/xmlui/handle/915/4770). Not yet read in depth; to be reviewed in backlog item E7-4.

## Decision

Chosen concept: **"World + companion" (the Pal) over a self-checking, auto-converted workbook.** Reasons:

1. Companion + progression is the most widely repeated mechanic among the popular apps.
2. Keeps the child's own book as content (no content licensing).
3. Task-type mini-games are a natural fit for the sample book's exercise types.
4. Feasible for a small team on macOS with PDFKit + Vision.

## Sample book analysis

The provided sample (29 A4 landscape pages, scanned two-page spreads, no embedded text, English workbook with German hints) contains: write-in blanks, correct/wrong ticks, numbering pictures, draw-lines matching, crosswords, read-and-choose. These drive the task-type catalogue in CONCEPT.md. Because the PDF is image-only, OCR is mandatory, not optional.
