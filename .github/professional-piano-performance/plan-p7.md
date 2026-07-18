# Plan P7 - 连续踏板、CoreMIDI 时间戳与音频输出可靠性

**Goal:** 把规范 transport commands 稳定、低抖动地交给应用内采样器和外部 MIDI，并完整处理连续控制、取消、停止、中断与恢复。

**Non-goals:** 本 phase 不更换专业三角钢琴采样，也不自研物理建模。

**Approach:** 扩展 controller 值与 output capability，重构 CoreMIDI 为 timestamped look-ahead 调度；AVAudio 服务使用明确 actor 与 lifecycle 执行 transport commands。平台差异通过小而稳定的 output seam 处理。

**Acceptance:**
- CC64、66、67 连续值从 score plan 到 output 保留。
- CoreMIDI 使用非零 host-time timestamp 提前调度。
- stop、cancel 与 route change 后无卡音、残留踏板或旧 generation 事件。
- 输出 metrics 可测 latency、jitter、miss 与 reset。

**Rules:**
- 不因采样器不支持某控制器而丢弃 plan 事实。
- 不在 MainActor 调度密集 MIDI 或 audio events。
- 错误不得被 try? 静默吞掉。

**State / lifecycle:** playback generation 拥有 scheduler task；start 前取消旧 generation，stop、interruption 与 teardown 必须完成 reset。重复 stop 幂等。

**Threading / actor:** transport scheduler 在专用 actor；UI 状态更新回 MainActor。CoreMIDI host time 转换不可使用 wall-clock Date。

**Debug / observability:** 记录 schedule horizon、send error category、late event、jitter bucket、route 或 interruption reason 和 reset result；不记录逐音原始数据。

**Testing strategy:** fake clock 与 fake output 单测；CoreMIDI packet construction 测试；Simulator 验证生命周期；真机指标留 P15。

**Audit focus:**
- timestamp 是否仍为 0。
- cancel 后已排队 packet 是否有 generation guard。
- sampler 与 external MIDI reset 是否一致。
- 半踏板能力不足是否清晰降级。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p7-t1"></a>
## P7-T1 把踏板模型升级为连续 controller value

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLControllerValue.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLPedalTimeline.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLPedalTimelineTests.swift`

**Implementation:**
1. 解析 damper 0 到 100 decimal 并映射为保留原值的 MIDI 0 到 127。
2. 统一 start、stop、change、continue 与连续 value，保留 provenance。
3. 为 sostenuto 与 soft pedal 建立 controller facts。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLPedalTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLControllerValue.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLPedalTimeline.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLPedalTimelineTests.swift'`
- Run: `git commit -m "feat: P7-T1 - 把踏板模型升级为连续 controller value"`

---

<a id="p7-t2"></a>
## P7-T2 将 CC64、66、67 与 capability 降级接入输出

**Requirements:** PERF-009
**Primary owner:** PERF-009

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceOutputCapabilities.swift`
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift`

**Implementation:**
1. 输出服务声明 continuous damper、sostenuto 与 soft pedal 支持级别。
2. 不支持连续值时执行明确量化并附 diagnostics approximation，不修改 plan。
3. sequence tests 断言连续值与 controller ordering。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceOutputCapabilities.swift' 'HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift'`
- Run: `git commit -m "feat: P7-T2 - 将 CC64、66、67 与 capability 降级接入输出"`

---

<a id="p7-t3"></a>
## P7-T3 扩展 CoreMIDIOutputService 支持 timestamped packets

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/MIDI/CoreMIDIOutputService.swift`
- Modify: `HappyPianistAVPTests/MIDI/MIDIEndpointConnectionPolicyTests.swift`

**Implementation:**
1. 协议接受 host timestamp 与一批有序 MIDI messages。
2. packet list 使用调用方 timestamp，不再硬编码 0。
3. 保留 immediate send 作为 timestamp=now 的明确 convenience，而不是 scheduler 默认。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/MIDIEndpointConnectionPolicyTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MIDI/CoreMIDIOutputService.swift' 'HappyPianistAVPTests/MIDI/MIDIEndpointConnectionPolicyTests.swift'`
- Run: `git commit -m "refactor: P7-T3 - 扩展 CoreMIDIOutputService 支持 timestamped packets"`

---

<a id="p7-t4"></a>
## P7-T4 建立 monotonic tick 到 MIDI host time 转换

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/MIDI/MIDIHostTimeConverter.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- Modify: `HappyPianistAVPTests/MIDI/MIDI2ValueMappingTests.swift`

**Implementation:**
1. 基于 continuous host time 定义可注入 converter。
2. 测试 tempo changes、pause directives、seek origin 与大 tick 值不溢出。
3. 创建后立即由 CoreMIDI playback service 消费。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/MIDI2ValueMappingTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MIDI/MIDIHostTimeConverter.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift' 'HappyPianistAVPTests/MIDI/MIDI2ValueMappingTests.swift'`
- Run: `git commit -m "feat: P7-T4 - 建立 monotonic tick 到 MIDI host time 转换"`

---

<a id="p7-t5"></a>
## P7-T5 用 look-ahead scheduler 替换逐事件 Task.sleep

**Requirements:** PERF-010
**Primary owner:** PERF-010

**Files:**
- Create: `HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- Modify: `HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift`
- Delete: `CoreMIDIPracticePlaybackService 逐事件 Task.sleep 调度循环`

**Implementation:**
1. 按有限 horizon 批量构建 timestamped packets，保持事件稳定顺序。
2. tempo、pause 与 seek 通过 transport time cursor 计算，不依赖 wake-up 时刻。
3. 使用 fake clock 与 output 测试 late event、batch boundary 和取消。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift' 'HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift'`
- Run: `git commit -m "perf: P7-T5 - 用 look-ahead scheduler 替换逐事件 Task.sleep"`

---

<a id="p7-t6"></a>
## P7-T6 给 scheduler 加 generation、取消与 route guard

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- Modify: `HappyPianistAVP/Services/MIDI/CoreMIDISourceMonitoringService.swift`
- Modify: `HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift`

**Implementation:**
1. start 生成新 generation，旧 batch 与 callback 在发送前验证 generation。
2. endpoint change、disconnect、stop 与 teardown 取消未来 packet 并执行 reset。
3. 重复 start 与 stop 行为写入测试。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift' 'HappyPianistAVP/Services/MIDI/CoreMIDISourceMonitoringService.swift' 'HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift'`
- Run: `git commit -m "fix: P7-T6 - 给 scheduler 加 generation、取消与 route guard"`

---

<a id="p7-t7"></a>
## P7-T7 让 AVAudio sampler 执行统一 transport commands

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift`

**Implementation:**
1. live note 与 sequence playback 都接受带 identity、velocity 与 controller 的 commands。
2. 用 actor 隔离 engine 与 sampler mutable state；MainActor 不做文件加载或事件调度。
3. 删除固定 velocity convenience 在生产调用方的使用。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift' 'HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift'`
- Run: `git commit -m "refactor: P7-T7 - 让 AVAudio sampler 执行统一 transport commands"`

---

<a id="p7-t8"></a>
## P7-T8 补齐音频中断、route change 与停止诊断

**Requirements:** PERF-011
**Primary owner:** PERF-011

**Files:**
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift`

**Implementation:**
1. 把 engine start、load、render、interruption 与 route errors 映射为结构化 PracticeAudioError。
2. 任何失败先执行统一 reset，再发布可恢复或不可恢复状态。
3. 删除关键路径 try?，测试失败注入与恢复。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift' 'HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift'`
- Run: `git commit -m "fix: P7-T8 - 补齐音频中断、route change 与停止诊断"`

---

<a id="p7-t9"></a>
## P7-T9 建立输出时延、抖动与漏事件指标

**Requirements:** PERF-012
**Primary owner:** PERF-012

**Files:**
- Create: `HappyPianistAVP/Models/Diagnostics/PianoOutputMetrics.swift`
- Modify: `HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift`
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- Modify: `HappyPianistAVP/Services/Diagnostics/DiagnosticsReporter.swift`
- Modify: `HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift`

**Implementation:**
1. 定义 scheduled、submitted 与 acknowledged monotonic timestamps 的低频汇总桶。
2. 记录 late、dropped、reset 与 stuck-note prevention，不导出逐音序列。
3. 测试聚合、七天导出策略和隐私字段。

**Validation:**
- Focus: HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift, HappyPianistAVPTests/Diagnostics/DiagnosticsReporterTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Diagnostics/PianoOutputMetrics.swift' 'HappyPianistAVP/Services/Audio/MIDILookAheadScheduler.swift' 'HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift' 'HappyPianistAVP/Services/Diagnostics/DiagnosticsReporter.swift' 'HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift'`
- Run: `git commit -m "feat: P7-T9 - 建立输出时延、抖动与漏事件指标"`

---

<a id="p7-t10"></a>
## P7-T10 增加输出 fake、故障注入与设备验收清单

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fakes/FakePerformanceOutput.swift`
- Modify: `HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift`
- Modify: `docs/testing/piano-performance-validation.md`

**Implementation:**
1. fake 捕获 timestamped commands、capabilities、generation 与 reset。
2. 覆盖 send failure、disconnect、interruption、double stop 与 late batch。
3. 文档列出 Simulator 能验证与必须真机验证的边界。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift, HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fakes/FakePerformanceOutput.swift' 'HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift' 'docs/testing/piano-performance-validation.md'`
- Run: `git commit -m "test: P7-T10 - 增加输出 fake、故障注入与设备验收清单"`

---

## Phase Audit

- Audit file: `audit-p7.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: timestamp 是否仍为 0。；cancel 后已排队 packet 是否有 generation guard。；sampler 与 external MIDI reset 是否一致。；半踏板能力不足是否清晰降级。
