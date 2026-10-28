# Offline AI: plan and spike (PP-039)

Status: **spike not run yet.** The code around the models is ready and checked
(`PictureMatching`, `CountStatement`, `OfflineModels`, `PictureScoring`); no model is bundled or downloaded.
The measurements below need the sample pages and a model file on the test Mac (M2 Max, 32 GB, macOS 15.8).

## What is already in place

| Part | File | What it does |
|------|------|--------------|
| Pairing pictures with words | `PictureMatching.swift` | Takes a score matrix (picture × word, any model) and returns the best one-to-one pairing and a confidence. Two equally good pairings, or a gap under 0.02, give nothing, so a grown-up decides. |
| Counting sentences | `CountStatement.swift` | Reads "There are two ladybirds" and judges it against a counted number; builds the tick key of a counting task. |
| Counting objects | `ObjectCounter.swift` | Counts similar blobs in a picture region without any model; returns nothing when the blobs are not of similar size. Not measured yet. |
| Where models live | `OfflineModels.swift` | `~/Library/Application Support/PagePals/Models`; a model is put there by hand, nothing is downloaded by the app. |
| Combining methods | `AnswerReconciler.swift` | Agreement of two methods = trusted; disagreement = left to a grown-up. |
| Model interface | `PictureScoring` | One method: `scores(pictureFiles:words:)`. A Core ML or MLX implementation plugs in here. |

## Spike procedure

1. Put a Core ML MobileCLIP image and text encoder (and its tokenizer vocabulary) into the Models folder by hand.
2. Implement `PictureScoring` in a new file in `PagePalsImport` (this needs `import CoreML`, a system framework, not a new package).
   Cosine similarity of the picture embedding and the text embedding of each word is the score.
3. Run it on the 9 school-object circles, the 4 tick rows and the 4 lollies of the sample page.
4. Write the results in the table below. Repeat with an MLX vision-language model (SmolVLM2 or Qwen2-VL, 4-bit) if the CLIP model misses the target of 7 of 9.
5. Record speed (seconds per page) and memory, and the smallest Mac that still works.

| Model | Circles right (of 9) | Tick rows right (of 4) | Lollies right (of 4) | Seconds per page | Memory | Notes |
|-------|----------------------|------------------------|----------------------|------------------|--------|-------|
| MobileCLIP (Core ML) | – | – | – | – | – | not measured |
| SmolVLM2 / Qwen2-VL (MLX, 4-bit) | – | – | – | – | – | not measured |

Apple Foundation Models is not an option on macOS 15 (see `OVERVIEW.md`).

## Decision

Not made yet. Until the table is filled in, answers come from calculation, the answer pages and the grown-up.
