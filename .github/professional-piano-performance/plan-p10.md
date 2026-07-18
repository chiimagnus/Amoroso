# Plan P10 - Score–Performance Alignment

**Goal:** 把连续用户演奏 observation 对齐到 ScorePerformancePlan 的 source events 和 performed occurrences，为评价提供可解释证据。

**Non-goals:** 本 phase 不生成教师建议、不修改进度稳定规则，也不强迫麦克风承担超出能力的维度。

**Approach:** 先定义 alignment result、candidate 与 evidence，再实现 MIDI 优先的 deterministic offline 与 incremental aligner。成本函数显式建模 pitch、onset、release、voice、occurrence、extra、missing 与 controller；歧义保留候选。

**Acceptance:**
- 单音、和弦、重复音、多声部、repeats 与踏板均可对齐。
- unknown、ambiguous、provisional 与 wrong 稳定分开。
- online 与 offline 对同一完整 take 得到一致最终映射。
- 旧 generation、自播放和乱序 observation 不污染 alignment。

**Rules:**
- 不得用正负一半音修改 pitch cost 为正确。
- aligner 输出不持久化到进度 JSON。
- 算法必须有有界窗口或复杂度说明和升级路径注释。

**State / lifecycle:** session alignment state 在 practice generation start 创建，seek、range、stop、cancel 与 teardown reset；offline take aligner 无共享状态。

**Threading / actor:** 对齐计算离开 MainActor；增量结果以节流 snapshot 回到 ViewModel 或 recorder。

**Debug / observability:** 记录候选数、alignment latency、ambiguity、extra 或 missing 聚合和窗口退化，不记录逐音内容。

**Testing strategy:** synthetic replay、golden take、property tests 与性能上限；不依赖真实硬件或网络。

**Audit focus:**
- 同音多声部与 performed occurrence 是否混淆。
- 在线窗口是否在长曲或 repeats 中漂移。
- score event 与 observation identity 是否可回溯。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p10-t1"></a>
## P10-T1 定义 alignment 候选、映射与证据模型

**Requirements:** ASSESS-001
**Primary owner:** ASSESS-001

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceAlignment.swift`
- Create: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`
- Modify: `HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift`
- Modify: `HappyPianistAVP/Models/Practice/PerformanceObservation.swift`

**Implementation:**
1. 定义 aligned、missing、extra、ambiguous 与 provisional link 和 evidence components。
2. link 保存 plan event ID、source note ID、performed occurrence 与 observation ID。
3. 模型由下一 task service 和测试立即消费。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceAlignment.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift' 'HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift' 'HappyPianistAVP/Models/Practice/PerformanceObservation.swift'`
- Run: `git commit -m "feat: P10-T1 - 定义 alignment 候选、映射与证据模型"`

---

<a id="p10-t2"></a>
## P10-T2 建立 capability-aware alignment engine 与离线入口

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Create: `HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift`
- Modify: `HappyPianistAVP/Services/Recording/RecordingSupport.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`
- Modify: `HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift`

**Implementation:**
1. engine 按 active range、performed time window、pitch candidate 与 source capability 构建有限候选，并保留无候选原因。
2. RecordedTakeAligner 立即消费 engine，将 versioned take 转成候选快照；不复制候选逻辑。
3. 缺 release、velocity 或 hand 的 source 不使用对应过滤；测试覆盖 capability 裁剪。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift' 'HappyPianistAVP/Services/Recording/RecordingSupport.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift' 'HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift'`
- Run: `git commit -m "feat: P10-T2 - 建立 capability-aware alignment engine 与离线入口"`

---

<a id="p10-t3"></a>
## P10-T3 实现 pitch、onset 与 chord alignment cost

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`

**Implementation:**
1. 在统一 engine 中实现独立成本分量：exact pitch、onset deviation、chord spread、extra 与 missing。
2. arpeggiated target 使用 plan semantics，而不是放宽所有和弦窗口。
3. 所有权重进入明确 rubric config，并有默认测试。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift'`
- Run: `git commit -m "feat: P10-T3 - 实现 pitch、onset 与 chord alignment cost"`

---

<a id="p10-t4"></a>
## P10-T4 加入 release、duration 与 controller 对齐

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Modify: `HappyPianistAVP/Models/Practice/PerformanceAlignment.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`

**Implementation:**
1. 只有 capability observed 时比较 note-off 与 duration。
2. pedal 与 controller 以 time series edge 或 value 对齐，不绑定单一 note。
3. 缺证据输出 notObserved，不增加错误 cost。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVP/Models/Practice/PerformanceAlignment.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift'`
- Run: `git commit -m "feat: P10-T4 - 加入 release、duration 与 controller 对齐"`

---

<a id="p10-t5"></a>
## P10-T5 处理 voice、同音与 performed occurrence

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`

**Implementation:**
1. 利用 source voice、staff 与 hand evidence 区分同音候选，但不要求缺失维度。
2. repeats 中按 performed occurrence 和时间上下文选择，不覆盖 source identity。
3. 增加 polyphonic unison 与 repeated section regression。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift'`
- Run: `git commit -m "fix: P10-T5 - 处理 voice、同音与 performed occurrence"`

---

<a id="p10-t6"></a>
## P10-T6 实现增量在线 alignment 状态机

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Alignment/IncrementalPerformanceAligner.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`

**Implementation:**
1. 维护有界候选窗口、当前 occurrence、provisional links 与 commit horizon。
2. 定义 start、append、seek、rangeChange、reset 与 finish。
3. RecordedTakeAligner 以确定性 replay 模式消费同一增量状态机，比较 online final 与 offline result；旧 timestamp、旧 generation 和自播放事件拒绝进入。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/IncrementalPerformanceAligner.swift' 'HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift'`
- Run: `git commit -m "feat: P10-T6 - 实现增量在线 alignment 状态机"`

---

<a id="p10-t7"></a>
## P10-T7 实现完整 take 离线 aligner

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Modify: `HappyPianistAVP/Services/Recording/RecordingSupport.swift`
- Modify: `HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift`

**Implementation:**
1. 补齐 versioned RecordingTake 的全局 / 分段 alignment、controller series 和 performed occurrence 处理。
2. 继续复用同一 engine 与增量状态机，不复制 candidate 或 cost 算法。
3. 输出可比较 online final 与 offline result 的 diagnostics snapshot。

**Validation:**
- Focus: HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/RecordedTakeAligner.swift' 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVP/Services/Recording/RecordingSupport.swift' 'HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift'`
- Run: `git commit -m "feat: P10-T7 - 实现完整 take 离线 aligner"`

---

<a id="p10-t8"></a>
## P10-T8 稳定表达 ambiguity、unknown 与 provisional

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PerformanceAlignment.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/IncrementalPerformanceAligner.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`

**Implementation:**
1. 定义何时可 commit link，何时保留多个候选，何时声明 missing 或 extra。
2. tracking 或 audio evidence 不足不得被 cost 强制选中。
3. 结果序列化到测试 snapshot，但不持久化业务数据。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceAlignment.swift' 'HappyPianistAVP/Services/Practice/Alignment/PerformanceAlignmentEngine.swift' 'HappyPianistAVP/Services/Practice/Alignment/IncrementalPerformanceAligner.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift'`
- Run: `git commit -m "refactor: P10-T8 - 稳定表达 ambiguity、unknown 与 provisional"`

---

<a id="p10-t9"></a>
## P10-T9 将 alignment 接入 session analyzer 生命周期

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift`

**Implementation:**
1. composition root 注入 analyzer；session recorder 同 generation 推送 plan 与 observations。
2. 当前阶段只保存 transient alignment snapshot 和 diagnostics，不改 UI 或 progress。
3. stop、cancel、seek 与 teardown 明确 reset，删除孤立测试-only service。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift, HappyPianistAVPTests/Practice/PracticeSessionViewModelTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift' 'HappyPianistAVP/ViewModels/LiveAppGraph.swift' 'HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift'`
- Run: `git commit -m "feat: P10-T9 - 将 alignment 接入 session analyzer 生命周期"`

---

<a id="p10-t10"></a>
## P10-T10 建立 alignment golden replay 与性能上限

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/PerformanceAlignmentReplays.json`
- Modify: `HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift`
- Modify: `docs/data-flow.md`

**Implementation:**
1. 覆盖 correct、early、late、serial chord、extra、missing、repeat、unison、pedal 与 ambiguous。
2. 增加长曲有界窗口基准，记录上限和升级路径 ponytail 注释。
3. 文档加入 observation 到 alignment 数据流和非持久化边界。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/PerformanceAlignmentReplays.json' 'HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift' 'HappyPianistAVPTests/Practice/PerformanceAlignmentTests.swift' 'docs/data-flow.md'`
- Run: `git commit -m "test: P10-T10 - 建立 alignment golden replay 与性能上限"`

---

## Phase Audit

- Audit file: `audit-p10.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 同音多声部与 performed occurrence 是否混淆。；在线窗口是否在长曲或 repeats 中漂移。；score event 与 observation identity 是否可回溯。
