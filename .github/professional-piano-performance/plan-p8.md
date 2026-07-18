# Plan P8 - 统一 PerformanceObservation、MIDI、麦克风与录制证据

**Goal:** 在不做专业评分前，完整保留用户演奏事件的来源、能力、时间、置信度与校准，并让录制可作为可追溯证据。

**Non-goals:** 本 phase 不声称麦克风具备复调转录，也不把 observation 持久化到练习进度。

**Approach:** 定义中立 observation contract 与 capability set；MIDI、麦克风和录制分别适配。即时 matcher 可消费投影，但原始 observation 必须保留到 session analyzer。RecordingTake 使用显式版本向后解码。

**Acceptance:**
- MIDI velocity、release、CC64、66、67、channel、group、source 与 monotonic time 不再丢失。
- 麦克风缺失维度明确为 notObserved。
- RecordingTake 可关联 score、source、clock 与 calibration。
- 输入时钟可进行 latency correction。

**Rules:**
- 不把 Date 当唯一排序时钟。
- 不把麦克风置信度不足判为 wrong note。
- 原始逐音 observation 不写入进度 JSON 或 exportable diagnostics。

**State / lifecycle:** 每个 source adapter 有 start、stop、cancel 与 generation；session teardown 取消流并关闭 continuation。录制 take 生命周期与 session 明确绑定。

**Threading / actor:** adapter 可在各自 actor 运行；统一 observation 进入 analyzer 前按 monotonic timestamp 排序。MainActor 只接收汇总状态。

**Debug / observability:** 记录 source capability、event count、out-of-order、clock skew、dropped 与 insufficient evidence 聚合。

**Testing strategy:** fake event source 与 deterministic replay；持久化 migration tests；MIDI1、MIDI2 与 microphone capability tests。

**Audit focus:**
- 是否仍有 case noteOn(note, _) 丢 velocity。
- 同名 MIDI note 跨 channel 或 group 是否冲突。
- 旧 recording JSON 是否可读且不丢事件。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p8-t1"></a>
## P8-T1 定义 PerformanceObservation 事件契约

**Requirements:** ARCH-002
**Primary owner:** ARCH-002

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceObservation.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift`

**Implementation:**
1. 定义 source identity、capabilities、monotonic 与 source timestamp、pitch、velocity、release、controller、confidence 和 calibration reference。
2. 事件可表示 note-on、note-off、controller、contact 与 target-audio detection，但不强迫所有 source 填同样字段。
3. 由 session contract 与 test fake 立即消费。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceObservation.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift'`
- Run: `git commit -m "feat: P8-T1 - 定义 PerformanceObservation 事件契约"`

---

<a id="p8-t2"></a>
## P8-T2 定义输入能力与证据状态

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceInputCapabilities.swift`
- Modify: `HappyPianistAVP/Models/Practice/PerformanceObservation.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift`

**Implementation:**
1. 能力维度覆盖 pitch、onset、release、velocity、controllers、polyphony、hand、finger、position 与 confidence。
2. 每个维度区分 observed、unavailable 与 degraded，不用 Bool 混淆。
3. 现有 MIDI、audio 与 hand mode 映射为 capability set。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSessionMIDIOnlyModeTests.swift, HappyPianistAVPTests/Practice/PracticeSessionAudioRecognitionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceInputCapabilities.swift' 'HappyPianistAVP/Models/Practice/PerformanceObservation.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift'`
- Run: `git commit -m "feat: P8-T2 - 定义输入能力与证据状态"`

---

<a id="p8-t3"></a>
## P8-T3 建立统一 monotonic clock 与 latency calibration

**Requirements:** OBS-009
**Primary owner:** OBS-009

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceClock.swift`
- Create: `HappyPianistAVP/Services/Practice/Input/PerformanceClockSynchronizer.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift`
- Modify: `HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift`

**Implementation:**
1. 统一 host monotonic instant、source timestamp、estimated latency 与 correction provenance。
2. clock synchronizer 处理 offset、drift sample 与不可校准 source。
3. 所有测试通过 injected clock 推进，不读取 Date 作为排序依据。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceClock.swift' 'HappyPianistAVP/Services/Practice/Input/PerformanceClockSynchronizer.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift' 'HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift'`
- Run: `git commit -m "feat: P8-T3 - 建立统一 monotonic clock 与 latency calibration"`

---

<a id="p8-t4"></a>
## P8-T4 完整适配 MIDI1 与 MIDI2 observation

**Requirements:** OBS-001
**Primary owner:** OBS-001

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Input/MIDIPerformanceObservationAdapter.swift`
- Modify: `HappyPianistAVP/Models/MIDI/MIDI1InputEvent.swift`
- Modify: `HappyPianistAVP/Models/MIDI/MIDI2InputEvent.swift`
- Modify: `HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift`

**Implementation:**
1. 保留 velocity、release velocity、CC、channel、group、source、source timestamp 与 host uptime。
2. MIDI2 高分辨率值保留原始 normalized precision，只有输出到 MIDI1 时 downconvert。
3. 删除忽略 velocity 与 controller 的 switch 分支。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift, HappyPianistAVPTests/MIDI/MIDI2ValueMappingTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Input/MIDIPerformanceObservationAdapter.swift' 'HappyPianistAVP/Models/MIDI/MIDI1InputEvent.swift' 'HappyPianistAVP/Models/MIDI/MIDI2InputEvent.swift' 'HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift' 'HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift'`
- Run: `git commit -m "refactor: P8-T4 - 完整适配 MIDI1 与 MIDI2 observation"`

---

<a id="p8-t5"></a>
## P8-T5 让 PracticeMIDIInputService 发布 observation 流

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelInputRefresh.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift`

**Implementation:**
1. 原始 observation 进入 recorder 与 analyzer；即时 step matcher 只消费明确投影。
2. start、stop 与 refresh source 时 generation guard 丢弃旧事件。
3. 自播放 suppression 根据 source 与 playback generation，不靠时间猜测。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift, HappyPianistAVPTests/Practice/PracticeSessionReplayGateTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelInputRefresh.swift' 'HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift'`
- Run: `git commit -m "refactor: P8-T5 - 让 PracticeMIDIInputService 发布 observation 流"`

---

<a id="p8-t6"></a>
## P8-T6 重构 chord attempt 的 onset 与 release 语义

**Requirements:** OBS-002
**Primary owner:** OBS-002

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Matching/MIDIPracticeStepMatcher.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/ChordAttemptAccumulator.swift`
- Modify: `HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift`

**Implementation:**
1. 用 observation timestamps 计算 chord onset spread，不再只在宽时间窗内累积音高集合。
2. 区分 rolled 或 arpeggiated target 与普通 simultaneous chord。
3. release 仅在输入 capability 存在且当前目标需要时参与即时判定。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Matching/MIDIPracticeStepMatcher.swift' 'HappyPianistAVP/Services/Practice/Matching/ChordAttemptAccumulator.swift' 'HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift'`
- Run: `git commit -m "refactor: P8-T6 - 重构 chord attempt 的 onset 与 release 语义"`

---

<a id="p8-t7"></a>
## P8-T7 明确麦克风 observation 的有限能力

**Requirements:** OBS-003
**Primary owner:** OBS-003

**Files:**
- Modify: `HappyPianistAVP/Services/AudioRecognition/AudioRecognitionTypes.swift`
- Modify: `HappyPianistAVP/Services/Practice/Input/PracticeAudioRecognitionInputService.swift`
- Modify: `HappyPianistAVP/Services/AudioRecognition/TargetedHarmonicTemplateDetector.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeAudioRecognitionCoordinatorTests.swift`

**Implementation:**
1. targeted detector 输出 target evidence、confidence、onset 与 generation，不伪造 polyphonic note stream、release 或 velocity。
2. 映射到 observation 时 capability 明确为 target-guided 与 monophonic-limited。
3. insufficient confidence 返回 unknown，不进入 wrong-note reducer。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeAudioRecognitionCoordinatorTests.swift, HappyPianistAVPTests/AudioRecognition/TargetedHarmonicTemplateDetectorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/AudioRecognition/AudioRecognitionTypes.swift' 'HappyPianistAVP/Services/Practice/Input/PracticeAudioRecognitionInputService.swift' 'HappyPianistAVP/Services/AudioRecognition/TargetedHarmonicTemplateDetector.swift' 'HappyPianistAVPTests/Practice/PracticeAudioRecognitionCoordinatorTests.swift'`
- Run: `git commit -m "refactor: P8-T7 - 明确麦克风 observation 的有限能力"`

---

<a id="p8-t8"></a>
## P8-T8 升级 RecordingTake 元数据与向后解码

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Recording/RecordingModels.swift`
- Modify: `HappyPianistAVP/Services/Recording/RecordingSupport.swift`
- Modify: `HappyPianistAVPTests/Recording/RecordingTakeStoreTests.swift`

**Implementation:**
1. schema 增加 score identity、input source descriptor、capabilities、clock mapping、latency correction 与 calibration version。
2. 旧 JSON 缺字段时使用明确 legacy defaults，不创建第二套 store。
3. 编码禁止绝对路径与原始曲谱。

**Validation:**
- Focus: HappyPianistAVPTests/Recording/RecordingTakeStoreTests.swift, HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Recording/RecordingModels.swift' 'HappyPianistAVP/Services/Recording/RecordingSupport.swift' 'HappyPianistAVPTests/Recording/RecordingTakeStoreTests.swift'`
- Run: `git commit -m "feat: P8-T8 - 升级 RecordingTake 元数据与向后解码"`

---

<a id="p8-t9"></a>
## P8-T9 修正录制事件身份与评价证据

**Requirements:** RECORD-001
**Primary owner:** RECORD-001

**Files:**
- Modify: `HappyPianistAVP/Services/Recording/RecordingTakeRecorder.swift`
- Modify: `HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift`
- Modify: `HappyPianistAVP/Services/Recording/RecordingSupport.swift`
- Modify: `HappyPianistAVPTests/Recording/RecordingTakeRecorderTests.swift`

**Implementation:**
1. open note key 使用 source、group、channel、midi 与 event identity，避免跨通道互相关闭。
2. 保留 source 和 host monotonic time、release、controllers 与 calibration reference。
3. 真实与虚拟琴 contact 不再固定 velocity 90；在 P9 接入计算值前明确 degraded source。

**Validation:**
- Focus: HappyPianistAVPTests/Recording/RecordingTakeRecorderTests.swift, HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Recording/RecordingTakeRecorder.swift' 'HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift' 'HappyPianistAVP/Services/Recording/RecordingSupport.swift' 'HappyPianistAVPTests/Recording/RecordingTakeRecorderTests.swift'`
- Run: `git commit -m "fix: P8-T9 - 修正录制事件身份与评价证据"`

---

<a id="p8-t10"></a>
## P8-T10 建立 observation 与 recording 重放 fixtures

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/PerformanceObservationReplays.json`
- Modify: `HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift`
- Modify: `HappyPianistAVPTests/Recording/RecordingMIDIInputTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`

**Implementation:**
1. 覆盖 MIDI1、MIDI2、target audio、乱序、clock offset、controller 与 legacy take。
2. 同一 replay 可驱动 matcher、recorder 与未来 aligner。
3. 文档更新 observation、take 与 progress 的存储边界和隐私限制。

**Validation:**
- Focus: HappyPianistAVPTests/Recording/RecordingMIDIInputTests.swift, HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/PerformanceObservationReplays.json' 'HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift' 'HappyPianistAVPTests/Recording/RecordingMIDIInputTests.swift' 'docs/storage.md' 'docs/data-flow.md'`
- Run: `git commit -m "test: P8-T10 - 建立 observation 与 recording 重放 fixtures"`

---

## Phase Audit

- Audit file: `audit-p8.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否仍有 case noteOn(note, _) 丢 velocity。；同名 MIDI note 跨 channel 或 group 是否冲突。；旧 recording JSON 是否可读且不丢事件。
