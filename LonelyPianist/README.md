# macOS App：LonelyPianist

这里是 **macOS 主应用**的源码目录（SwiftUI + CoreMIDI + SwiftData）。

## 这个 App 做什么

- 监听 MIDI 输入（电子琴/MIDI 键盘）
- 把演奏事件映射为文本 / 快捷键 / 快捷指令（Shortcuts）等（以根目录 `README.md` 为准）
- 与本机 Python 后端配合，实现 **Piano Dialogue（AI 钢琴对话）**

## 从哪里开始看

- 项目总体介绍与使用说明：`README.md`
- 研发计划/审计（内部）：`.github/features/`

## 运行与验收（建议按根文档）

本目录不单独维护一套“安装/运行/验收”流程，避免重复与漂移；请直接按根目录文档执行：

- `README.md` →「🎛️ 使用指南」
- `README.md` →「🤖 Piano Dialogue（AI 钢琴对话模式）」

