# Plan P2 - MusicXML 来源身份、书写事实与解析正确性

**Goal:** 保留原始 part、written pitch、source note identity 与 direction identity，并修正确定性的 MusicXML 解析规范错误。

**Non-goals:** 本 phase 不决定左右手、不展开演奏顺序、不建立最终 ScorePerformancePlan。

**Approach:** 先扩展纯模型，再让 parser 在单次解析中分配稳定 source identity；随后修正 dynamics、offset、拍号、移调和 octave-shift。每个替换 task 同时删除旧的派生 ID 或直接 velocity 解释。

**Acceptance:**
- 同一 MusicXML 重复解析产生完全相同的 source IDs。
- written pitch 与 performed MIDI pitch 同时保留。
- 所有 direction 类事件通过一个 offset 解析路径。
- 数值 dynamics 按 MusicXML 百分比语义解释 decimal。

**Rules:**
- source identity 不能由 velocity、duration 或后续表现字段组成。
- 不把微分音强制四舍五入后丢弃原始 alter。
- parser 不访问 UI、播放或持久化。

**State / lifecycle:** parser delegate state 在每次 parse 创建；source ordinal 只在当前 score 生命周期内递增并在结束后释放。

**Threading / actor:** XML 解析与模型构建不在 MainActor；新增值类型满足 Swift 6 并发约束。

**Debug / observability:** 解析失败只记录安全错误类别、元素名和匿名计数，不记录原始曲谱文本或绝对路径。

**Testing strategy:** 每个规范修复先增加最小 XML fixture，再更新 snapshot；保留 partwise、timewise 和 MXL 回归。

**Audit focus:**
- ID 是否在 timewise 转换、MXL 解包和结构展开前后保持来源一致。
- offset 是否被重复应用。
- 旧 id 计算属性和旧 dynamics 断言是否在同 task 删除。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p2-t1"></a>
## P2-T1 增加 part 与 instrument 元数据模型

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLPartMetadata.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`

**Implementation:**
1. 定义 score-part、part-name、part-abbreviation、score-instrument 和 midi-instrument 的最小事实模型。
2. 把 metadata 挂到 MusicXMLScore，保持 Model 纯数据。
3. 初始化所有 parser state，避免缺省依赖 P1。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLPartMetadata.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift'`
- Run: `git commit -m "feat: P2-T1 - 增加 part 与 instrument 元数据模型"`

---

<a id="p2-t2"></a>
## P2-T2 解析 part-list 与 MIDI instrument 信息

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+XMLParserDelegate.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift`

**Implementation:**
1. 在 part-list 生命周期内收集名称、instrument name、MIDI channel、program 和 bank。
2. 按 part ID 绑定元数据；重复或缺失 ID 返回可诊断解析错误。
3. 增加双乐器与钢琴 part fixture，验证元数据不被 note count 推断覆盖。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+XMLParserDelegate.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift'`
- Run: `git commit -m "feat: P2-T2 - 解析 part-list 与 MIDI instrument 信息"`

---

<a id="p2-t3"></a>
## P2-T3 保留 written pitch 与 decimal alter

**Requirements:** SCORE-006
**Primary owner:** SCORE-006

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLWrittenPitch.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift`

**Implementation:**
1. 用 step、octave、decimal alter 和 accidental token 保存书写音高。
2. performed MIDI pitch 继续作为可选派生值，但不得替代 written pitch。
3. 覆盖 C# 与 Db、双升降、四分音变化和 rest 无 pitch。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLWrittenPitch.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift'`
- Run: `git commit -m "feat: P2-T3 - 保留 written pitch 与 decimal alter"`

---

<a id="p2-t4"></a>
## P2-T4 引入稳定 source note identity

**Requirements:** SCORE-007
**Primary owner:** SCORE-007

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLSourceIdentity.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift`
- Delete: `MusicXMLNoteEvent.id 的旧字符串拼接实现`

**Implementation:**
1. ID 包含 part、source measure index 与 token、staff、voice 和 source ordinal，而不是表现后字段。
2. 同音同 tick、多声部、和弦成员与 grace note 均获得不同 source ID。
3. 只迁移 parser 与 identity-sensitive 测试；尚未采用 source ID 的下游在 P5/P6 切换，未解析身份以显式 unresolved provenance 表示，不伪造 legacy ID。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLSourceIdentity.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift'`
- Run: `git commit -m "refactor: P2-T4 - 引入稳定 source note identity"`

---

<a id="p2-t5"></a>
## P2-T5 给 direction 与 controller 事件分配来源身份

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLDirectionIdentity.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 为 tempo、dynamic、wedge、pedal、fermata、words 和 sound directive 保存 source direction ordinal。
2. 同 tick 多 direction 不依赖内容字符串生成 ID。
3. 快照验证 ID 在排序和过滤后仍可追溯。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLDirectionIdentity.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "refactor: P2-T5 - 给 direction 与 controller 事件分配来源身份"`

---

<a id="p2-t6"></a>
## P2-T6 修正数值 dynamics 百分比与 decimal 语义

**Requirements:** SCORE-001
**Primary owner:** SCORE-001

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift`

**Implementation:**
1. 将 MusicXML dynamics decimal 解释为相对 MIDI forte 90 的百分比，并统一 clamp 与 rounding 规则。
2. direction sound dynamics 与 note-level dynamics 使用同一转换函数。
3. 删除 raw 64 直接等于 velocity 64 的旧测试，增加 100、72.5、越界和非法值。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift'`
- Run: `git commit -m "fix: P2-T6 - 修正数值 dynamics 百分比与 decimal 语义"`

---

<a id="p2-t7"></a>
## P2-T7 建立统一 direction offset resolver

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/MusicXML/MusicXMLDirectionOffsetResolver.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`

**Implementation:**
1. 集中计算 direction start tick、offset divisions 与最终 absolute tick。
2. 处理正负 offset、缺 divisions、跨 measure 边界和非法数值。
3. 创建后立即由 parser direction path 消费，删除散落的 offset index bookkeeping。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserPerformanceTimingTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLDirectionOffsetResolver.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift'`
- Run: `git commit -m "refactor: P2-T7 - 建立统一 direction offset resolver"`

---

<a id="p2-t8"></a>
## P2-T8 让全部 direction 事件一致应用 offset

**Requirements:** SCORE-002
**Primary owner:** SCORE-002

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserWedgeTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserWordsTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift`

**Implementation:**
1. tempo、sound dynamics、dynamics、wedge、pedal、fermata、words 和 structure sound 统一使用 resolver tick。
2. 移除每类事件各自修补 offset 的旧路径，确保只应用一次。
3. 用同一 fixture 对所有 direction kind 做表驱动断言。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserWedgeTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserWordsTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserWedgeTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserWordsTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift'`
- Run: `git commit -m "fix: P2-T8 - 让全部 direction 事件一致应用 offset"`

---

<a id="p2-t9"></a>
## P2-T9 支持 additive meter 与复合拍事实

**Requirements:** SCORE-008
**Primary owner:** SCORE-008

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLMeter.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Timing.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLAttributeTimeline.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLAttributeTimelineTests.swift`

**Implementation:**
1. 用 beat groups 表示 3+2+3/8 等 additive meter，不再强制 beats 为单个 Int。
2. 保留 symbol 和 senza-misura 等未完全解释 token 与 approximation。
3. 更新 attribute timeline 和快照，删除旧单值假设。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLAttributeTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLMeter.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Timing.swift' 'HappyPianistAVP/Services/MusicXML/MusicXMLAttributeTimeline.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLAttributeTimelineTests.swift'`
- Run: `git commit -m "feat: P2-T9 - 支持 additive meter 与复合拍事实"`

---

<a id="p2-t10"></a>
## P2-T10 解析 transpose 与 octave-shift 事实

**Requirements:** SCORE-008

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLPitchTransform.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift`

**Implementation:**
1. 解析 chromatic、diatonic、octave-change、double 与 octave-shift start、stop、continue。
2. 保留 written pitch 和 sounding transform，禁止把变换直接烧进 source identity。
3. 覆盖移调乐器、8va、8vb、跨 measure stop 和未闭合 shift。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLPitchTransform.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift'`
- Run: `git commit -m "feat: P2-T10 - 解析 transpose 与 octave-shift 事实"`

---

<a id="p2-t11"></a>
## P2-T11 回归 partwise、timewise 与 MXL 身份一致性

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLTimewiseConverter.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/MXLReader.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserTimewiseTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLParserMXLTests.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MXLReaderTests.swift`

**Implementation:**
1. 确保 timewise 转换保留 part metadata、source measure identity、direction identity 与 written pitch。
2. MXL 只负责容器读取，不重新分配 source IDs。
3. 更新快照并删除依赖旧 ID 字符串的测试辅助。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTimewiseTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLParserMXLTests.swift, HappyPianistAVPTests/MusicXML/MXLReaderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLTimewiseConverter.swift' 'HappyPianistAVP/Services/MusicXML/MXLReader.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserTimewiseTests.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLParserMXLTests.swift' 'HappyPianistAVPTests/MusicXML/MXLReaderTests.swift'`
- Run: `git commit -m "test: P2-T11 - 回归 partwise、timewise 与 MXL 身份一致性"`

---

## Phase Audit

- Audit file: `audit-p2.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: ID 是否在 timewise 转换、MXL 解包和结构展开前后保持来源一致。；offset 是否被重复应用。；旧 id 计算属性和旧 dynamics 断言是否在同 task 删除。
