# Piano Dialogue Server

## Setup

```bash
cd piano_dialogue_server
python3.12 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

## OMR (PDF/Image -> MusicXML)

- OMR output root: `out/omr/`
- Each conversion job writes to: `out/omr/<basename>-<timestamp>/`
- Job layout:
  - `input/` rendered pages or copied input image
  - `debug/` oemer debug artifacts
  - `output/score.musicxml` final output for AVP import

The OMR module lives in `omr/`. Future tasks add the CLI and converter pipeline.
