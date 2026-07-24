# 配置

## 工程与命令

| 项目 | 当前值 |
| --- | --- |
| 工程 / scheme | `HappyPianist.xcodeproj` / `HappyPianistAVP` |
| targets | `HappyPianistAVP`、`HappyPianistAVPTests` |
| Swift / deployment | Swift 6.0 / visionOS 26.0 |
| 平台 | `xros`、`xrsimulator` |
| SwiftPM | 本地 `RealityKitContent`、`ZIPFoundation` 0.9.20 |

日常入口：

```bash
make doctor
make destinations
make build
make test
```

Makefile 和 CI 最终调用 `xcodebuild`；Simulator ID 可通过 `SIMULATOR_ID` 或 `DEVICE_ID` 覆盖。没有实际运行 `xcodebuild test`、Simulator 或真机时，不把类型检查或 `build-for-testing` 说成测试通过。

## 权限与资源

配置文件是 `HappyPianistAVP/Resources/Info.plist`。只为实际启用的能力声明权限：

| 能力 | 配置 |
| --- | --- |
| 手部追踪 / 虚拟琴平面 | `NSHandsTrackingUsageDescription`、`NSWorldSensingUsageDescription` |
| 麦克风识别 | `NSMicrophoneUsageDescription` |
| Bluetooth MIDI | `NSBluetoothAlwaysUsageDescription` |
| Aria v2 网络后端 | `NSLocalNetworkUsageDescription`、`NSBonjourServices`、`NSAllowsLocalNetworking` |
| 文件导入 / 五线谱 | `.musicxml`、`.mxl`、`.xml` importer；`UIAppFonts` 声明 `Fonts/Bravura.otf` |

仓库稳定包含 Bravura 字体；`SeedScores/`、`SalC5Light2.sf2` 和 `AIDuetPerformanceRNN.mlpackage` 属于可选或私有资源。缺失时对应集成测试可以跳过，但不能标记资源能力已通过。

依赖边界：普通练习不依赖 Python；`.mxl` 解包使用 `ZIPFoundation`；Apple framework 的最终行为只能在 Xcode、Simulator 或设备验证。

## 练习设置

| UserDefaults key | 作用 |
| --- | --- |
| `practiceManualAdvanceMode` | 手动推进策略 |
| `practiceHandMode` | 左手、右手、双手 |
| `practiceStep3AudioRecognitionMode` | 音频 detector |
| `practiceSoundOutputRoute` | `localSampler` 或 `externalMIDIDestination` |
| `practiceMIDIDestinationUniqueID` | MIDI destination；`0`/缺失表示未选择 |
| `practiceSendLocalControlOff` | 是否 best-effort 发送 CC122 |
| `practiceTempoScale` | 下一轮速度比例 |
| `practiceLoopEnabled` | 下一轮是否循环 |
| `practiceRequiredSuccesses` | 连续成功目标 |
| `practiceImprovBackendKind` | 用户选择的 AI backend |
| `audioOutputVolume` | sampler 与试听音频的 0...1 音量 |

设置分为长期默认值、下一轮 pending configuration 和当前轮 immutable configuration。修改手别、速度、循环和成功目标不得直接改变正在进行的一轮。

AI backend 缺失时使用当前默认选择；未知 token 显示无效并停止生成，不自动切换 provider。用户必须明确选择新的 backend。

## 触键校准

`PianoTouchCalibration` 是真实钢琴和虚拟琴共用的版本化契约；真实钢琴保存 world-anchor 校准，虚拟琴使用 composition root 注入的默认值。当前版本之外的字段或版本直接拒绝，不建立旧格式 fallback。

校准旋钮包括：键面偏移、释放滞回、最小/满量程击键速度、velocity 上下限、曲线指数和重复触键防抖。真机调整按[验证与测试](testing.md)中的硬件协议分设备、OS、route 和 calibration version 建 baseline；只记录安全聚合，不记录逐帧手部位置。

## 可选 Aria v2

```bash
cd python_backend/aria_server
uv sync
cd ..
uv run --project aria_server python scripts/aria_server.py --host 0.0.0.0 --port 8766
```

需要 Python 3.11+、`uv`、本地模型文件、Vision Pro 与 Mac 同一局域网及 Local Network 权限。Bonjour、连接超时、无效响应或质量门拒绝只停止当前生成；不会自动切换 provider。

## 排查顺序

| 现象 | 先查 |
| --- | --- |
| 五线谱符号异常 | `Bravura.otf` 是否在 App target 的 Copy Bundle Resources |
| 本地回放无声 | `SalC5Light2.sf2`、sampler route、audio volume |
| CoreML 不可用 | 模型是否在 bundle、backend 状态 |
| 找不到 Aria | server 监听地址、Bonjour、防火墙、Local Network 权限 |
| MIDI source 为空 | Bluetooth MIDI 面板、权限、CoreMIDI source |
| 麦克风不推进 | 权限、输入设备、噪声、detector status |
| 虚拟琴无法继续 | 平面检测、放置确认、immersive space 状态 |

SwiftFormat 使用仓库根 `.swiftformat`；提交前可运行 `swiftformat . --lint`。
