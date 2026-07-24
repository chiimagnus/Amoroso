# 钢琴演奏与专业质量边界

本页是产品措辞与证据门的唯一入口。代码实现能证明规则存在，不能单独证明听感、真机可靠性、评价有效性或教学有效性。

## 当前定位

HappyPianist 是以找键、和弦完成和小节练习为核心，具备 MusicXML 驱动回放、多来源输入观察、客观演奏分析和小节级进度事实的空间钢琴练习系统。

当前可以安全宣称：

- 已覆盖语义的 MusicXML 可审查回放；
- 按输入 capability 裁剪的 MIDI、音频和手部练习证据；
- 有范围、来源和完成条件的单一练习动作；
- 小节级 progress、恢复点、MIDI take 和安全诊断。

当前不能宣称：

- 钢琴家级示范、专业评分或教师替代；
- 对所有 MusicXML 作品的无损解释；
- 麦克风、MIDI 与手部追踪提供等价证据；
- 未经真机和专家证据验证的表现力乐器或教学效果。

## 事实与能力边界

```text
MusicXML source facts
  → ScorePerformancePlan
  → playback / steps / guides / notation

typed PerformanceObservation
  → alignment
  → capability-aware assessment
  → one CoachingAction
  → source-measure facts
```

- `ScorePerformancePlan` 是声音、tempo、controller、performed occurrence 和 provenance 的唯一真源。
- `PracticeStep` 只负责即时判定；source measure 才进入 progress。
- score alignment、逐音 evidence、target、issue、decision 和复测关联只在运行期存在。
- unknown、insufficient、degraded 和低置信度不是错误；产品必须按 capability 隐去不具备的结论。

| 输入 | 可以评价 | 不可以从中推导 |
| --- | --- | --- |
| Bluetooth MIDI | pitch、onset、release、velocity、controller、polyphony | hand、finger、姿势 |
| 定向麦克风 | 目标音集合、有限 onset/confidence | 逐音 release、velocity、复杂复调、完整踏板 |
| 手部接触 | 键位、接触生命周期、hand/finger、估算 velocity | 未经真机验证的精确力度、姿势质量、踏板 |

参考回放是确定性乐谱解释，不是钢琴家示范；AI 对弹是用户选择 provider 的运行期创意响应，不是谱面真值、assessment target 或评分基准。

## 能力声明与状态

| 能力 | 当前允许措辞 | 仍需的证据 |
| --- | --- | --- |
| CG-001 乐谱忠实示范 | 已覆盖语义的可审查 MusicXML 驱动示范 | 合法多 exporter corpus、真机输出和钢琴家盲评 |
| CG-002 MIDI 演奏评价 | capability-aware 客观指标 | 真机 MIDI 与独立教师标注一致性 |
| CG-003 表现力虚拟琴 | 使用版本化校准映射接触速度到 velocity | 分设备真机 latency/jitter、可靠性和钢琴家听感 |
| CG-004 专业虚拟指导 | 基于证据选择一个可复测动作 | assessment validity 与 coaching before/after 研究 |

当前四项均为 `pending evidence`；缺少合法 exporter、硬件或参与者授权时为 `blocked evidence`。状态规则：

- `pending evidence`：必要证据尚未完成或尚未绑定实际 run record；
- `passed`：所有必需层按同一 app/score/rubric 或 calibration version 完成并复核；
- `blocked evidence`：缺少合法语料、硬件、授权或其他必要条件，不等同实现失败。

证据记录绑定提交 SHA、fixture/score revision、协议版本、设备/OS/route（适用时）、rubric 或 calibration version、日期和聚合结果。自动化通过不能覆盖真机、盲评、教师标注或教学研究。

## 发布门

发布前至少分别检查：

1. MusicXML source/performed identity、controller、tempo、repeat 和 notation projection 的确定性快照；
2. Simulator 的 Swift 6、生命周期、reset、持久化和 generation 测试；
3. Vision Pro 上的 MIDI、音频、手部 latency/jitter、漏触发、卡音和恢复；
4. 需要专业措辞时的授权 corpus、钢琴家盲评、教师标注和 coaching 研究。

运行方法、真机协议和结果索引见[验证与测试](testing.md)。

## 必须保留的边界

- AI 严格使用用户选择的 backend；失败即停止本次生成，不自动 fallback。
- cue、summary、恢复地图、RealityKit 表现和原始传感数据不写入 progress JSON。
- 指导一次最多选择一个 action；证据不足时只请求补充证据。
- 新实现替换旧实现时，同一 task 删除旧 API、状态、测试入口和双轨分支。
