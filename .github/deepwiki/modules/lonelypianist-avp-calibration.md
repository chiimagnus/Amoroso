# AVP Calibration

## 范围
校准页覆盖 A0/C8 捕获、世界锚点存储、恢复、重新校准和定位前置条件。

## 关键对象
| 对象 | 职责 |
| --- | --- |
| `AppModel` | 存储 calibration 和定位结果 |
| `ARGuideViewModel` | Step 1 / Step 3 编排 |
| `CalibrationPointCaptureService` | 准星稳定与锚点 ID 记录 |
| `WorldAnchorCalibrationStore` | JSON 持久化 |
| `PianoKeyGeometryService` | 根据校准生成 88 键区域 |
| `KeyboardFrame` | 从 A0/C8 推导键盘局部坐标系（用于渲染与按键检测） |

## 行为
- `saveCalibrationIfPossible()` 会拒绝不完整校准。
- 保存后会 reset capture state。
- `beginCalibrationRecapture()` 会清理临时锚点。
- `resolveRuntimeCalibrationFromTrackedAnchors()` 会检查 anchor 是否存在、是否 tracked、是否足够远。
- runtime calibration 会把 **A0/C8 解释为琴键“前沿线”**（keyboard-local `z = 0`），并基于 `DeviceAnchor` 判断琴键内部方向，从而得到 `frontEdgeToKeyCenterLocalZ`（通常是 `± keyDepth/2`）。

## Step 1：引导式校准流程（Guided Flow）

Step 1 不只是“捕获两点”，而是一条由 `ARGuideViewModel` 驱动的引导式状态机：

| 阶段（`CalibrationPhase`） | UI 表现 | 下一步触发 |
| --- | --- | --- |
| `capturingA0` | 提示把左手食指放到 A0，等待准星变绿后右手捏合确认 | 右手捏合 + `isReticleReadyToConfirm == true` |
| `transitionA0` | 短暂过渡（用于引导从 A0 移动到 C8） | 约 1.25s 后进入 C8 捕获 |
| `capturingC8` | 提示把左手食指放到 C8，等待准星变绿后右手捏合确认 | 右手捏合 + `isReticleReadyToConfirm == true` |
| `transitionC8` | 短暂过渡并尝试保存校准 | 约 0.3s 后执行保存 |
| `completed` | 展示“校准完成”并允许返回首页 | 用户返回 |
| `error(message)` | 展示错误文案并中止捕获 | 返回首页或重试 |

在 `CalibrationStepView`：
- `onAppear` 调用 `beginCalibrationGuidedFlow()`，并以 `.calibration` 模式打开沉浸空间。
- `onDisappear` 调用 `endCalibrationGuidedFlow()`，并关闭沉浸空间；若沉浸空间状态卡死，会尝试恢复。

## 交互与确认（准星变绿 + 右手捏合）

Step 1 的确认手势为：
- **左手**：用食指把准星对准目标琴键（A0/C8）。
- **右手**：捏合确认（右手食指与拇指距离小于阈值时触发一次确认）。

确认时会在准星位置创建 `WorldAnchor` 并添加到 `WorldTrackingProvider`，然后把 anchor id 写入 `CalibrationPointCaptureService`；如果替换了旧 anchor，会尝试删除旧的 world anchor。

## Reticle 稳定判定（`isReticleReadyToConfirm`）

`CalibrationPointCaptureService.updateReticleFromHandTracking(_, nowUptime:)` 会在以下条件满足时将 `isReticleReadyToConfirm` 置为 `true`：
- 两次 reticle 点位移动距离 < `0.002m`（2mm）
- 连续稳定时长 ≥ `0.5s`

当手部追踪点缺失时，会立即清空稳定窗口并置 `isReticleReadyToConfirm = false`。

## 模拟器演示（Debug only）

在 `DEBUG && targetEnvironment(simulator)` 下，Step 1 提供模拟器演示路径：
- 不依赖真实手部追踪；UI 中提供“下一步”按钮推进阶段，用于演示校准状态机和页面闭环。

## 坐标系约定（KeyboardFrame）

- 原点：A0（投影到 `planeHeight`）。
- +X：从 A0 指向 C8（水平投影）。
- +Y：世界向上。
- +Z：按右手系推导（满足 `cross(x, y) == z`）。注意 +Z 未必“朝向用户”，需结合设备位姿判定哪一侧是琴键内部。

## 失败类型
| 失败 | 含义 |
| --- | --- |
| `missingStoredCalibration` | 没有持久化校准 |
| `anchorMissing` | 锚点没在当前环境恢复 |
| `anchorNotTracked` | 锚点存在但未跟踪 |
| `anchorsTooClose` | A0/C8 距离过近 |
| `devicePoseUnavailable` | 设备位姿暂不可用，无法判定前后方向 |

## 调试抓手
- `calibrationStatusMessage`
- `pendingCalibrationCaptureAnchor`
- `storedCalibration`
- `practiceLocalizationState`


## Coverage Gaps
- 校准流程的空间交互仍依赖手工验证，缺少沉浸式 UI 自动化。

## 更新记录（Update Notes）
- 2026-04-26: 补充 Step 1 引导式校准流程（`CalibrationPhase`）、准星稳定判定、右手捏合确认与模拟器演示路径。
