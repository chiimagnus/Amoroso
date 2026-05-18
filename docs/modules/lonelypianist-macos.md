# 模块：LonelyPianist macOS

## 边界
- 负责：MIDI 监听、映射编辑与执行、录音 / 回放、Dialogue 会话控制。
- 不负责：visionOS 追踪和 Python 推理细节。

## 目录地图
| 路径 | 角色 |
| --- | --- |
| `ViewModels/` | 业务编排 |
| `Services/MIDI/` | MIDI 输入 / 输出 |
| `Services/Bluetooth/` | BLE MIDI 连接前置检查（权限/开关），用于在 App 内打开系统 Bluetooth MIDI 连接窗口 |
| `Services/Mapping/` | mapping engine |
| `Services/Dialogue/` | turn-based 对话 |
| `Services/Recording/` | take 构建 |
| `Services/Storage/` | SwiftData 持久化 |
| `Views/` | UI |

## 入口与生命周期
| 入口 | 行为 |
| --- | --- |
| `LonelyPianistApp.swift` | 组装容器、服务、view model |
| `bootstrap()` | 读权限、seed config、加载 takes、刷新输出 |
| `toggleListening()` | 启停 CoreMIDI |
| `startDialogue()` | 打开 WS + silence loop |
| `startRecordingTake()` / `playSelectedTake()` | Recorder 录放 |

## Runtime

### 范围
Runtime 页处理“连没连上、当前在做什么、按下去后发生了什么”。

### 关键对象
| 对象 | 职责 |
| --- | --- |
| `LonelyPianistViewModel` | 运行面状态总控 |
| `CoreMIDIInputService` | 输入监听与来源刷新 |
| `CoreMIDIOutputService` | 目标 MIDI 目的地枚举与发送 |
| `BluetoothAccessPreflight` | 在打开系统 `Bluetooth MIDI…` 连接窗口前预检蓝牙权限/开关，提供面向用户的引导提示 |
| `KeyboardEventService` | CGEvent 按键注入 |
| `ShortcutExecutionService` | 打开 Shortcuts URL scheme |

### 生命周期
1. `LonelyPianistApp` 初始化 `ModelContainer`、输入输出服务和 `DialogueManager`。
2. `bootstrap()` 读取权限、配置和 takes。
3. `startListening()` 打开 CoreMIDI。
4. `refreshMIDISources()` 重新绑定来源。
5. `stopListening()` 清空状态并重置 mapping。

蓝牙 MIDI（BLE MIDI）连接路径：
1. 用户点击工具栏 `Bluetooth MIDI…`（`RecorderPanelView`）。
2. `BluetoothAccessPreflight` 预检蓝牙权限与开关。
3. 通过预检后，打开系统 `CABTLEMIDIWindowController` 让用户完成 Connect。
4. 连接完成后，BLE MIDI 以 CoreMIDI source 形式出现，`CoreMIDIInputService` 会在系统 setup 变更通知后自动 refresh sources。

### 状态和可观察字段
| 字段 | 含义 |
| --- | --- |
| `connectionState` | MIDI 连接状态 |
| `connectedSourceNames` | 当前来源名 |
| `midiEventCount` | 事件计数 |
| `pressedNotes` | 当前按下集合 |
| `recentLogs` | 近期日志 |
| `statusMessage` | 顶层状态提示 |

### 调试抓手
- 无输出：先看 `hasAccessibilityPermission`。
- 无来源：先看 `connectionState` 和 `connectedSourceNames`。
- BLE MIDI 连接失败：先确认蓝牙权限与蓝牙开关，再确认设备是否已在系统窗口中 Connected。
- 无按键注入：先看 `KeyboardEventService` 是否成功发 CGEvent。

## Mappings

### 范围
映射页覆盖单键、和弦、velocity 阈值和编辑持久化。

### 关键对象
| 对象 | 职责 |
| --- | --- |
| `DefaultMappingEngine` | 把 MIDIEvent 转成 resolved keystrokes |
| `MappingConfigPayload` | 可编码的映射载荷 |
| `KeyStroke` | 系统按键表示 |
| `SingleKeyMappingRule` | 单音映射 |
| `ChordMappingRule` | 和弦映射 |

### 规则语义
| 规则 | 行为 |
| --- | --- |
| 单键 | 按 note 精确匹配 |
| velocity | 超阈值时加 `.shift` |
| 和弦 | 按下集合必须严格等于规则集合 |
| 去重 | 同一个 chord rule 只触发一次，直到松开 |

### 编辑行为
- `setSingleKeyMapping` 会先清掉同 note 的旧规则，再写入新规则。
- `createChordRule` 会对 notes 去重、排序和 clamp。
- `updateChordRule` 会保持 rule id 不变，只更新内容。
- `deleteChordRule` 直接移除目标规则。

### 调试抓手
- `previewText` 会显示已触发的快捷键。
- `recentLogs` 会记录触发来源和 key label。
- `MappingConfigPayload` 编解码回归可直接防止配置漂移。

## Recorder

### 范围
Recorder 页覆盖 take 录制、MIDI 导入、take 回放、seek、重命名和删除。

### 关键对象
| 对象 | 职责 |
| --- | --- |
| `DefaultRecordingService` | 把 note on/off 合成 `RecordingTake` |
| `RecordingTakeRepository` | take 的持久化 |
| `MIDIFileImporter` | 导入 MIDI 文件为 notes |
| `RoutedMIDIPlaybackService` | 播放 take |

### 录制规则
| 规则 | 含义 |
| --- | --- |
| 开启录制时清空旧状态 | 避免串 take |
| note off 缺失 | stop 时按 stop 时刻补全 |
| duration 最短值 | 保证 note 至少持续 0.01 秒 |
| 时间戳早于开始 | fallback 到当前 clock |

### 播放和导入
- `playSelectedTake()` 会从当前 playhead 开始播放。
- `seekPlayback(to:)` 在播放中会延迟 50ms 再重启播放。
- `importMIDIFile(from:mode:)` 支持 `all` 和 `pianoOnly`。
- `setPlaybackOutput(id:)` 可切换 built-in sampler 或外部 MIDI 目的地。

### 调试抓手
- `recorderMode` / `recorderStatusMessage`
- `takes` / `selectedTakeID`
- `playheadSec`
- `playbackOutputs` / `selectedPlaybackOutputID`

## Dialogue

### 范围
Dialogue 页覆盖 turn-based 对话状态机、静默触发、回放策略和 take 落盘。

### 关键对象
| 对象 | 职责 |
| --- | --- |
| `DialogueManager` | 会话编排与状态机 |
| `WebSocketDialogueService` | WS 客户端 |
| `DefaultSilenceDetectionService` | 静默检测 |
| `DialoguePlaybackInterruptionBehavior` | 回放期间输入策略 |

### 状态机
| 状态 | 说明 |
| --- | --- |
| `idle` | 未开启对话 |
| `listening` | 收集人类演奏 |
| `thinking` | 请求 Python 生成中 |
| `playing` | AI 回放中 |

### 行为
- 静默检测轮询间隔是 80ms。
- `ignore / interrupt / queue` 三种策略可持久化。
- AI reply 会写成 `RecordingTake`。
- 结束时会保存整个 session take。

### 协议
- 请求类型固定为 `generate`。
- 协议版本固定为 `1`。
- payload 带 `notes`、`params` 和 `session_id`。

### 调试抓手
- `dialogueStatus`
- `dialogueLatencyMs`
- `statusMessage`
- `recentLogs`
- Python `health` 和 `test_client.py`

## 风险点
- `handleMIDIEvent`
- `setSingleKeyMapping`
- `stopTransport`
- `DialogueManager.start()`
- `RecorderPanelView.openBluetoothMIDIWindow()`（蓝牙权限/系统窗口行为受环境影响）


## Coverage Gaps
- 集成测试仍主要覆盖 service / view model 层，没有系统级 E2E。
