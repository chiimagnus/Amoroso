# Plan P1 - Practice 启动所有权与轻量 Library

**Goal:** 在不保留双轨实现的前提下，把 selection persistence 与 index mutation 先收口，再把 preparation/session/configuration 生命周期从 Library 原子迁移到 Practice，并加入唯一“开始练习”入口。

**Non-goals:** 本 phase 不实现最终进度 Ornament、不增加 score metadata、不改变新导入文件名/替换事务、不实现跨 revision 通用偏好。

**Repository evidence:** 当前调用链是 `LibraryCrateView -> SongLibraryView.didSelectEntry -> SongLibraryViewModel.selectEntryForPractice -> 200ms settle -> indexStore.save(old snapshot) -> PracticePreparationService.prepare -> ARGuideViewModel.applyPreparedPractice`。`SongLibraryView` 同时持有本地 selection；`LiveSongLibraryBootstrapLoader` 使用独立 store；`ARGuideViewModel.latestPreparedPractice` 可在 session replacement 时复活旧曲谱。

**Approach:** 先替换 index 的整份覆盖 API并建立唯一 selection；再把现有 Documents/security-scope 文件 IO 移出 MainActor并删除同步接口；随后把 typed failure 和 entry resolution 从 Library 命名/内联逻辑中拆出，但每一步都立即让现有生产路径使用新实现并删除被替代部分。再增加精确的 song-specific teardown。最后在一个原子 cutover task 中创建 launch owner、Practice 容器与窗口生命周期，同时删除 Library 自动 preparation、配置 Ornament、旧状态、旧测试和旧文档描述。Phase 末只补竞态与调用图 gate，不承担延迟清理。

**Acceptance:**
- production 无 `SongLibraryIndexStoreProtocol.save(_:)`，bootstrap 与 ViewModel 使用同一个 store/provider 实例。
- `SongLibraryViewModel.selectedEntryID` 是唯一 selection，View 无第二份 `@State`。
- Library selection、restore、playback 和主内容不可达 score resolve/preparation/session mutation。
- request registration 不做 IO；Practice scene active 后才 resolve/prepare。
- explicit return/new activation 清空所有 song-specific prepared state但保留 calibration/piano mode。
- 旧 Library preparation/configuration views/models/tests/docs 在 cutover task 内删除或迁移。

**Rules:**
- 任一 task 引入替代 API 时，同 task 删除被替代 API/调用/测试入口。
- 不用 compatibility facade 把旧 `SongLibraryViewModel` preparation API转发到新 owner。
- selection persistence 与 snapshot/preparation generation 不共用 generation。
- Library 主按钮属于内容操作，不因 AVP Ornament chrome 规则被挪入 Ornament。
- MainActor 不执行 index JSON IO、score IO 或 parsing。
- 所有修改过的业务诊断走 `DiagnosticsReporting`。

**State / lifecycle:**
- Selection owner：`SongLibraryViewModel`。
- Launch owner：P1-T7 后为 `PracticeLaunchViewModel`。
- Registration：Library synchronous request only。
- Activation：Practice root + active scene。
- Suspend：scene 非 active，request 保留为 requested。
- Clear：新 activation 前、retry 前、显式 return、unexpected disappear；清除 song-specific state。

**Threading / actor:**
- index read-modify-write 在 `SongLibraryIndexStore` actor。
- bootstrap loader actor只协调共享 store/provider。
- `PracticeLaunchViewModel` 为 `@MainActor @Observable`，只编排异步 service。
- `PracticePreparationService` 保持 actor；score resolution 通过 async service，不回到 Library MainActor 做文件 IO。

**Debug / observability:**
- failure mapping保持具体 parser/MXL/structure code与安全相对路径。
- request stale/cancel/suspend不写用户错误。
- invalid saved configuration、resolve/prepare failure使用 typed code；不记录绝对 URL。

**Testing strategy:**
- 每个 store mutation 使用 actor fake/临时 JSON测试并发保留语义。
- launch 使用 fake resolver、fake preparation、recording ARGuide adapter、controllable continuation。
- 旧 Library tests 中仍有效的行为必须先迁移到新 owner/selection tests，再删除旧文件。
- Apple target验证只使用 `xcodebuild`；本 phase audit需另做 CodeGraph调用路径检查。

---

## P1-T1 用 actor concern mutation 替换整份 index save 并共享 bootstrap 实例

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift`
- Modify: `HappyPianistAVP/Services/Library/BundledSongLibraryProvider.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryProgressCleanupTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift`
- Create: `HappyPianistAVPTests/Library/BundledSongLibraryProviderTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/architecture.md`

**Step 1: 用 concern-specific mutation 原子替换 public save**

把 protocol 收口为 `load` 加 actor 内 mutation，至少包括：

- `setLastSelectedEntryID(_:) -> SongLibraryIndex`
- `appendUserEntry(_:) -> SongLibraryIndex`
- `removeUserEntry(id:fallbackLastSelectedEntryID:) -> SongLibraryEntryMutationResult`
- `updateAudioFileName(entryID:expectedCurrentFileName:newFileName:) -> SongLibraryEntryMutationResult`

每个方法必须在 actor 内 load latest document、只修改一个 concern、atomic write并返回最新 index/实际 entry。删除 protocol、production、fake 的 `save(_:)`，不保留同名 overload、adapter 或“临时”整份写入口。

**Step 2: 同 task 迁移全部现有 callers并删除旧 snapshot 计算**

- timestamp score import 暂时使用 `appendUserEntry`；P3-T2 在引入事务 actor时同 task删除旧 import方法。
- delete 使用 store 返回的磁盘实际 removed entry，再清 progress/score/audio；不再用 ViewModel cached index决定要删的文件。
- audio binding 使用 expected old audio filename；index commit后才删除旧 audio，失败删除新 audio。
- 当前 selection persistence 使用 `setLastSelectedEntryID`，P1-T2 再收口 selection UI/generation。

Run: `rg -n "indexStore\\.save|func save\\(_ index: SongLibraryIndex" HappyPianistAVP HappyPianistAVPTests`

Expected: production、protocol与fake零命中。

**Step 3: 注入唯一 bootstrap store/provider**

`LiveSongLibraryBootstrapLoader` 增加 init injection并删除内部 `SongLibraryIndexStore()`/`BundledSongLibraryProvider()`。`BundledSongLibraryProviderProtocol` 同 task 标记 `Sendable`，使同一provider值可安全注入bootstrap actor与后续resolver；不得用 `@unchecked Sendable` 包装可变共享状态。`LiveAppGraph` 把同一个 index actor与bundled provider实例同时注入 loader、ViewModel及后续resolver。不得用第二actor访问同一index JSON。

**Step 4: 测试 actor mutation 与共享实例**

覆盖：

- selection mutation与append交错不丢entry；
- selection与audio update交错不丢audio/last-selected；
- remove返回磁盘实际entry并保持其余顺序；
- expected audio filename不匹配时拒绝覆盖；
- bootstrap loader与ViewModel recording store/provider是同一注入实例；
- bundled ID可保存为last-selected，即使不在user entries数组。

**Step 5: 同步 canonical docs**

storage/data-flow/architecture立即改为actor concern mutation + shared store/provider。不得保留“ViewModel load snapshot后save整份index”的当前描述。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: mutation与bootstrap tests通过；whole-index save API不存在。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift HappyPianistAVP/Services/Library/BundledSongLibraryProvider.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift HappyPianistAVPTests/Library/SongLibraryProgressCleanupTests.swift HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift HappyPianistAVPTests/Library/BundledSongLibraryProviderTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift docs/storage.md docs/data-flow.md docs/architecture.md`

Run: `git commit -m "refactor: P1-T1 - 收口曲库索引原子写入"`

---

## P1-T2 建立唯一 Library selection 与独立 persistence generation

**Files:**
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryCrateView.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Create: `HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`

**Step 1: ViewModel成为唯一 selection owner**

新增 `private(set) var selectedEntryID: UUID?`，并在同 task删除 `selectedPracticeEntryID`。P1-T7 cutover前仍存在的旧preparation state/guards临时改读 `selectedEntryID`；不得在ViewModel内部保留第二份选择。

bootstrap完成后由ViewModel从last-selected/first-entry解析合法selection。import/delete后只通过一个helper选择fallback；bundled ID允许成为selection。

**Step 2: selection persistence使用独立 generation**

`selectEntry(_:)` 固定执行：验证entry -> 切歌时停止试听 -> 立即发布selection -> 递增selection generation -> debounce调用P1-T1 `setLastSelectedEntryID`。旧preparation generation不得参与保存guard。

增加 `flushPendingSelectionPersistence()`：取消delay并保存当前selection。Library disappear只通过MainActor Task调用；graph持有VM，所以View销毁不得丢失最终保存。delete/import使selection失效时递增generation，旧await结果不能覆盖新fallback。保存失败只展示错误，不回滚内存selection。

**Step 3: 删除 View 与 crate 的 selection 双真源**

删除 `SongLibraryView.@State selectedEntryID` 与 `synchronizeSelection()`。`LibraryCrateView` 改为只读selected ID + `onSelectEntry(UUID)` intent；Button、drag、record tap、上一首/下一首与VoiceOver adjustable action全部只调用该closure。不得同时使用Binding setter和回调造成双写。

**Step 4: 测试所有selection入口与竞态**

覆盖 A->B->A只持久化最终A、disappear flush、保存失败不回退、delete使旧generation失效、bootstrap invalid ID fallback、bundled last-selected、drag/VoiceOver/上一首下一首共享同一intent。旧preparation tests只保留cutover前必要断言，并改读新selection；P1-T7删除旧preparation test文件。

**Step 5: 同步 docs并验证**

Run: `rg -n "@State private var selectedEntryID|selectedPracticeEntryID|synchronizeSelection" HappyPianistAVP HappyPianistAVPTests`

Expected: 三个旧selection符号零命中。

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: selection tests通过，View无本地selection状态。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/SongLibraryView.swift HappyPianistAVP/Views/Library/LibraryCrateView.swift HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift docs/data-flow.md docs/modules/happypianist-avp.md`

Run: `git commit -m "refactor: P1-T2 - 统一曲库选择状态"`

---

## P1-T3 将现有曲库文件 IO 移出 MainActor 并删除同步接口

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongFileStore.swift`
- Modify: `HappyPianistAVP/Services/Library/AudioImportService.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `HappyPianistAVPTests/Library/SongFileStoreTests.swift`
- Modify: `HappyPianistAVPTests/Audio/AudioImportServiceTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryViewModelListeningStateTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryFileIOIsolationTests.swift`
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`

**Step 1: 把同步文件服务替换为 actor 隔离的 async API**

`SongFileStoreProtocol` 与 `AudioImportServiceProtocol` 改为 `Sendable` async requirements；production `SongFileStore`、`AudioImportService` 改为 actor，由 actor 独占 `FileManager`、`SongLibraryPaths` 与 clock。所有会查询 Documents、创建目录、复制、删除或解析 security scope 的方法均为 async actor hop；不使用 `Task.detached`、GCD 或 `nonisolated(unsafe)` 绕开隔离。

同 task 删除全部同步 requirements/implementations/fakes，禁止保留同名 sync overload 或 compatibility adapter。测试 clock 使用 `@Sendable` closure或actor-owned deterministic value，满足 Swift 6 strict concurrency。

**Step 2: 迁移全部现有调用者并防止 await 后使用陈旧状态**

- MusicXML import、delete、audio bind及失败补偿全部 `await` 文件服务；index 提交继续使用 P1-T1 已建立的 concern-specific mutation。
- 当前 Library preparation 在 P1-T5 resolver 接管前，临时通过 `await fileStore.scoreFileURL` 获取用户曲谱 URL；P1-T5 同 task 删除该直接调用。
- `didTapListen(entryID:)` 改为 async。用户曲目 URL resolve 返回 MainActor 后，必须重新确认该 entry 仍存在且 `audioFileName` 仍等于请求时值，再调用现有 MainActor playback controller；stale 结果静默丢弃。
- `SongLibraryView` 的 listen action 只创建 MainActor `Task` await ViewModel intent；Button 本身不直接访问文件服务。
- import/delete/audio bind 的补偿删除也必须 await，且失败只更新已有安全错误/diagnostic，不记录绝对路径。

**Step 3: 迁移 tests/fakes并立即删除旧同步假实现**

把 `SongFileStoreTests`、`AudioImportServiceTests` 改为 async tests。所有 `SongFileStoreProtocol`/`AudioImportServiceProtocol` fake改为 actor或明确 Sendable async fake；删除同步 fake methods。

`SongLibraryFileIOIsolationTests` 使用可控 continuation 验证：

- audio URL resolve suspend期间 MainActor仍可处理选择变化；旧结果不会启动播放；
- async import完成后才提交index，copy失败不append；
- audio index commit失败会await删除新文件；成功后才删除旧文件；
- delete先依据P1-T1 actor返回的实际entry，再异步删对应score/audio，不使用旧ViewModel snapshot。

**Step 4: 同步 canonical docs**

`architecture.md` 与 `data-flow.md` 立即标明 Library ViewModel只在MainActor编排，所有Documents/security-scope/copy/delete通过actor服务执行。不得等P3事务阶段再修正文档；P3只替换score import实现，不重新引入MainActor IO。

**Step 5: 验证**

Run: `rg -n "func (importMusicXML|scoreFileURL|audioFileURL|deleteScoreFile|deleteAudioFile|importAudio).*throws" HappyPianistAVP HappyPianistAVPTests`

Expected: 所有协议、production与fake签名均含`async throws`；无同步overload。

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 文件服务测试通过；stale await结果不会触发播放或错误index mutation。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Services/Library/SongFileStore.swift HappyPianistAVP/Services/Library/AudioImportService.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/SongLibraryView.swift HappyPianistAVPTests/Library/SongFileStoreTests.swift HappyPianistAVPTests/Audio/AudioImportServiceTests.swift HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift HappyPianistAVPTests/Library/SongLibraryViewModelListeningStateTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Library/SongLibraryFileIOIsolationTests.swift docs/architecture.md docs/data-flow.md`

Run: `git commit -m "refactor: P1-T3 - 将曲库文件IO移出主线程"`

---

## P1-T4 原子迁移 typed preparation failure 到 Practice 命名空间

**Files:**
- Create: `HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift`
- Modify: `HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryPracticeFailureView.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticePreparationFailureTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`

**Step 1: 移动而非复制 failure model**

在 Practice model中定义 `PracticeLaunchFailure` 与未来 request/state所需最小纯模型。把现有完整 typed mapping移动过去；同 task 从 `LibraryPracticePreparationModels.swift` 删除 `LibraryPracticePreparationFailure`。旧 Library preparation state临时改为持有 `PracticeLaunchFailure`，不得同时保留两个结构。

**Step 2: 保持错误 taxonomy 与隐私**

复用现有 `PracticePreparationError`、`DiagnosticCategory.practicePreparation` 与既有 `DiagnosticCode.practice*` 分类；本task不新增重复launch-specific code。`DiagnosticFileReference`只允许 `Bundle/<name>` 或 `SongLibrary/scores/<name>`；unexpected reason使用safe summary。

**Step 3: 立即迁移所有 callers/views/tests**

- current `SongLibraryViewModel` failure mapping改用新类型；
- current Library failure view临时渲染新类型，P1-T7随旧UI删除；
- 把旧 failure test全部迁到 `PracticeLaunchFailureTests.swift`；
- `SongLibraryPracticePreparationTests` 中 diagnostics assertions改用新类型。

运行 `rg "LibraryPracticePreparationFailure"` 必须零命中。

**Step 4: 验证**

覆盖 file missing、unreadable、MXL各错误、XML line/column、no notes、missing structure、unexpected、technical text与diagnostic一致、绝对路径不泄漏。

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: mapping tests通过，旧类型/测试文件不存在。

**Step 5: 原子提交**

Run: `git add -A HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift HappyPianistAVP/Views/Library/LibraryPracticeFailureView.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift HappyPianistAVPTests/Library/LibraryPracticePreparationFailureTests.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`

Run: `git commit -m "refactor: P1-T4 - 将准备失败模型迁入练习域"`

---

## P1-T5 抽取并立即接入共享 entry/score resolver

**Files:**
- Create: `HappyPianistAVP/Services/Library/SongLibraryEntryResolver.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryEntryResolverTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`

**Step 1: 定义窄 `Sendable` async resolver 协议与结果**

在同一文件定义仅供 launch/当前过渡 consumer 使用的 `SongLibraryEntryResolving: Sendable`；production 采用 actor 实现，测试使用显式 actor fake，不用 `@unchecked Sendable`。结果包含当前 `SongLibraryEntry` snapshot、score URL、安全 diagnostic file reference；不包含prepared data。resolver通过共享 index store + bundled provider + file store按 songID解析：

- bundled从provider entries查找并解析bundle URL；
- user从最新index查找再解析Documents URL；
- missing entry/file与不可读路径映射具体 preparation error。

不要缓存entry或URL，replacement后下一次activation必须读取最新index。

**Step 2: 立即替换当前内联 resolve代码**

当前 Library `prepareSelectedEntry` 改为调用resolver；删除其中 bundled/user分支、score URL构造和diagnostic reference helper。新文件创建当日即被生产consumer使用，不留孤立服务。

**Step 3: composition root复用实例**

`LiveAppGraph`用P1-T1共享的 index/provider/file store创建resolver，先注入当前 Library VM；P1-T7同一resolver转交launch owner。不要创建第二份store/provider。

**Step 4: 测试**

覆盖 bundled/user resolve、latest index读取、missing entry、missing bundled URL、user file path error、同display name不同ID、相对diagnostic path、每次调用不缓存旧entry。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: current preparation tests继续通过；ViewModel不再直接构造score URL。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Services/Library/SongLibraryEntryResolver.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVPTests/Library/SongLibraryEntryResolverTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`

Run: `git commit -m "refactor: P1-T5 - 抽取曲目解析边界"`

---

## P1-T6 增加保留校准的 prepared-song teardown

**Files:**
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift`
- Modify: `HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSessionViewModelTests.swift`
- Create: `HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`

**Step 1: 定义 song-specific clear API**

在 session增加精确方法，停止manual replay/autoplay/audio recognition/input并清除：song identity、progress generation/session progress、steps、tempo/maps、measure spans、round configuration、highlight/feedback与current step。必须保留 calibration、keyboard geometry、selected piano mode、service instances与非曲谱设置。

不要用现有 `resetSession()` 代替；它会清除校准。保留 `resetSession()` 给原有调用者，除非调用图证明可安全统一，否则不做无关重构。

**Step 2: ARGuide统一清理**

增加 async `clearPreparedPracticeForLaunch()`（最终命名按现有风格）：

1. 使 `preparedPracticeApplicationID` 失效；
2. flush当前progress但不shutdown reusable session；
3. 调用song-specific clear；
4. `latestPreparedPractice = nil`；
5. `practiceSetupState.clearSongAndSteps()`；
6. 清除与旧曲谱相关的feedback/autoplay presentation。

方法重复调用幂等；stale apply continuation不能在clear后重新写入setup/latest。

**Step 3: 测试复活路径**

覆盖：

- clear后session无song/steps/config/progress；
- calibration/keyboard geometry仍存在；
- clear后`replacePracticeSessionViewModel()`不会重新安装旧`latestPreparedPractice`；
- apply正在await progress时clear，旧prepared不能落盘为latest/setup；
- repeated clear安全。

**Step 4: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: song-specific与calibration assertions均通过。

**Step 5: 原子提交**

Run: `git add HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift HappyPianistAVPTests/Practice/PracticeSessionViewModelTests.swift HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`

Run: `git commit -m "feat: P1-T6 - 增加练习曲谱精确清理生命周期"`

---

## P1-T7 原子切换 Practice launch owner 并删除 Library preparation/configuration

**Files:**
- Modify: `HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift`
- Create: `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`
- Create: `HappyPianistAVP/Views/Practice/PracticeLaunchContainerView.swift`
- Create: `HappyPianistAVP/Views/Practice/PracticeLaunchFailureView.swift`
- Modify: `HappyPianistAVP/Views/Practice/PracticeWindowRootView.swift`
- Modify: `HappyPianistAVP/Views/Practice/PracticeStepView.swift`
- Modify: `HappyPianistAVP/Views/HappyPianistAVPApp.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeOrnamentView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeFailureView.swift`
- Delete: `HappyPianistAVP/Views/Library/LibraryPracticeSkeletonView.swift`
- Delete: `HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Create: `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`
- Delete: `HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticeConfigurationTests.swift`
- Delete: `HappyPianistAVPTests/Library/LibraryPracticePresentationTests.swift`
- Modify: `README.md`
- Modify: `docs/overview.md`
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`
- Modify: `docs/modules/happypianist-avp-practice.md`
- Modify: `docs/testing/core-function-checklist.md`

**Step 1: 实现唯一 launch state machine**

`PracticeLaunchViewModel`为`@MainActor @Observable`，注入P1-T5 resolver、preparation actor、窄 `PracticeLaunchApplying: Sendable` 边界与diagnostics。该边界只暴露 launch 所需的 apply、song-specific clear、suspend/flush 与 full leave；`ARGuideViewModel`在同task直接遵循，测试使用recording fake，不把整个具体类型塞入owner。状态至少：noRequest、requested、loading(songID)、failure、ready(identity)、suspended/requested等价表达。

- `request(songID:)`：取消旧task、递增generation、只登记request并隐藏旧presentation；零IO/ARGuide调用。
- `activateCurrentRequest()`：同request重复loading/ready不重复；先P1-T6 flush/clear旧song，再resolve -> prepare ->验证steps/spans -> apply ->验证当前generation -> ready。
- `retry()`：同song新generation并重新activation。
- `suspendForInactiveScene()`：取消prepare、保留request并回到requested，沿用ARGuide suspend/flush。
- `beginReturn()`：同步取消task、递增generation、清request并发布noRequest，返回唯一return operation ID；零IO/ARGuide调用。
- `finishReturn(operationID:)`：仅当前operation可调用P1-T6 song-specific clear；重复或stale operation幂等退出。root负责immersive/window，launch owner负责request与prepared-song clear，二者不得各自再清一次。

**Step 2: 处理有效exact restore与无效配置**

保留现有exact identity恢复。`restoreProgressIfAvailable`之后若saved passage不能建立active range或diagnostic存在，必须清除该invalid configuration/resume并安装当前prepared score的fresh full passage；记录typed diagnostic，但launch可ready。把旧 `LibraryPracticeConfigurationTests` 的fresh defaults、exact config/resume、revision mismatch全部迁到launch/session测试后再删除旧文件。

**Step 3: Practice root成为唯一activation owner**

`PracticeLaunchContainerView`按state呈现：

- no request/requested/loading/failure不得挂载旧`PracticeStepView`；
- failure提供technical details、retry、return；
- ready才挂载`PracticeStepView`。

Practice root在`.task(id: request identity)`和scene active边界调用activate。scene inactive走suspend；active重新activate requested。

`PracticeStepView`保留现有ready后打开immersive的职责，因为它同时拥有本地autoplay与virtual-piano presentation状态；不要把这些UI状态复制到root。它必须删除`isLeavingPractice`与`leavePractice(shouldNavigateBack:)`，toolbar/summary只发出return intent。`.onDisappear`只取消feedback并处理“open请求完成时view已不可见”的局部close保护，不得调用`leavePracticeStep`、清session或导航。

`PracticeWindowRootView`成为唯一leave/close/recover/window owner。离开ready、retry、显式返回或unexpected disappear时，root用单一operation ID执行：`beginReturn()`同步失效launch generation -> await `ARGuideViewModel.leavePracticeStep()` -> close/recover immersive -> await `finishReturn(operationID:)`清song-specific state -> 再begin transition/open Library。scene inactive只调用launch suspend/flush并保留request，不走return。不得依赖`pendingTransition == nil`跳过teardown；重复`.onDisappear`必须因operation ID幂等退出。

`PracticeStepView`可以保留`dismissImmersiveSpace`仅用于其尚未完成的open任务在view消失后自我收尾；该局部分支不得再调用full leave。root与child的close路径通过同一immersive state幂等，测试必须证明close/leave各至多一次。

**Step 4: Library只登记request并提供唯一按钮**

从`SongLibraryViewModel`删除：ARGuide、preparation service/resolver、preparation task/generation/state、progress dictionary、prepared session/config/presentation、retry/cancel/start methods及相关constructor参数。

`SongLibraryView`删除自动prepare、reloadPracticeProgress、配置Ornament与onDisappear cancel。选曲只走P1-T2轻量selection。

把当前crate与track info主内容包进`ZStack(alignment: .bottomTrailing)`（不是scene根overlay），加入`Button("开始练习", systemImage: ...)`。使用Dynamic Type/system spacing、`buttonBorderShape`与可访问文本；不遮挡track playback/seek。按钮回调把当前songID传给`LibraryWindowRootView`，严格执行request -> transition -> open，不等待save。

P2之前右侧不显示Ornament；不要留静态假进度或隐藏旧配置分支。

**Step 5: 同 task 删除旧UI/model/test并迁移有效测试**

删除列出的Library files前，明确迁移：

- `latestPreparationGenerationWins`、missing spans、stale apply、failure diagnostic -> `PracticeLaunchViewModelTests`；
- rapid selection/persistence failure/cancel settle -> `SongLibrarySelectionPersistenceTests`；
- direct launch saved resume/edited pending config、fresh defaults、exact restore、revision mismatch、A-B-A drafts -> Practice launch/session tests；
- old `LibraryPracticePanelPresentation`、measure option与配置Ornament专属tests随被删除实现删除；P2以新snapshot facts tests替代，不复制旧UI presentation。

运行以下symbols必须零命中：

- `LibraryPracticePreparationState`
- `LibraryPracticePanelPresentation`
- `selectEntryForPractice`
- `prepareSelectedEntry`
- `startSelectedPractice`
- `preparedRoundConfigurationController`
- `LibraryPracticeOrnamentView`

**Step 6: 同 task更新 composition与canonical docs**

`LiveAppGraph`只创建一个launch owner并暴露给Practice/Library roots；`HappyPianistAVPApp`注入同一实例。README与全部列出的canonical docs立即移除“选择自动prepare”“右侧设置”“去练习！”并写入新activation边界、唯一按钮和暂时无进度Ornament的phase状态。人工清单同步更新，不留到P1-T8。

**Step 7: 测试**

覆盖：

- registration prepare count 0；activation后1；
- A->B->A only latest ready；
- no request/loading/failure不访问PracticeStepView/session presentation；
- loading scene inactive -> requested，active后重新prepare；
- explicit return/unexpected disappear clear且ARGuide leave/immersive close各一次；
- ready->loading/retry移除`PracticeStepView`时不会触发第二套leave或保留旧immersive；
- failure retry新ID；cancel/stale不记录failure；
- start selection save pending/failed仍使用内存songID；
- exact resume/config与invalid passage fallback；
- Library spy resolver/preparation/ARGuide call count恒为0。

**Step 8: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Expected: 全套测试编译通过；旧symbols/files不存在；Library调用图无法到达prepare/apply。

**Step 9: 原子提交**

Run: `git add -A HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift HappyPianistAVP/ViewModels/ARGuide/ARGuideViewModel.swift HappyPianistAVP/Views/Practice/PracticeLaunchContainerView.swift HappyPianistAVP/Views/Practice/PracticeLaunchFailureView.swift HappyPianistAVP/Views/Practice/PracticeWindowRootView.swift HappyPianistAVP/Views/Practice/PracticeStepView.swift HappyPianistAVP/Views/HappyPianistAVPApp.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/Views/Library/LibraryWindowView.swift HappyPianistAVP/Views/Library/SongLibraryView.swift HappyPianistAVP/Views/Library/LibraryPracticeOrnamentView.swift HappyPianistAVP/Views/Library/LibraryPracticeFailureView.swift HappyPianistAVP/Views/Library/LibraryPracticeSkeletonView.swift HappyPianistAVP/Models/Library/LibraryPracticePreparationModels.swift HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift HappyPianistAVPTests/Library/SongLibraryPracticePreparationTests.swift HappyPianistAVPTests/Library/LibraryPracticeConfigurationTests.swift HappyPianistAVPTests/Library/LibraryPracticePresentationTests.swift HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift README.md docs/overview.md docs/architecture.md docs/data-flow.md docs/modules/happypianist-avp.md docs/modules/happypianist-avp-practice.md docs/testing/core-function-checklist.md`

Run: `git commit -m "refactor: P1-T7 - 将曲谱准备原子迁入练习窗口"`

---

## P1-T8 完成启动竞态、布局证据与 phase gate

**Files:**
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift`
- Modify: `HappyPianistAVPTests/Window/WindowCoordinatorTests.swift`
- Modify: `docs/testing/core-function-checklist.md`

本task只把新执行的证据/状态写入清单，不把行为文档延迟到gate。

**Step 1: 补跨边界race matrix**

加入controllable continuations覆盖：resolve期间新request、prepare期间return、apply progress restore期间scene inactive、metadata尚未存在、session replacement、连续retry。每个case断言旧generation不ready、不泄漏setup/latest/session。

**Step 2: 静态调用图gate**

Run: `codegraph sync`

Run: `codegraph explore "Library selection restore playback ornament callers PracticePreparationService applyPreparedPractice scoreFileURL"`

Expected: Library browse路径没有prepare/apply/score read；唯一边界为Library request registration到Practice root activation。

Run: `rg -n "LibraryPractice|selectEntryForPractice|startSelectedPractice|preparedRoundConfigurationController" HappyPianistAVP HappyPianistAVPTests README.md docs`

Expected: 只允许明确历史文字（若有）；production与current docs零旧实现symbol。

**Step 3: Apple target gate**

Run: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=latest' CODE_SIGNING_ALLOWED=NO`

**Step 4: Simulator/人工证据**

检查按钮在主内容右下角、窗口最小/理想/最大尺寸不遮挡播放控制、VoiceOver名称与hint、键盘/间接输入、Practice loading/failure/retry/return、scene inactive恢复。未执行项在清单标`Not Run`，不能写Pass。

**Step 5: 原子提交**

Run: `git add HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift HappyPianistAVPTests/Library/SongLibrarySelectionPersistenceTests.swift HappyPianistAVPTests/Window/WindowCoordinatorTests.swift docs/testing/core-function-checklist.md`

Run: `git commit -m "test: P1-T8 - 验证练习启动所有权与窗口竞态"`

---

## Phase Audit

- Audit file: `audit-p1.md`
- Rule: 全部task完成后由`executing-plans`自动进入审计闭环。
- Audit focus:
  1. `save(_:)`、第二store实例、View selection双真源是否彻底消失。
  2. 每个替代task是否同commit删除旧API/state/tests/docs，无compat facade。
  3. Library所有selection入口是否只做轻量状态/persistence。
  4. request registration与activation是否严格分离。
  5. clear是否覆盖latest/setup/application/session且保留校准。
  6. scene inactive与explicit return是否语义不同且无旧session泄漏。
  7. MainActor IO、diagnostic privacy与full `xcodebuild` gate。
