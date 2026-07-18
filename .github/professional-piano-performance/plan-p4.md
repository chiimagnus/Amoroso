# Plan P4 - 统一表现语义与记谱调度

**Goal:** 用单一调度解释 grace、arpeggio、dynamics、wedge、tempo、articulation、fermata、slur 与常用 ornaments，并标记所有近似。

**Non-goals:** 本 phase 不直接控制 AVAudio 或 CoreMIDI，也不把风格启发式宣称为唯一钢琴家演绎。

**Approach:** 建立纯逻辑 ScoreTimingSchedule 与 interpretation profile，让 PracticeStepBuilder 和 note-span / performance plan builder 共享结果。先实现规范确定部分，再把风格相关值放入有来源的 profile 与 approximation。

**Acceptance:**
- grace previous、following 与 make-time 分别生效。
- arpeggio number、direction 与 cross-staff 分组稳定。
- dynamic 与 wedge 按最近有效事件和 scope 解析。
- tempo ramp、articulation、fermata 与 ornaments 只有一个调度实现。

**Rules:**
- 不得在 step builder 和 span builder 保留平行算法。
- 风格 profile 不能写入进度 JSON。
- 未支持符号必须保留 source identity 与 unsupported 或 approximation。

**State / lifecycle:** 调度器为纯值转换；profile 在准备开始时快照，运行中不变。

**Threading / actor:** 所有解析与调度离开 MainActor；不得使用真实时间。

**Debug / observability:** 记录 unsupported kind、approximation reason 和 event count，不记录原谱文本。

**Testing strategy:** 表驱动单元测试加 exporter fixture snapshots；每项语义覆盖边界和冲突优先级。

**Audit focus:**
- grace 是否仍错误缩短 following note。
- fermata 是否在 note duration 与 pause 两处重复。
- dynamic scope 与 tick precedence 是否被数组顺序影响。
- 旧调度代码是否完整删除。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p4-t1"></a>
## P4-T1 建立共享 ScoreTimingSchedule

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/ScoreTimingSchedule.swift`
- Create: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVP/Services/PracticeStepBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift`

**Implementation:**
1. 定义 source note 的 written interval、performed interval、onset offset、release policy 与 provenance。
2. builder 先复现当前基础 timing，并立即被两个现有 builder 调用。
3. 删除两个 builder 内最基础的重复 tick 算术。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/ScoreTimingSchedule.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVP/Services/PracticeStepBuilder.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift'`
- Run: `git commit -m "refactor: P4-T1 - 建立共享 ScoreTimingSchedule"`

---

<a id="p4-t2"></a>
## P4-T2 完整实现 grace previous、following 与 make-time

**Requirements:** SCORE-009
**Primary owner:** SCORE-009

**Files:**
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserGraceDetailsTests.swift`

**Implementation:**
1. 解析 make-time，并把 previous 与 following 的百分比基准绑定到正确相邻音。
2. 处理连续 grace、slash、无合法相邻音和跨 measure。
3. 删除把 previous 与 following 合并为同一 fallback 的旧逻辑。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserGraceDetailsTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserGraceTupletTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserGraceDetailsTests.swift'`
- Run: `git commit -m "fix: P4-T2 - 完整实现 grace previous、following 与 make-time"`

---

<a id="p4-t3"></a>
## P4-T3 按 number、direction 与跨谱表解释 arpeggio

**Requirements:** SCORE-010
**Primary owner:** SCORE-010

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift`

**Implementation:**
1. 分组 key 使用 logical instrument、performed tick、number token 与 source chord identity。
2. direction 决定升序或降序；跨 staff 同 number 合并，不同 number 分离。
3. 未标记成员不被同 tick 邻音误吸入。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift, HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift' 'HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift'`
- Run: `git commit -m "fix: P4-T3 - 按 number、direction 与跨谱表解释 arpeggio"`

---

<a id="p4-t4"></a>
## P4-T4 修正 dynamics 与 wedge 时间优先级

**Requirements:** SCORE-011
**Primary owner:** SCORE-011

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLVelocityResolverTests.swift`

**Implementation:**
1. 以不晚于 note tick 的最近有效 event 为基准，按 scope specificity 和 source precedence 解析。
2. 同 tick sound、direction 与 note override 冲突规则写成表，不依赖数组顺序。
3. wedge start 与 stop 通过 number token 配对，未闭合 wedge 标记近似。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLVelocityResolverTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserWedgeTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLVelocityResolverTests.swift'`
- Run: `git commit -m "fix: P4-T4 - 修正 dynamics 与 wedge 时间优先级"`

---

<a id="p4-t5"></a>
## P4-T5 生成连续 dynamic curve 与重音修饰

**Requirements:** SCORE-011

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLDynamicCurve.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 把 wedge 转换为有起止值、scope 和 interpolation provenance 的 curve。
2. accent 与 marcato 等局部修饰在曲线解析后应用，并 clamp 但不丢原始 base。
3. 测试跨 measure、嵌套 number、立即 stop 与 missing target。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLDynamicCurve.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "feat: P4-T5 - 生成连续 dynamic curve 与重音修饰"`

---

<a id="p4-t6"></a>
## P4-T6 扩展 tempo words 与 tempo ramp

**Requirements:** PERF-006
**Primary owner:** PERF-006

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLWordsSemanticsInterpreter.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLTempoMap.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLWordsSemanticsInterpreterTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLTempoMapTests.swift`

**Implementation:**
1. 扩展 ritardando、rallentando、accelerando、stringendo、a tempo、tempo primo、doppio 与 meno mosso 等受控词汇。
2. 只在有明确 anchor 与 target 时生成 ramp；否则保留 annotation 与 approximation。
3. tempo map 插值使用 tick-domain，不在 MainActor 或 wall clock 计算。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLWordsSemanticsInterpreterTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLTempoMapTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLWordsSemanticsInterpreter.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLTempoMap.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLWordsSemanticsInterpreterTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLTempoMapTests.swift'`
- Run: `git commit -m "feat: P4-T6 - 扩展 tempo words 与 tempo ramp"`

---

<a id="p4-t7"></a>
## P4-T7 建立发音法与 fermata interpretation profile

**Requirements:** PERF-005
**Primary owner:** PERF-005

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLInterpretationProfile.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLFermataTimeline.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift`

**Implementation:**
1. 把 staccato、staccatissimo、tenuto、detached legato、marcato 与 fermata 时值从散落常量迁入 profile。
2. profile 标记 generic approximation，不称为作曲家或钢琴家风格。
3. source score 保存 articulation 与 fermata 事实，performed timing 只保存解析结果和 profile ID。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLRealisticPlaybackDefaultsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLInterpretationProfile.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLFermataTimeline.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift'`
- Run: `git commit -m "refactor: P4-T7 - 建立发音法与 fermata interpretation profile"`

---

<a id="p4-t8"></a>
## P4-T8 为常用演奏符号建立来源契约

**Requirements:** SCORE-012
**Primary owner:** SCORE-012

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLPerformanceNotation.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserArticulationsTests.swift`

**Implementation:**
1. 解析并保留 slur、trill、mordent、turn、tremolo、glissando、breath 与 caesura 的 token、number、placement 和 source identity。
2. 尚未解释的参数仍进入模型，不静默忽略。
3. 更新 unsupported counts 为按 kind 的可诊断统计。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserArticulationsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLPerformanceNotation.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserArticulationsTests.swift'`
- Run: `git commit -m "feat: P4-T8 - 为常用演奏符号建立来源契约"`

---

<a id="p4-t9"></a>
## P4-T9 解释 slur、breath 与 caesura 的基础时序

**Requirements:** SCORE-012

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift`

**Implementation:**
1. slur 只影响连贯 release policy，不等同于 pedal。
2. breath 与 caesura 在明确位置生成 phrase gap 或 pause directive，并保留 profile provenance。
3. 冲突时优先保持 note identity 和不重叠安全，输出 approximation。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift'`
- Run: `git commit -m "feat: P4-T9 - 解释 slur、breath 与 caesura 的基础时序"`

---

<a id="p4-t10"></a>
## P4-T10 解释 ornament、tremolo 与 glissando 事件

**Requirements:** SCORE-012

**Files:**
- Create: `HappyPianistAVP/Services/MusicXML/MusicXMLOrnamentScheduler.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 用明确 profile 生成 trill、mordent 与 turn 的辅助音、速度和结束规则。
2. 区分 measured 与 unmeasured tremolo；glissando 仅在可确定端点和音阶策略时生成。
3. 无法确定 accidental 或 style 时保留 notation 并标记 unsupported，不猜测。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLOrnamentScheduler.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "feat: P4-T10 - 解释 ornament、tremolo 与 glissando 事件"`

---

<a id="p4-t11"></a>
## P4-T11 删除 step 与 note-span 的重复调度

**Requirements:** SCORE-014
**Primary owner:** SCORE-014

**Files:**
- Modify: `HappyPianistAVP/Services/PracticeStepBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Delete: `PracticeStepBuilder 内 grace 与 arpeggio 私有调度`
- Delete: `MusicXMLNoteSpanBuilder 内重复 grace 与 arpeggio 调度`

**Implementation:**
1. 两个 builder 只消费 ScoreTimingSchedule，不得各自重算 offset。
2. 同一 source note 的 performed onset 与 release 在两个投影中断言一致。
3. 删除旧 helper、旧常量和只覆盖旧路径的测试入口。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/PracticeStepBuilder.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift'`
- Run: `git commit -m "refactor: P4-T11 - 删除 step 与 note-span 的重复调度"`

---

<a id="p4-t12"></a>
## P4-T12 建立表现语义 golden snapshots

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ExpressivePianoSemantics.musicxml`
- Modify: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`
- Modify: `docs/piano-performance-quality.md`

**Implementation:**
1. fixture 同时覆盖 grace、arpeggio、dynamic curve、tempo ramp、fermata、slur、ornament 与 unsupported。
2. snapshot 断言 source notation、schedule、performed timing 和 provenance。
3. 更新质量文档的已支持、近似、未支持表，不改产品宣传。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ExpressivePianoSemantics.musicxml' 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift' 'docs/piano-performance-quality.md'`
- Run: `git commit -m "test: P4-T12 - 建立表现语义 golden snapshots"`

---

## Phase Audit

- Audit file: `audit-p4.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: grace 是否仍错误缩短 following note。；fermata 是否在 note duration 与 pause 两处重复。；dynamic scope 与 tick precedence 是否被数组顺序影响。；旧调度代码是否完整删除。
