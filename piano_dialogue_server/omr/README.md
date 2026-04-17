# OMR Module

This module hosts the local OMR pipeline that converts score PDF/images to MusicXML.

## Output Convention

All jobs are written under:

`piano_dialogue_server/out/omr/<basename>-<timestamp>/`

Each job keeps:

- `input/` preprocessed images used for OCR
- `debug/` analysis/debug artifacts from oemer and pipeline
- `output/score.musicxml` final output consumed by AVP
