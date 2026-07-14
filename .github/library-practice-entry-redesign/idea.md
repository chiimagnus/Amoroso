# 曲库进度 Ornament 与练习入口重构

- feature-slug: `library-practice-entry-redesign`

## 背景 / 触发

当前 Library 将唱片选择直接连接到完整 MusicXML preparation、`PracticeSessionViewModel` 安装和右侧配置 Ornament。右侧 Ornament 同时承担进度、片段、手别、速度、循环、连续成功目标以及进入练习等职责，导致 Library 的产品定位、数据流和运行时资源职责过重。

本 feature 将 Library 收敛为：浏览和试听当前曲目、回顾该曲目的持久化练习事实、鼓励用户再次练习。完整曲谱解析、练习 session 安装、配置恢复、失败与重试只在 Practice 窗口发生。

同时，新导入的用户曲谱保留用户提供的完整文件名。同名导入必须经过显式确认，并以可恢复事务替换原曲谱，而不是追加时间戳或 UUID 后缀创建重复条目。

## Goal

- Library 浏览、选择、恢复选择、试听和 Ornament 渲染不读取或解析 MusicXML，不创建或安装 Practice session。
- 右侧 Ornament 只展示当前选中曲目的持久化事实和由这些事实实时派生的展示数据。
- 从未练习过的曲目展示邀请练习空状态和轻量 SwiftUI 原生动画。
- Library 左侧主内容容器右下角提供唯一的“开始练习”主操作。
- 点击“开始练习”后立即打开 Practice；Practice 窗口出现后才开始 preparation，并自动恢复可用配置。
- 新导入曲谱保留 `sourceURL.lastPathComponent`，不添加时间戳或 UUID 后缀。
- 与现有用户曲谱发生文件名冲突时，显式确认替换或取消当前冲突项。
- 替换后保留 `songID`、顺序、displayName、last-selected、试听音频、历史练习事实和通用练习偏好；旧结构进度不得应用到新 revision。

## Non-goals

- 不实现用户整体练习概览、跨曲目趋势、周报、连续练习总览或独立统计入口。
- Library Ornament 不编辑片段、手别、速度、循环或连续成功目标。
- Library 不预解析、预加载或缓存全部曲谱。
- Library 不显示 preparation loading、解析失败详情或重试；这些属于 Practice。
- 不引入 Lottie 或其他动画依赖；使用 SwiftUI 原生动画并支持 Reduce Motion。
- 不允许用户导入目录中同时保留两个按目标文件系统语义发生冲突的文件名。
- bundled 曲谱不参与用户替换。
- 不新增第二套数据库，不持久化 UI presentation、进度条比例、颜色、文案或派生统计摘要。
- 不自动迁移或重命名已经存在的时间戳文件。
- 不在本 feature 修复与曲谱导入无关的既有音频导入架构债务。

## 正式支持范围

### 曲库来源

- 用户导入支持 `.musicxml`、`.xml`、`.mxl`。
- 当前 bundled discovery 继续只扫描 `.musicxml`；本 feature 不扩展 bundled 格式范围。
- 当前源码归档不包含 production `SeedScores`，因此 bundled 人工验收只有在本地 App target 实际加入曲谱资源时才能执行。

### 曲库交互

- 顶部/侧边按钮、侧边唱片点击、水平拖拽和 VoiceOver adjustable action 触发的选择。
- 试听中换曲、删除曲目、绑定试听音频、恢复 last-selected。
- 选择变化立即更新主内容和当前 Ornament 请求；last-selected 独立 debounce 保存，不再依赖 preparation generation。
- 点击“开始练习”使用当前 `selectedEntryID`，不等待 last-selected 保存或 preparation。

### Ornament 状态

Ornament 只绑定当前选中曲目，支持：

1. **未选择曲目**：提示选择曲目。
2. **从未练习**：没有可证实的练习尝试事实；显示邀请文案和原生动画，不显示伪造的零进度图表。
3. **已有当前版本进度**：展示可从持久化 facts 与 score metadata 派生的最近练习时间、稳定/学习小节、最近停留位置、最高稳定速度和近期问题。
4. **曲谱已替换、待建立新版本进度**：历史事实和通用偏好仍可用，但当前版本结构数字隐藏；说明下次练习会建立新版本数据。
5. **进度数据不可用**：降级为鼓励练习状态，不触发 score file access。

Ornament 不包含“去练习”或第二个练习按钮。

### Practice 启动

```text
Library 当前 selectedEntryID
-> register PracticeLaunchRequest(songID)
-> WindowTransitionState.beginTransition
-> open Practice window
-> Practice root 激活 request 并显示 loading
-> 解析 MusicXML / 建立 PreparedPractice
-> 安装 session
-> exact revision progress 存在：恢复完整配置和 resume
-> exact revision progress 不存在：全曲 + 可用通用偏好，无旧 resume/facts
-> ready
```

- 新曲目默认值沿用当前 `installFreshFullScoreConfiguration` 契约：全曲、双手、100%、不循环、现有默认连续成功目标。
- 同一 revision 恢复完整有效配置与恢复点。
- 替换后从同一 `songID` 的最新历史 progress 派生手别、速度、循环和连续成功目标；范围重置为全曲，恢复点清空。
- 保存数据损坏、配置无效或旧偏好不可用时，在 Practice 内使用有效默认值并记录 typed diagnostics；Library 仍可启动。

### 文件名冲突与替换

- 保存名使用经过路径分量安全化的 `sourceURL.lastPathComponent`；不得改变用户可见文件名。
- 冲突判断同时检查用户索引和目标目录，采用目标卷实际的文件名冲突语义；大小写或 Unicode 规范化差异若在目标卷不可共存，也属于冲突。
- 无冲突时创建新 `SongLibraryEntry`、新 `songID` 和新 `scoreFileVersionID`。
- 有冲突时先发布确认状态；确认前不得修改目标文件、索引或 progress。文件选择返回后立即在 import actor 内取得 security-scoped access lease，并在确认、取消、失败、窗口离开或队列结束的所有终止路径释放；pending source URL 只保存在当前 Library 会话内，不建立长期 bookmark。
- 取消只跳过当前冲突项并继续多选队列。
- 确认替换更新原 entry：
  - 保留 `songID`、顺序、`displayName`、last-selected 和 `audioFileName`。
  - 文件名保持原始完整文件名。
  - 更新 `importedAt`。
  - 生成新的 `scoreFileVersionID`，作为 Library 无需读取文件即可识别文件版本的 metadata token。
  - 保留旧 `PracticeSongIdentity` records；不删除历史 JSON。

## 默认行为与兼容策略

- `SongLibraryEntry.scoreFileVersionID` 为可选字段；旧 index 缺失时兼容解码为 `nil`。
- 已有时间戳文件继续按现有路径读取，不自动重命名。
- legacy user entry (`scoreFileVersionID == nil`) 在受支持流程中仍视为应用内部不可变文件：当最新 metadata 的 token 同样为 nil 时，可以展示该次 Practice 已确认的结构数据；metadata 尚不存在或总小节数未知时不显示完成率。replacement 总会写入非空 token，因此不会把旧 metadata 误认成替换后的当前版本。
- bundled entry 的 token 仍为 nil；当前归档没有 production bundled score。本 feature 不为未来的 bundled resource 升级建立额外版本 manifest，bundled 的结构状态只在实际 Practice preparation 后刷新。
- 新导入或替换后的 entry 使用非空 `scoreFileVersionID`。替换后该 token 与旧 score metadata 不一致，因此即使 progress metadata 写入失败，也不会把旧结构显示为当前版本。
- `PracticeSongIdentity(songID, scoreRevision)` 继续作为实际 score 内容 revision 的正式隔离边界。
- 通用偏好优先从同 `songID` 最新有效 `SongPracticeProgress.activeConfiguration` 派生；不要求用户先拥有新 metadata schema。
- 旧“选曲后自动 preparation/配置 Ornament”行为被完整替换，不保留自动 preparation 分支。

## 约束与不变量

- Library 的浏览路径（选择、恢复选择、试听、Ornament）不得解析、读取或 hash score 文件。导入事务可以复制用户明确选择的源文件，但不得解析其 MusicXML 内容。
- Library 不持有 `PreparedPractice`、`PracticeSessionViewModel`、pending round configuration 或 measure spans。
- Library -> Practice 只传稳定 `songID`；不得传预解析对象。
- MainActor 不执行曲库索引 IO、score 文件复制/替换、JSON 编解码或 MusicXML 解析。
- 新 import/replace 文件 IO 与跨文件事务由 actor service 拥有；ViewModel 只编排 UI 状态。
- 不持久化 `SongPracticeSummary` 之类的 UI 派生摘要。持久层只新增最小 `SongScorePracticeMetadata`（文件版本 token、score revision、唯一 source measure 总数、preparedAt）。稳定数、学习数、近期问题等每次从 progress facts 派生。
- `totalSourceMeasureCount` 使用当前 score 中唯一 `PracticeSourceMeasureID` 数量，不按 repeat occurrence 重复计数。
- 稳定/学习统计按最后使用的 hand mode 和唯一 source measure 计算；近期问题按 `lastAttemptAt` 排序且只使用真实 facts。
- `hasPracticeHistory` 由真实 attempt facts 派生；仅 preparation 成功不算已经练习。
- progress repository 的所有 mutation 必须由同一 actor 实例串行化并保留 document 中其他字段；删除曲目时同时删除 progress records 与 score metadata。
- index store 不允许调用方以旧 snapshot 做整份覆盖式保存。所有 last-selected、entry append/remove/audio binding/replacement mutation 必须通过 actor 内原子 read-modify-write API；replacement 还必须使用 expected songID/fileVersion 条件更新，避免与选择保存互相覆盖。
- replacement 文件与 index 的跨文件提交必须有 staged temp、backup 和持久化 transaction journal。进程崩溃后 bootstrap 必须在发布曲库 snapshot 前恢复或完成未决事务。
- 任何失败都不得留下 index 指向缺失文件，也不得先删除旧文件。
- 通用偏好仅包括 hand、tempo、loop、requiredSuccesses；passage、resume、measure/note identity 均属于 revision 结构。
- 原生动画尊重 Reduce Motion；关闭动画时信息层级和操作入口保持完整。
- 旧实现、旧测试和对应 canonical docs 必须在替代它们的同一个 task 删除/更新，不得留到最终清理 task。

## 架构决策（ADR 摘要）

### ADR-1：Practice 窗口拥有 preparation 生命周期

- **Decision**：Library 只登记 `songID` 启动意图；Practice root 激活后由共享 `PracticeLaunchViewModel` 读取文件、prepare、安装 session 和恢复配置。
- **Alternatives**：Library 预先 prepare 后把 `PreparedPractice` 传给 Practice；或继续由 `SongLibraryViewModel` 安装共享 session。
- **Why**：Library 的浏览与试听不应承担 score IO、解析和 session 生命周期；窗口激活是开始重工作的明确边界。
- **Risk**：窗口切换与异步结果可能竞态，因此必须使用 request generation、stale-result guard 和统一 teardown。

### ADR-2：只持久化最小 score metadata

- **Decision**：新增 `SongScorePracticeMetadata`，Library 展示快照每次由 metadata 与真实 progress facts 派生。
- **Alternatives**：持久化完整 `SongPracticeSummary` 或 UI presentation。
- **Why**：避免派生数据失真、schema 膨胀和双真源。
- **Risk**：每次读取需要派生计算；当前数据规模允许线性扫描，若未来曲目事实规模显著增长再引入索引。

### ADR-3：文件版本 token 与内容 revision 分工

- **Decision**：`scoreFileVersionID` 负责 Library 无文件读取的版本匹配，`scoreRevision` 继续负责 Practice progress 的内容隔离。
- **Alternatives**：Library hash 文件；复用文件名或 `importedAt` 判断版本。
- **Why**：Library 不读取 score 文件，文件名和时间都不是可靠内容身份。
- **Risk**：metadata 写入失败会暂时缺少当前结构数字；必须降级为待建立或数据不可用，不能回退显示旧结构。

### ADR-4：导入与替换使用单 actor 事务和持久化 journal

- **Decision**：同一 actor 串行化 security-scoped lease、stage、backup、文件替换、index 条件提交和 recovery。
- **Alternatives**：ViewModel 逐步调用 `SongFileStore` 与 `SongLibraryIndexStore`；先删旧文件再复制。
- **Why**：跨文件提交必须可恢复，且不能让 index 指向缺失文件。
- **Risk**：journal cleanup 可能失败；index 已提交后不得回滚新版本，下一次 bootstrap 负责收尾。

## 降级矩阵

| 失败点 | 保留能力 | 关闭/隐藏能力 | 用户状态 |
|---|---|---|---|
| Library progress snapshot 读取失败 | 浏览、选择、试听、开始练习 | 当前进度数字 | Ornament 显示数据不可用 |
| Practice score 读取/解析失败 | 返回 Library、重试、诊断详情 | session 安装与练习 | Practice 显示 typed failure |
| exact revision progress 缺失或损坏 | 练习与默认配置 | 旧 resume、旧结构 facts | 使用全曲与有效默认/通用偏好 |
| score metadata 写入失败 | 当前 Practice session | Library 当前结构数字 | 记录诊断，Library 不显示旧结构 |
| security-scoped access 失败 | 已有曲库与后续队列项 | 当前导入项 | 当前项失败并释放 lease |
| replacement 提交前失败 | 旧文件、旧 index、旧 progress | 新版本 | 恢复旧状态并提示失败 |
| replacement 提交后 cleanup 失败 | 新文件、新 token、新 index | 暂无 | 保留 journal，下次 bootstrap 清理 |
| transaction recovery 失败 | 无 | 发布可能损坏的曲库 snapshot | Library load failure，可重试 |

## 验收边界

- 不规定 preparation 的绝对耗时，但必须在 Practice 窗口激活后开始，且不得阻塞 MainActor。
- Library 进度统计只覆盖持久化真实 attempt facts；无 attempt 时不得显示伪造的 0/总数。
- 文件冲突结果以目标卷实际可共存语义为准；测试至少覆盖 exact、大小写和 Unicode 规范化差异。
- 自动化测试使用 fake provider、临时目录、确定性 clock 和故障注入；不得依赖真实用户文件、真实时间或外部网络。
- UI 布局、VoiceOver、Reduce Motion、真实 security-scoped URL 与进程中断恢复需要 Simulator/实机人工证据；未执行时标记 Not Run。

## 数据模型与数据流

### 文件版本 token

```text
SongLibraryEntry
- id: song identity，replacement 保留
- musicXMLFileName: 用户完整文件名
- importedAt: 导入/替换时间，仅用于展示与审计
- scoreFileVersionID: UUID?，文件版本 metadata；replacement 必须更新
```

`scoreFileVersionID` 不是文件名后缀，也不替代 `scoreRevision`。前者允许 Library 判断 index 所指文件是否与已知 metadata 同版本；后者由 Practice 读取内容后计算并隔离实际 progress。

### 最小持久化 metadata

```text
SongScorePracticeMetadata
- songID
- scoreFileVersionID: UUID?
- scoreRevision
- totalSourceMeasureCount
- preparedAt
```

`PracticeProgressDocument` 保存 `songs` 和 `scoreMetadata`。Repository 对 Library 暴露只读 `SongPracticeLibrarySnapshot`，在 actor 内由 metadata + progress facts 派生，不把 snapshot 本身写入 JSON。

### 选择与 last-selected

```text
selection event
-> selectedEntryID 立即更新
-> 停止上一首试听（如适用）
-> ViewModel 更新内存 index.lastSelectedEntryID
-> 独立 debounce task 保存最新 index
-> 异步请求当前 songID 的 Library snapshot（songID + generation gate）
```

View 消失不应因为 preparation cancellation 丢失最新选择；删除/替换 index 时必须让旧 selection save generation 失效。

### Practice launch owner

`PracticeLaunchViewModel`（或等价单一 owner）由 `LiveAppGraph` 创建并同时注入 Library/Practice。正式 request 只含 `songID`；内部 request ID 用于 generation，不属于跨层业务数据。

- Library `request(songID:)` 只登记意图。
- Practice root 激活后才解析。
- 新 request、retry、返回 Library、scene 非 active 与 window disappear 均有明确取消语义。
- ready/failure 只能由当前 request generation 发布。
- 新请求激活前必须清除已 flush 的旧 prepared/session presentation，不能在 loading/no-request 时显示旧曲目。

### import/replace actor transaction

```text
inspect source name (no target mutation)
-> no conflict: user import commit
-> conflict: await confirmation
-> acquire and retain session-scoped source access lease
-> await confirmation when conflict exists
-> copy to same-volume temp
-> write transaction journal + backup metadata
-> replace/create target
-> atomically save index with new scoreFileVersionID
-> delete backup/journal
-> return updated index
```

Bootstrap 在读取并发布 index 前调用 transaction recovery。Recovery 以 index 中实际 token、target/temp/backup 是否存在为事实，journal phase 只作提示：replacement 未提交 index 时恢复 backup，new import 未提交 index 时删除新 target；index 已提交新 token 时保留新 target并完成 cleanup。提交 index 之后的 cleanup 失败不得回滚已提交的新版本，只保留 journal 供下次 bootstrap 收尾。Progress 不参与文件/index transaction；替换状态由 version token mismatch 自然派生。

## 错误与降级

- Library snapshot 读取失败：保留浏览、试听和“开始练习”，Ornament 显示数据不可用。
- Practice preparation 失败：在 Practice 显示 typed failure、技术详情、重试和返回 Library。
- no request/stale request：Practice 不显示旧 session，提供返回 Library。
- 同名取消：目标文件、index、progress 完全不变，继续队列。
- security-scoped access、stage、replace 或 index commit 失败：提交前恢复旧文件/旧 index，记录 typed diagnostic；若 index 已提交而 cleanup 失败，则保留新版本与 journal，下一次 bootstrap 完成清理。
- crash recovery 失败：不发布可能损坏的曲库 snapshot；显示可重试的 Library load failure，并记录 transaction diagnostic。
- replacement 已提交但 score metadata 仍旧：Ornament 通过 version token mismatch 显示待重建；不需要修改/删除旧 progress。
- progress 文件损坏：沿用 quarantine；Practice 使用默认配置，Library 显示数据不可用。

## 验收标准

1. Library 连续切歌、恢复 last-selected、试听和 Ornament 加载均不调用 parser、`PracticePreparationService.prepare` 或 session 安装。
2. 选择后主唱片、曲名、试听和 Ornament 请求立即更新，不等待 preparation。
3. latest-wins last-selected 保存与 preparation 完全解耦；它只原子更新 last-selected 字段，不会用旧 snapshot 覆盖并发的 import/delete/audio/replacement；快速选择后立即进入 Practice 也不会丢失最终选择。
4. “开始练习”只位于左侧主 Library 内容容器右下角，窗口缩放后不遮挡播放条、不进入 Ornament、不漂到 scene 右下角。
5. Ornament 只展示当前曲目；没有全局统计、配置控件或第二个练习按钮。
6. 从未练习状态有 Reduce Motion 等价表现，不伪造 0/总数。
7. 点击按钮先打开 Practice；Practice root 激活后才开始 score IO/preparation。
8. no request/loading/failure/ready/return/retry/A->B request 的生命周期不会显示或安装旧 session。
9. 同 revision 恢复完整配置和 resume；新曲目使用全曲、双手、100%、不循环和默认 requiredSuccesses。
10. replacement 后使用旧通用偏好，但 passage 为全曲、resume/facts 不跨 revision。
11. `PracticeProgressDocument` 旧 JSON 兼容解码；不持久化 presentation summary。
12. current-version 总小节数来自唯一 source measures；稳定/学习/问题来自真实 facts，repeat occurrence 不重复计数。
13. 删除曲目同时删除所有 revision progress 和 score metadata。
14. 新导入文件名与安全化后的 `lastPathComponent` 完全一致，不含自动时间戳/UUID 后缀。
15. exact/case/Unicode 冲突按目标文件系统语义触发一个顺序 confirmation。
16. 取消冲突项无副作用并继续多文件队列。
17. 确认替换保留 `songID`、顺序、displayName、last-selected、audio、旧 progress，并更新 `scoreFileVersionID`。
18. source access lease 在 confirm/cancel/failure/disappear 全部释放；stage/replace/index-commit/cleanup 失败和进程中断恢复均不让 index 指向缺失文件；new import 未提交时删除 orphan target，replacement 未提交时旧文件可恢复，已提交后的 cleanup failure 不回滚新版本。
19. 旧带时间戳文件继续可用；没有自动迁移。
20. canonical docs 在对应 task 同步更新，不再描述选曲自动 preparation、配置 Ornament 或时间戳新导入。
21. 实际 macOS/visionOS 环境中完整 `xcodebuild test` 和 `xcodebuild build` 通过；未运行项必须标记 Not Run。

## 测试策略

- Selection：latest-wins debounce、view disappear、立即开始、删除/替换 generation、保存失败。
- Launch：request registration 不 prepare；Practice activation 才 prepare；loading/failure/retry/return/scenePhase/A-B stale result；旧 prepared state 清理。
- Configuration：exact revision full restore；new score fresh defaults；replacement fallback preferences；无旧 resume/facts。
- Repository：旧 JSON兼容；metadata upsert 保留 progress；progress upsert 保留 metadata；derived snapshot unique-source/hand/issue rules；remove 清理两类数据；corruption quarantine。
- Ornament presentation：未选择、从未练习、current、needs-rebuild、unavailable；generation gate；Reduce Motion。
- Import：原名、`.musicxml/.xml/.mxl`、多选顺序、exact/case/Unicode conflict、取消、确认、source access failure。
- Transaction：stage/backup/replace/index commit/journal cleanup 每个失败点；模拟进程中断后的 bootstrap recovery。
- Regression：试听切歌、删除、音频绑定、legacy timestamp files、MXL parser route、diagnostics privacy。
- UI/人工：真实 Library 布局中的按钮位置、Ornament 高度/宽度、VoiceOver、Reduce Motion、Practice loading/failure 和 confirmation 文案。

## Recommended approach

- P1 原子迁移完整 launch 生命周期并同步删除旧 Library preparation/configuration 代码、测试与文档。
- P2 只增加最小 score metadata；Library snapshot 由 repository 从 metadata + facts 派生，再构建进度 Ornament。
- P3 用单一 actor transaction service 接管新导入与 replacement，使用 `scoreFileVersionID` 和 journal 提供无 score read 的版本识别与 crash recovery。
- 不保留兼容双轨，不增加 Lottie，不持久化 UI summary。

## Phase split

- **P1：Practice 启动所有权与旧路径原子替换**  
  一次完成 request owner、窗口时序、取消/重试/no-request、旧 session 清理、独立 selection persistence、主按钮、旧 Library preparation 代码/测试/文档删除。
- **P2：最小 score metadata 与当前曲目 Ornament**  
  先扩展 progress document/repository 并派生 Library snapshot，再接入当前曲目 Ornament 和原生空状态动画；每个 task 同步更新相关 docs。
- **P3：原名导入与可恢复同名替换**  
  删除时间戳/UUID import path，接入 actor transaction、version token、顺序确认、journal recovery、跨 revision 偏好恢复、failure diagnostics 与 docs。

## Task granularity notes

- P1 的迁移、生命周期与旧代码删除不能拆成先不安全后补取消的两个 task。
- P2 metadata task 不持久化派生 summary，并在同 task 迁移所有 repository fakes 和 delete semantics。
- P3 新 actor/service 创建时必须在同 task 接入 bootstrap、ViewModel 和 composition root，同时删除旧 import API。
- canonical docs 与已知测试清理在对应生产 task 完成；不存在最终“清理旧代码”task。

## Audit focus by phase

- **P1**：Library 是否仍间接 prepare；Practice 是否窗口出现后才 prepare；no-request/scenePhase/A-B 是否泄漏旧 session；按钮是否属于左主内容。
- **P2**：是否误持久化 UI summary；数字是否从真实 facts 派生；version token/legacy 规则是否正确；delete 是否清理 metadata。
- **P3**：是否保留原名；冲突语义是否确定；MainActor 是否仍做 score copy/replace；journal 能否恢复中断；ID/audio/history/preferences 是否保留。
