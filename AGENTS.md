# 仓库指南

## 项目结构与模块组织

本仓库是一个 macOS 桌面应用（SwiftUI + CoreMIDI + SwiftData）。主代码位于 `LonelyPianist/`，按 MVVM 与服务分层组织：

- `Models/`：领域模型与存储实体（MIDI 事件、映射规则、Profile）。
- `Services/`：基础设施与业务服务（MIDI、输入注入、权限、映射引擎、存储仓储）。
- `ViewModels/`：状态编排与业务流程入口（当前主要是 `LonelyPianistViewModel`）。
- `Views/`：主窗口、控制面板与功能页 UI。
- `Utilities/`：解析器与默认配置工厂。
- `.github/deepwiki/`：仓库知识库（业务入口 + 技术细节）。

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## 代码风格与命名规范

- 以 `.github/deepwiki/references/开发规范.md` 为准：MVVM、面向协议、依赖注入。
- 统一使用 `@Observable`（macOS 14+），避免 `ObservableObject` 旧式写法。
- 命名遵循语义化：类型 `PascalCase`，变量/函数 `camelCase`，协议以 `Protocol` 结尾，服务实现以 `Service` 结尾。
- View 保持展示职责，业务逻辑放入 ViewModel，跨模块能力放入 Service。

## 测试指南

提交前至少完成以下手测：

1. 权限流程：未授权时按钮可触发请求，授权后状态可自动刷新。
2. MIDI 流程：Start Listening 后 `Sources` 与 `MIDI Events` 有变化。
3. 映射流程：Single Key、Chord、Melody 三类规则至少各验证一次。
4. 持久化流程：新建或编辑 Profile 后重启应用仍保留。

新增复杂逻辑时，优先补充 **Swift Testing** 单元测试（建议在 `LonelyPianistTests/` 下按功能命名如 `DefaultMappingEngineTests.swift`）。
如果引入新的 Service Protocol，请同时提供至少一个 mock 测试双（test double），覆盖成功路径与失败路径。涉及状态轮询、时间窗口和节流逻辑时，优先把时间源抽象为可注入依赖，避免测试依赖真实等待。

> 注：本仓库测试采用 **Swift Testing**（`import Testing` + `@Test` + `#expect`），不是 XCTest。新增测试文件请按现有风格放在 `LonelyPianistTests/` 下。
