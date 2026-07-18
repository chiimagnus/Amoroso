# Plan P12 - 受证据约束的诊断与虚拟指导

**Goal:** 把 assessment 转换为来源明确、优先级稳定、可执行且可验证的练法，同时保持现有单一练曲主线。

**Non-goals:** 本 phase 不增加音高、节奏或力度模式选择器，不实现开放式聊天教师，也不持久化派生 coaching decision。

**Approach:** 先定义 musical issue 与 coaching action，再建立规则映射、teacher target、tolerance 和 hand 或 fingering provenance。最后将现有 feedback、hotspot 与 next-action policies 改为消费 coaching decision，并保持现有 ViewModel 与 UI contract。

**Acceptance:**
- 每个建议能追溯 assessment evidence、score range 与 confidence。
- 一次只选择主要问题或明确组合练法。
- 证据不足时不生成伪教师诊断。
- 建议执行后可由后续 assessment 测量是否改善。

**Rules:**
- AI 不是默认诊断引擎。
- coaching decisions、cues 与 summaries 不写进 progress JSON。
- hand 或 fingering 启发式必须显示 provenance。

**State / lifecycle:** coaching service 在 assessment 完成后运行；seek、新 round 与新 generation 取消旧 decision。ViewModel 只持有当前派生结果。

**Threading / actor:** 规则评估离开 MainActor；UI 状态发布回 MainActor。

**Debug / observability:** 记录 issue kind、confidence bucket、action kind、accepted、skipped 与 remeasured 聚合，不记录用户演奏正文。

**Testing strategy:** 表驱动 issue 到 exercise 测试、unknown 与 conflict 测试、现有反馈集成测试和教学有效性 instrumentation。

**Audit focus:**
- 是否把低 confidence 诊断包装成确定文案。
- 是否产生新用户模式。
- 是否把建议持久化。
- 旧 feedback policy 是否与新 decision 双轨。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p12-t1"></a>
## P12-T1 定义可解释 MusicalIssue taxonomy

**Requirements:** ASSESS-003
**Primary owner:** ASSESS-003

**Files:**
- Create: `HappyPianistAVP/Models/Practice/MusicalIssue.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift`
- Modify: `HappyPianistAVP/Models/Practice/PerformanceAssessment.swift`

**Implementation:**
1. 覆盖 pitch、onset、chord spread、duration、articulation、voicing、dynamic contour、pedal、tempo、phrase 与 evidence issue。
2. issue 保存 score range、dimension results、confidence 和 provenance。
3. 不包含 UI 文案或 AI prompt。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/MusicalIssue.swift' 'HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift' 'HappyPianistAVP/Models/Practice/PerformanceAssessment.swift'`
- Run: `git commit -m "feat: P12-T1 - 定义可解释 MusicalIssue taxonomy"`

---

<a id="p12-t2"></a>
## P12-T2 定义 CoachingAction 与练习参数

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Practice/CoachingAction.swift`
- Modify: `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackModels.swift`

**Implementation:**
1. 动作表达 range、tempo ratio、hand focus、voice focus、repeat count、reference 或 cue 使用和完成条件。
2. 保持动作是派生数据，不进入 progress JSON。
3. 由下一 task policy 与现有 feedback model 立即消费。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/CoachingAction.swift' 'HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackModels.swift'`
- Run: `git commit -m "feat: P12-T2 - 定义 CoachingAction 与练习参数"`

---

<a id="p12-t3"></a>
## P12-T3 建立音乐问题到练法的规则映射

**Requirements:** GUIDE-001
**Primary owner:** GUIDE-001

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Guidance/PracticeExercisePolicy.swift`
- Create: `HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift`

**Implementation:**
1. 为每类 issue 定义最小、可测的练法和成功再测指标。
2. 优先复用现有 lower-tempo、hotspot、expand-range 与 manual replay 能力。
3. CoachingDecisionService 立即消费 policy 形成确定性 decision；不得用通用多练习文案代替动作。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guidance/PracticeExercisePolicy.swift' 'HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift' 'HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift'`
- Run: `git commit -m "feat: P12-T3 - 建立音乐问题到练法的规则映射"`

---

<a id="p12-t4"></a>
## P12-T4 实现主要问题优先级与冲突策略

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Guidance/CoachingPriorityPolicy.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift`

**Implementation:**
1. 按 severity、confidence、evidence coverage、可行动性和先决关系排序。
2. 一次输出一个主要 action；只有共享 range 或 prerequisite 时组合。
3. CoachingDecisionService 立即消费 priority policy，并定义跳过、连续无改善和重新评估规则。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guidance/CoachingPriorityPolicy.swift' 'HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift' 'HappyPianistAVPTests/Practice/PracticeCoachingDecisionTests.swift'`
- Run: `git commit -m "feat: P12-T4 - 实现主要问题优先级与冲突策略"`

---

<a id="p12-t5"></a>
## P12-T5 让 hotspot 与 next-action 消费 coaching decision

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Feedback/PracticeHotspotPolicy.swift`
- Modify: `HappyPianistAVP/Services/Practice/Feedback/PracticeNextActionPolicy.swift`
- Modify: `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeNextActionPolicyTests.swift`

**Implementation:**
1. 保留现有 UI contract，但 range、tempo 与 focus 由 CoachingAction 提供。
2. 删除只基于 wrong count 的平行 next-action 分支。
3. 缺 assessment 时继续使用明确基础重试，不伪造诊断。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeNextActionPolicyTests.swift, HappyPianistAVPTests/Practice/PracticeHotspotPolicyTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Feedback/PracticeHotspotPolicy.swift' 'HappyPianistAVP/Services/Practice/Feedback/PracticeNextActionPolicy.swift' 'HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift' 'HappyPianistAVPTests/Practice/PracticeNextActionPolicyTests.swift'`
- Run: `git commit -m "refactor: P12-T5 - 让 hotspot 与 next-action 消费 coaching decision"`

---

<a id="p12-t6"></a>
## P12-T6 引入教师目标与 tolerance profile

**Requirements:** GUIDE-003
**Primary owner:** GUIDE-003

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceTargetProfile.swift`
- Modify: `HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentRubric.swift`
- Modify: `HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift`

**Implementation:**
1. target 可来自 score default、教师或用户确认，并分别保存 provenance。
2. 允许 rubato、voicing 与 pedal 等多个合理区间，不强迫唯一理想演奏。
3. 没有教师 profile 时使用 generic baseline 并明确 approximation。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceTargetProfile.swift' 'HappyPianistAVP/Services/Practice/Assessment/PerformanceAssessmentRubric.swift' 'HappyPianistAVPTests/Practice/PerformanceAssessmentTests.swift'`
- Run: `git commit -m "feat: P12-T6 - 引入教师目标与 tolerance profile"`

---

<a id="p12-t7"></a>
## P12-T7 让 hand 与 fingering 建议显示来源

**Requirements:** GUIDE-002
**Primary owner:** GUIDE-002

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScoreHandAssignment.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guidance/PracticeExercisePolicy.swift`
- Modify: `HappyPianistAVPTests/Notation/ScoreHandTests.swift`

**Implementation:**
1. 建议对象保存 score、teacher、user 或 heuristic provenance 与 confidence。
2. 未知不得以颜色、staff 或位置伪装为确定。
3. 现有 UI 若不展示来源，先提供中性可访问 label，不重设计布局。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/ScoreHandTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreHandAssignment.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVP/Services/Practice/Guidance/PracticeExercisePolicy.swift' 'HappyPianistAVPTests/Notation/ScoreHandTests.swift'`
- Run: `git commit -m "feat: P12-T7 - 让 hand 与 fingering 建议显示来源"`

---

<a id="p12-t8"></a>
## P12-T8 定义证据不足与降级指导

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Guidance/CoachingPriorityPolicy.swift`
- Modify: `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeFeedbackPolicyTests.swift`

**Implementation:**
1. unknown、ambiguous 与 low confidence 优先生成重测、校准或继续的中性动作。
2. 麦克风不输出 voicing 或 pedal 指导；hand tracking 不确定不输出错音诊断。
3. 无可行动问题时不强制建议。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeFeedbackPolicyTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guidance/CoachingPriorityPolicy.swift' 'HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift' 'HappyPianistAVPTests/Practice/PracticeFeedbackPolicyTests.swift'`
- Run: `git commit -m "fix: P12-T8 - 定义证据不足与降级指导"`

---

<a id="p12-t9"></a>
## P12-T9 保证 coaching 派生状态不落进度 JSON

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift`

**Implementation:**
1. 编码白名单仅保留 measure facts；显式测试 coaching、cue、summary 与 target runtime state 不编码。
2. session resume 从 facts 重新计算建议，不恢复旧派生 decision。
3. 删除任何临时将 feedback 存入 progress 的路径。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift, HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift' 'HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift'`
- Run: `git commit -m "test: P12-T9 - 保证 coaching 派生状态不落进度 JSON"`

---

<a id="p12-t10"></a>
## P12-T10 接入现有 feedback ViewModel 而不新增模式 UI

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeFeedback/PracticeFeedbackViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeFeedbackViewModelTests.swift`

**Implementation:**
1. composition root 注入 decision service；ViewModel 将 action 映射到现有 feedback presentation。
2. 不增加音高、节奏或力度模式选择器；用户仍从同一练曲流程进入。
3. new generation、round 与 skip 清理旧 decision。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeFeedbackViewModelTests.swift, HappyPianistAVPTests/Practice/PracticePositiveFeedbackIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift' 'HappyPianistAVP/ViewModels/PracticeFeedback/PracticeFeedbackViewModel.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift' 'HappyPianistAVP/ViewModels/LiveAppGraph.swift' 'HappyPianistAVPTests/Practice/PracticeFeedbackViewModelTests.swift'`
- Run: `git commit -m "feat: P12-T10 - 接入现有 feedback ViewModel 而不新增模式 UI"`

---

<a id="p12-t11"></a>
## P12-T11 增加指导再测与教学有效性 instrumentation

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift`
- Modify: `docs/data-flow.md`

**Implementation:**
1. 用匿名 decision ID 关联 before metric、action kind 与 after metric，不保存逐音数据。
2. 测试 action 执行后重新 assessment，而不是仅点击即视为成功。
3. 文档更新 assessment、coaching 与 measure facts 闭环。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift' 'HappyPianistAVP/Services/Practice/Guidance/CoachingDecisionService.swift' 'HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift' 'docs/data-flow.md'`
- Run: `git commit -m "feat: P12-T11 - 增加指导再测与教学有效性 instrumentation"`

---

## Phase Audit

- Audit file: `audit-p12.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否把低 confidence 诊断包装成确定文案。；是否产生新用户模式。；是否把建议持久化。；旧 feedback policy 是否与新 decision 双轨。
