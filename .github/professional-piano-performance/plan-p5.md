# Plan P5 - 唯一 ScorePerformancePlan 与消费者切换

**Goal:** 建立并落地唯一规范演奏计划，使声音、高亮、PracticeStep、记谱与外部 MIDI 由同一 source identity 和 performed occurrence 投影。

**Non-goals:** 本 phase 不实现完整用户演奏评价，也不优化音频设备调度细节。

**Approach:** 先定义不可变计划及 builder，再加入 PreparedPractice。随后逐个消费者切换；每次切换同 task 删除对应旧反推路径。最后删除 note spans 与 highlight 作为声音真源的双轨状态。

**Acceptance:**
- PreparedPractice 持有唯一 ScorePerformancePlan。
- autoplay 不再从 guides 重建 note events。
- 所有 projection 可追溯到 source note 与 performed occurrence。
- 旧 note-span 与 timeline 双轨数据源被删除。

**Rules:**
- plan 只保存音乐与演奏事实，不保存 UI entity、颜色或恢复效果。
- plan 不写入进度 JSON。
- 投影层不得修改 plan 或互相反推。

**State / lifecycle:** plan 在 preparation generation 中一次性构建；取消准备时丢弃整个 generation。

**Threading / actor:** builder 不在 MainActor；ViewModel 只在准备完成后接收不可变结果。

**Debug / observability:** 记录 plan build duration、event counts、unsupported 与 approximation counts 和 projection mismatch。

**Testing strategy:** builder 单测、projection parity 与完整 preparation / autoplay integration snapshots。

**Audit focus:**
- 是否仍存在 guides 到 note events 的反向链。
- 是否因移除 note spans 丢 tie、voice 或 controller。
- PreparedPractice 生命周期和所有测试 convenience init 是否全部更新。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p5-t1"></a>
## P5-T1 定义 ScorePerformancePlan 核心模型

**Requirements:** ARCH-001
**Primary owner:** ARCH-001

**Files:**
- Create: `HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`

**Implementation:**
1. 定义 plan identity、source score identity、order、resolution、note events、tempo events、controller events、annotations 与 approximation provenance。
2. note event 同时保存 source note ID、performed occurrence、written 与 performed timing、pitch、velocity、staff、voice 和 hand assignment。
3. 保持纯数据且可稳定 snapshot，不加入 AVFoundation 或 CoreMIDI 类型。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift'`
- Run: `git commit -m "feat: P5-T1 - 定义 ScorePerformancePlan 核心模型"`

---

<a id="p5-t2"></a>
## P5-T2 实现 note event plan builder

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Performance/ScorePerformancePlanBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift`

**Implementation:**
1. 从 logical instrument、performed order、source notes、timing schedule 和 velocity resolution 构建 plan notes。
2. 保留同音多声部与重复触键，不按 MIDI 合并。
3. 创建后立即由测试和准备服务下一 task 消费，不暴露平台 API。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Performance/ScorePerformancePlanBuilder.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift'`
- Run: `git commit -m "feat: P5-T2 - 实现 note event plan builder"`

---

<a id="p5-t3"></a>
## P5-T3 把 tempo、pedal、controllers 与 annotations 加入 plan

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Performance/ScorePerformancePlanBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLPedalTimeline.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLTempoMap.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 控制事件保留 source direction ID、performed occurrence、continuous value 和 output capability requirement。
2. tempo、pause 与 phrase directives 和 note timing 使用同一 tick domain。
3. 快照验证 controllers 不因 active range 或 guide filtering 丢失。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Performance/ScorePerformancePlanBuilder.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLPedalTimeline.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLTempoMap.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "feat: P5-T3 - 把 tempo、pedal、controllers 与 annotations 加入 plan"`

---

<a id="p5-t4"></a>
## P5-T4 让 PreparedPractice 持久携带演奏计划

**Requirements:** PERF-001
**Primary owner:** PERF-001
**Atomicity exception:** PreparedPractice 是跨生产与测试的成员签名迁移；必须在一次提交内迁移全部直接构造点，避免引入临时 optional / legacy initializer 和双轨真源。

**Files:**
- Create: `HappyPianistAVPTests/Support/PreparedPracticeTestFactory.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift`
- Modify: `HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift`
- Modify: `HappyPianistAVPTests/Practice/ManualAdvanceStrategyTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeFlowCoordinatorTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLocalizationPolicyTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`

**Implementation:**
1. PreparedPractice 新增非可选 plan，并在准备服务同 generation 构建；准备取消或失败时不得发布半成品 plan。
2. 创建共享 test factory，并迁移 codegraph / 编译器识别出的全部直接 PreparedPractice 构造点；不得保留无 plan 的 production 或 legacy initializer。
3. 更新 state store 与生命周期测试，删除仅在 preparation 局部存在、无法被消费者审查的 note spans。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift, HappyPianistAVPTests/Practice/PracticePreparationCancellationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Support/PreparedPracticeTestFactory.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift' 'HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift' 'HappyPianistAVPTests/Practice/ManualAdvanceStrategyTests.swift' 'HappyPianistAVPTests/Practice/PracticeFlowCoordinatorTests.swift' 'HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift' 'HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift' 'HappyPianistAVPTests/Practice/PracticeLocalizationPolicyTests.swift' 'HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift'`
- Run: `git commit -m "refactor: P5-T4 - 让 PreparedPractice 持久携带演奏计划"`

---

<a id="p5-t5"></a>
## P5-T5 从 plan 投影即时 PracticeStep

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/PracticeStepBuilder.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift`

**Implementation:**
1. 让现有 PracticeStepBuilder 直接消费 plan notes，按 performed onset 生成即时目标 step，并保留 source note IDs 与 hand provenance。
2. PracticeStep 不承载完整 duration、assessment 或 controller。
3. 切换准备服务后，在同一 task 删除旧从 raw notes 独立调度 step 的入口；不新增挂在 Model 上的投影 extension。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/PracticeStepBuilder.swift' 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift'`
- Run: `git commit -m "refactor: P5-T5 - 从 plan 投影即时 PracticeStep"`

---

<a id="p5-t6"></a>
## P5-T6 从 plan 投影琴键 highlight guides

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Guides/PianoHighlightGuideBuilderService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVPTests/Piano/PianoHighlightGuideBuilderServiceTests.swift`

**Implementation:**
1. 让现有 PianoHighlightGuideBuilderService 直接消费 plan event identity 与 occurrence，不再用 midi、staff、voice 和 tick 猜 join。
2. 同音多声部可共享物理键视觉，但保留多个 source contributors。
3. 切换后删除旧 longest / first-wins join 逻辑；不新增挂在 Model 上的投影 extension。

**Validation:**
- Focus: HappyPianistAVPTests/Piano/PianoHighlightGuideBuilderServiceTests.swift, HappyPianistAVPTests/Piano/PianoHighlightViewConsistencyTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guides/PianoHighlightGuideBuilderService.swift' 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVPTests/Piano/PianoHighlightGuideBuilderServiceTests.swift'`
- Run: `git commit -m "refactor: P5-T6 - 从 plan 投影琴键 highlight guides"`

---

<a id="p5-t7"></a>
## P5-T7 从 plan 与 source score 投影 notation 输入

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`

**Implementation:**
1. 建立 source written facts 加 performed occurrence 与 active state 的 projection contract。
2. layout 暂保持现有能力，但不得再从 MIDI 推断 written duration 或 accidental 作为权威事实。
3. P13 在此 contract 上扩展完整表示。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift' 'HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift'`
- Run: `git commit -m "refactor: P5-T7 - 从 plan 与 source score 投影 notation 输入"`

---

<a id="p5-t8"></a>
## P5-T8 让 autoplay 直接消费 ScorePerformancePlan

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PracticePlaybackControlService.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelPlayback.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`
- Delete: `AutoplayPerformanceTimeline.normalizedNoteIntervals(from guides:)`

**Implementation:**
1. timeline 输入改为 plan、active range 与 hand filter projection。
2. note、tempo 与 controller 事件保留 event identity，不按 guide 合并。
3. 同 task 删除 guides-to-sound 入口与旧 normalized intervals。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVP/Services/Practice/Playback/PracticePlaybackControlService.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelPlayback.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "refactor: P5-T8 - 让 autoplay 直接消费 ScorePerformancePlan"`

---

<a id="p5-t9"></a>
## P5-T9 让应用内与外部 MIDI 使用同一 plan 事件序列

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PlaybackSequenceBuilder.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift`

**Implementation:**
1. sequence builders 接收 plan event IDs 与 controller events，不再重新解释 steps 或 guides。
2. 应用内 sampler 与 CoreMIDI 暂保留现有 transport，但事件内容必须一致。
3. 删除 PlaybackSequenceBuilder 中从 step 或 guide 合成表现事件的分支。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift, HappyPianistAVPTests/Playback/PlaybackSequenceBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift' 'HappyPianistAVP/Services/Practice/Playback/PlaybackSequenceBuilder.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift'`
- Run: `git commit -m "refactor: P5-T9 - 让应用内与外部 MIDI 使用同一 plan 事件序列"`

---

<a id="p5-t10"></a>
## P5-T10 删除旧演奏真源并更新架构文档

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift`
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/piano-performance-quality.md`
- Delete: `PreparedPractice 中旧并行 tempo、pedal、fermata 与 highlight 声音真源字段`
- Delete: `未被 plan 消费的 note-span preparation 局部路径`

**Implementation:**
1. 搜索并移除所有从 highlights 或 steps 反推声音的调用方。
2. 保留 highlight 与 steps 仅作为 plan projection；更新文档为唯一数据流。
3. 运行全测试并更新 snapshot，不保留 dual path feature flag。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift' 'docs/architecture.md' 'docs/data-flow.md' 'docs/modules/happypianist-avp.md' 'docs/piano-performance-quality.md'`
- Run: `git commit -m "refactor: P5-T10 - 删除旧演奏真源并更新架构文档"`

---

## Phase Audit

- Audit file: `audit-p5.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否仍存在 guides 到 note events 的反向链。；是否因移除 note spans 丢 tie、voice 或 controller。；PreparedPractice 生命周期和所有测试 convenience init 是否全部更新。
