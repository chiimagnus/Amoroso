# Professional Piano Performance — Plan Index

> 本计划将 `docs/piano-performance-quality.md` 的 3 个架构阻塞点和 51 个详细问题转换为可执行任务。
>
> `todo.toml` 是唯一执行状态真源；本索引只描述范围、依赖与 phase gate。

## 总览

- Feature slug：`professional-piano-performance`
- Phases：**15**
- Tasks：**158**
- Requirement IDs：**54**
- 工程边界：保留 `HappyPianist.xcodeproj`；不迁移 SwiftPM。
- 产品边界：保持单一“练好一首曲子”主线；内部诊断维度不自动变成用户模式。
- 正式验证：`xcodebuild test`、visionOS Simulator、必要的真机与钢琴家证据。

## 执行依赖

```text
P1 证据基线
  -> P2-P4 乐谱来源事实与演奏语义
  -> P5 唯一 ScorePerformancePlan
  -> P6-P7 transport 与平台输出可靠性
  -> P8-P9 用户演奏 observation 与虚拟琴表现力
  -> P10 alignment
  -> P11 assessment / progress facts
  -> P12 coaching
  -> P13 notation / fingering projection
  -> P14 AI 边界与质量门
  -> P15 corpus、真机、钢琴家验证与能力声明
```

任何 phase 未通过对应 `audit-pX.md` gate，不得进入下一 phase。

## Phase Map

| Phase | 目标 | Tasks | Primary requirements | Exit gate |
|---|---|---:|---|---|
| [P1](plan-p1.md) | 证据基线、快照与可重复验证 | 8 | 基础设施 / 验收 | 曲谱和演奏事件可序列化为稳定、无本机路径的文本快照。; 所有 54 个审查编号进入可机读 traceability。 |
| [P2](plan-p2.md) | MusicXML 来源身份、书写事实与解析正确性 | 11 | `SCORE-006`, `SCORE-007`, `SCORE-001`, `SCORE-002`, `SCORE-008` | 同一 MusicXML 重复解析产生完全相同的 source IDs。; written pitch 与 performed MIDI pitch 同时保留。 |
| [P3](plan-p3.md) | 逻辑钢琴乐器、part 选择、手别与演奏顺序 | 10 | `SCORE-003`, `SCORE-004`, `SCORE-005`, `SCORE-013` | 两个独立乐器不会被误合并成钢琴。; 同一钢琴拆成两个 part 时，notes、directions、attributes、measures 和 structure events 全部保留。 |
| [P4](plan-p4.md) | 统一表现语义与记谱调度 | 12 | `SCORE-009`, `SCORE-010`, `SCORE-011`, `PERF-006`, `PERF-005`, `SCORE-012`, `SCORE-014` | grace previous、following 与 make-time 分别生效。; arpeggio number、direction 与 cross-staff 分组稳定。 |
| [P5](plan-p5.md) | 唯一 ScorePerformancePlan 与消费者切换 | 10 | `ARCH-001`, `PERF-001` | PreparedPractice 持有唯一 ScorePerformancePlan。; autoplay 不再从 guides 重建 note events。 |
| [P6](plan-p6.md) | 复调同音、范围恢复与 transport 语义 | 10 | `PERF-002`, `PERF-003`, `PERF-004`, `PERF-007` | 同 MIDI 的多声部不被折叠。; 重复音能以正确 note-off 与 note-on 顺序重触发。 |
| [P7](plan-p7.md) | 连续踏板、CoreMIDI 时间戳与音频输出可靠性 | 10 | `PERF-009`, `PERF-010`, `PERF-011`, `PERF-012` | CC64、66、67 连续值从 score plan 到 output 保留。; CoreMIDI 使用非零 host-time timestamp 提前调度。 |
| [P8](plan-p8.md) | 统一 PerformanceObservation、MIDI、麦克风与录制证据 | 10 | `ARCH-002`, `OBS-009`, `OBS-001`, `OBS-002`, `OBS-003`, `RECORD-001` | MIDI velocity、release、CC64、66、67、channel、group、source 与 monotonic time 不再丢失。; 麦克风缺失维度明确为 notObserved。 |
| [P9](plan-p9.md) | 逐指手部证据与表现力虚拟琴 | 10 | `OBS-004`, `OBS-005`, `OBS-006`, `PERF-008`, `OBS-008`, `OBS-007` | palm 永不生成 note-on。; 每个 contact 保留 hand、finger、timestamp、confidence 与 kinematics。 |
| [P10](plan-p10.md) | Score–Performance Alignment | 10 | `ASSESS-001` | 单音、和弦、重复音、多声部、repeats 与踏板均可对齐。; unknown、ambiguous、provisional 与 wrong 稳定分开。 |
| [P11](plan-p11.md) | 能力感知的演奏评价与小节事实 | 10 | `ARCH-003`, `ASSESS-004`, `ASSESS-005`, `ASSESS-002` | 错误、未知、未观察、证据不足与通过分开。; 每个指标引用 alignment links 和 source plan events。 |
| [P12](plan-p12.md) | 受证据约束的诊断与虚拟指导 | 11 | `ASSESS-003`, `GUIDE-001`, `GUIDE-003`, `GUIDE-002` | 每个建议能追溯 assessment evidence、score range 与 confidence。; 一次只选择主要问题或明确组合练法。 |
| [P13](plan-p13.md) | 权威记谱投影与专业指法事实 | 10 | `NOTATION-001`, `NOTATION-002`, `NOTATION-003`, `NOTATION-004` | 异名同音与 accidental 正确显示。; 显示时值使用 written duration。 |
| [P14](plan-p14.md) | AI 对弹的语义边界、表现输入与质量门 | 9 | `AI-001`, `AI-002`, `AI-003` | 所有 AI 输入来源保留可观察 velocity、duration、controller 与 source capability。; 自播放事件不会进入用户 phrase。 |
| [P15](plan-p15.md) | 专业 corpus、真机与钢琴家验证及能力声明门 | 17 | 基础设施 / 验收 | golden corpus 覆盖审查列出的高风险语义和多个导出器。; 自动化测试、真机指标、盲听、评分一致性与教学有效性分别有证据。 |

## 执行与审计约定

1. 使用 `todo.toml` 取得下一 task；一个 task 对应一个原子提交。
2. 每个 task 在实现中同步接入 consumer / composition root，并在替换旧实现时同时清理旧路径。
3. 每个 phase 完成后自动创建并执行对应 `audit-pX.md`，先记录 finding，再修复，再验证。
4. 计划文件默认不提交 Git；业务代码提交使用稳定 task ID 和中文 Conventional Commit subject。
5. 未实际执行 Xcode、Simulator、真机、盲听或研究协议时，不得填写通过证据。

## Supporting Artifacts

- [需求真源与关键决策](idea.md)
- [54 项需求追踪](requirements-traceability.md)
- [已审阅代码与文档范围](reviewed-scope.md)
- [计划审计与修订记录](.audit/plan-review.md)
- [执行状态](todo.toml)
