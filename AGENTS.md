# 仓库指南

## 项目结构与模块组织

本仓库是一个 macOS 桌面应用（SwiftUI + CoreMIDI + SwiftData）。

- 主工程：`LonelyPianist.xcodeproj`
- App 代码：`LonelyPianist/`（按 MVVM + Services 分层：`Models/`、`Services/`、`ViewModels/`、`Views/`、`Utilities/`）
- 单元测试：`LonelyPianistTests/`（Swift Testing）
- visionOS 相关：`LonelyPianistAVP/`、`LonelyPianistAVPTests/`（scheme：`LonelyPianistAVP`）
- AI 后端工作区：`piano_dialogue_server/`（本机 Python 环境）
- 规范与知识库：`.github/deepwiki/`（优先参考 `.github/deepwiki/references/开发规范.md`）

## 构建、测试和开发命令

打开工程：

```bash
open LonelyPianist.xcodeproj
```

命令行构建（macOS Debug）：

```bash
xcodebuild -project LonelyPianist.xcodeproj -scheme LonelyPianist -configuration Debug build
```

运行单测（macOS Debug）：

```bash
xcodebuild -project LonelyPianist.xcodeproj -scheme LonelyPianist -configuration Debug test
```

visionOS（可选）：先查看可用 destination，再构建/测试 `LonelyPianistAVP`：

```bash
xcodebuild -project LonelyPianist.xcodeproj -scheme LonelyPianistAVP -showdestinations
```

```bash
xcodebuild -project LonelyPianist.xcodeproj -scheme LonelyPianistAVP -configuration Debug build
```

Piano Dialogue 后端（可选）：在独立终端启动本机服务（默认 `127.0.0.1:8765`）：

```bash
cd piano_dialogue_server
python3.12 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
cd server
../.venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8765
```

## 代码风格与命名规范

- 统一使用 `@Observable`（macOS 14+），避免 `ObservableObject`。
- 命名：类型 `PascalCase`；变量/函数 `camelCase`；协议以 `Protocol` 结尾；实现以 `Service` 结尾。
- View 只负责展示；状态编排与业务流程放 `ViewModels/`；跨模块能力下沉到 `Services/`，依赖通过注入传递。
- SwiftUI 事件：不需要旧/新值时优先 `.onChange(of:) { ... }` 无参数重载，避免 `(_, _)` 形式的冗余闭包签名。

## 测试指南

- 测试框架：Swift Testing（`import Testing` + `@Test` + `#expect`），新增文件放 `LonelyPianistTests/`，命名 `*Tests.swift`。
- 新增 Service Protocol 时提供最少 1 个测试替身（成功/失败各覆盖）；涉及时间窗口/节流时把时间源做成可注入依赖，避免真实等待。
- 提交前手测：权限请求与状态刷新、Start Listening 后 Sources/MIDI Events 更新、Single/Chord/Melody 映射各验证一次、Profile 持久化（重启仍保留）。

## 提交与 Pull Request 规范

- Commit message：优先 `feat:` / `fix:` / `refactor:` / `test:`，与 `.github/features/**` 的任务可追加标识（如 `P2-T1`）。
- PR 描述包含：动机、关键改动点、验证方式（命令 + 手测项）；涉及 UI 变更附截图或录屏。
