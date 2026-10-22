# Picture detection prototype (Python)

Used to design and tune `Sources/PagePalsImport/PictureFinder.swift` on the sample workbook.
Needs `numpy`, `opencv-python` and the `tesseract` command line tool (it stands in for Apple's Vision OCR).

```bash
pdftoppm -r 150 -png -f 14 -l 14 book.pdf s14
python3 find_pictures.py s14-14.png out.png 0.5 1.0   # last two numbers: left/right part of the image to analyse
```

Blue boxes are pictures, green boxes are structures (word lists, letter grids). Never commit workbook pages.
