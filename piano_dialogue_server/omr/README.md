# OMR Module

This module hosts the local OMR pipeline that converts score PDF/images to MusicXML.

## Output Convention

All jobs are written under:

`piano_dialogue_server/out/omr/<basename>-<timestamp>/`

Each job keeps:

- `input/` preprocessed images used for OCR
- `debug/` analysis/debug artifacts from oemer and pipeline
- `output/score.musicxml` final output consumed by AVP

## Multi-page PDF MVP policy

- Current MVP processes only the first page (`--page 1`).
- If a PDF has multiple pages, the CLI emits a warning and converts only page 1.
- Passing `--page` other than 1 for a multi-page PDF returns a clear error.
- Future work: merge-pages support.
