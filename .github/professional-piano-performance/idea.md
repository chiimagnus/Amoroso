# Professional Piano Performance — 需求真源

> Feature slug: `professional-piano-performance`
>
> 领域审查真源：`docs/piano-performance-quality.md`
>
> 固定基线：1254 行，SHA-256 `7801e321bbc9ec976fa9c646b1dcfca253cf910967ddf6fc883385a8ae188fa6`。若该文件内容或哈希变化，必须先重做需求差异分析与计划审计，不能直接继续执行旧计划。

## 背景 / 触发

HappyPianist 当前已具备 MusicXML 准备、自动播放、外部 MIDI、专业三角钢琴采样、MIDI / 麦克风 / 手部输入、练习进度、空间琴键指导与 AI 对弹等完整链路，但审查确认：音乐事实会在解析、规范化、演奏事件、输入观察、评价与指导之间丢失、被启发式替代，或被错误地当作确定事实。

用户确认本 feature 的目标不是增加一批割裂的练习模式，也不是重构为 SwiftPM；目标是以审查文档为领域需求真源，对其中识别出的全部专业性缺口建立可执行、可验证、可审计的改造计划。用户可见体验仍以“练好某一首曲子”为单一主线；音高、节奏、时值、力度、声部、踏板、连贯性等仅作为内部证据与诊断维度。

本 feature 采用现有 Xcode 工程和 visionOS App 架构。Linux 临时 harness 只能作为纯 Swift 逻辑的补充检查，不能替代 `xcodebuild test`、Simulator 或真机证据。

## 原始需求

1. 将审查文档中的 3 个架构阻塞点与 51 个编号问题全部纳入追踪；任何问题不得只因实现困难而静默删除。
2. 建立从 MusicXML 原始记谱事实到规范演奏计划、播放 / 高亮 / 记谱投影、用户演奏观察、谱面—演奏对齐、评价、指导与进度事实的单向数据链。
3. 让自动示范、外部 MIDI、手动重播、琴键灯光与记谱投影共享同一份权威音乐事实，禁止 UI 高亮反向成为声音真源。
4. 保留专业三角钢琴采样作为既有音源优势；重点提升进入音源的 note-on、note-off、velocity、tempo、pedal、controller、seek / loop / stop 与时间调度质量。
5. MIDI、麦克风、真实钢琴手部追踪与虚拟琴输入必须保留各自能够观察到的证据、时间、置信度与校准信息；无法观察的维度必须表示为未知，而不是默认正确或错误。
6. 建立可解释的 score-performance alignment、能力感知评价与受证据约束的指导，但不得把 `PracticeStep` 扩大为持久化的完整评价模型。
7. 练习事实继续以小节为持久化单位；cue、summary、恢复地图、RealityKit 点亮效果、逐音原始传感器数据与 AI 正文不得写入进度 JSON。
8. 纠正 MusicXML dynamics、direction offset、part 归一化、staff / hand、written pitch、source identity、grace、arpeggio、tempo、fermata、articulation、pedal 与曲式顺序等规范与数据问题。
9. 改善同音复调、重复触键、跨范围长音、seek / loop、连续踏板、CoreMIDI timestamp、音频中断与停止恢复等播放可靠性。
10. 改善虚拟琴触键速度、逐指状态、左右手分离、时间归一化与校准；palm 不得生成琴键触发，相邻半音容差不得改写音乐正确性。
11. 建立来源明确的 hand / fingering、教师目标与容差 profile、音乐问题到具体练法的映射，同时保持现有单一练曲体验，不把内部诊断维度变成用户必须选择的模式。
12. AI 对弹继续被定义为创意响应；不得成为忠实示范、教师参考或评分基准。用户选择的后端失败时提示并停止，不自动切换后端。
13. 建立 MusicXML golden corpus、演奏事件快照、输入重放与混淆矩阵、真机时延 / 抖动 / 漏触发测试、钢琴家盲听、评分一致性与指导有效性证据。
14. 代码、测试、文档与能力声明必须同步；只有满足对应完成定义与证据门槛后，才允许宣称“忠实示范”“MIDI 专业评价”“表现力虚拟琴”或“专业虚拟指导”。

## 审查问题清单

- **ARCH-001**：缺少唯一的谱面与演奏真源
- **ARCH-002**：输入能力、来源和置信度没有统一契约
- **ARCH-003**：产品模式共用同一个成功语义
- **SCORE-001**：数值 dynamics 的 MusicXML 语义错误
- **SCORE-002**：direction `<offset>` 没有一致移动全部方向事件
- **SCORE-003**：两 part “大谱表归一化”会丢事件并可能误合并乐器
- **SCORE-004**：主 part 选择依赖 P1 或音符数量启发式
- **SCORE-005**：staff 被当作确定的左右手
- **SCORE-006**：原始音名拼写和微分音信息被过早压缩为 MIDI note
- **SCORE-007**：note identity 缺少 staff / voice，复杂同音可能冲突
- **SCORE-008**：节拍、速度标记与移调语义覆盖不足
- **SCORE-009**：grace 的 previous / following / make-time 语义不完整
- **SCORE-010**：arpeggiate 分组、方向与跨谱表语义不完整
- **SCORE-011**：力度事件的时间优先级和 wedge 语义不够可靠
- **SCORE-012**：常用钢琴演奏符号仍未形成事件契约
- **SCORE-013**：书写顺序与演奏顺序没有成为显式产品模式
- **SCORE-014**：step 与 note-span 各自实现 grace / arpeggio 调度
- **PERF-001**：note spans 不是持久的准备结果
- **PERF-002**：高亮构建与自动播放会折叠同音声部
- **PERF-003**：从中间范围开始时没有完整重建正在发声的音
- **PERF-004**：fermata 可能同时延长 note-off 又插入 pause
- **PERF-005**：发音法、fermata 和 arpeggio 使用固定比例启发式
- **PERF-006**：速度文字和 tempo ramp 覆盖有限
- **PERF-007**：手动重播是音高预览，不是参考演奏
- **PERF-008**：虚拟琴实时 note-on 使用固定 velocity
- **PERF-009**：踏板从 MusicXML 到输出仍是二值
- **PERF-010**：外部 MIDI 逐事件 `Task.sleep`，packet timestamp 为“现在”
- **PERF-011**：音频会话与停止恢复不够可诊断
- **PERF-012**：没有端到端时延、抖动和漏触发指标
- **NOTATION-001**：当前五线谱是 MIDI 练习投影，不是原谱渲染
- **NOTATION-002**：显示时值来自表现后 on/off，而非记谱时值
- **NOTATION-003**：休止、谱号、连梁和复杂声部未保持原谱
- **NOTATION-004**：fingering 仅是单个文本，不足以支撑专业指法指导
- **OBS-001**：MIDI 输入拥有的演奏数据被主动丢弃
- **OBS-002**：MIDI chord matcher 允许宽窗内串行按键通过
- **OBS-003**：麦克风是目标导向谐波检测，不是复调演奏转录
- **OBS-004**：palm 被当作 tracked tip 参与接触与按键逻辑
- **OBS-005**：手部结果丢失手、指、时间、置信度和速度
- **OBS-006**：固定阈值、无 delta-time 的运动判断不能跨设备稳定
- **OBS-007**：相邻半音容差会把空间误差重写为正确音
- **OBS-008**：所谓 hand-separated 判定仍消费合并后的 pressed set
- **OBS-009**：输入时钟与延迟没有统一
- **ASSESS-001**：尚无 score-performance alignment
- **ASSESS-002**：当前进度代表“步骤稳定”，不是“演奏成熟”
- **ASSESS-003**：反馈政策是流程控制，不是教师诊断
- **ASSESS-004**：错误、未知和证据不足没有稳定分开
- **ASSESS-005**：没有按输入能力裁剪评分 rubric
- **GUIDE-001**：尚未建立从音乐问题到练法的专业映射
- **GUIDE-002**：手别与指法建议必须显示来源
- **GUIDE-003**：需要“教师目标”而不是唯一理想演奏
- **AI-001**：AI 对弹是创意响应，不是忠实示范
- **AI-002**：手部来源进入 AI phrase 时仍被固定力度扁平化
- **AI-003**：当前质量门只覆盖有限的结构性问题
- **RECORD-001**：录制适合回放/导出，尚不适合正式评价证据

## 默认值与兼容策略

- 保持 `HappyPianist.xcodeproj`、`HappyPianistAVP` 与 `HappyPianistAVPTests`；不引入 SwiftPM 迁移。
- 新能力默认通过现有 composition root 注入，不创建 `static let shared`。
- MusicXML 仍是正式曲谱来源；不为 MIDI 文件、AI 序列或其他来源预埋兼容管线。
- 现有用户的曲库、进度与录制数据必须可读取；涉及持久化 schema 时使用显式版本与向后解码默认值，不得静默丢失数据。
- 现有单一练曲流程保持可用；内部能力分层不要求新增用户可见模式或重新设计主界面。
- 解析或输入证据不足时，保留原始事实并输出 `unknown` / `unsupported` / `approximated`；不得伪造确定结论。
- 专业采样不能支持的控制器能力必须通过 capability / approximation 表达，不得丢掉上游连续控制事实。
- 新实现替换旧实现的 task 必须同时删除旧 API、旧状态、旧测试入口和双轨分支。

## 非目标

- 不把整个 App 或核心逻辑迁移到 SwiftPM。
- 不引入第二套持久化体系。
- 不重写为全新的 UI、练习模式选择器或开放式聊天教师。
- 不自研完整物理钢琴建模音源；先把上游演奏事件与控制链做正确。
- 不以“大模型更强”替代乐谱事实、输入证据、确定性算法和验证体系。
- 不在没有授权语料、盲听或真机证据的情况下训练或宣称钢琴家风格模型。
- 不为未确认的未来曲谱来源、设备或平台制造抽象层。

## 架构决策

### ADR-001：保留 Xcode 工程，按现有模块边界演进

- **Decision:** 所有实现继续位于现有 Xcode 工程；正式验证使用 `xcodebuild`。
- **Alternatives:** SwiftPM 核心拆包、Bazel、多 package。
- **Why:** 当前目标是专业化音乐事实与演奏闭环，不是构建系统迁移；额外构建边界会扩大风险并延后音乐正确性修复。
- **Risk:** 非 macOS 环境无法完成 Apple target 验证；通过确定性测试、静态审查与本机 Xcode 闭环管理。

### ADR-002：建立唯一 `ScorePerformancePlan`

- **Decision:** 规范谱面生成唯一演奏计划，播放、高亮、练习步骤和记谱均为投影。
- **Alternatives:** 延续 note spans → highlight → autoplay 的反向链；每个出口独立解释 MusicXML。
- **Why:** 当前数据链会折叠同音声部、丢 source identity，并让 UI 结构影响声音。
- **Risk:** 迁移面广；采用“先建模型和快照，再逐消费者切换，同 task 删除旧路径”的方式控制。

### ADR-003：原始观察与评价分离

- **Decision:** MIDI、麦克风和手部追踪先产生 `PerformanceObservation`，再对齐、评价和指导。
- **Alternatives:** 各输入直接调用 step matcher；把所有输入压成 `Set<Int>`。
- **Why:** 不同输入证据能力不同，过早压缩会不可逆地丢失 velocity、release、pedal、hand、finger、time 和 confidence。
- **Risk:** 数据结构增加；只保留真实需要的字段，不为单一实现制造空协议。

### ADR-004：用户体验保持单一练曲主线

- **Decision:** 内部维度与能力等级用于约束证据和算法，不自动转化为用户可见模式。
- **Alternatives:** 音高 / 节奏 / 力度 / 踏板等独立模式。
- **Why:** 用户的产品目标是练好一首曲子；系统应在内部诊断，不把架构复杂度转嫁给用户。
- **Risk:** 指导策略可能过早影响体验；先完成事实、观察、对齐和评估，再通过现有反馈接口逐步接入。

### ADR-005：专业结论必须由证据门控制

- **Decision:** 能力声明与完成定义绑定到自动化事件证据、真机指标和钢琴家验证。
- **Alternatives:** 以功能存在、单一 demo 或主观听感作为完成标准。
- **Why:** 专业演奏系统同时涉及规范、实时系统、硬件和音乐判断，单层测试不足。
- **Risk:** 完成周期更长；允许阶段性声明“支持 / 近似 / 尚未验证”，禁止过度承诺。

## 硬性规则

- 依赖方向保持 `SwiftUI / RealityKit -> ViewModel -> Services -> Models`。
- Model 保持纯数据；View 不直接读写文件、网络、音频、MIDI 或设备。
- Swift 6 严格并发；不使用旧式 GCD 或 `nonisolated(unsafe)` 逃避隔离。
- 解析、文件 IO、对齐、评分与重计算不得运行在 MainActor。
- 长生命周期任务必须有 generation / cancel / stop / teardown 规则；旧 generation 事件必须丢弃。
- 音频或外部 MIDI 自播放必须被输入评分链抑制，避免把系统播放当作用户演奏。
- `PracticeStep` 只负责即时判定；完整演奏观察、对齐与评价使用独立模型。
- 持久化继续以小节事实为单位；派生 cue / summary / visual state 不落盘。
- 结构化日志统一走 `DiagnosticsReporting`；可导出日志不含绝对路径、原始曲谱、逐音手部 / MIDI / 音频、AI 正文、密钥或认证信息。
- 任何“容差”只能改变置信度或结果状态，不能把错误音高重写为正确音高。
- hand / fingering 必须带来源：原谱、用户、教师或启发式；staff 不能直接等于 hand。
- AI 后端严格使用用户选择，失败即提示并结束该次生成，不自动切换。
- 新文件必须在创建它的 task 内接入 composition root、route 或实际 consumer；不得留下孤立文件。
- 新实现替换旧实现时，同一 task 删除旧 API、状态、测试入口与双轨分支。
- 没有实际运行 `xcodebuild test`、Simulator、真机或盲听时，不得声称对应验证通过。

## 降级矩阵

| 子系统 / 失败 | 保留能力 | 关闭或标记 | 对外状态 |
|---|---|---|---|
| MusicXML 包含未支持语义 | 已知音高、时值和原始事件 | 受影响维度不参与专业判断 | `unsupported` / `approximated`，保留 provenance |
| 曲谱 part / hand 无法唯一判定 | 原谱 staff / voice / part | 不生成确定手别结论 | `unknown hand`，允许后续教师或用户来源覆盖 |
| 采样器不支持半踏板或特定控制器 | note / velocity 与可支持控制器 | 不伪造声学效果 | 计划保留连续值，输出 capability 标记近似 |
| 外部 MIDI 设备断开 | 应用内采样器或静默停止 | 取消待发送事件并 reset controllers | 可诊断错误，不自动切换用户选择的路由 |
| MIDI 输入缺少 release / pedal | pitch / onset / velocity | duration / pedal rubric 不评分 | 对应维度 `notObserved` |
| 麦克风证据不足或复调模糊 | 目标导向音高线索 | 不做复调声部、velocity、pedal 结论 | `insufficientEvidence`，必要时请求重试 |
| 手部追踪置信度不足 | 已确认接触与空间状态 | 不触发模糊琴键，不做力度结论 | `unknown`，不得用相邻半音代偿 |
| 对齐存在多个等价候选 | 原始 observation 与候选集合 | 不输出确定错误归因 | `ambiguous` / `provisional` |
| 评价维度缺少证据 | 已知维度 | 未知维度不进入总分或稳定事实 | 明确 capability-aware rubric |
| 指导无法证明问题 | 保持当前练习流程 | 不生成具体教师诊断 | 中性重试或继续，不持久化派生建议 |
| AI provider 失败 | 本次已收集用户 phrase 与普通练习 | AI 回应终止 | 明确错误；不得自动换 provider |
| 音频中断 / route change | 状态与计划可恢复 | 立即 all-notes-off / controllers reset | 记录结构化事件，恢复前不继续调度 |

## 验收边界

- MusicXML 正确性以规范语义、多个制谱软件导出的 golden fixtures 和稳定事件快照共同验收。
- 参考演奏以 source note identity、performed occurrence、on/off、velocity、tempo、pedal、controller 与 approximation provenance 的事件级一致性验收。
- MIDI 专业评价至少覆盖 pitch、onset、chord spread、release / duration、velocity / voicing 与 pedal；缺失能力必须显示为未知。
- 麦克风在没有可靠复调转录前，只承担审查文档定义的目标导向能力，不进入完整专业评分。
- 虚拟琴“有表现力”必须证明逐指 velocity、重复触键、同时和弦、左右手分离、校准与端到端时延，而不只证明音源听感好。
- 真机指标必须记录 event-to-audio latency、hand-motion-to-audio latency、MIDI jitter、漏触发、和弦 onset spread、卡音与中断恢复；阈值由测量基线和钢琴家验收共同锁定，计划阶段不捏造数字。
- 钢琴家验证覆盖复调、古典清晰度、结构重音、浪漫派旋律 / rubato、印象派踏板 / 色彩与密集织体。
- 指导有效性必须形成“发现问题 → 给出练法 → 练习 → 复测 → 指标改善”的证据链。

## 总体验收标准

1. `requirements-traceability.md` 中 54 个编号需求均有唯一 primary owner task、验证证据和文档落点。
2. `PreparedPractice` 保留唯一规范演奏计划；自动播放、外部 MIDI、手动重播、highlight、PracticeStep 与 notation 不再互相反推音乐事实。
3. 解析结果保留 part metadata、written pitch、稳定 source note identity、performed occurrence 和 approximation provenance。
4. 三类输入通过统一观察契约接入，且 capability / timestamp / confidence / calibration 不被压缩丢失。
5. alignment、assessment 与 coaching 均有确定性测试；未知、错误、缺失与歧义稳定分离。
6. 现有进度 JSON 可兼容读取；新增持久化只包含小节练习事实，不包含原始逐音或派生 UI / coaching 状态。
7. 音频 / MIDI / ARKit 生命周期、取消、generation、自播放抑制与 controller reset 有测试或明确真机证据。
8. 所有 phase 完成后运行项目规定的 `xcodebuild test`；真机、时延、盲听与教学验证未实际执行时，能力声明保持受限。
9. README、architecture、data-flow、module、storage、configuration、testing checklist 与质量审查文档同步为当前实现，不追加开发流水账。
10. 计划执行结束时没有遗留旧 API、双轨数据源、孤立文件、无消费的模型或仅为未来需求建立的兼容层。
