# 曲库进度 Ornament 与练习入口重构

- feature-slug: `library-practice-entry-redesign`

## 仓库事实基线

本需求以 2026-07-14 上传的完整仓库为基线。审查确认：

- Xcode 工程只有 `HappyPianistAVP` 与 `HappyPianistAVPTests` 两个 target；没有 macOS App target。工程使用 `PBXFileSystemSynchronizedRootGroup`，新增源码/测试文件由同步目录接入，不应手工编辑 `project.pbxproj`。
- `SongLibraryViewModel` 当前同时负责曲库 bootstrap、selection debounce、MusicXML preparation、`ARGuideViewModel` session 安装、配置面板、导入、删除、试听与进度读取。
- `SongLibraryView` 另持有一份本地 `@State selectedEntryID`，而 ViewModel 又持有 `selectedPracticeEntryID`，当前选择存在双真源。
- `LiveSongLibraryBootstrapLoader` 当前私自创建另一份 `SongLibraryIndexStore` 与 `BundledSongLibraryProvider`，没有使用 `LiveAppGraph` 中共享实例。
- `SongLibraryIndexStoreProtocol.save(_:)` 允许调用方用旧 snapshot 整份覆盖 index；selection、import、delete、audio binding 可互相丢字段。
- `LibraryPracticeOrnamentView` 当前直接编辑 `PracticeRoundConfigurationController`，并包含第二个“去练习！”入口。
- `ARGuideViewModel.latestPreparedPractice` 会在重建 `PracticeSessionViewModel` 时重新安装；只 reset 当前 session 不足以清除旧曲谱。
- `PracticeProgressDocument` 当前只保存 `songs`，没有可让 Library 在不读取 score 文件时判断结构版本的 metadata。
- `SongLibraryViewModel` 为 `@MainActor`，但 `SongFileStore`/`AudioImportService` 当前是同步 struct；MusicXML 导入、曲谱/音频 URL 解析、文件复制与删除会在 MainActor 调用链执行。P1 必须先把这些现有 IO 迁到 actor async API并删除同步接口，P3 再用事务 actor 替换 score import。
- `SongFileStore.importMusicXML` 当前自行持有 security scope、创建目录并复制文件，并给文件名添加时间戳/UUID。
- bundled 曲谱 ID 已按文件名确定性生成；源码归档没有 production `SeedScores` 资源。
- `README.md`、`docs/architecture.md`、`docs/data-flow.md`、`docs/storage.md`、`docs/modules/*` 与人工检查表仍描述旧的自动 preparation 与配置 Ornament。

本 feature 只修改与以上调用链直接相关的 visionOS 代码、测试和 canonical docs。完整归档（排除 `.git`/`.codegraph`）共 549 个文件、4,756,241 bytes，已逐文件读取并校验摘要；其中 440 个 Swift、41 个 Python、14 个 JSON、6 个 MIDI、6 个 MusicXML，以及 plist/XML/ZIP/JPEG/Xcode 资源均完成结构校验。Python 工作区、RealityKit 内容包、MIDI/MusicXML 测试夹具与 `docs/assets/scene1.jpg` 不属于本次改动范围。当前审查环境没有 `xcodebuild`，所以计划中的 visionOS build/test gate 必须在 Apple 开发环境执行，不能把本次静态审查写成已通过。

## 背景 / 触发

Library 当前把唱片选择直接连接到完整 MusicXML preparation、练习 session 安装和右侧配置 Ornament。用户浏览或快速切歌时会触发 score 文件读取、hash、解析、结构展开和 session mutation；右侧 Ornament 还承担片段、手别、速度、循环、连续成功目标与进入练习，导致 Library 产品职责和运行时资源职责过重。

本 feature 将 Library 收敛为：浏览、选择、试听、查看当前曲目的持久化练习事实，以及通过唯一主操作进入 Practice。完整曲谱解析、session 安装、配置恢复、失败和重试只在 Practice 窗口激活后发生。

同时，新导入的用户曲谱保留用户提供的安全完整文件名。同名导入必须显式确认，并通过可恢复事务替换或修复现有目标，而不是添加时间戳/UUID 后缀制造重复条目。

## 核心需求

### 1. Library 必须轻量

1. Library 浏览、恢复选择、切歌、试听、进度 Ornament 渲染不得读取、hash 或解析 MusicXML。
2. Library 不得持有 `PreparedPractice`、measure spans、`PracticeSessionViewModel`、pending round configuration 或 preparation failure 生命周期。
3. Library 中唯一的权威选择是 `SongLibraryViewModel.selectedEntryID`；View 不再维护第二份选择状态。
4. 所有唱片点击、上一首/下一首、水平拖拽、VoiceOver adjustable action、恢复 last-selected 都进入同一 selection 方法。
5. last-selected 保存与 Practice preparation 完全解耦；选择立即更新 UI，debounce 后通过 index actor 原子保存。
6. 点击“开始练习”使用当前内存 `selectedEntryID`，不等待 selection persistence 或进度 snapshot。
7. Library `@MainActor` 只编排状态；Documents 路径查询、security-scope、copy、delete 与用户文件 URL resolve 必须通过 actor async service，await 返回后重新验证相关 entry/token，禁止用陈旧状态继续播放或提交。

### 2. 唯一练习入口与 Practice 所有权

1. “开始练习”位于 Library 主内容容器右下角，是内容级主操作，不属于窗口 chrome；不得放在 Ornament、播放条内部或 scene 根的任意浮层。
2. Library -> Practice 的正式请求只携带稳定 `songID`；内部 request/generation 不作为跨层业务数据。
3. 点击顺序固定为：登记 request -> `WindowTransitionState.beginTransition` -> 打开 Practice window。
4. `request(songID:)` 不执行 index IO、score URL 解析、文件读取、preparation 或 session mutation。
5. Practice window 出现且 scene active 后才激活当前 request，并显示 loading。
6. Practice 拥有 no-request、requested/loading、failure、ready、retry、suspend、return/clear 全生命周期。
7. 同一 revision 有有效 progress 时恢复完整配置与合法 resume；没有 exact progress 时使用当前曲谱全曲范围和默认值，P3 再加入通用偏好恢复。
8. 保存配置损坏、passage 不属于当前曲谱、resume 不合法时不得进入无效 active range；应回退当前曲谱的 fresh full-score 配置并记录 typed diagnostic。

### 3. 旧 prepared/session 不得泄漏

1. request registration 先隐藏旧 session，但不触碰 ARGuide。
2. Practice activation 在重工作前 flush 旧 progress，并清除 song-specific presentation。
3. 清除动作必须同时失效 `preparedPracticeApplicationID`、清空 `latestPreparedPractice`、调用 `PracticeSetupState.clearSongAndSteps()`，并清除 session 中的 song/progress/steps/configuration。
4. 清除 song-specific state 时保留钢琴模式、校准、keyboard geometry、输入/播放 service wiring 与其他非曲谱状态；不得直接复用会清空校准的全量 `resetSession()`。
5. 新 request、retry、显式返回、意外 window disappear 均使旧 generation 失效。
6. scene 变为非 active 时取消正在进行的 preparation 并 suspend/flush；保留 request 为 requested，scene 恢复 active 后可重新激活。它不是显式返回，不得丢失用户启动意图。
7. 只有当前 generation 能发布 failure/ready 或安装 session；stale/cancel 不记录为用户可见失败。

### 4. 只读练习进度 Ornament

Ornament 只绑定当前 `selectedEntryID`，包含以下状态：

1. **未选择**：提示选择曲目。
2. **加载事实**：只表示 JSON repository 读取，不表示 score preparation。
3. **从未练习**：没有任何真实 attempt fact；显示邀请文案和轻量原生动画，不显示伪造的 0/总数。
4. **当前版本进度**：entry version token 与 score metadata exact 匹配，显示当前 revision 的事实派生数据；若只有旧 revision 历史而当前 revision 尚无 attempt，仍属于当前版本已建立，只隐藏当前计数/resume并提示“当前版本尚未练习”，不得误报待重建。
5. **已替换、待建立新版本数据**：存在历史 attempt，但当前 token 没有 matching metadata；隐藏旧结构数字，说明下次练习会重建。
6. **数据不可用**：repository corrupted/读取失败；保留浏览、试听和开始练习。

Ornament 不编辑 passage、hand、tempo、loop、required successes，不包含“开始练习”“继续练习”或第二个练习按钮。

### 5. Ornament 的事实规则

1. `hasPracticeHistory` 只由真实 attempt 证据派生：成功/失败次数非零或 `lastAttemptAt != nil`；仅 preparation、配置保存或 `updatedAt` 变化不算练习。
2. 最近练习时间取真实 facts 中最大的 `lastAttemptAt`，不使用 progress `updatedAt`。
3. 当前 hand mode 取当前 revision 最近真实 attempt 的 hand；同时间按稳定 source-measure identity tie-break。没有真实 attempt 时为 nil。
4. stable/learning 只统计当前 revision、当前 hand、唯一 `PracticeSourceMeasureID`；重复 occurrence 不重复计数。
5. 若损坏数据中同 source measure/hand 出现多条 fact，先按 `lastAttemptAt` 取最新，再以稳定 identity/state tie-break，避免重复展示。
6. 最高稳定速度只来自当前 hand 的 stable facts。
7. 近期问题只来自带 `lastAttemptAt` 的真实 facts，按时间倒序并按 source measure 去重。
8. resume 只在 exact current revision 且 resume source measure 也存在真实 current fact 时展示；Library 不尝试读取 score 验证 occurrence。
9. total measure count 只来自 matching metadata，按唯一 `PracticeSourceMeasureID` 数量计算，不按 repeat occurrence 数量。

### 6. 最小持久化 metadata 与版本 token

1. `SongLibraryEntry` 增加可选 `scoreFileVersionID: UUID?`。
2. legacy 用户 entry 缺失字段时解码为 nil，现有时间戳文件不迁移、不改名。
3. 新导入和 replacement 必须写入 non-nil token。
4. bundled entry 不继续永久使用 nil：provider 使用 bundle identifier、short version、build version 与文件名生成保守的确定性 token。App 构建变化会使旧 bundled metadata 失配，宁可暂时隐藏结构数字，也不展示可能过期的数据。
5. `PracticeSongIdentity(songID, scoreRevision)` 继续作为实际内容与 progress 的隔离边界；version token 只供 Library 无文件读取地匹配当前文件版本。
6. `PracticeProgressDocument` 增加 `scoreMetadata`，旧 JSON 缺 key 时解码为空数组。
7. metadata 只保存 `songID`、`scoreFileVersionID`、`scoreRevision`、唯一 source measure 总数和 `preparedAt`；不持久化 UI summary、比例、颜色、文案、stable/learning count 或 recent issue。
8. Practice preparation/session 安装成功后 upsert metadata；写入失败记录 typed diagnostic，但不得把成功 session 变成 failure。
9. 对已经成功、且携带 immutable `songID + token + revision` 的 preparation，request 随后变 stale 也允许 metadata 幂等落盘；token mismatch 会隔离 replacement，不把该写入视为 UI publication。

### 7. Index 原子 mutation 与共享实例

1. `SongLibraryIndexStoreProtocol` 不再公开整份 `save(_:)` 给业务调用方。
2. last-selected、append、remove、audio binding 与 replacement 均由 actor 内 load-latest -> mutate one concern -> atomic write 完成，并返回最新结果。
3. selection、import、delete、audio binding 迁移到原子 API 的同一个 task 中删除旧 whole-snapshot save 调用。
4. replacement 使用 expected `songID + scoreFileVersionID + musicXMLFileName` 条件更新，同时保留顺序、displayName、audio 和 last-selected。
5. `LiveSongLibraryBootstrapLoader` 必须注入 `LiveAppGraph` 创建的同一个 index store 与 bundled provider；不得再私自构造第二实例访问同一 JSON。

### 8. 原名导入、冲突与替换

1. 支持 `.musicxml`、`.xml`、`.mxl`；服务层必须再次校验扩展名，不能只信任 `fileImporter`。
2. 保存名使用 `sourceURL.lastPathComponent` 的安全路径分量，保留用户可见字符和扩展名；拒绝空名、目录分量和不支持扩展，不追加时间戳、UUID 或 songID。
3. 冲突判断同时检查当前用户 index 与 `scores` 目录，并用目标卷实际解析结果/resource identifier 判断 case/Unicode 是否可共存；禁止用固定 `.lowercased()` 猜测文件系统语义。
4. bundled-only 同名不构成用户目录 replacement 冲突，因为 bundle 与 Documents 是不同存储域；bundled entry 永远不可被替换。
5. 冲突分类：
   - exactly one user entry + target exists：确认后替换该 entry；
   - exactly one user entry + target missing：确认后修复该 entry；
   - filesystem-only orphan：明确提示“未索引文件”，确认后覆盖并创建新 entry；
   - 多个 user entries 指向同一实际目标：typed blocking failure，不猜测 songID；
   - 无冲突：创建新 entry。
6. 多选的target/index mutation按用户返回顺序串行处理；取消只跳过当前冲突项并继续下一项。为避免等待确认时保存外部URL，transaction actor先在一次batch staging调用中按原顺序逐项复制所有source到独立operation目录并释放权限；后续队列只包含operation ID。
7. fileImporter 返回后，transaction actor对每项尝试取得session-scoped security access，把受支持扩展的普通非符号链接文件复制到`Documents/SongLibrary/transactions/<operationID>/stage/<safeOriginalName>`，随后立即释放access；`startAccessingSecurityScopedResource()` 返回false时仍允许对本就可访问的URL尝试读取，以实际权限错误判定access failure。不得跨用户确认长期持有外部URL/lease，也不建立bookmark。单项stage失败记录item failure并继续后续项；根目录/journal不可用才中止batch。
8. conflict confirmation期间只保留App内同卷stage、journal与UI-safe operation ID。journal不记录原始source URL；ViewModel只持ordered operation IDs与安全展示状态，不保存source URL、lease、stage绝对路径或score内容。
9. access failure、validation failure、copy failure、batch cancellation每条stage终止路径必须start/stop平衡；confirm/cancel/Library disappear/queue cancel只处理App内operation，不再依赖外部security scope。

### 9. 跨文件事务与恢复

1. transaction actor 是 score import/replace、短生命周期 security access、stage、backup、journal、index mutation 与 recovery 的唯一 owner。
2. operation directory/stage/backup 必须位于 `Documents/SongLibrary/transactions`，与 `scores` 同一 volume；外部 source URL 在 stage 完成后立即释放且不再参与后续流程。所有将要删除/覆盖的target必须先用journal中的文件指纹确认身份；无法确认时blocking，禁止依据phase或文件名猜测。
3. journal 每个 operation 单独保存，只记录 App 相对路径、operation ID、kind、songID/expected token/new token、phase、时间，以及仅用于恢复判定的 staged/backup 文件指纹（byte count + SHA-256）；不记录原始 source URL 或 score 内容，指纹不得写入 diagnostics。
4. batch staging中每项顺序为：创建operation directory与preparing journal -> 开启security access -> 校验并复制到stage -> 关闭security access -> fsync/atomic更新staged journal。轮到该operation提交时才依据最新index与目标卷事实分类；stage/journal不是用户曲库target/index mutation。
5. conflict confirm 前 `scores` target、index 与 progress 零 mutation；cancel只删除该 operation directory并继续队列。
6. new import：staged journal -> stage move exact source-name target -> atomic index append -> committed journal -> cleanup。
7. indexed replacement：staged journal -> target move backup（若存在）-> stage move exact source-name target -> conditional index replacement -> committed journal -> cleanup。
8. file-only orphan replacement 同样先 backup，再创建新 entry。
9. index commit 前失败必须恢复旧 target/backup；index 已提交新 token 后 cleanup 失败不得回滚新版本，只保留 journal 供下次 bootstrap 清理。
10. bootstrap 必须先 recovery，再发布 index snapshot。事实优先于 journal phase；无法无损判断时返回 blocking load failure。
11. recovery 重复运行必须幂等，任何结果都不得发布 index 指向缺失文件的 snapshot。
12. progress 不参与文件/index transaction；旧 revision records 与 metadata 保留，由 token/revision mismatch 隔离。

### 10. replacement 后的配置恢复

1. exact revision progress 存在且结构有效：恢复完整 active configuration 与合法 resume。
2. exact progress 缺失时，从同 `songID` 最新具有有效 active configuration 的历史 progress 提取通用偏好：hand、tempo、loop、requiredSuccesses。
3. latest 规则按 `updatedAt` 降序，时间相同按 `scoreRevision` 稳定排序。
4. 通用偏好应用到当前 prepared score 的 full passage；current step 从首步开始。
5. passage、resume、measure facts、source/occurrence IDs 不得跨 revision。
6. repository corrupted、历史配置无效或没有候选时使用 fresh full-score 默认值并记录 typed diagnostic；Library 仍可启动。

## 默认值与兼容策略

- 新曲目默认：全曲、双手、100%、不循环、现有 defaults store 的连续成功目标。
- legacy user entry token 为 nil；只有 matching metadata token 也为 nil 时才能认为文件版本匹配。
- legacy 文件按现有文件名继续读取、试听、删除和练习；不自动迁移。
- existing progress JSON 不做破坏式 migration；新增数组使用兼容解码。
- replacement 保留旧 progress/metadata 作为历史，但当前 token/revision 不匹配时不显示、不恢复结构事实。
- 当前 repository 规模使用 actor 内整份 JSON decode + 线性扫描；不增加缓存或第二数据库。若数据量实测成为瓶颈，再独立设计索引。
- Library snapshot 可做短 debounce 与 generation gate，避免快速拖拽排队读取；开始练习不等待 snapshot。

## 非目标

- 不实现跨曲目总览、趋势、周报、连续练习统计或独立统计窗口。
- 不扩展 bundled discovery 到 `.xml/.mxl`。
- 不迁移或重命名已有时间戳 score/audio 文件。
- 不重构与本 feature 无关的 audio import 命名策略。
- 不修改 MusicXML parser、repeat expander、练习判定、录制、AI、MIDI、ARKit 或 RealityKit 管线。
- 不引入 SwiftData、SQLite、Lottie 或第三方 transaction 库。
- 不为未来多设备同步、长期 bookmark 或云端曲库预留抽象。

## 架构决策（ADR）

### ADR-1：Practice window 拥有 preparation 生命周期

- **Decision**：Library 只登记 `songID`；Practice root 激活后由唯一 `PracticeLaunchViewModel` 解析 entry、prepare、安装 session、恢复配置和处理 failure/retry。
- **Alternatives**：Library 预 prepare 后传 `PreparedPractice`；继续让 `SongLibraryViewModel` 直接安装共享 session。
- **Why**：浏览路径不应承担 score IO 和 session 生命周期。
- **Risk**：窗口/scene 与异步结果竞态；以 request generation、显式 suspend/clear 和 ready gate 控制。

### ADR-2：ViewModel 是选择真源

- **Decision**：`SongLibraryViewModel.selectedEntryID` 是唯一选择状态，View 只渲染并发出 intent。
- **Alternatives**：保留 View `@State` 并与 ViewModel 双向同步。
- **Why**：开始按钮、snapshot、delete fallback 与 persistence 必须引用同一个即时值。
- **Risk**：ViewModel 生命周期跨窗口；离开时需显式 flush 当前选择。

### ADR-3：只持久化最小 score metadata

- **Decision**：Library snapshot 每次从 metadata +真实 progress facts 派生。
- **Alternatives**：持久化完整 `SongPracticeSummary` 或 UI presentation。
- **Why**：避免双真源和派生摘要失真。
- **Risk**：读取为线性扫描；当前规模接受，保留性能测试与升级阈值。

### ADR-4：version token 与 content revision 分工

- **Decision**：entry token 判断 Library 当前文件版本；score revision 隔离实际练习事实。
- **Alternatives**：Library hash 文件；用文件名/日期猜版本。
- **Why**：Library 禁止读取 score，文件名/日期不是内容身份。
- **Risk**：metadata write failure 暂时隐藏当前结构数据，而不是回退旧数据。

### ADR-5：单 actor + journal 管理 import/replace

- **Decision**：一个 actor 在 `begin` 内短暂取得 security access并先复制到 App 内同卷 stage，随后只用 stage、journal、backup、index 条件 mutation 与 recovery完成事务。
- **Alternatives**：跨确认长期持有外部 security-scoped URL；ViewModel 逐步协调多个 struct/actor；先删旧文件再 copy。
- **Why**：用户确认时间不可控，长期 lease更脆且难证明恰好释放；同卷 stage让后续提交可恢复且不发布 dangling index。
- **Risk**：stage会暂时占用一份额外空间；begin copy失败必须完整清理 operation，使用故障注入和每阶段 journal约束。

## 硬性规则

- Library 浏览链路不得出现 score URL、Data(contentsOf score)、parser、preparation 或 session mutation。
- MainActor 不执行 index/progress JSON IO、security-scope 文件复制/替换、journal IO 或 MusicXML parsing。
- 不新增 singleton、旧式 Observation/Combine 状态对象、GCD、`Task.detached`、强制解包或第二持久化体系。
- 修改过的业务代码统一使用 `DiagnosticsReporting`；不得新增直接 `os.Logger` + 文件双写。
- 诊断不得包含绝对路径、原始 MusicXML、逐小节 facts 或 source URL。
- 新文件在创建 task 中接入真实 consumer/composition root。
- 新实现替换旧实现时，同一 task 删除旧 API、旧 state、旧 tests、旧 docs 和双轨分支。
- 每个 task 对应原子中文 Conventional Commit；计划文件本身不 git add/commit。

## 降级矩阵

| 失败点 | 保留能力 | 隐藏/关闭 | 用户状态 |
|---|---|---|---|
| Library history 读取失败 | 浏览、选择、试听、开始练习 | 当前进度数字 | Ornament 数据不可用 |
| Practice entry/score resolve 失败 | 返回、重试、诊断 | session 安装 | Practice typed failure |
| preparation/structure 失败 | 返回、重试 | ready/session | Practice typed failure |
| exact progress corrupted/invalid | 练习 | 旧 passage/resume/facts | fresh defaults + diagnostic |
| metadata 写入失败 | 当前 ready session | Library 当前结构数字 | warning，不回滚 session |
| security access/stage copy 失败 | 已有曲库、后续队列 | 当前项 | 立即平衡access、清理operation并继续队列 |
| ambiguous index conflict | 已有数据、后续队列 | 当前项 confirm | blocking item failure |
| transaction commit 前失败 | 旧 target/index/progress | 新版本 | rollback 后提示失败 |
| commit 后 cleanup 失败 | 新 target/token/index | 无 | warning + journal 留待 recovery |
| bootstrap recovery blocking | 无 | 曲库 snapshot | load failure，可重试 |

## 验收标准

1. CodeGraph/静态调用检查证明 Library selection/restore/playback/Ornament 不可达 `PracticePreparationService.prepare`、score read/hash 或 `ARGuideViewModel.applyPreparedPractice`。
2. 选择快速 A->B->A 时 UI 立即跟随；只保存最终选择；开始按钮可在保存未完成/失败时按当前内存 A 启动。
3. Practice request registration 的 preparation call count 为 0；scene active activation 后才为 1。
4. no-request/loading/failure/suspended 状态不渲染旧 `PracticeStepView`；session rebuild 不会复活旧 `latestPreparedPractice`。
5. exact revision 有效配置/resume 恢复；无 exact 或损坏配置使用 full passage，且旧 facts/resume 不跨 revision。
6. Ornament 的 never/current/needs-rebuild/unavailable 状态及事实规则有确定性纯逻辑测试；快速切歌不显示上一首 snapshot。
7. Ornament 只读、无第二练习按钮；原生动画支持 Reduce Motion、VoiceOver 与 Differentiate Without Color。
8. index actor 并发 mutation tests 证明 selection、append、remove、audio、replacement 不互相丢字段；production 无整份 `save` 调用。
9. 新导入文件名与安全化 source last path component 完全相同，无时间戳/UUID suffix。
10. exact/case/Unicode 冲突结果按临时目标卷实际行为测试；bundled-only 同名允许，ambiguous user index 被阻止。
11. conflict confirm前`scores` target/index/progress零mutation；cancel继续operation-ID队列；batch staging每项的security access在返回前start/stop平衡，确认期间无外部lease/URL。
12. stage/backup/target/index/cleanup 每一故障点与 crash fact matrix 均可 recovery，且 bootstrap 不发布 dangling index。
13. replacement 保留 songID、顺序、displayName、last-selected、audio、旧 progress；更新 importedAt、文件名与 non-nil token。
14. README 与 canonical docs 在相应实现 task 同步更新，不把文档修正拖到最后 gate。
15. 完整 `xcodebuild test` 与 visionOS Simulator build 是执行阶段必需 gate；本计划审查环境无 `xcodebuild`，不得把当前静态检查表述为 Apple target 已通过。
