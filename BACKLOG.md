# PagePals – Product Backlog

> **Goal:** open a PDF workbook (English, Math or German) and get an **interactive page for every task**, where the child selects or enters the answer. The app recognises the correct answers **by itself and offline**; a grown-up types an answer only as the last resort.

Updated 22 Oct 2026 · Master copy: `BACKLOG.md` in the repo · Overview of what is built: `README.md`

## Principles

- **Same book, same pictures.** The page in the app looks like the page in the book, with the book's own pictures.
- **One task, one interactive page.** Never a loose set of pictures.
- **Answers found automatically.** Rules and calculation first, then on-device models. A grown-up types answers only when nothing else works.
- **Offline and private.** No internet needed to play or import, no cloud API, no account, no analytics.
- **Three subjects.** English, Math and German workbooks.
- **Kind to children.** No dark patterns, gentle feedback.
- **Easy to build.** Swift Package Manager and Command Line Tools only, no Xcode.

## Status at a glance

Stories: **73** · ✅ done **13** · 🟡 partly **9** · ⬜ to do **51**

| Epic | Stories | ✅ | 🟡 | ⬜ |
|---|---:|---:|---:|---:|
| [A · Open a book](#epic-a) | 6 | 1 | 2 | 3 |
| [B · Recognise the tasks on a page](#epic-b) | 10 | 4 | 2 | 4 |
| [C · Play: one interactive page per task](#epic-c) | 14 | 3 | 0 | 11 |
| [D · Answers without a grown-up, offline](#epic-d) | 12 | 2 | 1 | 9 |
| [E · Subjects: English, Math, German](#epic-e) | 3 | 0 | 1 | 2 |
| [F · Game layer](#epic-f) | 7 | 0 | 0 | 7 |
| [G · Parent area and review](#epic-g) | 7 | 1 | 0 | 6 |
| [H · Quality, privacy and offline](#epic-h) | 7 | 0 | 2 | 5 |
| [I · Build and delivery](#epic-i) | 7 | 2 | 1 | 4 |

**Legend:** ✅ done and checked on the Mac · 🟡 partly done (see the ticked and open criteria) · ⬜ to do. Priority **P0** must have, **P1** important, **P2** later. Size **S** < 1 day, **M** 1–3 days, **L** 3–7 days, **XL** > 1 week. Criteria with `[x]` are met.

## Milestones

| | Milestone | What the user can do | Stories |
|---|---|---|---|
| 🟡 **M1** | Play a real page | A real book page becomes playable pages (numbers, sums, ticks); the grown-up types answers where needed. | A1, B1, B3, B4, B5, C1, C2, C3, D1, D11, G1, H3, I1, I2, I3 |
| 🟡 **M2** | Answers without a grown-up, offline | Sums, answer pages, crosswords and word searches are solved by rules; pictures are matched to words by an on-device model. | D2, D3, D4, D5, D6, D7, D9, D10, H1 |
| 🟡 **M3** | All task types | Matching lines, multiple choice, circling, ordering, crossword, word search and open tasks have a page. | A3, A4, A5, B2, B6, B7, B8, B9, B10, C4, C5, C6, C7, C8, C9, C10 |
| 🟡 **M4** | Three subjects | Open an English, a Math or a German PDF workbook and get an interactive page for each task, with answers recognised. | A6, D8, E1, E2, E3 |
| ⬜ **M5** | Game and parent area | Pal, stars, world map; progress, time limits, profiles, review editor. | A2, C11, C12, D12, F1, F2, F3, F4, F5, F6, G2, G3, G4, G5, G6 |
| ⬜ **M6** | Release | Accessibility, localisation, signed and notarised app. | C13, C14, F7, G7, H2, H4, H5, H6, H7, I4, I5, I6, I7 |

## Personas

- **Child** (6–9 years): wants to play and answer on a page that looks like the book.
- **Parent / grown-up**: loads the books, wants to type as little as possible, stays in control.
- **Maintainer**: builds and releases the app.

## Test machine

MacBook Pro 14-inch (2023), Apple M2 Max, 32 GB memory, macOS 15.8. The app targets macOS 14 or newer.

## Offline AI options

Order of methods, from simple to heavy; each step works without the internet:

1. **Rules and calculation:** sums, number words, answer pages, crossword fitting, word-search scanning (D1–D5).
2. **Classic on-device ML:** Apple Vision (text, shapes), Natural Language (word similarity, en/de), an image-text model in Core ML such as [MobileCLIP](https://github.com/apple/ml-mobileclip) to match pictures to words (D6).
3. **Optional local language / vision model** for reading, grammar and counting (D7, D8). Candidates, to be measured in spike D9:
   - **Open vision-language model with MLX Swift** (for example SmolVLM2 or Qwen2-VL, see [mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples)): downloaded once or copied from a file, then fully offline. Fits the test Mac (Apple silicon, 32 GB): a 4-bit model of a few GB runs there. **First candidate.**
   - **Core ML CLIP-style model** such as [MobileCLIP](https://github.com/apple/ml-mobileclip) for picture-word matching only (small, fast). **First candidate for D6.**
   - **Apple Foundation Models framework:** the on-device model accepts image input in the newest OS generation and needs no server ([WWDC26 session](https://developer-rno.apple.com/videos/play/wwdc2026/241), [overview](https://callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new)). It needs a much newer macOS than the test Mac has (15.8), so it is **not an option today**; revisit after an OS upgrade.

The app must stay usable when no model is installed (then answers are calculated, read from answer pages, or typed once by a grown-up). The earlier cloud solver was removed because it needed an API key and the internet.

## Epic A · Open a book
<a id="epic-a"></a>

_A grown-up opens a PDF workbook and the app keeps it._

### A1 · Open a PDF workbook ✅

**As a** parent, **I want** to open a PDF workbook on my Mac, **so that** its pages are shown in the app.

- [x] Open PDF… picker, pages drawn at 200 dpi, Previous / Next
- [x] Works with scanned books (photos of pages)

`Done` · `P0` · `M` · `M1` · Checked on a 29-page two-page-spread scan.

### A2 · Open books by drag and drop and from a recent list ⬜

**As a** parent, **I want** to drop a PDF on the window or pick it from a recent list, **so that** starting a lesson takes one step.

- [ ] Drop a PDF on the window opens it
- [ ] Last 5 books are listed on the start screen

`To do` · `P2` · `S` · `M5`

### A3 · Split two-page spreads into book pages 🟡

**As a** parent, **I want** each book page to be its own page with its printed page number, **so that** I can say 'page 10' and find it.

- [x] Tasks on the left and the right page are found separately
- [ ] The image is split at the gutter
- [ ] The printed page number is read and shown

`Partly done` · `P1` · `M` · `M3` · Old E1-2.

### A4 · Keep imported books in a library ⬜

**As a** parent, **I want** a book to be recognised once and then stay in my library, **so that** it opens fast the next time and my answers are not lost.

- [ ] Lesson Pack (JSON + picture files) is written after import and read on start
- [ ] Cut-out pictures are saved as files, not recomputed
- [ ] Rename and delete a book
- [ ] Pack has a version number and loads older versions

`To do` · `P0` · `L` · `M3` · Replaces E1-7, E9-2, E6-6.

### A5 · See import progress, cancel and resume ⬜

**As a** parent, **I want** to see how far the import is and to stop it, **so that** a long book does not block me.

- [ ] Progress per page, Cancel button
- [ ] Resumes after quit without redoing finished pages

`To do` · `P1` · `M` · `M3` · Old E1-10.

### A6 · Read English, German and Russian text 🟡

**As a** parent, **I want** the text of my books to be read correctly, **so that** tasks and answers are found.

- [x] English and German text recognised (Apple Vision, on device)
- [ ] Russian recognised
- [ ] Language per book, mixed-language pages work

`Partly done` · `P0` · `M` · `M4` · Old E1-3.

## Epic B · Recognise the tasks on a page
<a id="epic-b"></a>

_The app finds each task, its answer fields and its pictures by itself._

### B1 · Find every task on a page ✅

**As a** parent, **I want** each numbered task to be found with its instruction, **so that** each task becomes its own page.

- [x] Headers like '1. Number.' and '4. How many lollies? Trace the lines and write.' found, also with a pencil icon in front
- [x] Spreads give tasks for both pages
- [ ] Test pages measure ≥ 90% of headers found (see B10)

`Done` · `P0` · `M` · `M1` · Old E1-4.

### B2 · Cut out the pictures exactly as in the book 🟡

**As a** child, **I want** to see the same pictures as in my book, **so that** I recognise them and the page feels familiar.

- [x] Pictures are found and shown as boxes and thumbnails
- [ ] Page shadows, grey arrow shapes and the gutter are not reported as pictures
- [ ] Stacked pictures are not merged
- [ ] Small drawings are not missed

`Partly done` · `P0` · `L` · `M3` · Old E9-1, E9-11.

### B3 · Find empty circles to fill ✅

**As a** parent, **I want** empty answer circles to be found, **so that** a task can ask the child for a number there.

- [x] 9 of 9 answer circles found on the sample page, printed circles and loops in scribbles ignored

`Done` · `P0` · `M` · `M1` · Old E9-12.

### B4 · Find grey answer bars ✅

**As a** parent, **I want** grey answer bars to be found, **so that** a task can ask the child to write there.

- [x] 8 of 8 bars found on the sample page

`Done` · `P0` · `S` · `M1` · Old E9-13.

### B5 · Find tick circles ✅

**As a** parent, **I want** the correct / wrong circles to be found in columns and rows, **so that** a task can ask the child to tick.

- [x] 8 of 8 grey circles found; the column headed 'correct' is detected

`Done` · `P0` · `S` · `M1` · Old E9-15.

### B6 · Find writing lines, boxes, check boxes and bubbles ⬜

**As a** parent, **I want** all other answer places to be found, **so that** more task types work.

- [ ] Writing lines and boxes
- [ ] Square check boxes and round bubbles with a letter or number
- [ ] Each field is attached to the right task

`To do` · `P0` · `L` · `M3` · Old E1-5.

### B7 · Recognise the task type 🟡

**As a** parent, **I want** the app to decide how a task is played, **so that** I do not choose types by hand.

- [x] Numbers, fill-in and tick are chosen from the shapes found
- [ ] Words in the header ('Draw lines', 'Circle', 'Match', 'Colour', 'Crossword', 'Read and choose') choose the type
- [ ] Unknown tasks become open tasks

`Partly done` · `P0` · `M` · `M3` · Old E1-6.

### B8 · Link each picture to its word or sentence ⬜

**As a** child, **I want** every picture to belong to the right word, **so that** the matching and numbering pages use my book's own pictures.

- [ ] Crossword: picture next to the first cell
- [ ] Fill-in: picture right of the blank
- [ ] Word list: by order and closeness
- [ ] Wrong links can be fixed in the review editor (G2)

`To do` · `P0` · `L` · `M3` · Old E9-3.

### B9 · Recognise crosswords and word searches ⬜

**As a** parent, **I want** crossword grids and letter grids to be found, **so that** those tasks can be played.

- [ ] Crossword cells found on a curved or tilted photo, numbered across / down
- [ ] Letter grid read cell by cell (single letters are not reliable in plain OCR)
- [ ] Printed word list read

`To do` · `P1` · `L` · `M3` · Old E9-4, E9-7.

### B10 · Test pages for recognition ⬜

**As a** maintainer, **I want** synthetic test pages with known answers, **so that** I can measure recognition and catch regressions.

- [ ] At least 10 generated pages, every task type at least twice, no copyrighted content
- [ ] A report shows found / missed per page
- [ ] `swift run PagePalsChecks` runs it

`To do` · `P0` · `M` · `M3` · Old E0-6, E7-6.

## Epic C · Play: one interactive page per task
<a id="epic-c"></a>

_The child sees the book page and answers on it._

### C1 · Put numbers into circles ✅

**As a** child, **I want** to type a number into each empty circle on my page, **so that** I can number the pictures.

- [x] Original page with white input circles, big dark digits
- [x] Right = green, wrong = orange, all right = 'All correct'
- [x] Grown-up can set the answers once

`Done` · `P0` · `M` · `M1` · Old E3-4.

### C2 · Write answers into boxes ✅

**As a** child, **I want** to write a number or a word into each grey box, **so that** I can solve sums and fill in gaps.

- [x] '4', 'four' and 'vier' all count
- [x] Judged when typed fully or with Return

`Done` · `P0` · `M` · `M1` · Old E3-2.

### C3 · Tick correct or wrong ✅

**As a** child, **I want** to tap 'correct' or 'wrong' in each row, **so that** I can say if a sentence fits the picture.

- [x] Tappable circles with a check mark, per-row feedback

`Done` · `P0` · `S` · `M1` · Old E3-3.

### C4 · Draw lines to match ⬜

**As a** child, **I want** to draw a line from a picture to its word, **so that** I can match like in my book.

- [ ] Drag from a start point to an end point, line snaps
- [ ] Wrong line wiggles back gently
- [ ] Works picture-word and picture-picture

`To do` · `P0` · `L` · `M3` · Old E3-5.

### C5 · Choose one answer ⬜

**As a** child, **I want** to tap the right answer among several, **so that** I can do 'read and choose' tasks.

- [ ] Options as buttons with the book's text or pictures
- [ ] Text can be read aloud (C12)

`To do` · `P0` · `M` · `M3` · Old E3-6.

### C6 · Circle or underline ⬜

**As a** child, **I want** to circle or underline the right words or pictures, **so that** I can do 'find and circle' tasks.

- [ ] Tap to circle, tap again to remove
- [ ] Feedback per item

`To do` · `P1` · `M` · `M3`

### C7 · Solve a crossword with picture clues ⬜

**As a** child, **I want** to fill a crossword whose clues are my book's pictures, **so that** it looks like my book.

- [ ] Rebuilt grid, original pictures as clues
- [ ] Keyboard input, per-letter feedback

`To do` · `P1` · `L` · `M3` · Old E3-7, E9-6.

### C8 · Find words in a letter grid ⬜

**As a** child, **I want** to swipe over words in the grid and cross them off the list, **so that** I can do word searches.

- [ ] Swipe selection, found words crossed off
- [ ] Then the sentences next to the drawings can be filled in

`To do` · `P1` · `L` · `M3` · Old E9-8.

### C9 · Put things in order ⬜

**As a** child, **I want** to drag words, sentences or pictures into order, **so that** I can do ordering tasks.

- [ ] Drag and drop with snap
- [ ] Feedback per position

`To do` · `P1` · `M` · `M3`

### C10 · Do open tasks on paper and confirm ⬜

**As a** child, **I want** a page even for drawing, colouring or speaking tasks, **so that** no task is skipped.

- [ ] Shows the task page and a 'Done' button
- [ ] A grown-up confirms, the star is given

`To do` · `P0` · `M` · `M3` · Old E3-8.

### C11 · Get hints that do not give the answer away ⬜

**As a** child, **I want** a small hint when I am stuck, **so that** I learn instead of guessing.

- [ ] After two wrong tries the field is highlighted
- [ ] Then the first letter or the matching word is shown

`To do` · `P1` · `M` · `M5` · Old E3-9.

### C12 · Hear words read aloud ⬜

**As a** child, **I want** to tap a word or sentence and hear it, **so that** I learn how it sounds, also when I cannot read yet.

- [ ] Works offline with the voices installed on the Mac (English, German)
- [ ] Speed control

`To do` · `P1` · `M` · `M5` · Old E5-8.

### C13 · Write by hand ⬜

**As a** child, **I want** to write with the trackpad or a pencil, **so that** writing feels natural.

- [ ] Handwriting recognised on device for letters and digits

`To do` · `P2` · `XL` · `M6` · Old E3-10.

### C14 · Use big targets, keyboard and reduced motion ⬜

**As a** child, **I want** big buttons and calm movement, **so that** I can use the app easily.

- [ ] Large-target mode
- [ ] Reduced-motion setting is respected

`To do` · `P1` · `S` · `M6` · Old E3-11.

## Epic D · Answers without a grown-up, offline
<a id="epic-d"></a>

_The app finds correct answers by itself, with rules first, then on-device models. No internet, no cloud API._

### D1 · Calculate simple sums ✅

**As a** parent, **I want** answers of 'three + one =' to be calculated, **so that** I do not type them.

- [x] Digits and number words, English and German, + and −
- [x] Negative results are rejected

`Done` · `P0` · `S` · `M1` · Old E9-13.

### D2 · Calculate every kind of maths task 🟡

**As a** parent, **I want** all arithmetic tasks to be solved by the app, **so that** a Math book needs no typing.

- [x] + − × ÷ with digits and number words 0–100 (English, German), usual precedence
- [x] Missing number (3 + _ = 7), comparing (<, >, =), number sequences with one gap
- [ ] Written columns, money, time and measures with units
- [ ] Each solved example from the sample books matches the book's key

`Partly done` · `P0` · `M` · `M2`

### D3 · Read the answer pages of the book ⬜

**As a** parent, **I want** the app to read the answer key printed at the back of a book, **so that** every task with a key needs no typing.

- [ ] Key pages are found, answers are matched by task number
- [ ] Used before any other method
- [ ] Source shown to the grown-up

`To do` · `P1` · `M` · `M2` · Old E1-9.

### D4 · Solve crosswords from the printed word list ⬜

**As a** parent, **I want** crossword answers to be found by fitting the word list, **so that** crosswords need no typing.

- [ ] Words are placed by length and crossing letters
- [ ] Unique solution found; if not unique, marked for the grown-up

`To do` · `P1` · `M` · `M2` · Old E9-5.

### D5 · Solve word searches ⬜

**As a** parent, **I want** words to be found in the letter grid by search, **so that** word searches need no typing.

- [ ] All 8 directions searched
- [ ] Found positions become the key

`To do` · `P1` · `M` · `M2`

### D6 · Match pictures to words with an on-device model ⬜

**As a** parent, **I want** the app to know which picture is a 'pencil case' or a 'ruler', **so that** matching and numbering tasks need no typing.

- [ ] An image-text model on the Mac (for example MobileCLIP in Core ML) scores each picture against the words of the task
- [ ] On the sample school-objects page at least 7 of 9 circles are right (measured, see D9)
- [ ] Low-confidence matches are marked for the grown-up

`To do` · `P0` · `L` · `M2` · Replaces the removed cloud solver.

### D7 · Count things in a picture ⬜

**As a** parent, **I want** the app to count animals or objects in a picture, **so that** 'There are two ladybirds' can be judged.

- [ ] Counts repeated small objects on the sample page correctly in at least 3 of 4 rows
- [ ] Uncertain counts are marked for the grown-up

`To do` · `P1` · `L` · `M2`

### D8 · Answer reading and grammar tasks with a local language model ⬜

**As a** parent, **I want** German and English reading and grammar tasks to be answered by an on-device model, **so that** Lückentext, articles, plural and reading questions need little typing.

- [ ] Runs offline, answers with a confidence
- [ ] Answers agree with the book's key on at least 80% of a sample set
- [ ] Without the model the app still works (grown-up types)

`To do` · `P1` · `L` · `M4`

### D9 · Choose the offline AI runtime (spike) ⬜

**As a** maintainer, **I want** to try the on-device options on the real sample pages, **so that** I choose by measured results, not by guesses.

- [ ] Try first, because they run on macOS 15 on the test Mac: an open vision-language model with MLX Swift (for example SmolVLM2 or Qwen2-VL, 4-bit) and a Core ML CLIP model
- [ ] Apple Foundation Models only if the Mac is upgraded to a newer macOS (it is not available on macOS 15)
- [ ] Measure on the 9 circles, the 4 tick rows and the 4 lollies
- [ ] Measure speed and memory on the test Mac (M2 Max, 32 GB) and write down the minimum Mac that still works
- [ ] A model is downloaded once or put in place from a file; after that no network is used
- [ ] Decision written to docs/OFFLINE_AI.md

`To do` · `P0` · `M` · `M2` · See 'Offline AI options' below.

### D10 · Trust an answer only when methods agree ⬜

**As a** parent, **I want** each answer to carry a confidence, **so that** only doubtful answers bother me.

- [ ] Calculation, answer page and model results are compared
- [ ] Agreement = trusted; disagreement or low score = marked

`To do` · `P1` · `M` · `M2`

### D11 · Type the answers once when nothing else works ✅

**As a** parent, **I want** to type an answer only when the app cannot find it, **so that** no task is stuck.

- [x] Tasks without a found answer show 'A grown-up must set the answers'
- [x] Typed answers are saved per book on the Mac and always win

`Done` · `P0` · `S` · `M1` · Replaces the removed AI answers (no API key).

### D12 · See where an answer came from ⬜

**As a** parent, **I want** each answer to say 'calculated', 'answer page', 'on-device AI' or 'grown-up', **so that** I can judge how much to trust it.

- [ ] Source label on the task card and in the review editor

`To do` · `P2` · `S` · `M5`

## Epic E · Subjects: English, Math, German
<a id="epic-e"></a>

_The end goal: open a PDF of any of the three subjects and get a playable page for each task._

### E1 · English workbook 🟡

**As a** child, **I want** my English book's tasks to be playable, **so that** I can learn words and sentences by doing.

- [x] Numbering, fill-in and tick tasks work on a real English book
- [ ] Matching lines, crosswords, word searches, circling, multiple choice work
- [ ] At least 80% of the tasks of one real book are playable and at least 70% of them have answers found automatically

`Partly done` · `P0` · `L` · `M4`

### E2 · Math workbook ⬜

**As a** child, **I want** my Math book's tasks to be playable, **so that** I can practise numbers by doing.

- [ ] Arithmetic, number lines, comparing, sequences, counting, simple word problems and shapes
- [ ] At least 80% playable and at least 90% with answers calculated

`To do` · `P0` · `L` · `M4`

### E3 · German workbook ⬜

**As a** child, **I want** my German book's tasks to be playable, **so that** I can practise reading and writing by doing.

- [ ] Lückentext, der / die / das, plural, spelling, reading questions
- [ ] At least 80% playable and at least 60% with answers found automatically

`To do` · `P0` · `L` · `M4`

## Epic F · Game layer
<a id="epic-f"></a>

_Children want to come back by themselves. No dark patterns._

### F1 · Grow a Pal with stars ⬜

**As a** child, **I want** a friend that grows when I finish tasks, **so that** I want to learn more.

- [ ] Three growth stages, original art
- [ ] Stars per task

`To do` · `P0` · `L` · `M5` · Old E5-1, E5-2.

### F2 · Travel a world map ⬜

**As a** child, **I want** a map where every chapter is an island, **so that** I see how far I am.

- [ ] Chapters = islands, pages = stops, calm unlocking

`To do` · `P0` · `L` · `M5` · Old E5-3.

### F3 · Gentle daily streak ⬜

**As a** child, **I want** to be cheered for coming back, **so that** it feels good, not bad, when I miss a day.

- [ ] No loss framing, no guilt messages

`To do` · `P1` · `S` · `M5` · Old E5-6.

### F4 · Pal reacts ⬜

**As a** child, **I want** my Pal to cheer, comfort or nap, **so that** it feels alive.

- [ ] Cheer on right, comfort on wrong, nap when I stop

`To do` · `P1` · `M` · `M5` · Old E5-4.

### F5 · Sounds and music ⬜

**As a** child, **I want** friendly sounds with a mute button, **so that** it is fun and not loud.

- [ ] Mute and volume, all sounds optional

`To do` · `P1` · `M` · `M5` · Old E5-7.

### F6 · Room with collectibles ⬜

**As a** child, **I want** to decorate a room with things I earned, **so that** I have something of my own.

- [ ] Earned, never bought

`To do` · `P1` · `L` · `M5` · Old E5-5.

### F7 · Mini games from known words ⬜

**As a** child, **I want** short games with words I have learned, **so that** I can repeat without a workbook.

- [ ] Words with right answers become a quick game

`To do` · `P2` · `XL` · `M6` · Old E5-9, E4-3.

## Epic G · Parent area and review
<a id="epic-g"></a>

_Grown-ups stay in control without doing the work._

### G1 · Review what the app recognised ✅

**As a** parent, **I want** to see tasks, answer fields and pictures drawn on the page, **so that** I can check them quickly.

- [x] Import tab shows text, pictures, circles, bars and tasks per page

`Done` · `P0` · `M` · `M1` · Old E2-1.

### G2 · Correct what the app got wrong ⬜

**As a** parent, **I want** to move or resize boxes, change the task type and fix answers, **so that** a wrong recognition is not the end.

- [ ] Drag and resize fields and pictures
- [ ] Change task type, prompt and answers
- [ ] Assign a picture to a word
- [ ] Undo and redo

`To do` · `P0` · `L` · `M5` · Old E2-2..E2-6, E9-10.

### G3 · Open the grown-up area safely ⬜

**As a** parent, **I want** a simple adult gate, **so that** children cannot change answers or limits.

- [ ] A small adult challenge before the area opens

`To do` · `P0` · `S` · `M5` · Old E6-1.

### G4 · See progress ⬜

**As a** parent, **I want** pages done, accuracy and hard items, **so that** I know where my child needs help.

- [ ] Per child, per book, per task type

`To do` · `P1` · `M` · `M5` · Old E6-2.

### G5 · Set a daily time limit ⬜

**As a** parent, **I want** a calm end of the session, **so that** screen time stays in my hands.

- [ ] The Pal says goodbye, no cut-off in the middle of a task

`To do` · `P1` · `M` · `M5` · Old E6-3.

### G6 · Several children ⬜

**As a** parent, **I want** a profile per child on this Mac, **so that** each child has their own progress.

- [ ] Local profiles, no accounts

`To do` · `P1` · `M` · `M5` · Old E6-4.

### G7 · Export progress ⬜

**As a** parent, **I want** to export progress as PDF or CSV, **so that** I can share it with a teacher.

- [ ] PDF and CSV

`To do` · `P2` · `S` · `M6` · Old E6-5.

## Epic H · Quality, privacy and offline
<a id="epic-h"></a>

_Safe for children, works without the internet._

### H1 · Work completely offline 🟡

**As a** parent, **I want** the app to need no internet after setup, **so that** it works anywhere and nothing leaves the Mac.

- [x] No cloud API is used (the removed AI answers were the only network feature)
- [ ] The app has no network access in its sandbox settings
- [ ] A test with the network switched off passes
- [ ] Only a one-time model download is allowed, and a model can also be put in place from a file

`Partly done` · `P0` · `S` · `M2`

### H2 · No accounts, no tracking ⬜

**As a** parent, **I want** no accounts and no analytics, **so that** my child's data stays private.

- [ ] Privacy review documented
- [ ] No third-party SDKs

`To do` · `P0` · `S` · `M6` · Old E7-3.

### H3 · Automatic checks 🟡

**As a** maintainer, **I want** checks to run before every push, **so that** a bad change cannot reach GitHub.

- [x] `swift run PagePalsChecks` has about 45 checks and runs first in the pre-push hook
- [ ] Recognition quality checks on the test pages (B10)
- [ ] GitHub Actions runs build and checks

`Partly done` · `P0` · `S` · `M1` · Old E0-4, E7-6.

### H4 · Fair design checklist ⬜

**As a** parent, **I want** the app to follow a checklist against dark patterns, **so that** it helps children and does not trap them.

- [ ] Checklist in docs, reviewed before release

`To do` · `P1` · `S` · `M6` · Old E7-4.

### H5 · Use with VoiceOver and keyboard ⬜

**As a** child, **I want** every control to be reachable and described, **so that** everyone can play.

- [ ] Labels and focus order for all players

`To do` · `P1` · `M` · `M6` · Old E7-1.

### H6 · App text in English, German and Russian ⬜

**As a** parent, **I want** the app's own menus in my language, **so that** I understand it.

- [ ] UI strings in en, de, ru

`To do` · `P1` · `M` · `M6` · Old E7-2.

### H7 · Try it with children ⬜

**As a** maintainer, **I want** 3 to 5 children to try the app, **so that** I learn what works.

- [ ] Notes and changes recorded

`To do` · `P1` · `L` · `M6` · Old E7-5.

## Epic I · Build and delivery
<a id="epic-i"></a>

_Easy to build without Xcode, safe to publish._

### I1 · Build without Xcode ✅

**As a** maintainer, **I want** to build with Swift Package Manager and Command Line Tools only, **so that** I do not need Xcode.

- [x] `./build-app.sh` makes PagePals.app, ad-hoc signed

`Done` · `P0` · `S` · `M1` · Old E0-3.

### I2 · Rebuild and start in one command ✅

**As a** maintainer, **I want** `./rebuild.sh`, **so that** I try a change in seconds.

- [x] Quits the old app, builds, starts the new one

`Done` · `P2` · `S` · `M1` · Old E0-9.

### I3 · Push safely 🟡

**As a** maintainer, **I want** `./push.sh` to run the checks and an Opus review before the push, **so that** only checked work reaches GitHub.

- [x] push.sh and hooks/pre-push exist; checks run first, then the Opus review
- [ ] A full run passes once (Claude login must be renewed first)

`Partly done` · `P1` · `S` · `M1` · Old E0-8.

### I4 · App icon and name check ⬜

**As a** parent, **I want** a friendly icon and a free name, **so that** the app is easy to find.

- [ ] Icon, trademark check for 'PagePals'

`To do` · `P1` · `S` · `M6` · Old E8-1.

### I5 · Signed and notarised app ⬜

**As a** parent, **I want** to install the app without warnings, **so that** I trust it.

- [ ] Code signing, notarisation, DMG

`To do` · `P1` · `M` · `M6` · Old E8-2.

### I6 · Decide on the Mac App Store ⬜

**As a** maintainer, **I want** a decision about the store, **so that** I know the rules for kids' apps.

- [ ] Kids category rules and privacy labels reviewed

`To do` · `P2` · `M` · `M6` · Old E8-3.

### I7 · Code style checks ⬜

**As a** maintainer, **I want** a formatter and linter, **so that** the code stays tidy.

- [ ] SwiftLint or swift-format configured

`To do` · `P2` · `S` · `M6` · Old E0-5.

## Open questions

- Do the books come with answer pages (D3)? Which books and subjects should be tested first?
- Which age range and which language pair first (assumed: English or German workbooks, child aged 6–9)?
- Mac only, or iPad later? (The SwiftUI code is kept portable.)

## Old numbers

Earlier versions used numbers like E9-12. Each story above lists the old numbers it replaces in its last line (`Old …`).
