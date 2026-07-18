# Plan P11 - 能力感知的演奏评价与小节事实

**Goal:** 从 alignment 生成多维、可解释、能力感知的 assessment，并把允许持久化的结果归约为小节练习事实。

**Non-goals:** 本 phase 不生成具体练法，不重设计评分 UI，不把单一总分当专业结论。

**Approach:** 定义 assessment 维度与 evidence status，分别实现 pitch、timing、duration、articulation、velocity、voicing 与 pedal。rubric 根据 input capabilities 裁剪。最后扩展 measure facts 与 reducer，并保持旧进度向后读取。

**Acceptance:**
- 错误、未知、未观察、证据不足与通过分开。
- 每个指标引用 alignment links 和 source plan events。
- step stable 与 passage performance maturity 分开。
- 进度 JSON 只保存小节聚合事实。

**Rules:**
- 没有证据的维度不计零分。
- PracticeStep 不增加完整 assessment 字段。
- 不持久化逐音 alignment、raw observations、cue 或 summary。

**State / lifecycle:** assessment 在 passage 或 take 完成、或 committed alignment 更新时运行；取消 generation 丢弃未完成结果。

**Threading / actor:** 指标计算离开 MainActor；只发布不可变 summary。

**Debug / observability:** 记录可评维度、unknown 比例、rubric version 与 metric distribution bucket，不记录逐音用户演奏。

**Testing strategy:** 每维合成 fixtures 加 capability matrix；progress migration 与 reducer tests；端到端 session integration。

**Audit focus:**
- 是否把 step match 继续当 performance mature。
- 旧进度文件升级是否改变已有稳定小节事实。
- total score 是否掩盖 unknown。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p11-t1"></a>
## P11-T1 定义 Assessment 与内部成功语义

**Requirements:** ARCH-003
**Primary owner:** ARCH-003

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceAssessment.swift`
- Create: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`

**Implementation:**
1. 定义 passage 与 measure assessment、dimension result、rubric version 和 evidence links。
2. 明确 pitch-step completion、passage assessment、reference playback 与 creative duet 是不同内部成功语义。
3. 不新增用户可见模式枚举。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceAssessment.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift'`
- Run: `git commit -m "feat: P11-T1 - 定义 Assessment 与内部成功语义"`

---

<a id="p11-t2"></a>
## P11-T2 统一 correct、incorrect、unknown 与 insufficient evidence

**Requirements:** ASSESS-004
**Primary owner:** ASSESS-004

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PerformanceAssessment.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/StepMatcher.swift`

**Implementation:**
1. 建立稳定 evidence status 与 outcome enum。
2. 把 audio 或 hand ambiguity 和 missing capability 映射为 unknown 或 insufficient，而非 wrong。
3. 即时 matcher 与 passage assessment 共享结果词汇但不共享数据模型。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/StepMatcherTests.swift, HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceAssessment.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVP/Services/Practice/Matching/StepMatcher.swift'`
- Run: `git commit -m "refactor: P11-T2 - 统一 correct、incorrect、unknown 与 insufficient evidence"`

---

<a id="p11-t3"></a>
## P11-T3 实现 pitch、onset 与 chord timing 指标

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. 在单一 PerformanceAssessmentService 中从 committed alignment 计算 exact pitch、extra、missing、onset deviation、chord spread 与 tempo-relative timing。
2. arpeggio 与 grace 使用 plan semantics。
3. PracticePerformanceAnalyzer 立即消费 service；指标保留样本数、confidence 与 evidence status。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift' 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P11-T3 - 实现 pitch、onset 与 chord timing 指标"`

---

<a id="p11-t4"></a>
## P11-T4 实现 duration、release 与 articulation 指标

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. 比较 performed duration 与 plan target 和 tolerance，不直接比较 written duration。
2. 区分 legato overlap、gap、staccato ratio 与 premature release。
3. 缺 note-off capability 返回 notObserved。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift' 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P11-T4 - 实现 duration、release 与 articulation 指标"`

---

<a id="p11-t5"></a>
## P11-T5 实现 velocity、dynamic contour 与 voicing 指标

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. 评估相对 dynamic contour、accent、melody 与 accompaniment balance 和 chord voicing。
2. 使用 score voice、hand 与 teacher target provenance，不假设最高音总是旋律。
3. MIDI 或 calibrated hand 有 velocity 才评分。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift' 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P11-T5 - 实现 velocity、dynamic contour 与 voicing 指标"`

---

<a id="p11-t6"></a>
## P11-T6 实现 pedal、tempo continuity 与 phrase 指标

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. 评估 pedal change time 与 value、overlap、gap、tempo drift 与 phrase continuity。
2. 只有 controller capability 存在才评 pedal；generic profile 结果标记 approximation。
3. 避免把 rubato 自动判为节奏错误。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift' 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P11-T6 - 实现 pedal、tempo continuity 与 phrase 指标"`

---

<a id="p11-t7"></a>
## P11-T7 实现 capability-aware rubric

**Requirements:** ASSESS-005
**Primary owner:** ASSESS-005

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentRubric.swift`
- Modify: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift`
- Modify: `HappyPianistAVP/Models/Practice/PerformanceInputCapabilities.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. rubric 根据 observed dimensions 选择指标和 tolerance，不可观测维度排除。
2. 输出维度结果与 evidence coverage，不生成误导性单一总分。
3. 麦克风、MIDI、hand 与 recording 的矩阵写成表驱动测试。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentRubric.swift' 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentService.swift' 'HappyPianistAVP/Models/Practice/PerformanceInputCapabilities.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P11-T7 - 实现 capability-aware rubric"`

---

<a id="p11-t8"></a>
## P11-T8 区分步骤稳定与演奏成熟

**Requirements:** ASSESS-002
**Primary owner:** ASSESS-002

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PracticeProgressModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeAttemptReducer.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeAttemptReducerTests.swift`

**Implementation:**
1. 保留现有 step completion 事实，但命名和模型不再暗示专业演奏稳定。
2. 新增可选 measure performance maturity summary，只来自 passage assessment。
3. 现有 stable 状态向后映射为 pitch-step stability，不自动升级 mature。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeAttemptReducerTests.swift, HappyPianistAVPTests/Practice/PracticeProgressModelsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PracticeProgressModels.swift' 'HappyPianistAVP/Services/Practice/Progress/PracticeAttemptReducer.swift' 'HappyPianistAVPTests/Practice/PracticeAttemptReducerTests.swift'`
- Run: `git commit -m "refactor: P11-T8 - 区分步骤稳定与演奏成熟"`

---

<a id="p11-t9"></a>
## P11-T9 升级小节练习事实 schema 并兼容旧 JSON

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PracticeProgressModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift`

**Implementation:**
1. 只持久化每小节的 metric summaries、sample counts、rubric version 与 evidence coverage。
2. 逐音 observation、alignment、cue、summary、teacher prompt 和 visuals 不编码。
3. 旧 schema 解码测试与 round-trip 不丢现有进度。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PracticeProgressModels.swift' 'HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift' 'HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift'`
- Run: `git commit -m "feat: P11-T9 - 升级小节练习事实 schema 并兼容旧 JSON"`

---

<a id="p11-t10"></a>
## P11-T10 把 assessment 接入 session 与 progress coordinator

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift`
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressCoordinator.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift`

**Implementation:**
1. passage 或 round 完成时产生 assessment 并归约到 measure facts。
2. 即时 step 流程保持低延迟，不等待完整 assessment 才推进。
3. generation、cancel 与 resume 不重复写入同一 assessment。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift, HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Alignment/PracticePerformanceAnalyzer.swift' 'HappyPianistAVP/Services/Practice/Progress/PracticeProgressCoordinator.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift' 'HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift'`
- Run: `git commit -m "feat: P11-T10 - 把 assessment 接入 session 与 progress coordinator"`

---

## Phase Audit

- Audit file: `audit-p11.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否把 step match 继续当 performance mature。；旧进度文件升级是否改变已有稳定小节事实。；total score 是否掩盖 unknown。
