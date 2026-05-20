# Generation Metadata

## Run info

| Item | Value |
| --- | --- |
| Commit hash | d59123b |
| Branch name | main |
| Generated at | 2026-05-20T16:04:55+09:00 |
| Output language | Chinese |
| Generation mode | Full docs reconciliation via `neat-freak` against uploaded archive |

## Updated document scope

| Area | Update |
| --- | --- |
| Repository entry docs | Rewrote root README/README.en/AGENTS around the current macOS recorder, AVP practice app and Python backend. |
| Canonical docs | Rebuilt overview, architecture, data flow, configuration, dependencies, storage, glossary and fallback pages around current code paths. |
| Module docs | Reconciled macOS, AVP, AVP practice and Python backend module pages with actual files and type names. |
| Subdirectory docs | Updated `LonelyPianist/README.md`, `LonelyPianistAVP/README.md`, `LonelyPianistAVP/AGENTS.md` and `piano_dialogue_server/README.md`. |
| Debug docs | Updated BLE MIDI protocol debugging notes for current MIDI 1.0/2.0 broadcaster and matching pipeline. |

## Current Coverage Gaps

- The uploaded archive does not contain `.git` history, so this sync used the archive contents as a temporary baseline.
- The repository contains no `.github/workflows/`; validation commands are local/manual.
- The archive does not include `LonelyPianistAVP/Resources/Audio/SoundFonts/SalC5Light2.sf2`.
- Vision Pro hardware behavior still needs real-device validation for hand tracking, plane detection, Bluetooth MIDI, microphone input, Local Network/Bonjour and visual comfort.
- There is no automated end-to-end test covering macOS recorder -> Python backend -> AVP practice.
