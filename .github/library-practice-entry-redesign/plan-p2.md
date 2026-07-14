# Plan P2 - 当前曲目练习事实与只读 Ornament

**Goal:** 在 Library 不读取 score 文件的前提下，用最小版本 metadata 与真实 attempt facts派生当前曲目快照，并重建只读进度 Ornament。

**Non-goals:** 本 phase 不实现原名导入/replacement transaction；不跨revision恢复通用偏好；不持久化UI summary；不建立跨曲目统计或repository cache。

**Repository evidence:** `PracticeProgressDocument` 当前只有`songs`；repository每次读取整份JSON并由一个actor mutation。facts持久化单位是`PracticeSourceMeasureID + handMode`，repeat occurrence不应重复。`SongLibraryViewModel.reloadPracticeProgress()` 当前加载整份document并按song取latest，且依赖会在P1删除。bundled provider已有确定性UUID helper，但entry没有文件版本token。

**Approach:** 先兼容扩展entry/progress schema与repository原子能力，同时给bundled资源生成保守版本token。然后在同一task创建纯snapshot builder并接入Library ViewModel，避免孤立新文件。Practice成功安装后写metadata。最后创建并挂载只读Ornament，立即更新相关docs/人工清单。Phase gate验证事实规则、快速切歌、无score访问与无第二按钮。

**Acceptance:**
- 旧index/progress JSON无需migration即可解码。
- current/needs-rebuild判断由entry token + metadata token/revision exact匹配完成。
- never-practiced不显示0/total伪进度。
- stable/learning/recent issue/tempo/resume遵守idea中的真实fact与去重规则。
- snapshot load generation绑定selected songID+token，A->B不闪A。
- Practice metadata failure不影响ready。
- trailing Ornament只读、无配置与练习按钮，支持Reduce Motion/VoiceOver。

**Rules:**
- metadata与progress仍在同一JSON、同一repository actor；不加第二数据库。
- repository mutation必须保留另一数组，不允许调用方整份覆盖。
- builder为纯Sendable逻辑，不读文件、不用MainActor/SwiftUI。
- Library只接收history input/snapshot，不接触score URL或PreparedPractice。
- bundled token在App构建变化时保守失配，不允许nil永久匹配旧结构。
- 新文件在创建task中接入production consumer。

**State / lifecycle:**
- Repository owner：`FilePracticeProgressRepository` actor。
- Snapshot owner：`SongLibraryViewModel`，selection debounce/generation与selection persistence独立。
- Metadata writer：`PracticeLaunchViewModel`，prepared session成功后best-effort upsert。
- Ornament presentation：未选择、loading、never、current、needsRebuild、unavailable。

**Threading / actor:**
- JSON decode/encode/history filtering/upsert在repository actor。
- snapshot builder使用非actor隔离的async纯函数在generic executor执行；MainActor只做generation校验和发布状态。
- metadata upsert await actor，不阻塞MainActor文件IO。

**Debug / observability:**
- history load/metadata write失败使用typed diagnostic；包含songID/token/revision/count，不含facts详情与绝对路径。
- builder不写日志。
- corrupted repository映射unavailable；Practice启动仍可继续并在P3恢复策略中记录defaults降级。

**Testing strategy:**
- 旧JSON fixture、temporary directory、deterministic date/token。
- synthetic facts覆盖repeat、hand、duplicate corruption、tie-break、empty attempts、old revision。
- recording repository与score-store spy证明Library零score access。
- UI人工证据覆盖window resize、Dynamic Type、Reduce Motion、VoiceOver与Differentiate Without Color。

---

## P2-T1 兼容扩展 entry token、progress metadata 与 repository history API

**Files:**
- Modify: `HappyPianistAVP/Models/Library/SongLibraryModels.swift`
- Modify: `HappyPianistAVP/Models/Practice/PracticeProgressModels.swift`
- Modify: `HappyPianistAVP/Services/Library/BundledSongLibraryProvider.swift`
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryProgressCleanupTests.swift`
- Create: `HappyPianistAVPTests/Library/BundledSongLibraryVersionTests.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeProgressDocumentCompatibilityTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/architecture.md`

**Step 1: entry version token兼容模型**

为`SongLibraryEntry`增加`scoreFileVersionID: UUID?`，initializer默认nil。旧JSON缺key须解码nil；round trip保值。token不参与文件路径或displayName。

**Step 2: bundled保守token**

`BundledSongLibraryProvider`使用已有`DeterministicUUID.make`，输入至少包含bundle identifier、`CFBundleShortVersionString`、`CFBundleVersion`和resource filename。提供可注入version strings或内部纯helper；bundle identifier/short version/build缺失时使用固定显式sentinel，不得回退随机值或nil。测试同构建稳定、build变化token变化、不同文件不同。不要读取/hash score内容。

**Step 3: metadata/history纯模型**

增加：

- `SongScorePracticeMetadata(songID, scoreFileVersionID, scoreRevision, totalSourceMeasureCount, preparedAt)`；total clamp非负。
- `PracticeSongHistory(songID, progresses, scoreMetadata)`，仅作为repository读取结果，不是UI summary。
- `PracticeSongHistoryLoadResult.loaded/corrupted`。

`PracticeProgressDocument`增加`scoreMetadata`，实现显式`init(from:)`使用`decodeIfPresent(...) ?? []`，并实现对应`encode(to:)`；nonoptional数组不能依赖合成解码自动使用默认值。

**Step 4: repository API与原子保留语义**

protocol增加：

- `history(for songID:) -> PracticeSongHistoryLoadResult`
- `upsert(_ metadata: SongScorePracticeMetadata) throws`

现有`upsert(progress)`只替换same identity并保留metadata；metadata upsert键为`songID + scoreFileVersionID + scoreRevision`并保留songs；`remove(songID:)`删除两类记录。保持一个actor、一个JSON。

不要增加“调用方传document保存”API。所有protocol fakes在同task更新；列出的测试文件是当前完整conformance集合，执行前再用`rg "PracticeProgressRepositoryProtocol"`确认新P1文件无遗漏。

**Step 5: corruption与排序**

保留现有read-only corrupted结果与mutation quarantine。数组编码稳定排序：songs按songID/revision，metadata按songID/token字符串/revision；nil token定义固定排序位置。history返回该song全部records，不在repository里做UI选择。

**Step 6: 测试**

覆盖：旧index、旧progress仅songs、unknown extra keys、新round trip、metadata/progress交错upsert、remove两数组、corruption quarantine、nil/non-nil token、bundled build token。

**Step 7: 文档**

storage/architecture立即说明同一progress JSON的两数组、entry token与bundled token策略；不等P2-T4。

**Step 8: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `rg -n "PracticeProgressRepositoryProtocol" HappyPianistAVP HappyPianistAVPTests`

Expected: 每个conformance实现新API；旧fixtures兼容；mutation不清空另一数组。

**Step 9: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongLibraryModels.swift HappyPianistAVP/Models/Practice/PracticeProgressModels.swift HappyPianistAVP/Services/Library/BundledSongLibraryProvider.swift HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift HappyPianistAVPTests/Library/SongLibraryProgressCleanupTests.swift HappyPianistAVPTests/Library/BundledSongLibraryVersionTests.swift HappyPianistAVPTests/Practice/PracticeProgressDocumentCompatibilityTests.swift HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift docs/storage.md docs/architecture.md`

Run: `git commit -m "feat: P2-T1 - 增加曲谱版本与练习元数据"`

---

## P2-T2 创建事实快照策略并立即接入 Library selection

**Files:**
- Create: `HappyPianistAVP/Models/Library/SongPracticeLibrarySnapshot.swift`
- Create: `HappyPianistAVP/Services/Library/SongPracticeLibrarySnapshotBuilder.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Create: `HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`

**Step 1: 定义无UI类型snapshot/presentation state**

`SongPracticeLibrarySnapshot`只包含展示事实：status、latest real practice date、current hand、stable/learning unique counts、total、resume source identity、highest stable tempo、recent issues、hasHistory。不得包含Color、Text、文案、比例或full document。

Library state携带selected songID与entry token：noSelection、loading、neverPracticed、current(snapshot)、needsRebuild(historyDate)、unavailable。任何旧结果都必须能被identity检查拒绝。

**Step 2: 实现token/revision选择**

纯builder的 `build(entry:history:) async` 为非actor隔离async入口，在generic executor处理current entry + `PracticeSongHistory`：

1. 找token exact metadata；多条时按preparedAt降序、revision稳定tie-break选current metadata。
2. nil只匹配nil；non-nil不匹配nil。
3. current facts只来自metadata scoreRevision exact progress。
4. 所有revision真实facts用于判断historical existence/latest date。
5. 有真实history且无matching metadata -> needsRebuild；隐藏counts/total/resume。current progress是否存在不能替代token/metadata匹配。
6. matching metadata存在时即为current版本；当前revision无真实attempt时保留historical latest date/hasHistory，但隐藏current counts/hand/resume并呈现“当前版本尚未练习”，不得返回needsRebuild。
7. 状态优先级固定：全部revision均无真实attempt -> neverPracticed；否则有matching metadata -> current（即使current revision无attempt）；否则 -> needsRebuild。这样metadata本身永远不伪造练习历史。

**Step 3: 实现真实facts与确定性去重**

严格落实idea规则：

- latest practice=max `lastAttemptAt`；
- hand=当前revision最近真实attempt hand；
- same source+hand duplicate先按lastAttemptAt，再state稳定优先级/identity tie-break；
- stable/learning唯一source measure；
- recent issues要求issue+timestamp，source去重后排序；
- highest tempo仅stable/current hand；
- resume仅exact progress且其source measure有真实current fact；
- total只取metadata unique count。

测试必须明确`updatedAt`晚但无attempt不改变latest/hasHistory；async builder从MainActor调用时不在MainActor执行排序（用可注入executor probe或Swift并发隔离断言，不依赖线程ID）。

**Step 4: 同 task接入 SongLibraryViewModel**

重新注入progress repository + builder，但不恢复任何score/preparation依赖。selection变化、initial load、import/delete及未来token变化调用`scheduleSnapshotLoad`。另外`LibraryWindowRootView`在窗口重新出现或scene恢复active时调用`refreshSelectedPracticeSnapshot()`，以读取Practice刚写入的metadata/facts；该调用只调度JSON history读取，不访问score：

- 立即发布loading(selectedID/token)；
- 取消旧task并递增独立snapshot generation；
- 使用短settle delay避免drag时排队JSON读取；
- await `history(songID)`，再await非MainActor builder派生；
- 只有selectedID + token + generation仍一致才发布；
- 同一run-loop/onAppear+active重复refresh必须取消/合并到最新generation，不能并发发布两份相同snapshot。

unavailable不设置全局error、不禁用试听/开始按钮。开始按钮完全不等待snapshot。

**Step 5: 明确轻量性能边界**

添加`ponytail:`注释说明当前progress JSON整份decode + 同song线性过滤/排序是有意简化；这些工作均不在MainActor。只有实测document规模或selection latency超阈值才引入索引/cache，不得在本task加缓存失效系统。

**Step 6: 测试**

Builder覆盖：never、current、needs rebuild、legacy nil、bundled token mismatch、repeat、duplicate corrupt facts、hands、old revision、tie-break、issues、resume guard、unknown total、updatedAt非attempt。

VM覆盖：A->B stale、token变化reload、delete fallback、repository corrupted、rapid drag debounce、Library返回时同selection refresh、onAppear+active coalesce、立即start不等待、score file/preparation spy零调用。

**Step 7: 文档**

data-flow与AVP module立即描述history read与generation gate；说明Library仍无Ornament UI直到P2-T4，但状态已可用。

**Step 8: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 纯builder无需filesystem/MainActor；VM spy证明零score access。

**Step 9: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongPracticeLibrarySnapshot.swift HappyPianistAVP/Services/Library/SongPracticeLibrarySnapshotBuilder.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/LibraryWindowView.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift docs/data-flow.md docs/modules/happypianist-avp.md`

Run: `git commit -m "feat: P2-T2 - 派生并加载当前曲目练习快照"`

---

## P2-T3 在成功 Practice preparation 后写入 metadata

**Files:**
- Modify: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp-practice.md`

**Step 1: resolver结果携带entry token**

使用P1 resolver的entry snapshot；launch owner在当前generation完成prepared验证与session apply后拥有songID、entry token、prepared revision和measure spans。不要重新读Library state。

**Step 2: 计算唯一source measure count**

`Set(prepared.measureSpans.map(\.sourceMeasureID)).count`；不按occurrence count。若spans已通过nonempty验证，total至少1；模型仍防御性clamp。

**Step 3: ready publication与best-effort upsert解耦**

当前generation完成apply与配置验证后立即发布ready；不要让metadata JSON IO延长loading。随后从immutable `(songID, entryToken, revision, uniqueCount, preparedAt)` 创建独立受管task await repository upsert。graph持有launch owner，task不能依赖View生命周期。

request随后切换或scene inactive不取消已经成功apply对应的metadata task；它允许幂等落盘，但绝不能再次发布ready/UI。replacement的新token不会匹配旧写入。metadata failure只记录warning，不能reset已安装session或进入launch failure。launch owner teardown/deinit要取消尚未取得immutable成功事实的任务，但不能取消已经开始的合法metadata commit。

**Step 4: typed diagnostics**

增加metadata write failed code/stage，reason仅safe error summary；字段包含songID/token/revision/unique count，不包含measure list或路径。

**Step 5: 测试**

覆盖unique count、repeat去重、nil legacy/non-nil/bundled token、repository failure仍ready、apply失败不写、prepare failure不写、stale after apply可写metadata但不可ready、diagnostic privacy。

**Step 6: 文档**

storage/data-flow/practice module同task说明writer时机、失败降级与stale幂等规则。

**Step 7: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: metadata failure case为ready + warning；无session success时无metadata。

**Step 8: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift docs/storage.md docs/data-flow.md docs/modules/happypianist-avp-practice.md`

Run: `git commit -m "feat: P2-T3 - 在练习准备成功后更新曲谱元数据"`

---

## P2-T4 创建并挂载只读 trailing Ornament

**Files:**
- Create: `HappyPianistAVP/Views/Library/LibraryPracticeProgressOrnamentView.swift`
- Create: `HappyPianistAVP/Views/Library/LibraryPracticeEmptyAnimationView.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `README.md`
- Modify: `docs/overview.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 按snapshot state渲染只读内容**

- no selection：选择提示；
- loading：小型`ProgressView`/redaction，只代表历史JSON；
- never：邀请文案+原生动画；
- current：最近练习、stable/learning/total、resume、tempo、issues中有值才显示；
- needs rebuild：显示历史存在/最近日期，不显示旧结构counts/resume；
- unavailable：鼓励练习与数据不可用说明。

所有文案/颜色映射在View/presentation extension，不写回snapshot或JSON。

**Step 2: 原生动画与accessibility**

动画使用SwiftUI shape/symbol effect/phase animator等平台API，不加依赖。Reduce Motion时使用静态图形；Differentiate Without Color不能只用颜色表达stable/learning；VoiceOver提供组合label/value；Dynamic Type不强制固定字体。面板宽度/spacing复用现有Library design token或内容自适应，不新增400等magic number。

**Step 3: 正确使用 Ornament**

在`SongLibraryView`恢复`.ornament(attachmentAnchor: .scene(.trailing))`，因为它是持续附着的辅助面板，符合AVP AGENTS。只注入当前snapshot state；不注入launch owner、ARGuide、configuration controller或score service。

Ornament内禁止任何“开始/继续/去练习”按钮、Picker、Slider、Toggle、Stepper。P1主内容右下角按钮保持唯一入口。

**Step 4: 同 task更新docs/checklist**

README/overview/module改为“右侧只读事实 + 左侧唯一按钮”。人工清单删除旧配置操作，增加never/current/rebuild/unavailable、Reduce Motion、VoiceOver、窗口resize检查。

**Step 5: 静态验证**

Run: `rg -n "Picker|Slider|Toggle|Stepper|去练习|继续练习|开始练习" HappyPianistAVP/Views/Library/LibraryPracticeProgressOrnamentView.swift`

Expected: 零交互配置与练习按钮命中。

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Expected: 全套测试通过。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Views/Library/LibraryPracticeProgressOrnamentView.swift HappyPianistAVP/Views/Library/LibraryPracticeEmptyAnimationView.swift HappyPianistAVP/Views/Library/SongLibraryView.swift README.md docs/overview.md docs/modules/happypianist-avp.md docs/testing/core-function-checklist.md`

Run: `git commit -m "feat: P2-T4 - 重建只读曲库进度 Ornament"`

---

## P2-T5 完成事实边界、性能与 UI phase gate

**Files:**
- Modify: `HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `docs/testing/core-function-checklist.md`

本task只记录证据/状态，不延迟前序task应完成的行为文档。

**Step 1: 边界回归矩阵**

覆盖：

- progress仅有active config/updatedAt但无attempt -> never；
- old revision有attempt、current metadata存在但current facts空 -> current版本已建立/无当前计数，不得needsRebuild；
- duplicate facts与same-time tie-break deterministic；
- resume source无真实fact ->隐藏；
- bundled build token变化 ->旧metadata不匹配；
- rapid A->B->A actor读取乱序 ->只显示最终A；
- metadata write failure后返回Library -> 有真实旧history时needsRebuild、全无attempt时never，绝不复用旧current结构。

**Step 2: 调用图与资源gate**

Run: `codegraph explore "LibraryPracticeProgressOrnament SongLibraryViewModel snapshot scoreFileURL PracticePreparationService PreparedPractice"`

Expected: Ornament/snapshot路径只到repository/builder；无score/preparation/session。

Run: `rg -n "LibraryPracticeProgressOrnamentView|onStartPractice|PracticeRoundConfigurationController" HappyPianistAVP/Views/Library`

Expected: Ornament无start/config controller；start只在主Library内容。

**Step 3: Apple target与人工证据**

Run: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO`

人工检查各状态、window min/ideal/max、Dynamic Type、VoiceOver、Reduce Motion、Differentiate Without Color。未执行标`Not Run`。

**Step 4: 原子提交**

Run: `git add HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift docs/testing/core-function-checklist.md`

Run: `git commit -m "test: P2-T5 - 验证曲库事实快照与 Ornament 边界"`

---

## Phase Audit

- Audit file: `audit-p2.md`
- Rule: 全部task完成后自动进入审计闭环。
- Audit focus:
  1. 旧JSON兼容与metadata/progress mutation保留语义。
  2. bundled token是否避免App更新后nil误匹配。
  3. facts规则是否只使用真实attempt、唯一source measure与current hand/revision。
  4. snapshot generation是否绑定songID+token且无score access。
  5. metadata failure是否不影响ready且diagnostic无敏感数据。
  6. Ornament是否只读、唯一入口仍在主内容、accessibility完整。
  7. docs是否在对应task更新而非gate补账。
