# PagePals overview

> **Goal:** open a PDF workbook (English, Math or German) and get an **interactive page for every task**, where the child selects or enters the answer. The app recognises the correct answers **by itself and offline**; a grown-up types an answer only as the last resort.

The stories live in `pp-backlog.md` (board: see its header).

## Principles

- **Same book, same pictures.** The page in the app looks like the page in the book, with the book's own pictures.
- **One task, one interactive page.** Never a loose set of pictures.
- **Answers found automatically.** Rules and calculation first, then on-device models. A grown-up types answers only when nothing else works.
- **Offline and private.** No internet needed to play or import, no cloud API, no account, no analytics.
- **Three subjects.** English, Math and German workbooks.
- **Kind to children.** No dark patterns, gentle feedback.
- **Easy to build.** Swift Package Manager and Command Line Tools only, no Xcode.

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
   - **Apple Foundation Models framework:** the on-device model accepts image input in the newest OS generation and needs no server ([WWDC26 session](https://developer.apple.com/videos/play/wwdc2026/241), [overview](https://callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new)). It needs a much newer macOS than the test Mac has (15.8), so it is **not an option today**; revisit after an OS upgrade.

The app must stay usable when no model is installed (then answers are calculated, read from answer pages, or typed once by a grown-up). The earlier cloud solver was removed because it needed an API key and the internet.

## Open questions

- Do the books come with answer pages (D3)? Which books and subjects should be tested first?
- Which age range and which language pair first (assumed: English or German workbooks, child aged 6–9)?
- Mac only, or iPad later? (The SwiftUI code is kept portable.)
