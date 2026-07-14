# Plan P1 - library-practice-entry-redesign

**Goal:** 把曲谱 preparation、session 安装与失败/重试生命周期从 Library 原子迁移到 Practice 窗口，并把 Library 收敛为轻量选择、试听和单一“开始练习”入口。

**Non-goals:** 本 phase 不实现最终的持久化进度 Ornament，不实现原名导入/同名替换事务，也不改变 MusicXML parser、练习判定或沉浸空间业务。

**Approach:** 先建立只携带 `songID` 的启动模型与单一 `PracticeLaunchViewModel`，再让 Practice root 在窗口激活后显式 activate request。最后一次性切断 Library 的 preparation/session/configuration 路径，独立保存 latest-wins 选择，并删除旧配置 Ornament、旧失败 UI 和旧测试入口。Library 与 Practice 共享同一个 launch owner，但 Library 只能登记请求，不能调用 activate 或接触 `PreparedPractice`。

**Acceptance:**
- 选择、恢复选择、试听和 Library Ornament/主内容渲染不读取 score URL、不调用 `PracticePreparationService.prepare`、不安装 session。
- 点击左侧主内容右下角“开始练习”后先登记当前 `songID` 并打开 Practice；Practice root 激活后才出现 loading 并开始 preparation。
- no-request、loading、failure、ready、retry、return、scene inactive 和 A→B request 都不会显示或安装旧 session。
- 同 revision 仍恢复完整配置和 resume；无 exact progress 时沿用现有全曲默认契约。
- 旧 Library preparation/configuration 类型、状态、视图、测试和 canonical docs 在替代它们的 task 中删除或改写。

**Rules:**
- Library → Practice 的正式业务数据只有稳定 `songID`；不得传 `URL`、`PreparedPractice`、measure spans 或配置草稿。
- `request(songID:)` 不得触发文件读取、解析、hash 或 session mutation。
- 只有当前 request generation 可以发布 loading/failure/ready 或调用 `ARGuideViewModel.applyPreparedPractice`。
- loading/no-request/failure 前必须清除已 flush 的旧 prepared/session presentation；旧异步结果必须丢弃。
- MainActor 不执行 score IO、MusicXML 解析或 JSON 文件 IO。
- 所有 teardown 路径必须取消 preparation task；重复 activate/return/retry 必须幂等或显式生成新 generation。

**State / lifecycle:**
- Owner：`PracticeLaunchViewModel`。
- Start：Library 调用 `request(songID:)`；Practice root `.task`/active scene 调用 `activateCurrentRequest()`。
- Stop：新 request、retry、返回 Library、Practice disappear、scene 非 active、无 request。
- Ready：当前 generation prepare、验证、session 安装、progress restore 全部完成。
- Reset：返回 Library 后 launch presentation 清空，Practice 不保留可见旧曲目。

**Threading / actor:**
- `PracticeLaunchViewModel` 为 `@MainActor @Observable`，只编排状态。
- entry 解析、index 读取、score URL 解析和 preparation 通过 actor/protocol 异步执行。
- `PracticePreparationService` 继续在其既有并发边界运行；UI 状态只在 MainActor 更新。

**Debug / observability:**
- 沿用 typed preparation diagnostics，但 stage 从 Library selection 语义改为 Practice launch 语义。
- 记录 request generation、songID、score revision 和安全的相对文件引用；禁止绝对路径和原始 MusicXML。
- cancellation/stale request 不记录为用户可见失败。

**Testing strategy:**
- 使用 fake entry resolver、fake preparation service、deterministic sleeper 和 recording ARGuide/session adapter。
- 单元测试不得依赖真实 MusicXML、真实文件权限、窗口或网络。
- 窗口替换、按钮位置、VoiceOver 与 scenePhase 另列 Simulator/人工证据。

---

## P1-T1 建立 Practice launch 请求、状态与 typed failure 模型

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Reference for later deletion: `HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift`
- Reference for later deletion: `HappyPianistAVPTests/Library/LibraryPracticePreparationFailureTests.swift`

**Step 1: 定义稳定请求与状态边界**

新增只公开 `songID` 的 `PracticeLaunchRequest`。定义 Practice 专属的 presentation state，至少覆盖 no request、requested/loading、failure、ready；request ID/generation 仅作为 owner 内部并发标识，不进入跨层业务模型。

**Step 2: 迁移错误映射语义**

把现有 `LibraryPracticePreparationFailure` 的 typed mapping 复制并重命名为 `PracticeLaunchFailure`，保留具体错误码、技术详情和隐私安全的 `DiagnosticFileReference`。新增必要的 Practice launch diagnostic code/stage，但不改变 parser error taxonomy。

**Step 3: 先用新测试锁定映射**

迁移失败映射测试到 Practice 命名空间，覆盖 file missing、MXL、XML source location、无 playable notes、缺少 measure structure、unexpected，以及 diagnostic event 的 songID/file privacy。

**Step 4: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 新 Practice failure tests 通过；旧 Library runtime 尚未切换，但新模型可独立编译。

**Step 5: 原子提交**

Run: `git add HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift`

Run: `git commit -m "refactor: P1-T1 - 建立练习启动状态与失败模型"`

---

## P1-T2 实现单一 PracticeLaunchViewModel 与 entry 解析边界

**Files:**
- Create: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Create: `HappyPianistAVP/Services/Library/SongLibraryEntryResolver.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift`

**Step 1: 建立可替换的 entry resolver**

定义 async resolver 边界，通过 `songID` 从 bundled provider 与用户 index 解析当前 `SongLibraryEntry` 及 score URL。生产实现不得缓存 `PreparedPractice`，测试提供 fake resolver；用户 index IO 保持 actor 隔离。

**Step 2: 实现 request registration**

`request(songID:)` 只更新当前请求、递增 generation、取消旧任务并清空旧 launch presentation；不得调用 resolver、score file store、preparation service 或 `ARGuideViewModel`。

**Step 3: 实现 activation pipeline**

`activateCurrentRequest()` 按当前 generation 执行：解析 entry/score URL → 调用 `PracticePreparationService.prepare` → 验证 steps 与 measure spans → 调用 `ARGuideViewModel.applyPreparedPractice` → 等待既有 exact-revision progress restore → 发布 ready。任何 guard 失败、取消或 generation 变化都不能发布状态或保留旧 session。

**Step 4: 实现 retry/cancel/return**

- retry：同一 songID 新 generation，重新 activate。
- cancel/return：取消 task、让旧 generation 失效、flush/reset 当前 prepared/session presentation。
- repeated activate：同一 request 已 loading/ready 时不重复启动。
- preparation failure：映射 `PracticeLaunchFailure` 并记录一次 typed diagnostic；stale/cancel 不记失败。

**Step 5: 接入 composition root**

`LiveAppGraph` 创建唯一 owner，注入 resolver、preparation service、ARGuide、diagnostics，并把 owner 作为 graph 字段暴露给 Library 与 Practice。不得在 `SongLibraryViewModel` 再创建第二个 owner。

**Step 6: 测试**

覆盖：registration 不 prepare、activation 才 prepare、exact request ready、A→B stale result、retry 新 generation、cancel 清旧 session、invalid steps/spans、resolver/file failure、diagnostic 只记录当前失败。

**Step 7: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: launch owner 的纯状态机与异步竞态测试通过，registration 断言 preparation request count 为 0。

**Step 8: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/PracticeLaunch HappyPianistAVP/Services/Library/SongLibraryEntryResolver.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`

Run: `git commit -m "feat: P1-T2 - 实现练习窗口启动所有权"`

---

## P1-T3 让 Practice root 承担 loading、failure、ready 与 teardown

**Files:**
- Create: `HappyPianistAVP/Views/Practice/PracticeLaunchContainerView.swift`
- Create: `HappyPianistAVP/Views/Practice/PracticeLaunchFailureView.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`
- Modify: `HappyPianistAVP/Views/Practice/PracticeWindowRootView.swift`
- Modify: `HappyPianistAVP/Views/HappyPianistAVPApp.swift`
- Modify: `docs/modules/happypianist-avp-practice.md`
- Modify: `docs/data-flow.md`

**Step 1: 构建 Practice launch 容器**

Practice window 按 owner state 呈现：
- no request：不显示旧 `PracticeStepView`，提供返回 Library。
- loading：显示当前曲目准备状态，不暴露 Library config UI。
- failure：显示 typed failure、可复制技术详情、重试和返回 Library。
- ready：才挂载 `PracticeStepView`。

**Step 2: 把激活点放在 Practice root**

在窗口出现且 scene active 后调用 `activateCurrentRequest()`；Library window 打开动作本身不能触发 activate。用 `.task(id:)` 或等价生命周期保证 request 变化可重新激活且旧 task 取消。

**Step 3: 收口 scene/disappear/return 语义**

scene 非 active：取消 launch preparation，并沿用既有 session suspension/flush。返回 Library 或无 pending transition 的 disappear：先清 launch presentation/session，再关闭 immersive，最后打开 Library。ready 以外不得显示旧 session。

**Step 4: 注入共享 owner**

`HappyPianistAVPApp` 将 graph 中同一个 `PracticeLaunchViewModel` 注入 `PracticeWindowRootView`；不得从 Practice root 反向读取 `SongLibraryViewModel`。

**Step 5: 测试与文档**

增加 no-request/loading/failure/ready、scene inactive、window disappear、return、retry 的生命周期测试。同步改写 Practice/data-flow canonical docs，明确 preparation 从 Practice activation 开始。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: Practice root 生命周期测试通过；非 ready 状态下 session view 不可达。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/Views/Practice HappyPianistAVP/Views/HappyPianistAVPApp.swift HappyPianistAVP/Views/Shared/ImmersiveActionAdapters.swift HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift docs/modules/happypianist-avp-practice.md docs/data-flow.md`

Run: `git commit -m "feat: P1-T3 - 在练习窗口激活并管理曲谱准备"`

---

## P1-T4 原子切断 Library preparation/configuration 并加入唯一开始入口

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryCrateView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeOrnamentView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeFailureView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeSkeletonView.swift`
- Delete: `HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift`
- Delete: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticeConfigurationTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticePresentationTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticePreparationFailureTests.swift`
- Modify/Create: `HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/overview.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 增加原子 last-selected mutation**

`SongLibraryIndexStoreProtocol` 新增 actor 内 read-modify-write 的 `setLastSelectedEntryID`（名称可按现有风格调整）。它只修改最新磁盘 document 的 last-selected，不接受调用方旧 snapshot 覆盖整份 index。

**Step 2: 重写 Library selection flow**

`SongLibraryViewModel` 删除 `ARGuideViewModel`、`PracticePreparationService`、preparation task/generation/state、prepared session getters、config presentation、progress dictionary 和 `startSelectedPractice`。新增独立 latest-wins debounce task：选择立即更新内存 selection 请求；最终 entryID 通过原子 store API 保存；保存失败只提示，不阻塞浏览或启动。

**Step 3: 切换 SwiftUI 选择调用**

所有唱片点击、按钮、拖拽、VoiceOver adjustable、恢复选择都走同一轻量 selection API。切歌仍停止上一首试听；view disappear 只停止试听和 flush/等待最新选择保存，不再 cancel preparation。

**Step 4: 加入唯一“开始练习”按钮**

按钮放在左侧主 Library 内容容器的右下角，由当前 `selectedEntryID` 驱动。按钮不得位于 Ornament、scene 根右下角或播放条内部；窗口缩放后不得遮挡试听控制。点击顺序固定为：`practiceLaunchViewModel.request(songID:)` → `WindowTransitionState.beginTransition` → `openWindow`，不等待 selection persistence。

**Step 5: 删除旧配置 Ornament 与旧路径**

彻底删除 Library preparation/configuration view/model/test。P2 之前可暂时没有右侧 Ornament，或仅保留不读取 score/progress 的静态占位；不得保留隐藏的旧 prepare 分支或第二个练习按钮。

**Step 6: 更新 composition 与 test harness**

`SongLibraryViewModel` 构造器只保留曲库 bootstrap、index mutation、试听、导入/删除等依赖。更新所有 fakes，删除旧 preparation fake。新增选择 latest-wins、快速选择后立即启动、disappear、保存失败、删除导致 generation 失效测试，并断言 parser/preparation/session spy 均未被调用。

**Step 7: 同步 canonical docs**

README、architecture、overview、AVP module 和核心人工检查表不再描述“选曲自动 preparation”“右侧配置 Ornament”“去练习！”。写明左侧唯一按钮和 Practice activation 边界。

**Step 8: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 全部测试编译通过；Library selection tests 证明连续切歌与启动不触发 preparation；旧 Library preparation/configuration symbols 不再存在。

**Step 9: 原子提交**

Run: `git add -A HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library HappyPianistAVP/Models/Library HappyPianistAVPTests/Library HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift README.md docs/architecture.md docs/overview.md docs/modules/happypianist-avp.md docs/testing/core-function-checklist.md`

Run: `git commit -m "refactor: P1-T4 - 原子移除曲库准备路径并加入练习入口"`

---

## P1-T5 补齐启动竞态回归、窗口验证与 phase gate

**Files:**
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift`
- Modify: `HappyPianistAVPTests/Window/WindowCoordinatorTests.swift`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 增加跨层回归矩阵**

覆盖：
- 快速 A→B→A，只有最后 request 可 ready。
- request 后立刻切换窗口，registration 阶段 prepare count 为 0。
- loading 时返回、scene inactive、Practice disappear，旧 result 不安装。
- failure retry 生成新 diagnostic ID；取消不生成 failure。
- selected entry 保存失败或尚未落盘时，当前按钮仍按内存 selected ID 启动。
- no request 的 Practice window 不显示旧 session。

**Step 2: 更新人工验证清单**

加入按钮在 Library 主容器右下角、窗口缩放不遮挡播放条、VoiceOver 名称、Practice loading/failure/return、Reduce Motion 基础检查。未执行 Simulator/实机时必须记录 Not Run。

**Step 3: Phase 验证**

Run: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO`

Expected: test 与 build 通过；没有 Library → `PracticePreparationService.prepare` 或 `applyPreparedPractice` 调用路径。

**Step 4: 原子提交**

Run: `git add HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift HappyPianistAVPTests/Window/WindowCoordinatorTests.swift docs/testing/core-function-checklist.md`

Run: `git commit -m "test: P1-T5 - 覆盖练习启动竞态与窗口生命周期"`

---

## Phase Audit

- Audit file: `audit-p1.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环
- Audit focus:
  1. 从所有 Library 选择/恢复/试听路径向下追踪，确认不存在 score URL、parser、preparation 或 session mutation。
  2. 验证 request registration 与 Practice activation 是两个明确步骤。
  3. 验证 no-request/loading/failure/scene inactive/A→B 不泄漏旧 session。
  4. 验证开始按钮属于左侧主内容，且 Library 不再有第二个练习按钮或配置控件。
  5. 检查取消路径、generation guards、diagnostic privacy 和 MainActor IO。
- Flow:
  1. 先记录发现
  2. 再修复问题
  3. 再运行本 phase 完整 `xcodebuild test` 与 `xcodebuild build`
