# macOS App：LonelyPianist

这里是 macOS 主应用源码目录，负责把 MIDI 输入变成可见、可控、可回放的本地体验。

## 这层负责什么

- 监听 MIDI 设备
- 把单音 / 和弦映射成文本、快捷键或系统动作
- 录制 take，并回放到内建 Sampler 或外部 MIDI 目的地
- 与 `piano_dialogue_server` 配合，完成 Piano Dialogue

## 快速上手

1. 打开 `LonelyPianist.xcodeproj`
2. 选择 `LonelyPianist` scheme
3. 运行到 macOS 26.0+ 目标
4. 首次使用时在系统设置里授予**辅助功能**权限

## Piano Dialogue

前置条件：先启动 `piano_dialogue_server`，让 `GET /health` 返回 `{"status":"ok"}`。

工作流：

1. 点击 `Start Listening`
2. 打开 `Dialogue`
3. 弹奏一段后停顿，默认静默窗口结束后触发生成
4. AI 回放会自动落盘为 take，可在 Recorder 中查看

当前回放打断策略可在以下三种模式间切换：

| 模式 | 行为 |
| --- | --- |
| Ignore | 忽略输入 |
| Interrupt | 一旦按键就打断 AI 回放 |
| Queue | 先排队，回放结束后再生成下一句 |

## 没有实体 MIDI 键盘？

可以用虚拟 MIDI 键盘测试，例如 [MidiKeys](https://github.com/flit/MidiKeys)。
打开后，在 App 中点 `Refresh MIDI Sources` 即可识别。

> 不建议用 GarageBand 做外部广播测试，它的 MIDI 事件不会稳定广播给外部应用。

## 关联文档

- Python 服务：[`../piano_dialogue_server/README.md`](../piano_dialogue_server/README.md)
- visionOS 端：[`../LonelyPianistAVP/README.md`](../LonelyPianistAVP/README.md)
- 仓库知识库：[`../.github/deepwiki/INDEX.md`](../.github/deepwiki/INDEX.md)
