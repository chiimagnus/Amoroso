# OMR Packaging PoC (PyInstaller)

This folder contains the packaging proof-of-concept for shipping the OMR converter without requiring a user-managed Python environment.

## Decision

- Packaging route: **PyInstaller one-folder app/CLI bundle**
- Runtime checkpoints strategy: **first-run download** (do not redistribute checkpoints inside package until license confirmation)

## Build steps

```bash
cd piano_dialogue_server
./.venv/bin/pip install -U pyinstaller
./omr/packaging/build_pyinstaller.sh
```

Expected artifact:

- `piano_dialogue_server/omr/packaging/dist/lp-omr-convert`

## Smoke run (packaged binary)

```bash
cd piano_dialogue_server/omr/packaging/dist/lp-omr-convert
./lp-omr-convert --help
```

## Notes

- First conversion may take longer due to checkpoint download.
- If network is unavailable, conversion fails with a clear runtime error; users can pre-seed checkpoints manually according to `omr/CHECKPOINTS.md`.
- Productization target cache path: `~/Library/Application Support/LonelyPianistOMR/checkpoints/` (to be wired in runtime adapter after legal/license confirmation).
