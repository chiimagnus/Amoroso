# 钢琴演奏与虚拟指导质量基线

本文定义 HappyPianist 在曲谱解释、钢琴回放、虚拟琴演奏和练习指导方面的当前质量边界，以及达到专业级钢琴产品前需要解决的问题。

这是一份长期质量基线，不是开发流水账。相关实现发生变化时，应更新对应结论、证据和验收标准。

## 审查前提

- 项目使用的三角钢琴采样由产品方确认具有良好听感。本文不把采样素材本身视为当前短板。
- 源码归档未包含实际 SoundFont，且本次没有在 Vision Pro、Simulator 或 Xcode 音频环境中试听，因此不对采样层数、循环点、release sample、立体声录音和最终听感作未经验证的判断。
- 本文重点审查代码能否把优质音源驱动成具有钢琴表现力的声音，以及系统是否能给出专业、可信的练习指导。
- “专业”拆成四个独立维度：曲谱忠实度、演奏表现力、演奏评价能力、空间指导可靠性。某一项优秀不能替代其他项。

## 当前结论

HappyPianist 已经超过“只把 MusicXML 转成琴键”的原型阶段：解析管线、速度图、力度、踏板、时值、装饰性时序和自动回放均有独立模型与测试入口，工程基础扎实。

当前最准确的产品定位是：

> 以音高和练习步骤正确性为核心，具备初步音乐表现力回放的空间钢琴练习系统。

它适合完成以下任务：

- 导入和准备主流 MusicXML 钢琴谱。
- 把音符映射到 88 键和空间提示。
- 按小节、手别和速度组织练习。
- 判断当前步骤要求的音高是否在允许窗口内出现。
- 使用乐谱中的 per-note velocity、音长、速度变化和二值踏板生成自动示范。

当前还不应宣称：

- 能评价用户是否弹得具有专业音乐表现力。
- 能可靠判断真实左右手分工、跨谱表演奏或双手交叉。
- 虚拟琴能表达真实触键速度、层次和声部平衡。
- 已完整覆盖钢琴文献中的踏板、装饰音、乐句和复杂反复语义。

## 已有优势

### MusicXML 准备管线

`PracticePreparationService` 已形成清晰的单向流程：

```text
MusicXML / MXL
-> parse
-> grand-staff normalization
-> optional structure expansion
-> primary part filtering
-> hand routing
-> steps / tempo / pedal / fermata / attributes / note spans
-> highlight guides
-> PreparedPractice
```

当前实现已经处理或建模：

- `score-partwise`、`score-timewise` 与 MXL。
- `divisions`、`backup`、`forward`、voice、staff、chord 和 measure。
- tie、dot、tuplet、attack/release timing。
- tempo events、tempo ramps、dynamics、wedge、articulation。
- grace note、arpeggiate、fermata、damper pedal。
- repeat、ending、D.C.、D.S.、Coda 等结构数据。
- 小节 source identity 与 occurrence identity。

这说明项目的核心问题不是“没有解析体系”，而是部分音乐语义仍被过度简化。

### 自动示范回放

自动回放链路优于手动提示链路：

- `MusicXMLNoteSpanBuilder` 生成带表现时序的音符区间。
- `AutoplayPerformanceTimeline` 保留 note-on velocity、note-off、踏板和 fermata pause。
- `PracticeSequencerSequenceBuilder` 把时间线转换为 sequencer 事件。
- 本地 sampler 与外部 MIDI 共用演奏事件语义。

只要输入的力度和时序正确，优质三角钢琴采样能够在这条链路上发挥价值。

### 练习架构边界

项目已经明确：

- `PracticeStep` 负责即时判定。
- 小节事实才进入持久化进度。
- cue、summary、恢复地图和 RealityKit 表现不写入进度 JSON。

该边界应保留。未来增加“演奏评价”时，应先定义独立产品模式和数据契约，不应把所有音乐指标塞入 `PracticeStep` 或现有进度格式。

## 需要修正的曲谱忠实度问题

### 1. MusicXML 数值力度被当成绝对 MIDI velocity

证据：

- `MusicXMLParserDelegate+Directions.swift`
- `MusicXMLParserDelegate.parseMIDIVelocity(_:)`

当前实现把 `dynamics="64"` 直接转换成 velocity 64，并且只接受整数。

MusicXML 4.0 中，`<sound dynamics>` 和 note 的 `dynamics` 是相对于默认 forte 90 的百分比，并允许 decimal。正确换算应以 `90 * percentage / 100` 为基准，再限制到 MIDI 范围。

影响：

- 不同制谱软件导出的同一力度可能被系统性放大或缩小。
- 合法的小数值会被拒绝。
- 当前相关测试会固化错误语义，需要与实现一起修正。

优先级：**P0，标准正确性。**

### 2. staff 被直接解释为左右手

证据：

- `PracticeModels.swift` 中的 `ScoreHand.fromStaff(_:)`
- `MusicXMLHandRouter.swift`

当前规则基本等价于：staff 1 是右手，staff 2 及以上是左手；单谱表作品再按音高中位数进行启发式分手。

MusicXML 的 staff 表示 part 内从上到下的谱表编号，不是演奏者的手。以下钢琴写法会产生错误指导：

- 右手跨到低音谱表。
- 左手跨到高音谱表。
- 双手交叉。
- 单手跨两个谱表。
- 三谱表作品。
- 同一谱表中的双手分奏。

影响：

- 音高对应琴键仍可能正确，但左右手提示可能误导用户。
- 单手练习过滤和左右手反馈可能建立在错误标签上。

目标边界：

- staff 可以作为默认提示，但不能作为确定的 hand truth。
- 无可靠证据时应保留未知或启发式来源，而不是伪装成确定事实。
- 需要支持人工修正或来源明确的手别契约时，再扩展模型。

优先级：**P0，指导可信度。**

### 3. `steal-time-previous` 被按 following note 处理

证据：

- `PracticeStepBuilder.computeGraceOnTickByNoteIndex(notes:)`
- `MusicXMLNoteSpanBuilder` 的 grace schedule

当前实现把 `steal-time-following` 和 `steal-time-previous` 合并为同一种计算，并统一从后续主体音中扣除时值。

MusicXML 语义要求：

- `steal-time-following` 从后音取时间。
- `steal-time-previous` 从前音取时间。
- `make-time` 表示额外增加时间，当前也未形成完整演奏契约。

影响：倚音和前后装饰音可能改变错误的主体音时值与 onset。

优先级：**P0，节奏正确性。**

### 4. 琶音分组没有完整消费 MusicXML 语义

证据：

- `PracticeStepBuilder.ArpeggiateKey`
- `MusicXMLNoteSpanBuilder.ArpeggiateKey`

当前分组主要使用 `partID + staff + tick`，没有完整使用：

- `arpeggiate.numberToken`
- voice
- 跨谱表连续信息

MusicXML 的 number 用于区分同一时刻分别琶奏或共同琶奏的和弦。当前实现可能把不应同组的音纳入同一展开，也无法形成可靠的跨谱表大琶音。

此外，练习 matcher 不验证琶音方向和顺序；自动回放能“展开”，不代表系统能判断用户是否正确演奏了琶音。

优先级：**P1，复杂织体正确性。**

### 5. 曲式结构能力存在，但正式流程默认不展开

证据：

- `MusicXMLPlaybackDefaults.swift`
- `MusicXMLRealisticPlaybackDefaults.shouldExpandStructure == false`

项目已经有结构展开器，但准备流程默认使用书写顺序。

这不是单纯 bug，而是产品语义未明确：

- 逐小节练习可按书写顺序。
- 完整示范通常应按演奏顺序。

应把二者定义成明确模式，而不是静默使用一个全局默认值承担两种含义。

优先级：**P1，完整示范语义。**

### 6. 乐句与装饰语义覆盖仍不完整

当前代码已处理部分 articulation、grace、arpeggiate 和 fermata，但尚未形成完整的钢琴演奏契约，例如：

- slur 与乐句层级。
- trill、mordent、turn。
- measured / unmeasured tremolo。
- glissando。
- breath 与 caesura。
- 更完整的复合力度标记，如 `sf`、`sfp`、`fp`、`rfz`、`sfz`、`fz`、`other-dynamics`。

`docs/data-flow.md` 当前提到 slur timeline，但源码中未找到对应的完整模型和消费链路；实现或文档至少有一侧需要校正。

优先级：**P2，文献覆盖广度。**

## 需要提升的钢琴演奏表现力

### 1. 虚拟琴实时发声使用固定 velocity

证据：

- `KeyContactResult` 只有 down、started、ended。
- `VirtualPianoInputController` 只向播放服务传递 MIDI note set。
- `PracticeSequencerPlaybackServiceProtocol.startLiveNotes(midiNotes:)` 不接收 velocity。
- `AVAudioSequencerPracticePlaybackService` 和 `CoreMIDIPracticePlaybackService` 使用默认 velocity 96。

这意味着轻触、重击、慢压和快速触键都会以同一力度触发采样。

对于优质三角钢琴采样，这是当前最主要的利用率瓶颈：采样可能包含丰富的动态层，但实时虚拟琴没有向 sampler 提供足够的演奏控制。

专业目标：

- 从接触前的手指法向速度估算独立 note-on velocity。
- 使用时间窗滤波，避免手部追踪抖动直接映射为力度抖动。
- 提供可校准 velocity curve、最小力度、最大力度和灵敏度。
- 同一和弦中的每个手指保留独立 velocity。
- 记录足够的低频诊断指标，但不得导出逐帧手部数据。

优先级：**P0，虚拟琴表现力。**

### 2. 踏板模型被压缩为二值开关

证据：

- `MusicXMLPedalEvent.isDown: Bool?`
- `MusicXMLPedalTimeline.Change.isDown: Bool`
- autoplay 只生成 pedal down / up。

当前 `<sound damper-pedal="1...100">` 只按是否大于 0 转换为开关。最终输出等价于 CC64 的 0 或 127。

缺少：

- 半踏板深度。
- 渐进踩下和抬起。
- repedaling 的连续值。
- sostenuto pedal。
- una corda / soft pedal 控制。
- 与采样或音源能力匹配的踏板共鸣控制。

优先级：**P1，浪漫派及以后曲目的表现力。**

### 3. 手动重播是音高提示，不是完整示范

证据：

- `PracticeManualReplaySequenceBuilder`

手动重播保留 step 中的 velocity，但每个音统一使用 0.35 秒音长，并在 step 之间发送 All Notes Off。它不复用完整 note spans、踏板、grace、arpeggiate、fermata 和乐句时序。

因此以下 UI 语义应保持明确：

- “播放琴声”可以表示当前音高提示。
- “重播本节”如果面向演奏示范，应改为复用 performance timeline。

优先级：**P1，避免教学语义误导。**

### 4. 外部 MIDI 自动回放采用逐事件 Task 唤醒

证据：

- `CoreMIDIPracticePlaybackService.MIDIEventScheduler`

当前 scheduler 根据目标时间逐个 `Task.sleep` 后发送事件。系统负载较高或事件密集时，快速重复音、和弦和控制事件可能产生调度抖动。

CoreMIDI packet timestamp 可表达事件应被播放的 host time。专业回放应优先提前批量发送带 timestamp 的事件，而不是在每个事件点临时唤醒 Task。

优先级：**P2，外部设备时序稳定性。**

## 虚拟指导与演奏评价边界

### 当前 matcher 主要判断音高集合

证据：

- `PracticeMIDIInputService` 忽略 MIDI 1.0 / 2.0 note-on velocity。
- `MIDIPracticeStepMatcher` 默认 `chordWindow = 0.55` 秒。
- `noteOffRequired` 默认关闭。
- matcher 使用 `Set<Int>` 收集期望音高。

因此，一个和弦即使在 0.55 秒内无序逐个按下，也可能通过。当前系统不评价：

- onset 偏差。
- 音符时值。
- note-off。
- 触键力度。
- 声部平衡。
- 琶音顺序。
- 踏板深度与换踏时机。
- 乐句连贯性。

这对“逐步找到正确琴键”的学习模式是合理的，但不能被描述为专业演奏评价。

### 建议的产品分层

#### 练习正确性模式

继续保留当前模型的优势：

- 低延迟。
- 规则确定。
- 对初学者友好。
- 只判断当前 step 是否满足。
- 结果聚合为小节事实。

#### 演奏评价模式

只有在产品明确需要后再增加，并先定义输入契约和用户承诺。可评价：

- 音高准确性。
- onset 与节拍偏差。
- duration / legato overlap。
- velocity 与动态轮廓。
- 旋律和伴奏的相对声部平衡。
- 琶音方向与展开时间。
- pedal timing 与深度。

该模式的分析结果不应自动写入现有进度 JSON。需要持久化时，应先定义独立、可解释、可版本化的数据契约。

### 空间指导的可信度要求

空间高亮和琴键定位可以继续消费确定的 MIDI 音高；但左右手颜色、手别过滤和动作建议必须暴露其证据来源：

- 曲谱明确提供。
- 用户人工指定。
- 系统启发式推断。
- 未知。

启发式结果不能以确定事实呈现。对于跨谱表、双手交叉和多声部作品，宁可少给手别结论，也不要给错误的专业指导。

## 改进顺序

### P0：先修正确性和输入表现力

1. 按 MusicXML 标准换算 decimal dynamics percentage，并修正测试。
2. 区分 staff 与 hand；停止把 staff 直接当作确定手别。
3. 正确处理 `steal-time-previous`、`steal-time-following` 和 `make-time`。
4. 让虚拟琴 note-on 携带由手指运动估算的 velocity。

### P1：统一专业回放语义

1. 保留连续 damper pedal 值，并输出 0...127 控制值。
2. 完整消费 arpeggiate number、voice 和跨谱表信息。
3. 将“完整重播”统一到 performance timeline；保留轻量音高提示时明确命名。
4. 明确“书写顺序练习”和“演奏顺序示范”两个产品模式。

### P2：扩展文献覆盖和演奏评价

1. 增加 slur、trill、mordent、turn、tremolo、glissando 等明确需要的语义。
2. 增加可选的 timing、duration、velocity、balance、pedal 评价模式。
3. 外部 MIDI 改用 timestamp 调度。
4. 评估音源是否暴露 release、resonance、una corda 等控制；只有音源实际支持时才接入，避免空抽象。

## 验收标准

### 曲谱解析 golden corpus

至少包含来自 MuseScore、Dorico、Sibelius 等真实软件导出的样本，并覆盖：

- 单谱表与双谱表钢琴。
- cross-staff notation。
- 双手交叉。
- 多 voice。
- grace previous / following / make-time。
- 分组与跨谱表 arpeggio。
- half pedal、change pedal、sostenuto。
- repeat、ending、D.C.、D.S.、Coda。
- 复合 dynamics 和 wedge。

每个 fixture 应验证解析模型和最终 playback event dump，而不只验证 XML parser 的局部字段。

### 演奏事件验收

对同一乐谱生成稳定、可审查的事件序列：

- note-on MIDI、velocity、tick / seconds。
- note-off tick / seconds。
- pedal controller 与 value。
- tempo 和 pause。
- structure occurrence。

事件级测试通过后，再做真实听感验证；听感不能替代事件正确性，事件正确性也不能替代听感。

### 真机音乐验收

由至少一名有古典钢琴训练的测试者在 Vision Pro 上检查：

- pp、mf、ff 是否有清晰而连续的触键差异。
- 同一和弦不同手指力度是否能形成旋律突出和伴奏弱化。
- 快速重复音是否可靠触发且没有明显漏音。
- 半踏板与换踏是否可听见、可控制。
- 空间琴键与实际手指接触位置是否稳定。
- 高亮不会错误宣称跨谱表音符的左右手。

未实际执行对应测试时，不得标记为通过。

## 相关实现

- `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- `HappyPianistAVP/Services/MusicXML/Parser/`
- `HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift`
- `HappyPianistAVP/Services/MusicXML/MusicXMLHandRouter.swift`
- `HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift`
- `HappyPianistAVP/Services/PracticeStepBuilder.swift`
- `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- `HappyPianistAVP/Services/Practice/Matching/MIDIPracticeStepMatcher.swift`
- `HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift`
- `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`
- `HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift`
- `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- `HappyPianistAVP/Services/Audio/PracticeManualReplaySequenceBuilder.swift`

## 规范参考

- [MusicXML 4.0](https://www.w3.org/2021/06/musicxml40/)
- [MusicXML `<staff>`](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/staff/)
- [MusicXML `<sound>`](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/sound/)
- [MusicXML note dynamics](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/note/)
- [MusicXML `<grace>`](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/grace/)
- [MusicXML `<arpeggiate>`](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/arpeggiate/)
- [MusicXML `<pedal>`](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/pedal/)
- [CoreMIDI `MIDIPacket.timeStamp`](https://developer.apple.com/documentation/coremidi/midipacket/timestamp)
