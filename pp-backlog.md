# PagePals Backlog

Project: PagePals (`PP`) · Repo: https://github.com/maxkerro/educational-game · Board: https://claude.ai/artifact/8BrEbdQn5Re1a3Lh7shBFb
Updated: 2026-10-28

Story numbers: `PP-001`… follow the old epic order (A1 = PP-001 … I7 = PP-073); the old number is kept in each title, e.g. `(D2)`. Status `doing` on a story means partly done; unchecked criteria are still open.

## Milestones

| ID | Name | Group | Goal |
|----|------|----------|------|
| M1 | Play a real page | Core app | A real book page becomes playable pages (numbers, sums, ticks); the grown-up types answers where needed. |
| M2 | Answers without a grown-up, offline | Core app | Sums, answer pages, crosswords and word searches are solved by rules; pictures are matched to words by an on-device model. |
| M3 | All task types | Core app | Matching lines, multiple choice, circling, ordering, crossword, word search and open tasks have a page. |
| M4 | Three subjects | Core app | Open an English, a Math or a German PDF workbook and get an interactive page for each task, with answers recognised. |
| M5 | Game and parent area | Game & parents | Pal, stars, world map; progress, time limits, profiles, review editor. |
| M6 | Release | Release | Accessibility, localisation, signed and notarised app. |
| IMP | Improvements | Ongoing | Smaller enhancements between milestones. |

## M1 — Play a real page

### PP-001 — Open a PDF workbook (A1)
- **Status:** done
- **Area:** Open a book · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want to open a PDF workbook on my Mac so that its pages are shown in the app.
- **Description:** A grown-up opens a PDF workbook and the app keeps it. Checked on a 29-page two-page-spread scan.
- **Acceptance criteria:**
  - [x] Open PDF… picker, pages drawn at 200 dpi, Previous / Next
  - [x] Works with scanned books (photos of pages)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A1.

### PP-007 — Find every task on a page (B1)
- **Status:** done
- **Area:** Recognise the tasks on a page · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want each numbered task to be found with its instruction so that each task becomes its own page.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E1-4.
- **Acceptance criteria:**
  - [x] Headers like '1. Number.' and '4. How many lollies? Trace the lines and write.' found, also with a pencil icon in front
  - [x] Spreads give tasks for both pages
  - [ ] Test pages measure ≥ 90% of headers found (see B10)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B1.

### PP-009 — Find empty circles to fill (B3)
- **Status:** done
- **Area:** Recognise the tasks on a page · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want empty answer circles to be found so that a task can ask the child for a number there.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-12.
- **Acceptance criteria:**
  - [x] 9 of 9 answer circles found on the sample page, printed circles and loops in scribbles ignored
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B3.

### PP-010 — Find grey answer bars (B4)
- **Status:** done
- **Area:** Recognise the tasks on a page · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want grey answer bars to be found so that a task can ask the child to write there.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-13.
- **Acceptance criteria:**
  - [x] 8 of 8 bars found on the sample page
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B4.

### PP-011 — Find tick circles (B5)
- **Status:** done
- **Area:** Recognise the tasks on a page · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want the correct / wrong circles to be found in columns and rows so that a task can ask the child to tick.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-15.
- **Acceptance criteria:**
  - [x] 8 of 8 grey circles found; the column headed 'correct' is detected
- **Tests:** Sources/PagePalsChecks/main.swift (AC1)
- **Commits:** 
- **Notes:** Old id B5.

### PP-017 — Put numbers into circles (C1)
- **Status:** done
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to type a number into each empty circle on my page so that I can number the pictures.
- **Description:** The child sees the book page and answers on it. Old E3-4.
- **Acceptance criteria:**
  - [x] Original page with white input circles, big dark digits
  - [x] Right = green, wrong = orange, all right = 'All correct'
  - [x] Grown-up can set the answers once
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C1.

### PP-018 — Write answers into boxes (C2)
- **Status:** done
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to write a number or a word into each grey box so that I can solve sums and fill in gaps.
- **Description:** The child sees the book page and answers on it. Old E3-2.
- **Acceptance criteria:**
  - [x] '4', 'four' and 'vier' all count
  - [x] Judged when typed fully or with Return
- **Tests:** Sources/PagePalsChecks/main.swift (AC1)
- **Commits:** 
- **Notes:** Old id C2.

### PP-019 — Tick correct or wrong (C3)
- **Status:** done
- **Area:** Play: one interactive page per task · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to tap 'correct' or 'wrong' in each row so that I can say if a sentence fits the picture.
- **Description:** The child sees the book page and answers on it. Old E3-3.
- **Acceptance criteria:**
  - [x] Tappable circles with a check mark, per-row feedback
- **Tests:** Sources/PagePalsChecks/main.swift (AC1)
- **Commits:** 
- **Notes:** Old id C3.

### PP-031 — Calculate simple sums (D1)
- **Status:** done
- **Area:** Answers without a grown-up, offline · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want answers of 'three + one =' to be calculated so that I do not type them.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. Old E9-13.
- **Acceptance criteria:**
  - [x] Digits and number words, English and German, + and −
  - [x] Negative results are rejected
- **Tests:** Sources/PagePalsChecks/main.swift (AC1, AC2)
- **Commits:** 
- **Notes:** Old id D1.

### PP-041 — Type the answers once when nothing else works (D11)
- **Status:** done
- **Area:** Answers without a grown-up, offline · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want to type an answer only when the app cannot find it so that no task is stuck.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. Replaces the removed AI answers (no API key).
- **Acceptance criteria:**
  - [x] Tasks without a found answer show 'A grown-up must set the answers'
  - [x] Typed answers are saved per book on the Mac and always win
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D11.

### PP-053 — Review what the app recognised (G1)
- **Status:** done
- **Area:** Parent area and review · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want to see tasks, answer fields and pictures drawn on the page so that I can check them quickly.
- **Description:** Grown-ups stay in control without doing the work. Old E2-1.
- **Acceptance criteria:**
  - [x] Import tab shows text, pictures, circles, bars and tasks per page
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G1.

### PP-062 — Automatic checks (H3)
- **Status:** doing
- **Area:** Quality, privacy and offline · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a maintainer, I want checks to run before every push so that a bad change cannot reach GitHub.
- **Description:** Safe for children, works without the internet. Old E0-4, E7-6.
- **Acceptance criteria:**
  - [x] `swift run PagePalsChecks` has over 110 checks and runs first in `push.sh`, before `git push` and the review hook
  - [ ] Recognition quality checks on the test pages (B10)
  - [ ] GitHub Actions runs build and checks
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H3. Partly done.

### PP-067 — Build without Xcode (I1)
- **Status:** done
- **Area:** Build and delivery · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a maintainer, I want to build with Swift Package Manager and Command Line Tools only so that I do not need Xcode.
- **Description:** Easy to build without Xcode, safe to publish. Old E0-3.
- **Acceptance criteria:**
  - [x] `./build-app.sh` makes PagePals.app, ad-hoc signed
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I1.

### PP-068 — Rebuild and start in one command (I2)
- **Status:** done
- **Area:** Build and delivery · **Points:** 2 · **Priority:** Could · **Depends on:** —
- **Story:** As a maintainer, I want `./rebuild.sh` so that I try a change in seconds.
- **Description:** Easy to build without Xcode, safe to publish. Old E0-9.
- **Acceptance criteria:**
  - [x] Quits the old app, builds, starts the new one
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I2.

### PP-069 — Push safely (I3)
- **Status:** doing
- **Area:** Build and delivery · **Points:** 2 · **Priority:** Should · **Depends on:** —
- **Story:** As a maintainer, I want `./push.sh` to run the checks and an Opus review before the push so that only checked work reaches GitHub.
- **Description:** Easy to build without Xcode, safe to publish. Old E0-8.
- **Acceptance criteria:**
  - [x] `push.sh` and `.githooks/pre-push` exist; `push.sh` runs the checks and build first, then `git push` starts the Opus review hook
  - [ ] A full run passes once (Claude login must be renewed first)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I3. Partly done. Review 2: `push.sh` stops when there are uncommitted changes, so the checks always test what is pushed.

## M2 — Answers without a grown-up, offline

### PP-032 — Calculate every kind of maths task (D2)
- **Status:** doing
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want all arithmetic tasks to be solved by the app so that a Math book needs no typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [x] + − × ÷ with digits and number words 0–100 (English, German), usual precedence
  - [x] Missing number (3 + _ = 7), comparing (<, >, =), number sequences with one gap
  - [ ] Written columns, money, time and measures with units
  - [ ] Each solved example from the sample books matches the book's key
- **Tests:** Sources/PagePalsChecks/main.swift (AC1, AC2)
- **Commits:** f6ba927
- **Notes:** Old id D2. Partly done.

### PP-033 — Read the answer pages of the book (D3)
- **Status:** doing
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Should · **Depends on:** PP-003
- **Story:** As a parent, I want the app to read the answer key printed at the back of a book so that every task with a key needs no typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. Old E1-9.
- **Acceptance criteria:**
  - [x] Key pages are found (heading + 'n. answers' lines) and answers are matched by task number to number and fill-in tasks
  - [ ] The importer reads all pages of a book first and applies the key before any other method
  - [ ] Source 'answer page' shown to the grown-up (D12)
- **Tests:** Sources/PagePalsChecks/main.swift (AC1)
- **Commits:** b7dbbbf, 3bb0abc
- **Notes:** Old id D3. Partly done. Review 1 (2026-10-27): heading must consist only of key words ('Answer the questions' is a task page); entries keep their page/unit group and a task only gets a key when exactly one entry fits (pass the printed page to apply); fill-in success test added. Multi-word answers need a comma in the key. Review 2 (2026-10-28): keys in two or three columns are read column by column (a heading belongs to the nearest column, and a column starts without a group); headings 'Pages 12-13' or 'Seite 10/11' start an unknown group that is never used; 'S. 10' and 'Lösungen zu Seite 10' are read; 'Lösung', 'Solution' and a lone 'Answer' on the first line count as key headings. Grouped keys need the printed page number, which comes with PP-003 (AC3).

### PP-034 — Solve crosswords from the printed word list (D4)
- **Status:** doing
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Should · **Depends on:** PP-015
- **Story:** As a parent, I want crossword answers to be found by fitting the word list so that crosswords need no typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. Old E9-5.
- **Acceptance criteria:**
  - [x] Words are placed by length and crossing letters
  - [x] Unique solution found; if not unique, marked for the grown-up
  - [ ] Fed by the recognised crossword grid (B9)
- **Tests:** Sources/PagePalsChecks/main.swift (AC1, AC2)
- **Commits:** b7dbbbf, 3bb0abc
- **Notes:** Old id D4. Partly done. Review 1: the same word listed twice is not a second solution; sharp s counts as one letter. Review 2: ß and capital ẞ are one letter, and a word with ß also fits a slot as 'SS' (STRASSE); 'Dog' and 'DOG' are the same word.

### PP-035 — Solve word searches (D5)
- **Status:** doing
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Should · **Depends on:** PP-015
- **Story:** As a parent, I want words to be found in the letter grid by search so that word searches need no typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [x] All 8 directions searched
  - [x] Words found once give their position; others are marked for the grown-up
  - [ ] Fed by the recognised letter grid (B9)
- **Tests:** Sources/PagePalsChecks/main.swift (AC1, AC2)
- **Commits:** b7dbbbf, 3bb0abc
- **Notes:** Old id D5. Partly done. Review 1: palindromes (MUM) count once; all 8 directions, found-twice and sharp s are tested. Review 2: a word with ß is also searched as 'SS' (STRASSE) and a capital ẞ cell matches.

### PP-036 — Match pictures to words with an on-device model (D6)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 8 · **Priority:** Must · **Depends on:** PP-039
- **Story:** As a parent, I want the app to know which picture is a 'pencil case' or a 'ruler' so that matching and numbering tasks need no typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. Replaces the removed cloud solver.
- **Acceptance criteria:**
  - [ ] An image-text model on the Mac (for example MobileCLIP in Core ML) scores each picture against the words of the task
  - [ ] On the sample school-objects page at least 7 of 9 circles are right (measured, see D9)
  - [ ] Low-confidence matches are marked for the grown-up
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D6.

### PP-037 — Count things in a picture (D7)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 8 · **Priority:** Should · **Depends on:** PP-039
- **Story:** As a parent, I want the app to count animals or objects in a picture so that 'There are two ladybirds' can be judged.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [ ] Counts repeated small objects on the sample page correctly in at least 3 of 4 rows
  - [ ] Uncertain counts are marked for the grown-up
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D7.

### PP-039 — Choose the offline AI runtime (spike) (D9)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a maintainer, I want to try the on-device options on the real sample pages so that I choose by measured results, not by guesses.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API. See 'Offline AI options' in docs/OVERVIEW.md.
- **Acceptance criteria:**
  - [ ] Try first, because they run on macOS 15 on the test Mac: an open vision-language model with MLX Swift (for example SmolVLM2 or Qwen2-VL, 4-bit) and a Core ML CLIP model
  - [ ] Apple Foundation Models only if the Mac is upgraded to a newer macOS (it is not available on macOS 15)
  - [ ] Measure on the 9 circles, the 4 tick rows and the 4 lollies
  - [ ] Measure speed and memory on the test Mac (M2 Max, 32 GB) and write down the minimum Mac that still works
  - [ ] A model is downloaded once or put in place from a file; after that no network is used
  - [ ] Decision written to docs/OFFLINE_AI.md
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D9.

### PP-040 — Trust an answer only when methods agree (D10)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want each answer to carry a confidence so that only doubtful answers bother me.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [ ] Calculation, answer page and model results are compared
  - [ ] Agreement = trusted; disagreement or low score = marked
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D10.

### PP-060 — Work completely offline (H1)
- **Status:** doing
- **Area:** Quality, privacy and offline · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want the app to need no internet after setup so that it works anywhere and nothing leaves the Mac.
- **Description:** Safe for children, works without the internet.
- **Acceptance criteria:**
  - [x] No cloud API is used (the removed AI answers were the only network feature)
  - [ ] The app has no network access in its sandbox settings
  - [ ] A test with the network switched off passes
  - [ ] Only a one-time model download is allowed, and a model can also be put in place from a file
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H1. Partly done.

## M3 — All task types

### PP-003 — Split two-page spreads into book pages (A3)
- **Status:** doing
- **Area:** Open a book · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want each book page to be its own page with its printed page number so that I can say 'page 10' and find it.
- **Description:** A grown-up opens a PDF workbook and the app keeps it. Old E1-2.
- **Acceptance criteria:**
  - [x] Tasks on the left and the right page are found separately
  - [ ] The image is split at the gutter
  - [ ] The printed page number is read and shown
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A3. Partly done.

### PP-004 — Keep imported books in a library (A4)
- **Status:** todo
- **Area:** Open a book · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want a book to be recognised once and then stay in my library so that it opens fast the next time and my answers are not lost.
- **Description:** A grown-up opens a PDF workbook and the app keeps it. Replaces E1-7, E9-2, E6-6.
- **Acceptance criteria:**
  - [ ] Lesson Pack (JSON + picture files) is written after import and read on start
  - [ ] Cut-out pictures are saved as files, not recomputed
  - [ ] Rename and delete a book
  - [ ] Pack has a version number and loads older versions
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A4.

### PP-005 — See import progress, cancel and resume (A5)
- **Status:** todo
- **Area:** Open a book · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want to see how far the import is and to stop it so that a long book does not block me.
- **Description:** A grown-up opens a PDF workbook and the app keeps it. Old E1-10.
- **Acceptance criteria:**
  - [ ] Progress per page, Cancel button
  - [ ] Resumes after quit without redoing finished pages
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A5.

### PP-008 — Cut out the pictures exactly as in the book (B2)
- **Status:** doing
- **Area:** Recognise the tasks on a page · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to see the same pictures as in my book so that I recognise them and the page feels familiar.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-1, E9-11.
- **Acceptance criteria:**
  - [x] Pictures are found and shown as boxes and thumbnails
  - [ ] Page shadows, grey arrow shapes and the gutter are not reported as pictures
  - [ ] Stacked pictures are not merged
  - [ ] Small drawings are not missed
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B2. Partly done.

### PP-012 — Find writing lines, boxes, check boxes and bubbles (B6)
- **Status:** todo
- **Area:** Recognise the tasks on a page · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want all other answer places to be found so that more task types work.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E1-5.
- **Acceptance criteria:**
  - [ ] Writing lines and boxes
  - [ ] Square check boxes and round bubbles with a letter or number
  - [ ] Each field is attached to the right task
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B6.

### PP-013 — Recognise the task type (B7)
- **Status:** doing
- **Area:** Recognise the tasks on a page · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want the app to decide how a task is played so that I do not choose types by hand.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E1-6.
- **Acceptance criteria:**
  - [x] Numbers, fill-in and tick are chosen from the shapes found
  - [ ] Words in the header ('Draw lines', 'Circle', 'Match', 'Colour', 'Crossword', 'Read and choose') choose the type
  - [ ] Unknown tasks become open tasks
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B7. Partly done.

### PP-014 — Link each picture to its word or sentence (B8)
- **Status:** todo
- **Area:** Recognise the tasks on a page · **Points:** 8 · **Priority:** Must · **Depends on:** PP-008
- **Story:** As a child, I want every picture to belong to the right word so that the matching and numbering pages use my book's own pictures.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-3.
- **Acceptance criteria:**
  - [ ] Crossword: picture next to the first cell
  - [ ] Fill-in: picture right of the blank
  - [ ] Word list: by order and closeness
  - [ ] Wrong links can be fixed in the review editor (G2)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B8.

### PP-015 — Recognise crosswords and word searches (B9)
- **Status:** todo
- **Area:** Recognise the tasks on a page · **Points:** 8 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want crossword grids and letter grids to be found so that those tasks can be played.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E9-4, E9-7.
- **Acceptance criteria:**
  - [ ] Crossword cells found on a curved or tilted photo, numbered across / down
  - [ ] Letter grid read cell by cell (single letters are not reliable in plain OCR)
  - [ ] Printed word list read
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B9.

### PP-016 — Test pages for recognition (B10)
- **Status:** todo
- **Area:** Recognise the tasks on a page · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a maintainer, I want synthetic test pages with known answers so that I can measure recognition and catch regressions.
- **Description:** The app finds each task, its answer fields and its pictures by itself. Old E0-6, E7-6.
- **Acceptance criteria:**
  - [ ] At least 10 generated pages, every task type at least twice, no copyrighted content
  - [ ] A report shows found / missed per page
  - [ ] `swift run PagePalsChecks` runs it
- **Tests:** 
- **Commits:** 
- **Notes:** Old id B10.

### PP-020 — Draw lines to match (C4)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to draw a line from a picture to its word so that I can match like in my book.
- **Description:** The child sees the book page and answers on it. Old E3-5.
- **Acceptance criteria:**
  - [ ] Drag from a start point to an end point, line snaps
  - [ ] Wrong line wiggles back gently
  - [ ] Works picture-word and picture-picture
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C4.

### PP-021 — Choose one answer (C5)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want to tap the right answer among several so that I can do 'read and choose' tasks.
- **Description:** The child sees the book page and answers on it. Old E3-6.
- **Acceptance criteria:**
  - [ ] Options as buttons with the book's text or pictures
  - [ ] Text can be read aloud (C12)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C5.

### PP-022 — Circle or underline (C6)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want to circle or underline the right words or pictures so that I can do 'find and circle' tasks.
- **Description:** The child sees the book page and answers on it.
- **Acceptance criteria:**
  - [ ] Tap to circle, tap again to remove
  - [ ] Feedback per item
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C6.

### PP-023 — Solve a crossword with picture clues (C7)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 8 · **Priority:** Should · **Depends on:** PP-015
- **Story:** As a child, I want to fill a crossword whose clues are my book's pictures so that it looks like my book.
- **Description:** The child sees the book page and answers on it. Old E3-7, E9-6.
- **Acceptance criteria:**
  - [ ] Rebuilt grid, original pictures as clues
  - [ ] Keyboard input, per-letter feedback
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C7.

### PP-024 — Find words in a letter grid (C8)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 8 · **Priority:** Should · **Depends on:** PP-015
- **Story:** As a child, I want to swipe over words in the grid and cross them off the list so that I can do word searches.
- **Description:** The child sees the book page and answers on it. Old E9-8.
- **Acceptance criteria:**
  - [ ] Swipe selection, found words crossed off
  - [ ] Then the sentences next to the drawings can be filled in
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C8.

### PP-025 — Put things in order (C9)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want to drag words, sentences or pictures into order so that I can do ordering tasks.
- **Description:** The child sees the book page and answers on it.
- **Acceptance criteria:**
  - [ ] Drag and drop with snap
  - [ ] Feedback per position
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C9.

### PP-026 — Do open tasks on paper and confirm (C10)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want a page even for drawing, colouring or speaking tasks so that no task is skipped.
- **Description:** The child sees the book page and answers on it. Old E3-8.
- **Acceptance criteria:**
  - [ ] Shows the task page and a 'Done' button
  - [ ] A grown-up confirms, the star is given
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C10.

## M4 — Three subjects

### PP-006 — Read English, German and Russian text (A6)
- **Status:** doing
- **Area:** Open a book · **Points:** 5 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want the text of my books to be read correctly so that tasks and answers are found.
- **Description:** A grown-up opens a PDF workbook and the app keeps it. Old E1-3.
- **Acceptance criteria:**
  - [x] English and German text recognised (Apple Vision, on device)
  - [ ] Russian recognised
  - [ ] Language per book, mixed-language pages work
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A6. Partly done.

### PP-038 — Answer reading and grammar tasks with a local language model (D8)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 8 · **Priority:** Should · **Depends on:** PP-039
- **Story:** As a parent, I want German and English reading and grammar tasks to be answered by an on-device model so that Lückentext, articles, plural and reading questions need little typing.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [ ] Runs offline, answers with a confidence
  - [ ] Answers agree with the book's key on at least 80% of a sample set
  - [ ] Without the model the app still works (grown-up types)
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D8.

### PP-043 — English workbook (E1)
- **Status:** doing
- **Area:** Subjects: English, Math, German · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want my English book's tasks to be playable so that I can learn words and sentences by doing.
- **Description:** The end goal: open a PDF of any of the three subjects and get a playable page for each task.
- **Acceptance criteria:**
  - [x] Numbering, fill-in and tick tasks work on a real English book
  - [ ] Matching lines, crosswords, word searches, circling, multiple choice work
  - [ ] At least 80% of the tasks of one real book are playable and at least 70% of them have answers found automatically
- **Tests:** 
- **Commits:** 
- **Notes:** Old id E1. Partly done.

### PP-044 — Math workbook (E2)
- **Status:** todo
- **Area:** Subjects: English, Math, German · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want my Math book's tasks to be playable so that I can practise numbers by doing.
- **Description:** The end goal: open a PDF of any of the three subjects and get a playable page for each task.
- **Acceptance criteria:**
  - [ ] Arithmetic, number lines, comparing, sequences, counting, simple word problems and shapes
  - [ ] At least 80% playable and at least 90% with answers calculated
- **Tests:** 
- **Commits:** 
- **Notes:** Old id E2.

### PP-045 — German workbook (E3)
- **Status:** todo
- **Area:** Subjects: English, Math, German · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want my German book's tasks to be playable so that I can practise reading and writing by doing.
- **Description:** The end goal: open a PDF of any of the three subjects and get a playable page for each task.
- **Acceptance criteria:**
  - [ ] Lückentext, der / die / das, plural, spelling, reading questions
  - [ ] At least 80% playable and at least 60% with answers found automatically
- **Tests:** 
- **Commits:** 
- **Notes:** Old id E3.

## M5 — Game and parent area

### PP-002 — Open books by drag and drop and from a recent list (A2)
- **Status:** todo
- **Area:** Open a book · **Points:** 2 · **Priority:** Could · **Depends on:** —
- **Story:** As a parent, I want to drop a PDF on the window or pick it from a recent list so that starting a lesson takes one step.
- **Description:** A grown-up opens a PDF workbook and the app keeps it.
- **Acceptance criteria:**
  - [ ] Drop a PDF on the window opens it
  - [ ] Last 5 books are listed on the start screen
- **Tests:** 
- **Commits:** 
- **Notes:** Old id A2.

### PP-027 — Get hints that do not give the answer away (C11)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want a small hint when I am stuck so that I learn instead of guessing.
- **Description:** The child sees the book page and answers on it. Old E3-9.
- **Acceptance criteria:**
  - [ ] After two wrong tries the field is highlighted
  - [ ] Then the first letter or the matching word is shown
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C11.

### PP-028 — Hear words read aloud (C12)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want to tap a word or sentence and hear it so that I learn how it sounds, also when I cannot read yet.
- **Description:** The child sees the book page and answers on it. Old E5-8.
- **Acceptance criteria:**
  - [ ] Works offline with the voices installed on the Mac (English, German)
  - [ ] Speed control
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C12.

### PP-042 — See where an answer came from (D12)
- **Status:** todo
- **Area:** Answers without a grown-up, offline · **Points:** 2 · **Priority:** Could · **Depends on:** —
- **Story:** As a parent, I want each answer to say 'calculated', 'answer page', 'on-device AI' or 'grown-up' so that I can judge how much to trust it.
- **Description:** The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API.
- **Acceptance criteria:**
  - [ ] Source label on the task card and in the review editor
- **Tests:** 
- **Commits:** 
- **Notes:** Old id D12.

### PP-046 — Grow a Pal with stars (F1)
- **Status:** todo
- **Area:** Game layer · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want a friend that grows when I finish tasks so that I want to learn more.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-1, E5-2.
- **Acceptance criteria:**
  - [ ] Three growth stages, original art
  - [ ] Stars per task
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F1.

### PP-047 — Travel a world map (F2)
- **Status:** todo
- **Area:** Game layer · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a child, I want a map where every chapter is an island so that I see how far I am.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-3.
- **Acceptance criteria:**
  - [ ] Chapters = islands, pages = stops, calm unlocking
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F2.

### PP-048 — Gentle daily streak (F3)
- **Status:** todo
- **Area:** Game layer · **Points:** 2 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want to be cheered for coming back so that it feels good, not bad, when I miss a day.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-6.
- **Acceptance criteria:**
  - [ ] No loss framing, no guilt messages
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F3.

### PP-049 — Pal reacts (F4)
- **Status:** todo
- **Area:** Game layer · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want my Pal to cheer, comfort or nap so that it feels alive.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-4.
- **Acceptance criteria:**
  - [ ] Cheer on right, comfort on wrong, nap when I stop
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F4.

### PP-050 — Sounds and music (F5)
- **Status:** todo
- **Area:** Game layer · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want friendly sounds with a mute button so that it is fun and not loud.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-7.
- **Acceptance criteria:**
  - [ ] Mute and volume, all sounds optional
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F5.

### PP-051 — Room with collectibles (F6)
- **Status:** todo
- **Area:** Game layer · **Points:** 8 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want to decorate a room with things I earned so that I have something of my own.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-5.
- **Acceptance criteria:**
  - [ ] Earned, never bought
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F6.

### PP-054 — Correct what the app got wrong (G2)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 8 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want to move or resize boxes, change the task type and fix answers so that a wrong recognition is not the end.
- **Description:** Grown-ups stay in control without doing the work. Old E2-2..E2-6, E9-10.
- **Acceptance criteria:**
  - [ ] Drag and resize fields and pictures
  - [ ] Change task type, prompt and answers
  - [ ] Assign a picture to a word
  - [ ] Undo and redo
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G2.

### PP-055 — Open the grown-up area safely (G3)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want a simple adult gate so that children cannot change answers or limits.
- **Description:** Grown-ups stay in control without doing the work. Old E6-1.
- **Acceptance criteria:**
  - [ ] A small adult challenge before the area opens
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G3.

### PP-056 — See progress (G4)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want pages done, accuracy and hard items so that I know where my child needs help.
- **Description:** Grown-ups stay in control without doing the work. Old E6-2.
- **Acceptance criteria:**
  - [ ] Per child, per book, per task type
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G4.

### PP-057 — Set a daily time limit (G5)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want a calm end of the session so that screen time stays in my hands.
- **Description:** Grown-ups stay in control without doing the work. Old E6-3.
- **Acceptance criteria:**
  - [ ] The Pal says goodbye, no cut-off in the middle of a task
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G5.

### PP-058 — Several children (G6)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want a profile per child on this Mac so that each child has their own progress.
- **Description:** Grown-ups stay in control without doing the work. Old E6-4.
- **Acceptance criteria:**
  - [ ] Local profiles, no accounts
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G6.

## M6 — Release

### PP-029 — Write by hand (C13)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 13 · **Priority:** Could · **Depends on:** —
- **Story:** As a child, I want to write with the trackpad or a pencil so that writing feels natural.
- **Description:** The child sees the book page and answers on it. Old E3-10.
- **Acceptance criteria:**
  - [ ] Handwriting recognised on device for letters and digits
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C13.

### PP-030 — Use big targets, keyboard and reduced motion (C14)
- **Status:** todo
- **Area:** Play: one interactive page per task · **Points:** 2 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want big buttons and calm movement so that I can use the app easily.
- **Description:** The child sees the book page and answers on it. Old E3-11.
- **Acceptance criteria:**
  - [ ] Large-target mode
  - [ ] Reduced-motion setting is respected
- **Tests:** 
- **Commits:** 
- **Notes:** Old id C14.

### PP-052 — Mini games from known words (F7)
- **Status:** todo
- **Area:** Game layer · **Points:** 13 · **Priority:** Could · **Depends on:** —
- **Story:** As a child, I want short games with words I have learned so that I can repeat without a workbook.
- **Description:** Children want to come back by themselves. No dark patterns. Old E5-9, E4-3.
- **Acceptance criteria:**
  - [ ] Words with right answers become a quick game
- **Tests:** 
- **Commits:** 
- **Notes:** Old id F7.

### PP-059 — Export progress (G7)
- **Status:** todo
- **Area:** Parent area and review · **Points:** 2 · **Priority:** Could · **Depends on:** —
- **Story:** As a parent, I want to export progress as PDF or CSV so that I can share it with a teacher.
- **Description:** Grown-ups stay in control without doing the work. Old E6-5.
- **Acceptance criteria:**
  - [ ] PDF and CSV
- **Tests:** 
- **Commits:** 
- **Notes:** Old id G7.

### PP-061 — No accounts, no tracking (H2)
- **Status:** todo
- **Area:** Quality, privacy and offline · **Points:** 2 · **Priority:** Must · **Depends on:** —
- **Story:** As a parent, I want no accounts and no analytics so that my child's data stays private.
- **Description:** Safe for children, works without the internet. Old E7-3.
- **Acceptance criteria:**
  - [ ] Privacy review documented
  - [ ] No third-party SDKs
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H2.

### PP-063 — Fair design checklist (H4)
- **Status:** todo
- **Area:** Quality, privacy and offline · **Points:** 2 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want the app to follow a checklist against dark patterns so that it helps children and does not trap them.
- **Description:** Safe for children, works without the internet. Old E7-4.
- **Acceptance criteria:**
  - [ ] Checklist in docs, reviewed before release
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H4.

### PP-064 — Use with VoiceOver and keyboard (H5)
- **Status:** todo
- **Area:** Quality, privacy and offline · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a child, I want every control to be reachable and described so that everyone can play.
- **Description:** Safe for children, works without the internet. Old E7-1.
- **Acceptance criteria:**
  - [ ] Labels and focus order for all players
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H5.

### PP-065 — App text in English, German and Russian (H6)
- **Status:** todo
- **Area:** Quality, privacy and offline · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want the app's own menus in my language so that I understand it.
- **Description:** Safe for children, works without the internet. Old E7-2.
- **Acceptance criteria:**
  - [ ] UI strings in en, de, ru
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H6.

### PP-066 — Try it with children (H7)
- **Status:** todo
- **Area:** Quality, privacy and offline · **Points:** 8 · **Priority:** Should · **Depends on:** —
- **Story:** As a maintainer, I want 3 to 5 children to try the app so that I learn what works.
- **Description:** Safe for children, works without the internet. Old E7-5.
- **Acceptance criteria:**
  - [ ] Notes and changes recorded
- **Tests:** 
- **Commits:** 
- **Notes:** Old id H7.

### PP-070 — App icon and name check (I4)
- **Status:** todo
- **Area:** Build and delivery · **Points:** 2 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want a friendly icon and a free name so that the app is easy to find.
- **Description:** Easy to build without Xcode, safe to publish. Old E8-1.
- **Acceptance criteria:**
  - [ ] Icon, trademark check for 'PagePals'
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I4.

### PP-071 — Signed and notarised app (I5)
- **Status:** todo
- **Area:** Build and delivery · **Points:** 5 · **Priority:** Should · **Depends on:** —
- **Story:** As a parent, I want to install the app without warnings so that I trust it.
- **Description:** Easy to build without Xcode, safe to publish. Old E8-2.
- **Acceptance criteria:**
  - [ ] Code signing, notarisation, DMG
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I5.

### PP-072 — Decide on the Mac App Store (I6)
- **Status:** todo
- **Area:** Build and delivery · **Points:** 5 · **Priority:** Could · **Depends on:** —
- **Story:** As a maintainer, I want a decision about the store so that I know the rules for kids' apps.
- **Description:** Easy to build without Xcode, safe to publish. Old E8-3.
- **Acceptance criteria:**
  - [ ] Kids category rules and privacy labels reviewed
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I6.

### PP-073 — Code style checks (I7)
- **Status:** todo
- **Area:** Build and delivery · **Points:** 2 · **Priority:** Could · **Depends on:** —
- **Story:** As a maintainer, I want a formatter and linter so that the code stays tidy.
- **Description:** Easy to build without Xcode, safe to publish. Old E0-5.
- **Acceptance criteria:**
  - [ ] SwiftLint or swift-format configured
- **Tests:** 
- **Commits:** 
- **Notes:** Old id I7.

## IMP — Improvements
