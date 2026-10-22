# Concept: PagePals

## Target users

- **Child (age ~6-10)**: does exercises from a workbook; wants fun, quick feedback, no reading of menus.
- **Parent / teacher**: imports the book, checks progress, corrects misdetected tasks.

First content target: English-as-a-foreign-language workbooks for German-speaking children (the sample book is an A4 two-page-spread scan with hints in German). The design stays language-agnostic.

## Core loop

1. Pick a page on the **world map** (each book chapter = an island, each page = a stop).
2. Play the page's tasks, each rebuilt as a mini-game.
3. Instant, friendly feedback per answer (never "wrong!", always "try again" with a hint).
4. Finish -> stars + food -> the **Pal** grows, gets accessories, a new island unlocks.
5. Come back tomorrow: gentle streak ("Pal is waiting"), never punishing.

## Task-type catalogue (from the sample book)

| Book task | Interactive version | Check |
|---|---|---|
| "How much is it? Write." (fill in blank) | Tap a blank, type, or choose from letter/word tiles; optional handwriting (Apple Pencil/trackpad, later) | Text compare, case/diacritics-insensitive |
| "Correct or wrong? Tick." | Two big buttons / tick circles per statement, picture highlights | Boolean per item |
| "Number the pictures" / "Read and number" | Drag numbered bubbles onto pictures, or tap in order | Order per item |
| "Draw lines" (match word to picture) | Drag a rope from word to picture, line snaps and wiggles | Pair map |
| "Do the crossword" (fruit pictures around a grid, word list below) | Rebuilt grid; each word shows its original picture as the clue; on-screen keyboard; word list as tappable help | Cell letters, key solved from the word list |
| "Find the words and circle them. Fill in." (letter grid + word list + sentences with small drawings) | Letter grid you swipe across to select words, found words cross off the list, then the sentences are filled in beside their original drawings | Found cells + typed words |
| "Which alien is it? Read and choose" | Tap the picture that matches the text; text read aloud | Single choice |
| Anything else | Falls back to "Open task": child answers on a photo of the page, parent confirms | Parent check |

## The Pal (companion)

- Chosen at first launch from 3-4 original creatures (no licensed characters).
- Grows through stages with total stars; wardrobe/room decorated with collected items.
- Reacts to events: cheers on correct, comforts on a miss, naps when the child stops.
- Speaks short phrases in the book's target language (text-to-speech), which supports the learning goal.

## Design principles

0. **Same pictures as the book.** Every picture that belongs to a word or task in the book is cut out of the page and shown in the app exactly as printed (crossword clues, matching pictures, "I see with my ..." drawings). The app never swaps them for stock art. Pictures are stored as assets in the lesson pack and tied to the word they illustrate.
1. **Child-led**: big targets, no text-heavy menus, voice prompts, works with mouse, trackpad or touch.
2. **Book first**: the original page art stays visible; the interactive layer sits on it, so progress in the app maps to the physical book.
3. **Kind feedback**: wrong answers give hints, never penalties; no lives, no timers by default.
4. **No dark patterns**: no manipulative exit screens, no fake urgency, no ads, no purchases in the child area. Session reminders are calm and parent-configurable.
5. **Parent in control**: review/edit detected tasks, set daily time, see what was hard.
6. **Local-first and private**: no accounts, no child data uploaded by default.

## Out of scope (for now)

iPad/iPhone apps, multi-child cloud sync, marketplace of books, speech-recognition scoring, teacher dashboards across a class.
