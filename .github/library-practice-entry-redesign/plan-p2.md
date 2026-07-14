# Plan P2 - library-practice-entry-redesign

**Goal:** 用最小 score metadata 与真实练习 facts 构建当前曲目进度快照，并把 Library 右侧 Ornament 重建为只读进度与邀请练习界面。

**Non-goals:** 本 phase 不实现原名导入、冲突确认、文件替换或 transaction journal；不持久化任何 UI summary、比例、颜色或文案；不重新引入 Library score 读取。

**Approach:** 先扩展持久化模型和 repository，使 metadata 与 progress 在同一 actor document 中兼容读写且互不覆盖。然后用纯函数/纯模型从 entry version、metadata 和 facts 派生 Library snapshot，Practice preparation 成功后写入 metadata，Library selection 仅异步读取 snapshot。最后接入五类产品状态与 Reduce Motion 等价的 SwiftUI Ornament。

**Acceptance:**
- `PracticeProgressDocument` 旧 JSON 可兼容解码，metadata upsert 不丢 progress，progress upsert 不丢 metadata。
- Library snapshot 不读取、解析或 hash score 文件；总小节数只来自当前 version metadata。
- 稳定/学习/近期问题/最高稳定速度只来自真实 attempt facts，按最后 hand mode 和唯一 source measure 计算。
- 无真实 attempt 时显示邀请练习，不显示 `0 / total` 伪进度。
- replacement/version mismatch 时隐藏旧结构数字但可识别已有历史与通用偏好。
- 删除曲目同时删除全部 revision progress 与 score metadata。
- 右侧 Ornament 没有片段、手别、速度、循环、连续成功设置，也没有第二个练习按钮。

**Rules:**
- `scoreFileVersionID` 只做 Library metadata matching；`scoreRevision` 仍是 progress 内容隔离边界。
- `SongScorePracticeMetadata` 只包含 songID、version token、score revision、唯一 source measure 总数、preparedAt。
- `hasPracticeHistory` 必须由真实 attempt facts 派生；单纯 preparation 或空 progress record 不算练习过。
- repeat occurrence 不得重复计入总数、stable/learning 数或问题小节。
- legacy user/bundled token 为 nil 时，只能与 nil metadata token 匹配；replacement 产生非 nil token 后不得误用旧 metadata。
- metadata 写入失败不得阻止当前 Practice ready，但 Library 不得回退显示旧结构。

**State / lifecycle:**
- Snapshot owner：`FilePracticeProgressRepository` 提供原始读取，纯 builder 派生。
- Library owner：`SongLibraryViewModel` 持有当前 selected song 的 Ornament state 和 request generation。
- Selection：立即更新 selected ID → 取消旧 snapshot task → 异步读取当前 songID/version → 仅当前 generation 发布。
- Practice：prepare 成功并获得 measure spans 后 upsert metadata；session 继续 ready，即使 metadata 写入失败。

**Threading / actor:**
- JSON decode/encode、metadata/progress mutation、snapshot input读取都在 repository actor。
- 派生 builder 为 `Sendable` 纯逻辑，不依赖 MainActor。
- Library ViewModel 只在 MainActor 发布 presentation state。

**Debug / observability:**
- metadata write/load failure 使用 typed diagnostics，包含 songID/version/revision，不包含原始曲谱或绝对路径。
- snapshot builder 本身不写日志；错误由 repository/owner 边界记录。
- 记录 total unique source measures 与事实条数时只用计数，不记录逐小节数据。

**Testing strategy:**
- 使用旧版 JSON fixture、临时目录、确定性日期和 synthetic progress facts。
- snapshot tests 覆盖重复小节、不同 hand mode、空 facts、旧 revision、version mismatch、nil token legacy。
- ViewModel tests 用 recording repository 验证 selection generation 与零 score-file access。
- UI 人工测试覆盖 Ornament 宽高、VoiceOver、Reduce Motion 和长文案布局。

---

## P2-T1 扩展 entry version 与 progress metadata 兼容模型

**Files:**
- Modify: `HappyPianistAVP/Models/Library/SongLibraryModels.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeProgressModels.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeProgressDocumentCompatibilityTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`

**Step 1: 增加文件版本 token**

为 `SongLibraryEntry` 增加可选 `scoreFileVersionID: UUID?`，旧 index 缺失 key 时解码为 nil。不要改文件名或用 token 生成路径。

**Step 2: 增加最小 metadata**

定义 `SongScorePracticeMetadata`：`songID`、`scoreFileVersionID`、`scoreRevision`、`totalSourceMeasureCount`、`preparedAt`。构造时保证 total 非负，不存 measure list 或 UI summary。

**Step 3: 兼容扩展 document**

`PracticeProgressDocument` 增加 `scoreMetadata`，使用显式 Codable 或 `decodeIfPresent ?? []` 保证旧 JSON 只含 `songs` 时仍可读。编码继续 pretty/sorted 由 repository 控制。

**Step 4: 测试**

覆盖旧 index、旧 progress JSON、新 document round trip、metadata nil/non-nil token、未知额外 key，以及不存在 metadata key 时默认空数组。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 旧 fixture 无迁移即可解码；新字段 round trip 保持值。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongLibraryModels.swift HappyPianistAVP/Models/Practice/PracticeProgressModels.swift HappyPianistAVPTests/Practice/PracticeProgressDocumentCompatibilityTests.swift HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`

Run: `git commit -m "feat: P2-T1 - 增加曲谱版本与最小练习元数据"`

---

## P2-T2 扩展 progress repository 的 metadata 与原子保留语义

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift`
- Modify: all protocol fakes under `HappyPianistAVPTests/` that conform to `PracticeProgressRepositoryProtocol`

**Step 1: 扩展 protocol**

增加最小能力：
- upsert score metadata；
- 读取指定 songID 的全部 progress 与 metadata（或等价 snapshot input）；
- 读取同 songID 最新有效 progress，供后续通用偏好恢复；
- remove song 同时删除两类数据。

不要让调用方拿旧 `PracticeProgressDocument` 做整份覆盖。

**Step 2: 保证 mutation 互不覆盖**

`upsert(progress)` 只替换同 identity progress 并保留 metadata；`upsert(metadata)` 只替换同 songID + version/revision 的 metadata 并保留 songs；所有 mutation 继续由同一 actor 串行化。

**Step 3: 定义排序与 latest 规则**

latest progress 按 `updatedAt`，相同时间使用稳定 revision tie-break；无 active configuration 或无 facts 仍可作为候选输入，但 snapshot builder 决定是否算 history。

**Step 4: corruption 与删除**

保留现有 quarantine 行为。`remove(songID:)` 删除该 song 全 revision progress 和全部 metadata；删除其他 song 时不得受影响。

**Step 5: 测试**

覆盖 metadata/progress 交错并发 upsert、旧 JSON mutation 后保留、remove 两类数据、latest deterministic、corruption quarantine 后新 document 两数组均有效。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: repository tests 证明任一 mutation 不会清空另一类字段。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift HappyPianistAVPTests`

Run: `git commit -m "feat: P2-T2 - 扩展练习仓库的元数据原子读写"`

---

## P2-T3 实现当前曲目 Library snapshot 纯派生策略

**Files:**
- Create: `HappyPianistAVP/Models/Library/SongPracticeLibrarySnapshot.swift`
- Create: `HappyPianistAVP/Services/Practice/Progress/SongPracticeLibrarySnapshotBuilder.swift`
- Create: `HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift`

**Step 1: 定义只读 snapshot**

snapshot 只包含展示所需事实，例如：状态、最近练习时间、stable/learning unique measure counts、total、resume measure title input、最高稳定速度、近期问题、历史存在标记。不要包含 SwiftUI 类型、颜色、文案或完整 progress document。

**Step 2: 实现 version/revision 匹配**

- entry token 与 metadata token exact 匹配才视为 current structure。
- nil entry token 只匹配 nil metadata token。
- current metadata 的 `scoreRevision` 只读取同 identity progress facts。
- 有历史但无 current metadata 或 token mismatch → needs-rebuild。
- repository 输入不可用由上层映射 unavailable，不在 builder 猜测。

**Step 3: 实现真实 facts 规则**

- `hasPracticeHistory`：至少一个 fact 有真实 attempt 证据（成功/失败次数或 `lastAttemptAt`）。
- hand mode：优先最新有效 active configuration 的 hand；否则从最近 attempt fact 的 hand 决定；无 facts 使用 nil。
- stable/learning：同 hand、当前 revision、唯一 `PracticeSourceMeasureID`。
- recent issue：有 issue 且有 `lastAttemptAt`，按时间倒序稳定排序。
- highest stable tempo：只看 stable facts 的非 nil 值。
- resume：只有 exact revision 且 occurrence/结构由 Practice 已验证的 progress；Library 只输出可显示的 source measure identity，不尝试读取 score。

**Step 4: 测试**

覆盖 never-practiced、current、needs-rebuild、legacy nil token、metadata missing、空 progress record、repeat occurrence 不重复、不同 hand facts、旧 revision facts 隔离、issue 排序、unknown total。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 纯 builder tests 全部通过且不需要文件系统、MainActor 或真实时间。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongPracticeLibrarySnapshot.swift HappyPianistAVP/Services/Practice/Progress/SongPracticeLibrarySnapshotBuilder.swift HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift`

Run: `git commit -m "feat: P2-T3 - 从真实练习事实派生曲库快照"`

---

## P2-T4 在 Practice preparation 成功后写入当前 score metadata

**Files:**
- Modify: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`

**Step 1: 计算唯一 source measure 总数**

在 prepared result 已通过 steps/measure spans 验证后，用 `Set(prepared.measureSpans.map(\.sourceMeasureID)).count` 生成 total；不要按 occurrence 数量计数。

**Step 2: upsert metadata**

使用当前 entry 的 `scoreFileVersionID`、prepared identity revision 与 deterministic/system clock 写入 metadata。写入时机必须在成功 preparation 后，且与 Library 无关。

**Step 3: 定义失败降级**

metadata write 失败：记录 typed warning/error diagnostic，但不撤销已准备成功的 session，不让 Practice 进入 failure。后续 Library 因缺失/mismatch metadata 不显示旧结构数字。

**Step 4: 测试**

覆盖 unique source count、nil/non-nil token、metadata upsert 参数、repository failure 仍 ready、旧 generation 不写 metadata、cancel 不写 metadata。

**Step 5: 文档**

storage/data-flow 说明 `PracticeProgressDocument` 同时保存 songs 与 scoreMetadata，metadata 由 Practice preparation 刷新，Library 只读派生。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: metadata failure test 中 launch state 为 ready 且产生安全 diagnostic。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift docs/storage.md docs/data-flow.md`

Run: `git commit -m "feat: P2-T4 - 在练习准备后更新曲谱元数据"`

---

## P2-T5 让 SongLibraryViewModel 按选择异步加载当前快照

**Files:**
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Create: `HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift`

**Step 1: 定义 Ornament presentation state**

在 Library 模型层定义 no selection、loading（仅 repository 读取的瞬态）、never practiced、current、needs rebuild、unavailable。状态携带 selected songID，避免旧曲目数据短暂显示在新选择上。

**Step 2: 接入 generation-gated load**

选择、恢复选择、import/delete/replace 导致当前 entry/version 变化时：取消旧 task、递增 generation、请求 repository 输入并调用纯 builder。只有当前 selected songID + generation + version token 一致时发布。

**Step 3: 保持 Library 轻量**

删除任何 score URL、parser、preparation service 或 session dependency。snapshot load failure 只设置 unavailable，不影响试听、选择、导入、删除和开始练习。

**Step 4: 测试**

覆盖 A→B stale snapshot、恢复 last-selected、无选择、repository corrupted/unavailable、version token 变化重新加载、立即开始不等待 snapshot、spy file store/preparation 零调用。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: snapshot state 始终绑定当前 songID；数据失败不禁用开始按钮。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift`

Run: `git commit -m "feat: P2-T5 - 按当前曲目加载只读练习快照"`

---

## P2-T6 重建只读进度 Ornament 与 Reduce Motion 空状态

**Files:**
- Create: `HappyPianistAVP/Views/Library/LibraryPracticeOrnamentView.swift`
- Create: `HappyPianistAVP/Views/Library/LibraryPracticeInvitationView.swift`
- Create: `HappyPianistAVP/Models/Library/LibraryPracticeOrnamentPresentation.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Create/Modify: `HappyPianistAVPTests/Library/LibraryPracticeOrnamentPresentationTests.swift`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/overview.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/modules/happypianist-avp-practice.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 构建五类产品状态**

- 未选择：提示选择曲目。
- 从未练习：邀请文案 + SwiftUI 原生轻量动画；无 0/总数图表。
- current：最近练习、stable/learning、最近停留、最高稳定速度、近期问题。
- needs rebuild：说明曲谱已更新，下次练习建立新版本；隐藏旧结构数字。
- unavailable：鼓励练习，不触发 score access。

loading 瞬态可使用系统 `ProgressView`，但文案不得暗示正在解析曲谱。

**Step 2: 保证只读与单一入口**

Ornament 不接受 `PracticeRoundConfigurationController`，不包含 Picker/Slider/Toggle/Stepper，也不包含“去练习”或任何第二个启动按钮。开始按钮仍只在左侧主内容。

**Step 3: 实现可访问动画**

使用 SwiftUI 原生 symbol/shape/opacity/scale 动画；`accessibilityReduceMotion == true` 时使用静态等价层级。动画不影响信息和按钮可达性，不引入依赖。

**Step 4: presentation tests**

用纯 presentation model 测试五态文案/数字可见性、never-practiced 不输出零进度、needs-rebuild 不输出旧 total、日期/百分比 FormatStyle、recent issue 顺序。

**Step 5: 同步 docs 与人工清单**

canonical docs 描述“当前曲目持久化事实 Ornament”，删除旧配置控件与 preparation failure 位于 Library 的说明。人工检查加入 VoiceOver、Reduce Motion、窗口高度/宽度和滚动。

**Step 6: Phase 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO`

Expected: test/build 通过；代码搜索与调用图确认 Ornament 无 score IO、parser、session/config controller 依赖。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/Views/Library HappyPianistAVP/Models/Library/LibraryPracticeOrnamentPresentation.swift HappyPianistAVPTests/Library/LibraryPracticeOrnamentPresentationTests.swift README.md docs/architecture.md docs/overview.md docs/modules/happypianist-avp.md docs/modules/happypianist-avp-practice.md docs/testing/core-function-checklist.md`

Run: `git commit -m "feat: P2-T6 - 重建当前曲目只读进度装饰栏"`

---

## Phase Audit

- Audit file: `audit-p2.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环
- Audit focus:
  1. 检查 document Codable 是否真实兼容旧 JSON，任一 mutation 是否保留另一类字段。
  2. 检查 total/stable/learning/issues 是否按唯一 source measure、当前 revision 和最后 hand mode 派生。
  3. 检查 nil token legacy 与 non-nil replacement mismatch 是否不会误认旧结构。
  4. 检查 hasPracticeHistory 是否只来自真实 attempt facts。
  5. 检查 Ornament 是否持久化/持有 UI summary、配置 controller、score URL 或第二启动按钮。
  6. 检查 metadata failure 降级、diagnostic privacy 和 MainActor IO。
- Flow:
  1. 先记录发现
  2. 再修复问题
  3. 再运行本 phase 完整 `xcodebuild test` 与 `xcodebuild build`
