# Plan P6 - 复调同音、范围恢复与 transport 语义

**Goal:** 修复同音声部、重复触键、tie 与 held note、active range、seek、loop、fermata 与手动重播的事件正确性。

**Non-goals:** 本 phase 不优化 CoreMIDI timestamp 或 AVAudio session；只确定平台无关 transport 事件和状态恢复语义。

**Approach:** 在 plan event identity 上建立 transport state reducer 和 range-start snapshot。所有 seek、loop 与 stop 都从 reducer 计算所需 note 与 controller reset，禁止通过 MIDI note 数组猜测。

**Acceptance:**
- 同 MIDI 的多声部不被折叠。
- 重复音能以正确 note-off 与 note-on 顺序重触发。
- 从范围中间开始可重建 tie、held notes、tempo 与 controllers。
- manual replay 与 reference playback 使用同一 plan。

**Rules:**
- note-off 必须按 event identity 配对，不能只按 MIDI 清空另一个声部。
- fermata 只有一个 performed-time authority。
- stop、seek 与 loop 必须产生确定 reset sequence。

**State / lifecycle:** transport reducer 由 playback coordinator 持有；start、seek、loop、stop、cancel 与 teardown 均有幂等定义。

**Threading / actor:** 状态计算离开 MainActor；UI 只接收播放进度。平台发送留到 P7 actor。

**Debug / observability:** 记录 retrigger、orphan off、range reconstruction、reset reason 与 stuck-note prevention count。

**Testing strategy:** 纯 reducer 测试覆盖密集复调、重复音、跨范围 tie、controller carry 与取消。

**Audit focus:**
- 是否仍按 MIDI 单键截断所有 voice。
- range start 是否会漏发或重复发 held note。
- manual replay 是否仍使用固定 0.35 秒。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p6-t1"></a>
## P6-T1 保留同音多声部事件身份

**Requirements:** PERF-002
**Primary owner:** PERF-002

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift`
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`

**Implementation:**
1. note-on 与 note-off 以 plan event ID 配对，物理 MIDI 相同不等于同一演奏事件。
2. 为相同 onTick 与 midi 的不同 voice 保留独立 source contributors。
3. 增加 unison polyphony fixture，断言事件不被 max velocity 或 max off 合并。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/ScorePerformancePlan.swift' 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "fix: P6-T1 - 保留同音多声部事件身份"`

---

<a id="p6-t2"></a>
## P6-T2 实现重复音与 retrigger reducer

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift`
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`

**Implementation:**
1. 明确同 key 新 note-on 前的 note-off、零间隔重复和 sustain 下重触发顺序。
2. reducer 输出平台无关 ordered transport commands。
3. 创建后立即由 autoplay timeline 与测试消费。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift' 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "feat: P6-T2 - 实现重复音与 retrigger reducer"`

---

<a id="p6-t3"></a>
## P6-T3 建立 active range 起点状态重建

**Requirements:** PERF-003
**Primary owner:** PERF-003

**Files:**
- Create: `HappyPianistAVP/Services/Practice/Playback/PerformanceRangeStateResolver.swift`
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`

**Implementation:**
1. 在 start tick 计算当前 tempo、controllers、pedal 与跨界 held 或 tied notes。
2. 区分应在起点重发的持续状态与不应伪造 attack 的声音状态，并记录 approximation。
3. 处理起点恰好等于 note-on、note-off 或 pedal change。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Playback/PerformanceRangeStateResolver.swift' 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "feat: P6-T3 - 建立 active range 起点状态重建"`

---

<a id="p6-t4"></a>
## P6-T4 定义 seek、loop 与 end 的状态转换

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PracticePlaybackControlService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticePlaybackCoordinatorTests.swift`

**Implementation:**
1. seek 先 reset 当前 active event IDs，再应用目标 tick state。
2. loop end 与 start 不允许旧 generation 事件穿越边界。
3. end 与 stop 幂等，重复调用不产生额外 note-on。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticePlaybackCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift' 'HappyPianistAVP/Services/Practice/Playback/PracticePlaybackControlService.swift' 'HappyPianistAVPTests/Practice/PracticePlaybackCoordinatorTests.swift'`
- Run: `git commit -m "feat: P6-T4 - 定义 seek、loop 与 end 的状态转换"`

---

<a id="p6-t5"></a>
## P6-T5 消除 fermata 双重延时

**Requirements:** PERF-004
**Primary owner:** PERF-004

**Files:**
- Modify: `HappyPianistAVP/Services/MusicXML/MusicXMLFermataTimeline.swift`
- Modify: `HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift`
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`

**Implementation:**
1. 选择 performed tick 或 pause directive 的单一表示，禁止同时延长 note-off 和再次 pause。
2. fermata 对不同 voice 或 staff 的作用通过 source identity 合并一次。
3. 删除 extraHoldSeconds 与 note extension 的重复路径。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift, HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/MusicXML/MusicXMLFermataTimeline.swift' 'HappyPianistAVP/Services/MusicXML/ScoreTimingScheduleBuilder.swift' 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift'`
- Run: `git commit -m "fix: P6-T5 - 消除 fermata 双重延时"`

---

<a id="p6-t6"></a>
## P6-T6 重建 range 边界的 sustain 与 held notes

**Requirements:** PERF-003, PERF-009

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Playback/PerformanceRangeStateResolver.swift`
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`

**Implementation:**
1. range start 恢复连续 controller value，而不是仅 bool pedal down。
2. range end 对本范围启动的 notes 发送 off；对起点继承状态按 transport policy 收口。
3. 覆盖 repedal、半踏板、跨 range tie 与同音重触发。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Playback/PerformanceRangeStateResolver.swift' 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "fix: P6-T6 - 重建 range 边界的 sustain 与 held notes"`

---

<a id="p6-t7"></a>
## P6-T7 让手动重播使用规范演奏计划

**Requirements:** PERF-007
**Primary owner:** PERF-007

**Files:**
- Modify: `HappyPianistAVP/Services/Audio/PracticeManualReplaySequenceBuilder.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PracticeManualReplayService.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeManualReplaySequenceBuilderTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeManualReplayCoordinatorTests.swift`
- Delete: `固定 stepSeconds 与 chordDurationSeconds 参考演奏路径`

**Implementation:**
1. manual replay 按选定 measure 或 range 投影 plan，保留 timing、velocity、controllers、grace、arpeggio 与 fermata。
2. 仍需要纯音高预览时使用明确 preview API 和命名，不复用 reference playback。
3. 删除固定时长序列与旧测试。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeManualReplaySequenceBuilderTests.swift, HappyPianistAVPTests/Practice/PracticeManualReplayCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Audio/PracticeManualReplaySequenceBuilder.swift' 'HappyPianistAVP/Services/Practice/Playback/PracticeManualReplayService.swift' 'HappyPianistAVPTests/Practice/PracticeManualReplaySequenceBuilderTests.swift' 'HappyPianistAVPTests/Practice/PracticeManualReplayCoordinatorTests.swift'`
- Run: `git commit -m "refactor: P6-T7 - 让手动重播使用规范演奏计划"`

---

<a id="p6-t8"></a>
## P6-T8 定义统一 reset command 序列

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PerformanceTransportCommand.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift`
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- Modify: `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`

**Implementation:**
1. 定义 note off by identity、all notes off、sustain、sostenuto、soft reset 与 all sound off 的有序命令。
2. stop、error、interruption 与 route change 共享同一 reducer 输出。
3. 平台服务仅执行命令，不自行发明 reset 顺序。

**Validation:**
- Focus: HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift, HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Practice/PerformanceTransportCommand.swift' 'HappyPianistAVP/Services/Practice/Playback/PerformanceTransportReducer.swift' 'HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift' 'HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift'`
- Run: `git commit -m "refactor: P6-T8 - 定义统一 reset command 序列"`

---

<a id="p6-t9"></a>
## P6-T9 增加复调与范围 transport regression corpus

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/PolyphonicUnisonRetrigger.musicxml`
- Create: `HappyPianistAVPTests/Fixtures/RangeStartHeldNotes.musicxml`
- Modify: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`
- Modify: `HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift`

**Implementation:**
1. 覆盖两 voice 同音、延音中重击、tie 跨小节、range 中间启动与 repedal。
2. snapshot 断言 event identity、顺序、range state 和 reset commands。
3. 不得以听感代替事件断言。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/PolyphonicUnisonRetrigger.musicxml' 'HappyPianistAVPTests/Fixtures/RangeStartHeldNotes.musicxml' 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json' 'HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift'`
- Run: `git commit -m "test: P6-T9 - 增加复调与范围 transport regression corpus"`

---

<a id="p6-t10"></a>
## P6-T10 清理旧 timeline normalization 并更新数据流

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- Modify: `HappyPianistAVP/Services/Practice/Playback/PlaybackSequenceBuilder.swift`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp-practice.md`
- Delete: `按 MIDI 截断 previous interval 的旧算法`
- Delete: `从 step 或 guide 生成 manual reference 的旧路径`

**Implementation:**
1. 删除所有已由 transport reducer 与 range resolver 取代的 helper。
2. 代码搜索确认 event identity 从 plan 到 output 不丢失。
3. 文档区分 preview、reference playback 与 transport reset。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/AutoplayPerformanceTimelineTests.swift, HappyPianistAVPTests/Playback/PlaybackSequenceBuilderTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift' 'HappyPianistAVP/Services/Practice/Playback/PlaybackSequenceBuilder.swift' 'docs/data-flow.md' 'docs/modules/happypianist-avp-practice.md'`
- Run: `git commit -m "refactor: P6-T10 - 清理旧 timeline normalization 并更新数据流"`

---

## Phase Audit

- Audit file: `audit-p6.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否仍按 MIDI 单键截断所有 voice。；range start 是否会漏发或重复发 held note。；manual replay 是否仍使用固定 0.35 秒。
