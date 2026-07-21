# Generation Metadata

## Run info

| Item | Value |
| --- | --- |
| Repository | `chiimagnus/Amoroso` |
| Source branch | `main` |
| Source commit | `98ecccb67a063f741c3a0dc8bf5c2a352e7b1d2f` |
| Output branch | `docs/neat-freak-20260721` |
| Generated at | 2026-07-21T04:32:08+09:00 |
| Output language | Chinese |
| Generation mode | Canonical documentation reconciliation with `neat-freak` |

## Canonical pages

- `AGENTS.md`
- `README.md`
- `docs/overview.md`
- `docs/architecture.md`
- `docs/data-flow.md`
- `docs/piano-performance-quality.md`
- `docs/configuration.md`
- `docs/storage.md`
- `docs/modules/happypianist-avp.md`
- `docs/modules/happypianist-avp-practice.md`
- `docs/testing/core-function-checklist.md`
- `docs/testing/piano-performance-validation.md`

## Reconciliation summary

- Replaced archive-only metadata with the audited Git commit and branch.
- Reconciled resource documentation with the checked-in Bravura font and omitted private SeedScores, SoundFont and CoreML model.
- Reconciled practice and quality documentation with the current `ScorePerformancePlan`, `PerformanceObservation`, hand-contact velocity, continuous controller and MIDI look-ahead implementations.
- Removed historical fixed-issue backlog from the canonical professional-quality page; retained current claims, remaining gaps and evidence gates.

## Coverage gaps

- The environment could inspect repository files through the connected GitHub service, but could not create a complete local clone because direct GitHub DNS access was unavailable.
- `xcodebuild test`, visionOS Simulator and Apple Vision Pro were not run in this documentation pass.
- Private `SeedScores`, `SalC5Light2.sf2`, the Performance RNN CoreML model and Aria weights were not available for resource integration or listening tests.
- Hand tracking, microphone, Bluetooth MIDI, spatial alignment, output latency and comfort still require Apple Vision Pro and the target hardware.
