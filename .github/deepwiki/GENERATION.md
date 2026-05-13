# Generation Metadata

## Run info
| Item | Value |
| --- | --- |
| Commit hash | 453d6366041d31542035769f671565a0d9d27c6f |
| Branch name | crh2 |
| Generated at | 2026-05-13T11:50:18+08:00 |
| Output language | Chinese |
| Generation mode | Incremental update via `deepwiki` skill |

## Key updates in this generation
| Area | Update |
| --- | --- |
| AVP BLE MIDI：准备页与系统面板 | 更新 deepwiki 以反映 `BluetoothMIDIPreparationView` 改为**内嵌**系统 Bluetooth MIDI 面板（不再 sheet 弹窗），并移除 sources 刷新/列表 UI；保留 `sourceCount` gate。 |
| AVP BLE MIDI：Step 推进判定 | 记录 BLE MIDI 的 step 推进为“note-on 事件聚合判定”，并补充多音/和弦的聚合窗口与多数命中规则（当前配置更宽松以降低卡步）。 |
| Services/Practice 目录整理 | 更新 deepwiki 中引用的 Practice 相关源码路径，反映 `Services/Practice/` 按用途拆分子目录（AI/Autoplay/Guides/ManualAdvance/Matching/Session）。 |
| 虚拟钢琴入口表述修正 | 修正 deepwiki 中“Step 3 设置页切换虚拟钢琴”的过期表述，改为以 `PianoKind`（类型选择/准备页）驱动。 |

## Generated page list
### Core pages
- `INDEX.md`
- `business-context.md`
- `overview.md`
- `architecture.md`
- `dependencies.md`
- `data-flow.md`
- `configuration.md`
- `storage.md`
- `testing.md`
- `workflow.md`
- `troubleshooting.md`
- `glossary.md`
- `Fallbacks.md`
- `GENERATION.md`

### Module pages (`modules/`)
- `modules/lonelypianist-macos.md`
- `modules/lonelypianist-macos-runtime.md`
- `modules/lonelypianist-macos-mapping.md`
- `modules/lonelypianist-macos-recording.md`
- `modules/lonelypianist-macos-dialogue.md`
- `modules/lonelypianist-avp.md`
- `modules/lonelypianist-avp-library.md`
- `modules/lonelypianist-avp-calibration.md`
- `modules/lonelypianist-avp-musicxml.md`
- `modules/lonelypianist-avp-tracking.md`
- `modules/lonelypianist-avp-practice.md`
- `modules/lonelypianist-avp-practice-audio.md`
- `modules/piano-dialogue-server.md`
- `modules/piano-dialogue-server-protocol.md`
- `modules/piano-dialogue-server-inference.md`
- `modules/piano-dialogue-server-debug.md`

## Copied asset list
- None (no files under `assets/`).

## Current Coverage Gaps
- The repo currently has no GitHub Actions workflows; all tests are manual/local.
- There is no unified release workflow.
- There is no full macOS -> Python -> AVP end-to-end automated test.
- Audio recognition fallback behavior and performance tuning still requires real-device verification.
- Audio recognition engine failures (e.g., RemoteIO -10851) are still environment-dependent; simulator behavior is not a reliable proxy for Vision Pro devices.
- AutoplayPerformanceTimeline complex edge cases (e.g., simultaneous pedal up/down) may need more test coverage.
- Virtual piano placement experience (plane detection stability, palm confirmation thresholds) and 3D rendering (key size, spacing, material) need Vision Pro real-device verification.
- KeyContactDetectionService hysteresis thresholds (press 2mm / release 8mm) need real-device tuning.
- Decal highlight alignment, z-fighting, and visual comfort need Vision Pro real-device verification.
- AVP Bonjour 发现与 `/generate` 请求强依赖同一局域网与 Local Network 授权；denied/解析失败仍需真机验证与网络环境排查。
