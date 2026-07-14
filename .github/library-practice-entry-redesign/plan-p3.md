# Plan P3 - 原名导入事务、替换恢复与跨 revision 偏好

**Goal:** 用单一 actor 把原名导入、冲突确认、替换、崩溃恢复和 index 条件 mutation 收口为可恢复事务，并在 replacement 后只跨 revision 恢复通用练习偏好。

**Non-goals:** 本 phase 不迁移旧时间戳文件、不重命名现有用户文件、不删除旧 progress/metadata、不把 score 内容写入 journal、不建立 security-scoped bookmark、不增加数据库或后台常驻扫描器。

**Repository evidence:** 当前 `SongFileStore.importMusicXML` 在 `@MainActor SongLibraryViewModel.importMusicXML` 调用链内执行 security access、目录创建与同步 copy，并通过 ISO8601 时间戳/UUID 规避同名。`LibraryContentView.fileImporter` 支持多选但没有逐项冲突状态。index 目前没有 replacement CAS；bootstrap 也没有 transaction recovery。现有 progress identity 已按 `songID + scoreRevision` 隔离，`restoreProgressIfAvailable()` 会恢复 exact configuration，但 passage 无效时仅留下 invalid range；跨 revision 通用偏好尚不存在。

**Approach:** 先建立实际目标卷冲突事实、journal/recovery 模型与 index 条件替换，并把 recovery 在创建 task 中立即挂到 bootstrap。随后用App内同卷batch staging替换旧timestamp import：所有选择项先按顺序复制为独立operation并逐项平衡security access，后续target/index mutation只排队operation ID。再逐项增加用户确认replacement、队列和故障恢复。最后用纯 resolver 提取历史通用偏好，并在 Practice apply 流程中只对“无有效 exact progress”应用到当前 full passage。每个 task 都同步删除被替代 API、测试与文档描述；最后 gate 不承担老代码清理。

**Acceptance:**
- 新导入 target 文件名等于安全化 source lastPathComponent，无时间戳/UUID 后缀。
- service 层再次校验 `.xml/.musicxml/.mxl`，无效名/扩展在 target/index mutation 前失败。
- conflict confirmation 期间无外部 security lease；ViewModel 不保存 source URL 或绝对路径。
- no-conflict、indexed replacement、missing-target repair、filesystem orphan 与 ambiguous index 分类确定且可测试。
- confirm 前 `scores` target/index/progress 零 mutation；cancel 当前项后继续队列。
- replacement CAS 保留 songID、entry 顺序、displayName、audio、last-selected，更新 importedAt/file/token。
- 每个 journal phase crash 后 bootstrap recovery 幂等，且不发布 index 指向缺失 score 的 snapshot。
- recovery 只在 staged/backup/target 当前指纹与 journal 记录匹配时执行删除、覆盖或回滚；身份不明一律 blocking，不猜测。
- exact revision 有效配置优先；无 exact 时只继承 hand/tempo/loop/requiredSuccesses 到新 full passage，绝不跨 revision 复用 passage/resume/facts。

**Rules:**
- transaction actor 是 operation directory、短生命周期 security access、stage、backup、journal、target mutation、index mutation 和 recovery 的唯一 owner。
- batch staging对每个source在返回前必须关闭security access；process/confirm/cancel只接受operation ID。
- 所有 stage/backup/journal 使用 `SongLibrary` 根目录下相对路径；diagnostic/journal 禁止 source URL、绝对路径和 score 内容。
- destructive recovery/cleanup 必须先验证 byte count + SHA-256 指纹；不匹配或缺失证据时保留现场并 blocking。指纹只在内部journal存在，禁止进入diagnostic archive。
- conflict 判断以最新 index + `scores` 实际 URL/resource identity 为准；禁止固定 lowercase/Unicode normalization 猜测。
- bootstrap recovery 必须早于 index snapshot publication；blocking ambiguity 不得降级为空 index 后继续。
- progress/metadata 不参加 file/index transaction，也不因 replacement 删除。
- 新文件在创建 task 中必须进入 production graph/caller；替代 timestamp API 时同 task 删除旧模型、方法与测试断言。

**State / lifecycle:**
- Import queue owner：`SongLibraryViewModel`只把fileImporter返回数组直接传给actor的batch staging调用；调用返回后仅持ordered operation IDs与UI-safe`SongImportPresentationState`，不保存外部URL。
- Operation owner：`SongLibraryImportTransactionService` actor；`stageImports`返回ordered staged/failed descriptors，`process(operationID:)`返回committed、requiresConfirmation、blocked或failed。
- Pending confirmation：actor 持 operation directory/journal；ViewModel 只持 operation ID、safe filename、conflict kind与安全文案。
- Recovery owner：同一 transaction actor；bootstrap 调用 `recoverPendingTransactions()` 后再 load index/bundled entries。
- Preference owner：纯 `PracticeHistoricalPreferencesResolver`；launch owner选择 exact/fallback policy，session只安装最终策略。

**Threading / actor:**
- security access、文件校验/copy/move/remove、journal、index mutation/recovery全部离开MainActor。
- ViewModel只await actor并发布队列/alert状态。
- history读取在progress repository actor；偏好resolver用非actor隔离async纯函数在generic executor选择；session状态修改回MainActor。
- 不使用GCD、`Task.detached` 或非隔离可变全局状态。

**Debug / observability:**
- transaction diagnostics包含operation ID、safe filename、kind、journal phase、songID/token；不含source URL、绝对路径、XML内容。
- batch staging每项记录access acquired/result的结构化字段但不记录路径；start=false也必须允许普通sandbox URL继续copy尝试。
- recovery记录facts observed与action selected；blocking reason typed，不把journal phase当唯一事实。
- historical preference降级记录 exactMissing/historyCorrupted/noValidCandidate/invalidExactConfiguration；不记录measure facts。

**Testing strategy:**
- temporary `SongLibrary` root、可注入FileManager/clock/UUID、recording security access、fault-injecting filesystem与index actor。
- 在临时目标目录实测exact/case/Unicode名称是否解析到同一resource，而不是写死平台假设。
- journal phase与实际filesystem/index facts做table-driven recovery matrix；同一case连续recover两次。
- multi-select operation-ID顺序、cancel/confirm/blocked/failed混合队列使用deterministic fake actor。
- preference resolver用synthetic历史；session测试证明full passage与current step reset。

---

## P3-T1 建立 transaction facts、journal、条件 replacement 与 bootstrap recovery 入口

**Files:**
- Modify: `HappyPianistAVP/Models/Library/SongLibraryModels.swift`
- Create: `HappyPianistAVP/Models/Library/SongLibraryImportTransactionModels.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryPaths.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift`
- Create: `HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift`
- Create: `HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryImportConflictClassifierTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryPlannerTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `docs/storage.md`
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`

**Step 1: 定义最小持久化与UI-safe模型**

新增：

- operation ID/kind（new import、indexed replace、missing-target repair、orphan adopt）；
- conflict kind（none、indexed target、indexed missing target、filesystem orphan、ambiguous indexed targets）；
- journal phase（preparing、staged、backupMoved、targetInstalled、indexCommitted）；
- `TransactionFileFingerprint(byteCount, sha256)`，仅用于staged/backup/target恢复比对，不进入UI或diagnostics；
- expected entry identity（songID、expected token、expected filename）；
- new entry payload（songID、displayName、safe filename、importedAt、new non-nil token）；
- UI-safe pending/blocked result。

journal Codable 只含相对路径和上述标识。指纹digest用固定小写hex编码并验证长度；不要把 URL、score Data、error localized description 或完整 entry array 放入 journal。

**Step 2: 增加同卷 transaction paths**

`SongLibraryPaths`增加 `transactionsDirectoryURL()`、operation/stage/backup/journal URL helper，并由`ensureDirectoriesExist`创建transactions根目录。helper必须对operation ID与safe filename做path-component约束；禁止调用方拼绝对字符串。

**Step 3: 增加 replacement CAS**

在P1 concern-specific index API上增加：

`replaceUserScore(expectedSongID:expectedScoreFileVersionID:expectedMusicXMLFileName:with:)`

actor内load latest后必须：

- 找到恰好一个同songID user entry；
- token与filename均exact匹配（nil也必须exact）；
- 只替换musicXML filename、importedAt、scoreFileVersionID；
- 保留array位置、id、displayName、audio、isBundled、last-selected；
- mismatch返回typed conflict，不写文件。

为orphan adopt继续使用P1 `appendUserEntry`，不得增加整份save。

**Step 4: 纯 conflict/recovery planner**

classifier输入最新user entries、candidate safe filename和目标卷探测facts：candidate是否存在、解析后的resource identifier、目录中实际同resource names。bundled entries不参与user replacement。多个user entries解析到同一target时返回blocking ambiguous。

recovery planner输入journal + stage/backup/target存在性、文件指纹/resource identity + index expected/new状态，输出有限action：cleanup、rollForwardTarget、commitIndex、restoreBackup、removeUncommittedTarget、block。任何删除/覆盖动作都要求当前文件匹配journal指纹；文件存在但身份不匹配视为外部变化并block。事实优先于journal phase；不存在无损答案时block。

**Step 5: 创建actor并立即挂到bootstrap**

`SongLibraryImportTransactionService`本task先实现`recoverPendingTransactions()`与空目录快速路径，注入shared index store、paths、file manager、clock/UUID、diagnostics。它枚举每个operation journal，调用pure planner执行动作。

`LiveAppGraph`创建唯一service并注入`LiveSongLibraryBootstrapLoader`；loader顺序固定为recover -> index load -> bundled load。把当前总能携带index的`SongLibraryBootstrapSnapshot`替换为显式结果（例如`loaded(index:bundledEntries:)`/`blocked(error:)`）：`SongLibraryViewModel`只有loaded时才能替换index与标记loaded，blocked时保留已有内存状态并发布可重试错误。删除“recovery失败仍发布empty index”的fallback，禁止用`.empty`伪装成功。所有bootstrap fakes/harness同task迁移。

新actor创建当日即有production caller，不留未使用服务。

**Step 6: 测试与文档**

覆盖CAS preserve/mismatch/concurrent selection/audio、exact/case/Unicode临时卷facts、ambiguous classification、空recovery、blocking recovery、recovery先于load。storage/architecture/data-flow立即写transaction目录、journal隐私、bootstrap顺序。

**Step 7: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: replacement CAS不丢字段；bootstrap recording顺序为recover before load；journal model无URL字段。

**Step 8: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongLibraryModels.swift HappyPianistAVP/Models/Library/SongLibraryImportTransactionModels.swift HappyPianistAVP/Services/Library/SongLibraryPaths.swift HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift HappyPianistAVPTests/Library/SongLibraryImportConflictClassifierTests.swift HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryPlannerTests.swift HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift docs/storage.md docs/architecture.md docs/data-flow.md`

Run: `git commit -m "feat: P3-T1 - 建立曲谱导入事务与恢复基础"`

---

## P3-T2 用 batch-staged 原名导入替换 timestamp/UUID 旧路径

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift`
- Modify: `HappyPianistAVP/Services/Library/SongFileStore.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Library/SongFileStoreTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryImportTransactionTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `README.md`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`

**Step 1: actor batch staging负责validate、短lease与stage**

实现`stageImports(from selectedURLs:)`，只在actor调用栈中持有输入URL数组：

1. 仅取`sourceURL.lastPathComponent`，验证它等于安全单一path component、非空且扩展为xml/musicxml/mxl；读取resource values并拒绝目录、符号链接及非普通文件；
2. 创建operation directory并atomic写preparing journal；
3. 调用`startAccessingSecurityScopedResource()`；返回true时用defer恰好stop一次，返回false时仍尝试读取，因为测试临时URL/应用容器URL可能无需scope；只有实际permission/copy错误才分类access failure；
4. copy到同卷stage临时名；同步文件内容，计算byte count + SHA-256指纹，再atomic rename为safe original name并同步journal；
5. 更新staged journal并返回ordered operation descriptor，不跨await UI持有source URL/lease；
6. 按selectedURLs顺序继续stage后续项；单项失败返回safe item failure并继续，只有transactions根目录/journal不可用才停止batch。

同步copy本身不可中断；copy返回后立即检查cancellation，若已取消则先按指纹清理当前stage/operation再返回。已经staged的operations由调用方随后按operation ID取消。cleanup失败保留journal并报typed diagnostic，不能留下无journal临时文件。

**Step 2: 实现按operation ID分类与无冲突commit**

`process(operationID:)`重新读取shared index store与目标卷facts后分类。`.none`直接在actor内：stage atomic move到exact target filename -> `appendUserEntry` -> indexCommitted journal -> cleanup。entry的`musicXMLFileName`严格使用safe original filename，`displayName`固定使用删除最后一个扩展名后的basename（与当前产品行为一致），写入new UUID token和songID。

如果target move成功但append失败，按journal facts移回stage/删除uncommitted target；旧曲库不变。cleanup失败不回滚已commit index。

**Step 3: conflict只发布pending，target/index零mutation**

indexed target、indexed missing、orphan返回`requiresConfirmation`，operation留在staged phase。ambiguous返回blocked并保留足够diagnostic后清理operation；不得猜replacement songID。

**Step 4: 同task删除旧timestamp API与调用链**

从`SongFileStoreProtocol/SongFileStore`删除：

- `ImportedSongScoreFile`；
- `importMusicXML(from:)`；
- `uniqueScoreDestinationURL`；
- `makeDestinationFileName`；
- 仅为旧import存在的`now`依赖。

保留score/audio URL和delete能力。`SongLibraryViewModel.importMusicXML`改为await transaction actor，禁止MainActor copy；移除旧copy成功后手工append/rollback分支。所有fakes/tests同task迁移，运行`rg "ImportedSongScoreFile|makeDestinationFileName|uniqueScoreDestinationURL|importMusicXML\(from"`确认旧service API零命中（ViewModel入口可按新命名保留）。

**Step 5: 暂存UI-safe conflict state**

ViewModel增加最小import state：idle、staging(index/count)、processing(operationID/index/count)、awaitingConfirmation(pending)、itemFailure(safe message)。`LibraryContentView`把selected URLs直接交给ViewModel方法；该方法立即await actor batch staging，返回后丢弃URL数组，只保留ordered operation IDs。P3-T3前冲突UI至少能显示安全说明并允许取消当前item；不要提供未实现的replace按钮。

**Step 6: 测试与文档**

覆盖安全文件名、扩展复核、目录/符号链接拒绝、batch顺序、单项stage失败继续、security start true/false、每个异常stop平衡、stage完成后外部URL不再访问、stage指纹、原名无suffix、no-conflict commit/rollback、ambiguous block、confirm前target/index不变。README/docs立即删除timestamp命名描述并说明同卷stage。

**Step 7: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `rg -n "ImportedSongScoreFile|makeDestinationFileName|uniqueScoreDestinationURL|func importMusicXML\(from sourceURL" HappyPianistAVP HappyPianistAVPTests`

Expected: no-conflict原名落盘；旧timestamp/UUID API零命中；MainActor无copy调用。

**Step 8: 原子提交**

Run: `git add -A HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift HappyPianistAVP/Services/Library/SongFileStore.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Views/Library/LibraryWindowView.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Library/SongFileStoreTests.swift HappyPianistAVPTests/Library/SongLibraryImportTransactionTests.swift HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift README.md docs/storage.md docs/data-flow.md docs/modules/happypianist-avp.md`

Run: `git commit -m "refactor: P3-T2 - 以原名暂存事务替换旧导入路径"`

---

## P3-T3 完成冲突确认、replacement 与 missing/orphan 修复

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryImportTransactionTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryImportConflictPresentationTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: confirm/cancel只接受operation ID**

actor加载operation journal并重新读取最新index/target facts，不信任旧pending snapshot。若conflict已变化，重新分类并返回updated pending/blocked；ViewModel不传source URL、entry或target URL。

`cancel(operationID:)`只删除该operation目录，target/index/progress不变；幂等cancel返回已结束而非throw。

**Step 2: indexed target replacement**

确认后：

1. 重新验证target为普通文件并计算其backup指纹；先把指纹atomic写入journal；
2. 将当前target atomic move到operation backup，并验证backup仍匹配该指纹；
3. journal backupMoved；
4. 仅当stage匹配staged指纹时move到exact target，再验证target指纹；
5. journal targetInstalled；
6. 调用index CAS替换expected songID/token/filename；
7. journal indexCommitted；
8. 仅按已记录指纹删除backup/operation。

CAS mismatch或index commit前任意failure恢复旧target；恢复失败保留journal并返回blocking，不继续队列覆盖事实。

**Step 3: indexed missing-target repair**

无旧target时仅在stage匹配staged指纹且target仍不存在时stage -> target，验证target指纹后再CAS同一entry。保留songID/顺序/display/audio/last-selected；更新importedAt/token。若文件在confirm前出现，重新分类为target replacement或ambiguous，不盲目覆盖。

**Step 4: filesystem orphan adopt**

先验证orphan为普通文件、记录其backup指纹并move到backup，再验证staged指纹后stage -> target，随后append新entry。失败只在backup/target指纹匹配时回滚orphan；成功创建new songID/token。提示文案必须明确“未索引文件将被替换并加入曲库”，不伪装成已有曲目更新。

**Step 5: UI确认与可访问性**

用SwiftUI confirmation dialog/alert呈现safe filename与conflict kind：

- replace/repair/adopt使用不同明确动词；
- cancel跳过当前项；
- ambiguous只有关闭/诊断，不显示replace；
- destructive role仅用于实际覆盖已有target；
- VoiceOver label不依赖颜色/图标。

删除P3-T2临时“只能取消”分支；不得保留两套conflict presentation。

**Step 6: 测试与文档**

覆盖四类确认、confirm前零mutation、CAS race、target在等待中变化、rollback、preserve fields、old progress保留、new token、cleanup failure留journal、UI按钮/role/accessibility。docs/checklist同task更新。

**Step 7: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: replacement各case字段保留正确；旧临时冲突分支零命中。

**Step 8: 原子提交**

Run: `git add HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/LibraryWindowView.swift HappyPianistAVP/Views/Library/SongLibraryView.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Library/SongLibraryImportTransactionTests.swift HappyPianistAVPTests/Library/SongLibraryImportConflictPresentationTests.swift docs/storage.md docs/data-flow.md docs/modules/happypianist-avp.md docs/testing/core-function-checklist.md`

Run: `git commit -m "feat: P3-T3 - 完成同名曲谱确认与替换"`

---

## P3-T4 收口 operation-ID 队列、取消语义与 crash recovery fault matrix

**Files:**
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryImportQueueTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryIntegrationTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 单一串行queue state machine**

ViewModel按batch staging返回的ordered operation IDs处理：processing -> awaiting confirmation -> committed/cancelled/failed -> next。等待确认时不process下一项；所有外部URL早已释放。取消当前冲突继续下一operation；用户取消整个queue则actor逐个cancel当前与剩余staged operations。

Library disappear触发`cancelImportQueue()`：已commit项保留；当前与尚未process的operation目录清理。View层只发intent，不直接调用transaction actor。

**Step 2: stale callback/generation guard**

queue generation绑定每次batch staging结果。旧confirm/cancel callback只能结束其operation，不能推进或覆盖新queue UI。重复confirm/cancel幂等；当前queue完成后state回idle并刷新index/selection snapshot。

**Step 3: 完整crash fact matrix**

对每种operation在以下点故障/模拟重启：preparing journal、stage copy中、staged、backupMoved、targetInstalled、indexCommitted、cleanup。planner依据stage/backup/target指纹与resource identity、index expected/new facts选择rollforward/rollback/cleanup/block。

至少证明：

- index仍old且backup存在可rollback或rollforward，结果不dangling；
- index已new时绝不恢复old backup覆盖新target；
- target缺失但index new时若stage/backup不能恢复则blocking；
- target被外部同名文件替换或篡改时指纹不匹配并block，orphan adopt与new import不会误删非transaction文件；
- recovery连续运行两次结果相同；
- recovery blocking时bootstrap不发布snapshot。

**Step 4: diagnostics与无敏感数据检查**

fault tests读取journal/diagnostic archive，断言无`file://`、Documents绝对路径、source URL、XML片段；journal允许内部指纹，diagnostic archive不得包含指纹。cleanup warning与blocking error使用不同code。

**Step 5: 文档与人工清单**

storage/data-flow写完整queue与recovery事实表；checklist加入多选cancel、Library关闭、App重启、磁盘/权限失败。不要等phase gate补文档。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 每个fault case无dangling index；queue顺序与cancel语义确定。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/LibraryWindowView.swift HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Library/SongLibraryImportQueueTests.swift HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryIntegrationTests.swift HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift docs/storage.md docs/data-flow.md docs/testing/core-function-checklist.md`

Run: `git commit -m "test: P3-T4 - 封闭导入队列与事务恢复故障矩阵"`

---

## P3-T5 建立历史通用偏好 resolver 与 repository 选择规则

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift`
- Create: `HappyPianistAVP/Services/Practice/Progress/PracticeHistoricalPreferencesResolver.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesResolverTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp-practice.md`

**Step 1: 定义不含结构身份的preferences**

`PracticeHistoricalPreferences`只含handMode、clamped tempoScale、loopEnabled、clamped requiredSuccesses。禁止passage、resume、facts、source/occurrence ID、score revision。

定义launch restore policy：exactAvailable、historicalPreferences、freshDefaults、historyUnavailable。它是纯模型，不直接持repository document。

**Step 2: 非MainActor的纯deterministic resolver**

`resolve(identity:history:) async`为非actor隔离async入口，在generic executor处理当前identity与P2 `PracticeSongHistoryLoadResult`：

1. corrupted -> historyUnavailable；
2. 存在exact identity progress -> exactAvailable，不选择历史偏好；
3. 无exact时过滤activeConfiguration非nil的历史progress；
4. 先按identity去重；同identity重复损坏记录按`updatedAt`降序，再按四项通用偏好的canonical tuple稳定选择。候选间按`updatedAt`降序，tie按scoreRevision、canonical preference tuple排序；不得依赖JSON数组偶然顺序；
5. 用`PracticeRoundConfiguration`公共范围重新构造/clamp preferences；
6. 无候选 -> freshDefaults。

即使历史passage损坏/不属于当前score，只读取四个通用字段；若枚举/文档整体无法解码则repository已返回corrupted。

**Step 3: launch owner读取history但不触碰Library**

`PracticeLaunchViewModel`在resolve entry后、session apply前await repository history，再await非MainActor resolver计算policy。history失败不阻止prepare；记录typed warning并用fresh defaults。generation guard只控制UI/session publication；history结果不得写回Library。

新resolver创建同task立即被production launch owner使用。

**Step 4: 测试与文档**

覆盖exact优先、latest updatedAt、tie-break、nil config、clamp、old facts/resume忽略、corrupted/no candidate、stale generation。data-flow/practice module同task写policy。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: resolver输出从不包含passage/resume；exact存在时不返回historical preferences。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift HappyPianistAVP/Services/Practice/Progress/PracticeHistoricalPreferencesResolver.swift HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesResolverTests.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift docs/data-flow.md docs/modules/happypianist-avp-practice.md`

Run: `git commit -m "feat: P3-T5 - 解析跨版本练习通用偏好"`

---

## P3-T6 将历史偏好安全应用到当前 full passage

**Files:**
- Modify: `HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeRoundConfigurationController.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesApplicationTests.swift`
- Modify: `docs/modules/happypianist-avp-practice.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 单一session apply策略**

在prepared session安装流程传入P3-T5 restore policy：

- exactAvailable：沿用progress coordinator exact restore；随后验证active range有效；
- historicalPreferences：先安装当前score fresh full passage，再只覆盖hand/tempo/loop/requiredSuccesses；
- freshDefaults/historyUnavailable：沿用仓库已验证的fresh full-score规则（hand `.both`、tempo `1.0`、loop `false`、requiredSuccesses使用controller当前批准默认值）；不得顺手改成UserDefaults中的上次设置。

不要在launch和session各自应用一遍配置。最终配置安装集中在session command/controller一个入口。

**Step 2: 修复exact invalid fallback根因**

exact restore后若active range为空、boundary diagnostic存在或resume不属于active range：清除该session中的invalid configuration/resume，重新安装当前full passage；保留exact facts仅供同revision后续学习逻辑时必须确认不会驱动旧范围。记录typed warning但launch ready。

若P1-T7已实现同一fallback，本task扩展该单一路径以接收restore policy，不新建第二套validator；同task删除被替代helper/分支。

**Step 3: historical application边界**

应用后：

- passage严格为current prepared first...last occurrence；
- current step为full passage firstStep；
- sessionProgress/resume/facts为空（直到当前revision新attempt）；
- pending与active configuration一致；
- hand gate/tempo/autoplay routing按现有controller刷新一次；
- defaults store本身不被历史偏好永久改写。

**Step 4: stale/clear保护**

apply过程中request stale、suspend、clear时，P1 generation/applicationID guard必须拒绝旧policy/session publication。新request activation先song-specific clear，再应用其policy。

**Step 5: 测试与文档**

覆盖exact valid、exact invalid passage、invalid resume、historical preferences、corrupted history、replacement token/revision mismatch、full passage/current step、facts不跨revision、calibration保留、stale apply。practice docs/checklist同task更新。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: replacement后仅四项偏好继承；旧passage/resume/facts零跨revision。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift HappyPianistAVP/Services/Practice/Session/PracticeRoundConfigurationController.swift HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesApplicationTests.swift docs/modules/happypianist-avp-practice.md docs/testing/core-function-checklist.md`

Run: `git commit -m "feat: P3-T6 - 安全应用跨版本练习偏好"`

---

## P3-T7 执行端到端调用图、数据安全与 visionOS gate

**Files:**
- Create: `.github/features/library-practice-entry-redesign/.audit/p3/gate-evidence.md`

若gate暴露业务缺陷，必须回到引入缺陷的task修改其已列文件并amend对应commit；本gate只创建本地证据文件，不新增“清理”业务提交。

**Step 1: 静态旧代码与调用图 gate**

Run: `codegraph sync`

Run: `codegraph explore "Library import transaction recovery score replacement historical preferences callers"`

Run: `rg -n "ImportedSongScoreFile|makeDestinationFileName|uniqueScoreDestinationURL|indexStore\.save|LibraryPracticeOrnamentView|prepareSelectedEntry" HappyPianistAVP HappyPianistAVPTests README.md docs`

证明：

- `SongFileStore`无timestamp/UUID import API；
- ViewModel/MainActor不执行score copy/journal IO；
- import confirm callback只传operation ID；
- production无index whole-save；
- bootstrap recover先于index load；
- historical preferences类型无passage/resume/facts；
- canonical docs无旧timestamp导入、Library配置Ornament或Library自动prepare描述。

任何命中回到所属task即时修复并amend；不得在本task创建“清理旧代码”提交。

**Step 2: 完整测试与build**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO`

保存命令、exit code、失败测试与修复commit到audit evidence。当前Linux审查环境没有xcodebuild，执行阶段必须在Apple工具链运行，不能以Swift语法检查代替。

**Step 3: 手工验收**

按checklist验证：

- 原名新导入；exact/case/Unicode冲突按当前目标卷行为；
- indexed replace/missing repair/orphan adopt/ambiguous block；
- multi-select cancel继续、Library关闭、App重启recovery；
- replacement后Ornament needs-rebuild，Practice full passage继承通用偏好；
- VoiceOver确认文案与destructive role；
- diagnostics/journal无绝对路径/source URL/XML内容。

**Step 4: Phase Audit**

创建`audit-p3.md`，重点审查transaction facts优先、rollback/rollforward、security access平衡、index CAS字段保留、跨revision隔离，以及每个替代task是否同commit删除旧实现。

**Step 5: 提交规则**

本task默认不创建新业务commit。若gate发现缺陷，回到引入缺陷的task修复并amend；计划/audit/evidence文件不入库。

---

## Phase Audit

- Audit file: `audit-p3.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环
- Audit focus:
  - old timestamp/UUID import是否在P3-T2同commit删除；
  - confirm期间是否完全不依赖外部security lease；
  - target/index各fault point是否可恢复且bootstrap不发布dangling entry；
  - replacement CAS是否保留全部非score字段；
  - progress/metadata是否保持历史且由token/revision隔离；
  - historical preferences是否只含四项通用值；
  - exact invalid fallback与stale generation是否只有一个实现路径；
  - docs是否由相应task同步更新而非最后补写。
