# Keeping the book's pictures

## Why

A child who sees the book's pear next to a crossword row recognises it. Generic art breaks the link to the printed page, so the app reuses the book's own pictures wherever a word or task is tied to one.

## What the sample book looks like

Pages are camera photos of two-page spreads: curved paper, uneven light, a coloured header band on each page. Pictures come in two kinds:

- **Solid colour illustrations** (fruit, basket): easy to separate from paper.
- **Pale line drawings** (hands, ears, feet next to writing lines): thin outlines, light fills, sit right beside grey writing lines and text.

## Method (PictureFinder)

1. Scale the page to a fixed width; estimate local paper brightness and mark pixels clearly darker or more colourful than paper.
2. **Solid pass**: remove thin lines (grid, outlines) by morphological opening, close gaps, keep blobs.
3. **Line-art pass**: erase recognised text words, drop long thin components (writing lines, rules) and specks, merge the remainder.
4. Combine both: a line-art box that swallows several solid pictures is replaced by those pictures.
5. Drop header bands, page-edge strips and oversized blobs.
6. Boxes full of text or many letter-sized specks are marked **structure** (word list, letter grid) and not cut out as pictures.

## Results on the sample (Python prototype, before the Swift port)

| Page | Result |
|---|---|
| Fruit crossword (page 35) | all 10 fruit pictures and the basket found |
| Body and feelings word search (page 14) | hands, arms, ears, eyes, lips, legs, feet found; letter grid and word list marked as structures |

Known problems: two stacked drawings can merge, a grey writing line can stay attached to a picture, a very small drawing can be missed or mistaken for a structure. The parent review editor (E9-10) exists to fix these in a few clicks.

## Next

Picture-to-word association (E9-3), crossword grid detection and solving (E9-4, E9-5), then the players that show the cropped pictures (E9-6, E9-8, E9-9).
