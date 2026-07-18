# Plan P1 - 证据基线、快照与可重复验证

**Goal:** 先让曲谱、演奏事件、输入观察和运行指标可被稳定比较，为后续每个音乐语义改动建立回归证据。

**Non-goals:** 本 phase 不修正 MusicXML 语义，不改变播放、匹配、进度或用户界面。

**Approach:** 增加只承载事实的确定性 snapshot、fixture 与 replay 支持，先记录当前链路和已知偏差。测试支持必须复用生产模型或独立 test support，不能另造一套业务实现。

**Acceptance:**
- 曲谱和演奏事件可序列化为稳定、无本机路径的文本快照。
- 所有 54 个审查编号进入可机读 traceability。
- 输入重放不依赖真实时间、真实硬件或网络。
- 诊断指标不包含原始乐谱、逐音传感器或敏感路径。

**Rules:**
- 只新增证据与 characterization，不用 snapshot 固化已知错误为正确规范。
- 测试时间使用确定性时钟；不得通过真实 Task.sleep 等待。
- 计划与证据文件不写入业务进度 JSON。

**State / lifecycle:** 测试支持无长期任务；fixture loader 每次调用独立创建、读取并释放资源。

**Threading / actor:** 快照编码和 fixture 读取不在 MainActor；测试断言可在测试 actor 执行。

**Debug / observability:** 新增 DiagnosticsReporting category 只记录计数、阶段、耗时桶和 capability，不记录逐音正文。

**Testing strategy:** 使用 Swift Testing；先建立 snapshot 与 manifest 自检，再运行完整 visionOS 测试 target。

**Audit focus:**
- 快照字段是否足以发现 source identity、同音折叠、踏板、tempo 与 occurrence 丢失。
- 是否误把测试专用模型接入生产状态或持久化。
- traceability 是否覆盖 54 个编号且无重复 primary owner。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p1-t1"></a>
## P1-T1 建立确定性快照编码约定

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Support/PianoPerformanceSnapshotSupport.swift`
- Modify: `HappyPianistAVPTests/Support/PracticeAttemptTestSupport.swift`

**Implementation:**
1. 定义稳定排序、数字格式、可选值和 provenance 的文本编码约定。
2. 提供 snapshot comparison helper，失败时输出最小 diff，不写绝对路径。
3. 由至少一个现有 MusicXML 测试实际消费 helper，避免孤立文件。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Support/PianoPerformanceSnapshotSupport.swift' 'HappyPianistAVPTests/Support/PracticeAttemptTestSupport.swift'`
- Run: `git commit -m "test: P1-T1 - 建立确定性快照编码约定"`

---

<a id="p1-t2"></a>
## P1-T2 增加规范谱面快照投影

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Support/MusicXMLScoreSnapshot.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 从 MusicXMLScore 投影 notes、directions、measures、repeats 和 scope。
2. 按 source order、tick 和 scope 稳定排序，不调用业务启发式。
3. 在 expressivity integration test 中生成并断言最小 fixture 快照。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Support/MusicXMLScoreSnapshot.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "test: P1-T2 - 增加规范谱面快照投影"`

---

<a id="p1-t3"></a>
## P1-T3 增加演奏事件快照投影

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Support/PerformanceEventSnapshot.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift`

**Implementation:**
1. 记录 tick、event kind、MIDI、velocity、controller、step 与 guide identity 及排序位置。
2. 保留当前缺失字段的显式占位，后续引入 source identity 时只扩字段不改排序原则。
3. 用现有 autoplay 和 sequence builder 测试消费快照。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift, HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Support/PerformanceEventSnapshot.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift' 'HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift'`
- Run: `git commit -m "test: P1-T3 - 增加演奏事件快照投影"`

---

<a id="p1-t4"></a>
## P1-T4 建立 MusicXML fixture manifest

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`
- Create: `HappyPianistAVPTests/Support/PianoPerformanceFixtureLoader.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift`

**Implementation:**
1. 为现有 fixture 登记来源、授权、导出器、覆盖语义和期望 snapshot 名称。
2. loader 校验每个文件存在、ID 唯一且没有未登记的专业 fixture。
3. 将现有 autoplay regression fixture 接入 manifest。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json' 'HappyPianistAVPTests/Support/PianoPerformanceFixtureLoader.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift'`
- Run: `git commit -m "test: P1-T4 - 建立 MusicXML fixture manifest"`

---

<a id="p1-t5"></a>
## P1-T5 建立输入重放与确定性时钟支持

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift`
- Modify: `HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift`
- Modify: `HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift`

**Implementation:**
1. 定义测试专用 monotonic instant、source event 和 replay cursor。
2. 允许按明确顺序同步推进事件，不依赖 wall clock 或真实 Task.sleep。
3. 让一个 matcher 测试和一个 recording 测试使用同一 replay 支持。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift, HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift' 'HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift' 'HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift'`
- Run: `git commit -m "test: P1-T5 - 建立输入重放与确定性时钟支持"`

---

<a id="p1-t6"></a>
## P1-T6 登记已知偏差而不固化错误行为

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/PianoPerformanceKnownDeviations.json`
- Create: `HappyPianistAVPTests/Support/KnownDeviationManifestTests.swift`

**Implementation:**
1. 把 54 个审查编号与当前 fixture、test 和 planned task 建立可解析映射。
2. 对尚无 fixture 的编号明确 missingEvidence，不添加会永久通过错误实现的断言。
3. 测试确保编号唯一且审查文档编号全部被登记。

**Validation:**
- Focus: HappyPianistAVPTests/Support/KnownDeviationManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/PianoPerformanceKnownDeviations.json' 'HappyPianistAVPTests/Support/KnownDeviationManifestTests.swift'`
- Run: `git commit -m "test: P1-T6 - 登记已知偏差而不固化错误行为"`

---

<a id="p1-t7"></a>
## P1-T7 增加专业链路结构化诊断事件

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift`
- Modify: `HappyPianistAVP/Services/Diagnostics/DiagnosticsReporter.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift`

**Implementation:**
1. 定义 preparation、plan、playback、input、alignment 和 assessment 的低基数事件与计数。
2. 在 composition root 注册并由现有 reporter 消费；不得直接新增 os.Logger 调用。
3. 标记可导出事件并测试隐私字段白名单。

**Validation:**
- Focus: HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift, HappyPianistAVPTests/Diagnostics/DiagnosticsReporterTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift' 'HappyPianistAVP/Services/Diagnostics/DiagnosticsReporter.swift' 'HappyPianistAVP/ViewModels/LiveAppGraph.swift' 'HappyPianistAVPTests/Diagnostics/DiagnosticModelsTests.swift'`
- Run: `git commit -m "feat: P1-T7 - 增加专业链路结构化诊断事件"`

---

<a id="p1-t8"></a>
## P1-T8 记录专业验证运行手册并接入文档导航

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/piano-performance-validation.md`
- Modify: `docs/testing/core-function-checklist.md`
- Modify: `docs/overview.md`

**Implementation:**
1. 记录 snapshot、fixture、输入重放、Simulator、真机、盲听和教学有效性证据的分层。
2. 明确 xcodebuild test、真机测试和人工证据不能互相替代。
3. 更新 overview 与核心功能检查清单入口，不追加开发流水账。

**Validation:**
- Focus: docs/testing/piano-performance-validation.md, docs/overview.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/piano-performance-validation.md' 'docs/testing/core-function-checklist.md' 'docs/overview.md'`
- Run: `git commit -m "docs: P1-T8 - 记录专业验证运行手册并接入文档导航"`

---

## Phase Audit

- Audit file: `audit-p1.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 快照字段是否足以发现 source identity、同音折叠、踏板、tempo 与 occurrence 丢失。；是否误把测试专用模型接入生产状态或持久化。；traceability 是否覆盖 54 个编号且无重复 primary owner。
