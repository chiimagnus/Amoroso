# Plan P14 - AI 对弹的语义边界、表现输入与质量门

**Goal:** 让 AI 对弹完整使用用户表现事件并建立更可靠的创意质量门，同时严格与忠实示范、评价和指导基准分离。

**Non-goals:** 本 phase 不把生成结果写回乐谱真源、不自动切换 provider，也不宣称 AI 生成等同钢琴家参考。

**Approach:** 建立 creative duet contract，统一 observation 到 phrase event；补齐 hand velocity、duration 与 sustain。扩展确定性质量 rubric 与 regression corpus，并保留现有 backend selection 和 failure semantics。

**Acceptance:**
- 所有 AI 输入来源保留可观察 velocity、duration、controller 与 source capability。
- 自播放事件不会进入用户 phrase。
- 质量门覆盖节奏、和声、声部、重复、终止与延迟。
- AI 结果不会成为 assessment target。

**Rules:**
- 用户选择 provider 失败即停止，不 fallback。
- prompt 与 AI 正文不进入 exportable diagnostics。
- AI phrase 不覆盖 ScorePerformancePlan。

**State / lifecycle:** duet generation 有 request 与 playback generation；disable、stop 与 new phrase 取消旧请求，out-of-order response 丢弃。

**Threading / actor:** 网络、CoreML 与 rule generation 不阻塞 MainActor；UI 状态更新回 MainActor。

**Debug / observability:** 记录 provider、latency bucket、quality gate reason、cancel 与 stale response，不记录 phrase 正文。

**Testing strategy:** 每个 backend 使用固定 seeds 与 fixture phrases；覆盖故障、乱序、自播放 suppression 和质量 regression。

**Audit focus:**
- 手部输入是否仍固定 velocity 90。
- 质量 gate 是否错误引用参考演奏或评分 rubric。
- provider fallback 是否被重新引入。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p14-t1"></a>
## P14-T1 明确 CreativeDuet 与参考演奏契约分离

**Requirements:** AI-001
**Primary owner:** AI-001

**Files:**
- Create: `HappyPianistAVP/Models/Practice/CreativeDuetModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/AIPerformanceService.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendProtocol.swift`

**Implementation:**
1. 模型明确输入 phrase、creative response、provider、generation 与 provenance。
2. API 禁止接受 ScorePerformancePlan 作为理想演奏或输出 assessment target。
3. 更新现有调用方并删除含混的 reference 命名。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/AIPerformanceCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/CreativeDuetModels.swift' 'HappyPianistAVP/Services/Practice/AI/AIPerformanceService.swift' 'HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendProtocol.swift'`
- Run: `git commit -m "refactor: P14-T1 - 明确 CreativeDuet 与参考演奏契约分离"`

---

<a id="p14-t2"></a>
## P14-T2 统一 observation 到 duet phrase 的转换

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/AI/PerformanceObservationPhraseAdapter.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseEventBuffer.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseBuffer.swift`

**Implementation:**
1. MIDI、recording 与 hand observations 使用同一 phrase event schema。
2. 按 monotonic time 归一化 onset 与 duration，保留 capability 和 approximation。
3. 创建后立即替换各 source 的独立 phrase 构建。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetPhraseEventBufferTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/AI/PerformanceObservationPhraseAdapter.swift' 'HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseEventBuffer.swift' 'HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseBuffer.swift'`
- Run: `git commit -m "refactor: P14-T2 - 统一 observation 到 duet phrase 的转换"`

---

<a id="p14-t3"></a>
## P14-T3 保留手部 phrase 的 velocity、duration 与 pedal

**Requirements:** AI-002
**Primary owner:** AI-002

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/PerformanceObservationPhraseAdapter.swift`
- Modify: `HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift`
- Modify: `HappyPianistAVPTests/Practice/DuetPhraseEventBufferTests.swift`

**Implementation:**
1. 使用 P9 resolved velocity 与 release 事件，不再固定 90。
2. 有 controller capability 时保留 sustain；没有时标记 notObserved。
3. 录制、播放与 AI 输入共享 observation identity。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetPhraseEventBufferTests.swift, HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift' 'HappyPianistAVP/Services/Practice/AI/PerformanceObservationPhraseAdapter.swift' 'HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift' 'HappyPianistAVPTests/Practice/DuetPhraseEventBufferTests.swift'`
- Run: `git commit -m "fix: P14-T3 - 保留手部 phrase 的 velocity、duration 与 pedal"`

---

<a id="p14-t4"></a>
## P14-T4 强化 self-playback suppression 与 generation guard

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetTurnTakingCore.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/Playback/DuetAIPlaybackQueue.swift`
- Modify: `HappyPianistAVPTests/Practice/DuetParallelInputWhilePlaybackTests.swift`
- Modify: `HappyPianistAVPTests/Practice/DuetOutOfOrderResponseTests.swift`

**Implementation:**
1. 通过 source 与 playback generation 排除系统播放，不依赖静音时间窗。
2. 旧 response、旧 playback callback 与 disable 后事件全部丢弃。
3. teardown 取消请求、队列和音频命令。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetParallelInputWhilePlaybackTests.swift, HappyPianistAVPTests/Practice/DuetOutOfOrderResponseTests.swift, HappyPianistAVPTests/Practice/DuetDisableTeardownTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetTurnTakingCore.swift' 'HappyPianistAVP/Services/Practice/AI/Playback/DuetAIPlaybackQueue.swift' 'HappyPianistAVPTests/Practice/DuetParallelInputWhilePlaybackTests.swift' 'HappyPianistAVPTests/Practice/DuetOutOfOrderResponseTests.swift'`
- Run: `git commit -m "fix: P14-T4 - 强化 self-playback suppression 与 generation guard"`

---

<a id="p14-t5"></a>
## P14-T5 定义创意对弹质量 rubric

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/AI/ImprovQualityRubric.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovScheduleBuilder.swift`
- Modify: `HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift`

**Implementation:**
1. 维度覆盖 density、repetition、register、rhythmic coherence、voice leading、harmonic fit、cadence、conflict 与 response latency。
2. rubric 只判断 creative response 可用性，不判断用户专业演奏。
3. 阈值版本化并有默认 fixture。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/AI/ImprovQualityRubric.swift' 'HappyPianistAVP/Services/Practice/AI/ImprovScheduleBuilder.swift' 'HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift'`
- Run: `git commit -m "feat: P14-T5 - 定义创意对弹质量 rubric"`

---

<a id="p14-t6"></a>
## P14-T6 扩展和声、风格与长程结构质量门

**Requirements:** AI-003
**Primary owner:** AI-003

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovQualityRubric.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleImprovGenerator.swift`
- Modify: `HappyPianistAVPTests/Practice/DuetQualityRegressionFixtures.swift`

**Implementation:**
1. 加入 phrase-level harmonic tension 与 release、cadence、motivic repetition 和 voice crossing 检查。
2. 不合格响应返回结构化 reason；不得自动换 provider。
3. 覆盖短 phrase、密集 chord、跨 register leap 与无终止。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/AI/ImprovQualityRubric.swift' 'HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleImprovGenerator.swift' 'HappyPianistAVPTests/Practice/DuetQualityRegressionFixtures.swift'`
- Run: `git commit -m "feat: P14-T6 - 扩展和声、风格与长程结构质量门"`

---

<a id="p14-t7"></a>
## P14-T7 建立每个 backend 的确定性质量 corpus

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVPTests/Practice/DuetQualityRegressionFixtures.swift`
- Modify: `HappyPianistAVPTests/Practice/ImprovScheduleBuilderTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceRNNEventDecodingTests.swift`

**Implementation:**
1. 固定 seeds、输入 phrase、provider configuration 与期望 rubric outcomes。
2. 本地 rule、CoreML 与 network protocol 共享结构性门，但不要求相同音符。
3. 网络测试使用 fake response，不依赖外部服务。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift, HappyPianistAVPTests/Practice/PerformanceRNNEventDecodingTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Practice/DuetQualityRegressionFixtures.swift' 'HappyPianistAVPTests/Practice/ImprovScheduleBuilderTests.swift' 'HappyPianistAVPTests/Practice/PerformanceRNNEventDecodingTests.swift'`
- Run: `git commit -m "test: P14-T7 - 建立每个 backend 的确定性质量 corpus"`

---

<a id="p14-t8"></a>
## P14-T8 锁定用户选择后端的失败语义与诊断

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendRegistry.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendSelection.swift`
- Modify: `HappyPianistAVP/Services/Practice/AI/AIPerformanceService.swift`
- Modify: `HappyPianistAVPTests/Practice/AIPerformanceCoordinatorTests.swift`

**Implementation:**
1. provider unavailable、timeout、invalid response 与 quality gate failure 均终止本次生成并返回明确错误。
2. 删除任何隐式 fallback 或 silent local substitution。
3. diagnostics 只记录 provider kind 与 failure category。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/AIPerformanceCoordinatorTests.swift, HappyPianistAVPTests/Networking/ImprovStreamingClientTimeoutTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendRegistry.swift' 'HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendSelection.swift' 'HappyPianistAVP/Services/Practice/AI/AIPerformanceService.swift' 'HappyPianistAVPTests/Practice/AIPerformanceCoordinatorTests.swift'`
- Run: `git commit -m "fix: P14-T8 - 锁定用户选择后端的失败语义与诊断"`

---

<a id="p14-t9"></a>
## P14-T9 更新 AI 能力边界与隐私文档

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/configuration.md`
- Modify: `docs/piano-performance-quality.md`
- Modify: `README.md`

**Implementation:**
1. 明确 AI 对弹是创意响应，不是忠实示范、评分目标或教师事实。
2. 记录 provider failure、no fallback 与 diagnostics 隐私边界。
3. 只有质量 corpus 与实际 provider 验证通过后更新支持声明。

**Validation:**
- Focus: docs/piano-performance-quality.md, docs/configuration.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/architecture.md' 'docs/data-flow.md' 'docs/configuration.md' 'docs/piano-performance-quality.md' 'README.md'`
- Run: `git commit -m "docs: P14-T9 - 更新 AI 能力边界与隐私文档"`

---

## Phase Audit

- Audit file: `audit-p14.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 手部输入是否仍固定 velocity 90。；质量 gate 是否错误引用参考演奏或评分 rubric。；provider fallback 是否被重新引入。
