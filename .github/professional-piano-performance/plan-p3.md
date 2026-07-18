# Plan P3 - 逻辑钢琴乐器、part 选择、手别与演奏顺序

**Goal:** 在不破坏原谱 staff 与 voice 的前提下，安全识别钢琴逻辑乐器、选择练习 part、表达 hand provenance，并显式区分书写顺序与演奏顺序。

**Non-goals:** 本 phase 不生成最终声音事件，不把启发式 hand 写回原谱，也不新增用户可见模式。

**Approach:** 以 P2 的 part metadata 和 source identity 为输入，建立 logical instrument 与 performed occurrence。所有不确定选择必须显式失败或标记 ambiguous，禁止继续用 P1、note-count 或 staff 硬编码确定事实。

**Acceptance:**
- 两个独立乐器不会被误合并成钢琴。
- 同一钢琴拆成两个 part 时，notes、directions、attributes、measures 和 structure events 全部保留。
- staff 与 hand 分离，hand 带 explicit、inferred 或 unknown provenance。
- performed order 产生稳定 occurrence IDs 并可映射回 source measures。

**Rules:**
- 原始 partID、staff、voice 和 source IDs 不被归一化覆盖。
- 不为 hand unknown 自动默认 right hand。
- 不因启用 performed order 改变 source score。

**State / lifecycle:** 归一化与结构展开为一次性纯转换；无长期任务或共享可变状态。

**Threading / actor:** 转换不在 MainActor；输出为不可变值，供准备服务消费。

**Debug / observability:** 只记录 part count、selection reason、ambiguity 和 expansion count，不记录曲名或原谱文本。

**Testing strategy:** 使用双乐器、双 part 钢琴、跨谱表、双手交叉、单谱表交错和 repeats fixtures。

**Audit focus:**
- 是否仍有 staff 小于等于 1 就是右手的路径。
- 是否仅移动 notes 而遗漏低音 part 的 directions 与 measures。
- performed occurrence 与 persisted source measure identity 是否混淆。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p3-t1"></a>
## P3-T1 建立逻辑乐器与 part selection 结果模型

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLLogicalInstrument.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`

**Implementation:**
1. 定义 logical instrument、member part IDs、classification evidence 和 selection ambiguity。
2. 保持 source score 不变，由转换结果引用 source IDs。
3. 增加纯模型 equality 测试并由 grand-staff normalizer 消费。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLLogicalInstrument.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift'`
- Run: `git commit -m "feat: P3-T1 - 建立逻辑乐器与 part selection 结果模型"`

---

<a id="p3-t2"></a>
## P3-T2 重写安全的大谱表归一化

**Requirements:** SCORE-003
**Primary owner:** SCORE-003

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLPianoGrandStaffNormalizer.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLScore+PartFiltering.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift`

**Implementation:**
1. 只在 part metadata 明确指向同一钢琴逻辑乐器时合并，不再以两 part 加 G/F clef 作为充分条件。
2. 保留每个 source part，并将 notes、directions、attributes、measures、repeats 与 endings 映射到 logical instrument。
3. 增加双乐器反例与低音 part direction 保留测试。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLPianoGrandStaffNormalizer.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLScore+PartFiltering.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift'`
- Run: `git commit -m "fix: P3-T2 - 重写安全的大谱表归一化"`

---

<a id="p3-t3"></a>
## P3-T3 替换 P1 与音符数量主 part 启发式

**Requirements:** SCORE-004
**Primary owner:** SCORE-004

**Files:**
- Create: `HappyPianistAVP/Services/MusicXML/MusicXMLPracticePartSelector.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLScore+PartFiltering.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift`

**Implementation:**
1. 按 explicit piano metadata、single logical instrument 与可演奏性排序选择。
2. 多候选且无法判定时返回结构化 ambiguity，不静默选最多 notes。
3. 删除 preferredPrimaryPartID 的 P1 与 note-count 实现和旧测试。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLPracticePartSelector.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLScore+PartFiltering.swift' 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift'`
- Run: `git commit -m "refactor: P3-T3 - 替换 P1 与音符数量主 part 启发式"`

---

<a id="p3-t4"></a>
## P3-T4 定义 hand assignment 与来源

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Practice/ScoreHandAssignment.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVP/Models/Practice/PianoHighlightGuide.swift`

**Implementation:**
1. 支持 right、left、unknown 与 score、user、teacher、heuristic provenance。
2. 允许同一 staff 上不同 source notes 拥有不同 assignment。
3. 现有消费者先接受 unknown，不在模型 init 中默认 right。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/ScoreHandTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreHandAssignment.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVP/Models/Practice/PianoHighlightGuide.swift'`
- Run: `git commit -m "feat: P3-T4 - 定义 hand assignment 与来源"`

---

<a id="p3-t5"></a>
## P3-T5 删除 staff 等于 hand 的硬编码

**Requirements:** SCORE-005
**Primary owner:** SCORE-005

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/PianoGuideKeyHighlightResolver.swift`
- Modify: `HappyPianistAVPTests/Notation/ScoreHandTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PianoGuideKeyHighlightResolverTests.swift`
- Delete: `ScoreHand.fromStaff(_:) 旧 API`

**Implementation:**
1. 删除 ScoreHand.fromStaff 与 PracticeStepNote 的隐式默认。
2. 调用方必须传 assignment；unknown 由视觉和匹配层使用中性处理。
3. 覆盖 cross-staff、双手交叉和三谱表不误判。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/ScoreHandTests.swift, HappyPianistAVPTests/Practice/PianoGuideKeyHighlightResolverTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVP/Services/Practice/Guides/PianoGuideKeyHighlightResolver.swift' 'HappyPianistAVPTests/Notation/ScoreHandTests.swift' 'HappyPianistAVPTests/Practice/PianoGuideKeyHighlightResolverTests.swift'`
- Run: `git commit -m "fix: P3-T5 - 删除 staff 等于 hand 的硬编码"`

---

<a id="p3-t6"></a>
## P3-T6 让单谱表 hand router 只产生派生 assignment

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLHandRouter.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift`

**Implementation:**
1. 保留原 staff 和 voice，不再按 pitch 改写 staff。
2. 输出带 heuristic provenance 与 confidence 的 source-note assignment map。
3. 启发式不能确定时返回 unknown；删除旧 staff mutation 分支。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLHandRouter.swift' 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift'`
- Run: `git commit -m "refactor: P3-T6 - 让单谱表 hand router 只产生派生 assignment"`

---

<a id="p3-t7"></a>
## P3-T7 显式建模书写顺序与演奏顺序

**Requirements:** SCORE-013
**Primary owner:** SCORE-013

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLPerformedOrder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLPlaybackDefaults.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift`

**Implementation:**
1. 定义 written 与 performed 作为内部准备语义，不添加用户模式 UI。
2. 选择结果进入准备契约和 diagnostics，禁止隐藏全局 shouldExpandStructure 常量。
3. 默认值保持当前练习行为，参考播放可明确请求 performed order。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLRealisticPlaybackDefaultsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLPerformedOrder.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLPlaybackDefaults.swift' 'HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift'`
- Run: `git commit -m "refactor: P3-T7 - 显式建模书写顺序与演奏顺序"`

---

<a id="p3-t8"></a>
## P3-T8 让结构展开产生稳定 occurrence identity

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLStructureExpander.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLStructureExpanderTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift`

**Implementation:**
1. 每个 performed note、direction 和 measure occurrence 保留 source ID 加 occurrence index。
2. 处理 repeats、endings、D.C.、D.S.、Coda 的确定路径和循环上限。
3. 不得改写 source measure identity 或进度持久化 key。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLStructureExpanderTests.swift, HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLStructureExpander.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLStructureExpanderTests.swift' 'HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift'`
- Run: `git commit -m "feat: P3-T8 - 让结构展开产生稳定 occurrence identity"`

---

<a id="p3-t9"></a>
## P3-T9 将逻辑乐器、hand 与 order 接入准备服务

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticePreparationIdentityTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`

**Implementation:**
1. 按 part selection、order、hand assignment 的固定顺序转换。
2. 准备结果暂存 source score context 和 hand assignments，供 P5 演奏计划消费。
3. 删除旧 grand-staff、primary-part 与 hand-route 分散调用。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticePreparationIdentityTests.swift, HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift' 'HappyPianistAVP/Models/Practice/PracticeModels.swift' 'HappyPianistAVPTests/Practice/PracticePreparationIdentityTests.swift' 'HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift'`
- Run: `git commit -m "refactor: P3-T9 - 将逻辑乐器、hand 与 order 接入准备服务"`

---

<a id="p3-t10"></a>
## P3-T10 补齐多 part 与跨谱表 golden fixtures

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/TwoInstrumentNotPiano.musicxml`
- Create: `HappyPianistAVPTests/Fixtures/SplitPartGrandStaffPiano.musicxml`
- Create: `HappyPianistAVPTests/Fixtures/CrossStaffHandAssignment.musicxml`
- Modify: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift`
- Modify: `docs/data-flow.md`

**Implementation:**
1. 新增最小但真实的反例与正例，并登记 exporter 与 provenance。
2. 快照同时断言 source facts、logical instrument 与 performed occurrences。
3. 更新 data-flow 中的 score normalization 边界。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/TwoInstrumentNotPiano.musicxml' 'HappyPianistAVPTests/Fixtures/SplitPartGrandStaffPiano.musicxml' 'HappyPianistAVPTests/Fixtures/CrossStaffHandAssignment.musicxml' 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json' 'HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift' 'docs/data-flow.md'`
- Run: `git commit -m "test: P3-T10 - 补齐多 part 与跨谱表 golden fixtures"`

---

## Phase Audit

- Audit file: `audit-p3.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否仍有 staff 小于等于 1 就是右手的路径。；是否仅移动 notes 而遗漏低音 part 的 directions 与 measures。；performed occurrence 与 persisted source measure identity 是否混淆。
