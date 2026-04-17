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

## Packaging PoC (PyInstaller)

P4 默认采用独立转换器形态，PoC 打包路线使用 `pyinstaller`。

- 入口：`python -m omr.cli --input <score.pdf>`
- 打包产物：`piano_dialogue_server/omr/packaging/dist/lp-omr-convert`
- checkpoints 策略（PoC）：**首次运行下载**，不随包分发模型文件。
- 推荐缓存目录（产品化目标）：`~/Library/Application Support/LonelyPianistOMR/checkpoints/`

详细步骤见：`omr/packaging/README.md`。
