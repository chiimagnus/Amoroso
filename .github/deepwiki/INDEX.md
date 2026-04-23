# Deepwiki 索引（LonelyPianist）

本索引是 `.github/deepwiki/` 的入口。目标是让读者先看业务，再看实现；或者先看工程，再落到模块。

## 推荐阅读路径

### business-first
1. [business-context.md](business-context.md)
2. [overview.md](overview.md)
3. [architecture.md](architecture.md)
4. [data-flow.md](data-flow.md)
5. [modules/lonelypianist-avp.md](modules/lonelypianist-avp.md)
6. [modules/lonelypianist-macos.md](modules/lonelypianist-macos.md)
7. [modules/piano-dialogue-server.md](modules/piano-dialogue-server.md)
8. [troubleshooting.md](troubleshooting.md)

### engineering-first
1. [overview.md](overview.md)
2. [architecture.md](architecture.md)
3. [dependencies.md](dependencies.md)
4. [configuration.md](configuration.md)
5. [data-flow.md](data-flow.md)
6. [testing.md](testing.md)
7. [workflow.md](workflow.md)
8. [modules/lonelypianist-macos-runtime.md](modules/lonelypianist-macos-runtime.md)
9. [modules/lonelypianist-avp-musicxml.md](modules/lonelypianist-avp-musicxml.md)
10. [modules/piano-dialogue-server-inference.md](modules/piano-dialogue-server-inference.md)

## 页面分组

### 业务入口与全局认知
- [business-context.md](business-context.md)
- [overview.md](overview.md)
- [architecture.md](architecture.md)
- [data-flow.md](data-flow.md)

### 工程基线
- [dependencies.md](dependencies.md)
- [configuration.md](configuration.md)
- [storage.md](storage.md)
- [testing.md](testing.md)
- [workflow.md](workflow.md)
- [troubleshooting.md](troubleshooting.md)

### macOS 主应用
- [modules/lonelypianist-macos.md](modules/lonelypianist-macos.md)
- [modules/lonelypianist-macos-runtime.md](modules/lonelypianist-macos-runtime.md)
- [modules/lonelypianist-macos-mapping.md](modules/lonelypianist-macos-mapping.md)
- [modules/lonelypianist-macos-recording.md](modules/lonelypianist-macos-recording.md)
- [modules/lonelypianist-macos-dialogue.md](modules/lonelypianist-macos-dialogue.md)

### visionOS 原型
- [modules/lonelypianist-avp.md](modules/lonelypianist-avp.md)
- [modules/lonelypianist-avp-library.md](modules/lonelypianist-avp-library.md)
- [modules/lonelypianist-avp-calibration.md](modules/lonelypianist-avp-calibration.md)
- [modules/lonelypianist-avp-musicxml.md](modules/lonelypianist-avp-musicxml.md)
- [modules/lonelypianist-avp-tracking.md](modules/lonelypianist-avp-tracking.md)
- [modules/lonelypianist-avp-practice.md](modules/lonelypianist-avp-practice.md)

### Python 对话服务
- [modules/piano-dialogue-server.md](modules/piano-dialogue-server.md)
- [modules/piano-dialogue-server-protocol.md](modules/piano-dialogue-server-protocol.md)
- [modules/piano-dialogue-server-inference.md](modules/piano-dialogue-server-inference.md)
- [modules/piano-dialogue-server-debug.md](modules/piano-dialogue-server-debug.md)

### 术语与元数据
- [glossary.md](glossary.md)
- [GENERATION.md](GENERATION.md)

## 按问题导航
- **想先理解产品在做什么**：先看 `business-context.md`。
- **要改 macOS 监听 / 映射 / 录音 / 对话**：看 `modules/lonelypianist-macos.md`，再下钻对应子页。
- **要改 AVP 导入 / 校准 / 练习 / MusicXML**：看 `modules/lonelypianist-avp.md`，再下钻对应子页。
- **要改 Python 协议或采样逻辑**：看 `modules/piano-dialogue-server.md` 与 `modules/piano-dialogue-server-inference.md`。
- **遇到运行异常**：从 `troubleshooting.md` 开始。

## Coverage Gaps / Missing Assets
- 仓库内没有 `.github/workflows/*`，CI 门禁仍只能依赖本地测试链路。
- `LonelyPianist` 的 macOS 共享 scheme 已入库；`LonelyPianistAVP` 仍主要依赖本地 Xcode scheme 管理，跨机器的可用性不完全一致。
- `.github/deepwiki/assets/` 保留为资产位，但本次没有额外图片资产可复制。
