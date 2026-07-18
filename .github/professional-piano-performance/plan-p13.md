# Plan P13 - 权威记谱投影与专业指法事实

**Goal:** 让五线谱与指法展示来自 source score 的 written facts，并与 performed occurrence 和 highlight 同步，而不是从 MIDI 与表现后时值反推。

**Non-goals:** 本 phase 不自研完整出版级 engraving engine；只对支持 corpus 建立忠实事实投影和明确 approximation。

**Approach:** 扩展 P5 的 notation projection，逐步保留 written pitch、duration、rests、ties、tuplets、clefs、key、time、voices、beams、cross-staff 与 fingering provenance；layout 只负责排布。

**Acceptance:**
- 异名同音与 accidental 正确显示。
- 显示时值使用 written duration。
- rests、clefs、voices、beams 与 cross-staff 在支持范围保持。
- fingering 可表达来源、多个标记与替换。

**Rules:**
- layout 不修改 score facts。
- unsupported engraving 必须显式近似，不回退到错误 MIDI 推断。
- 显示投影不成为声音或评分真源。

**State / lifecycle:** notation projection 随 prepared practice 一次构建；active range 与 playback 只改变 transient display state。

**Threading / actor:** score projection 可后台构建；RealityKit 与 SwiftUI layout 状态回 MainActor。

**Debug / observability:** 记录 unsupported notation kind、layout fallback 与 source mapping mismatch，不记录曲谱正文。

**Testing strategy:** fixture snapshots、layout 单测与 accessibility labels；视觉验收不替代事实测试。

**Audit focus:**
- 是否仍统一把黑键写成升号。
- performance offTick 是否改变 written note value。
- 休止和 voice 是否在 active range 裁剪时丢失。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p13-t1"></a>
## P13-T1 让 notation projection 以 source score 为真源

**Requirements:** NOTATION-001
**Primary owner:** NOTATION-001

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`

**Implementation:**
1. projection 使用 source note、measure、attributes 与 performed occurrence links。
2. 删除从 MIDI note 推导 staff、accidental 与 duration 的权威路径。
3. highlight active state 仅作为 overlay，不改变 notation facts。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift' 'HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift'`
- Run: `git commit -m "refactor: P13-T1 - 让 notation projection 以 source score 为真源"`

---

<a id="p13-t2"></a>
## P13-T2 忠实显示 written pitch、accidental 与变调

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift`
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`

**Implementation:**
1. 使用 step、octave、decimal alter 与 accidental token，保留 enharmonic spelling。
2. transpose 与 octave-shift 分开表达 written 和 sounding position。
3. 无法显示 microtonal glyph 时保留 token 并标记 fallback。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift' 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift'`
- Run: `git commit -m "feat: P13-T2 - 忠实显示 written pitch、accidental 与变调"`

---

<a id="p13-t3"></a>
## P13-T3 分离 written duration 与 performed duration

**Requirements:** NOTATION-002
**Primary owner:** NOTATION-002

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`

**Implementation:**
1. note value、dots 与 tuplets 来自 source written duration。
2. staccato、fermata 与 expressive release 只影响 playback overlay，不改 notehead value。
3. 删除用 guide offTick 减 onTick 选音符值的旧逻辑。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift' 'HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift'`
- Run: `git commit -m "fix: P13-T3 - 分离 written duration 与 performed duration"`

---

<a id="p13-t4"></a>
## P13-T4 投影 rests、ties 与 tuplets

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`

**Implementation:**
1. 每 voice 与 staff 保留 rests 和 tuplets，不用空白代替。
2. tie 与 slur 使用不同模型和 source IDs。
3. active range 边界保留跨界 tie continuation。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift'`
- Run: `git commit -m "feat: P13-T4 - 投影 rests、ties 与 tuplets"`

---

<a id="p13-t5"></a>
## P13-T5 投影 clef、key、meter、voices 与 beams

**Requirements:** NOTATION-003
**Primary owner:** NOTATION-003

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`

**Implementation:**
1. 按 attribute timeline 在 measure 与 staff 上放置 clef、key 与 additive meter。
2. 保留 voice IDs 与 beam groups，避免多声部重排丢身份。
3. unsupported beam 或 stem override 明确 fallback。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift, HappyPianistAVPTests/MusicXML/MusicXMLAttributeTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift'`
- Run: `git commit -m "feat: P13-T5 - 投影 clef、key、meter、voices 与 beams"`

---

<a id="p13-t6"></a>
## P13-T6 支持 cross-staff 与 performed occurrence 映射

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationViewportLayoutService.swift`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationViewportLayoutServiceTests.swift`

**Implementation:**
1. 显示保持 source staff，hand assignment 仅作为辅助。
2. repeats 与 endings 的 performed occurrence 高亮映射回 source measure display。
3. 同 source measure 多 occurrence 不修改持久化 identity。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationViewportLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationViewportLayoutService.swift' 'HappyPianistAVPTests/Notation/GrandStaffNotationViewportLayoutServiceTests.swift'`
- Run: `git commit -m "feat: P13-T6 - 支持 cross-staff 与 performed occurrence 映射"`

---

<a id="p13-t7"></a>
## P13-T7 建立可追溯的专业 fingering 模型

**Requirements:** NOTATION-004
**Primary owner:** NOTATION-004

**Files:**
- Create: `HappyPianistAVP/Models/MusicXML/MusicXMLFingering.swift`
- Modify: `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`
- Modify: `HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift`

**Implementation:**
1. 支持多个 fingering、substitution、alternate、placement、hand 与 score、teacher、user provenance。
2. 不再把单个 fingeringText 当完整指法事实。
3. 旧字符串消费者迁移后删除旧字段。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift, HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/MusicXML/MusicXMLFingering.swift' 'HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift' 'HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift' 'HappyPianistAVP/Models/Practice/ScoreNotationProjection.swift'`
- Run: `git commit -m "refactor: P13-T7 - 建立可追溯的专业 fingering 模型"`

---

<a id="p13-t8"></a>
## P13-T8 更新 layout 对 unsupported notation 的降级

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationViewportLayoutService.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift`

**Implementation:**
1. 每个 fallback 带 source ID、kind 与 reason，视觉上保持可访问而非静默错画。
2. 不因缺 glyph 丢 playback 或 assessment facts。
3. diagnostics 只聚合 kind 与 count。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift' 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationViewportLayoutService.swift' 'HappyPianistAVP/Models/Diagnostics/PianoPerformanceDiagnostics.swift'`
- Run: `git commit -m "fix: P13-T8 - 更新 layout 对 unsupported notation 的降级"`

---

<a id="p13-t9"></a>
## P13-T9 增加 notation golden 与可访问性验证

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/NotationFidelityPiano.musicxml`
- Modify: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`
- Modify: `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`
- Modify: `HappyPianistAVPTests/Piano/PianoHighlightViewConsistencyTests.swift`

**Implementation:**
1. fixture 覆盖 enharmonic、rests、ties、tuplets、clef change、voices、beams、cross-staff 与 fingering。
2. 事实 snapshot 与 layout snapshot 分开。
3. 图标、指法与 hand 状态提供可访问文本，不依赖颜色区分。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift, HappyPianistAVPTests/Piano/PianoHighlightViewConsistencyTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/NotationFidelityPiano.musicxml' 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json' 'HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift' 'HappyPianistAVPTests/Piano/PianoHighlightViewConsistencyTests.swift'`
- Run: `git commit -m "test: P13-T9 - 增加 notation golden 与可访问性验证"`

---

<a id="p13-t10"></a>
## P13-T10 清理 MIDI 反推记谱并更新模块文档

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/piano-performance-quality.md`
- Delete: `从 MIDI 黑键统一选择升号的权威路径`
- Delete: `从 performed offTick 反推 written value 的路径`

**Implementation:**
1. 代码搜索确认 notation source 只来自 score projection。
2. 文档说明支持范围、fallback 与 projection 非真源边界。
3. 保留现有 UI 布局，避免把本 task 扩成界面重设计。

**Validation:**
- Focus: HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift' 'docs/modules/happypianist-avp.md' 'docs/data-flow.md' 'docs/piano-performance-quality.md'`
- Run: `git commit -m "refactor: P13-T10 - 清理 MIDI 反推记谱并更新模块文档"`

---

## Phase Audit

- Audit file: `audit-p13.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否仍统一把黑键写成升号。；performance offTick 是否改变 written note value。；休止和 voice 是否在 active range 裁剪时丢失。
