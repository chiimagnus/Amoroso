# Plan P3 - library-practice-entry-redesign

**Goal:** 保留用户曲谱原始完整文件名，并用单 actor、条件 index mutation 与持久化 journal 实现可确认、可回滚、可恢复的同名导入替换。

**Non-goals:** 不迁移或重命名已有时间戳文件，不允许替换 bundled 曲谱，不修复无关的音频导入架构，不建立长期 security-scoped bookmark，不删除旧 revision progress。

**Approach:** 先建立文件名/冲突与 transaction recovery 的纯模型和可故障注入策略，再把 index store 收口为 actor 内原子 mutation。随后在一个原子 task 中创建完整 `SongLibraryImportTransactionService` actor，并同时接入 bootstrap、ViewModel、UI 与 composition root，删除旧时间戳 import API。最后补上 replacement 后“只恢复通用偏好、范围全曲、无旧 resume/facts”的 Practice 规则和全故障矩阵。

**Acceptance:**
- 新导入保存名等于安全化后的 `sourceURL.lastPathComponent`，不添加时间戳或 UUID 后缀。
- `.musicxml`、`.xml`、`.mxl` 多选导入按顺序处理；exact/case/Unicode 冲突按目标卷实际语义逐项确认。
- 确认前不修改 target、index 或 progress；取消当前冲突项后继续队列。
- replacement 保留 songID、顺序、displayName、last-selected、audio、旧 progress，更新 importedAt 与非 nil scoreFileVersionID。
- stage/replace/index commit/cleanup 任一失败或进程中断后，bootstrap recovery 不发布 index 指向缺失文件的 snapshot。
- index 已提交新 token 后 cleanup failure 不回滚新版本，只保留 journal 等待下次清理。
- replacement 后 exact revision 缺失时只恢复 hand/tempo/loop/requiredSuccesses，passage 全曲、resume/facts 清空。

**Rules:**
- import/replace 文件 IO、security-scoped lease、journal 与跨文件提交由同一 actor 实例串行化。
- ViewModel 只持有 UI-safe pending conflict ID/文案，不长期持有 source URL 或 lease。
- pending source lease 必须在 confirm、cancel、failure、Library disappear、队列结束的每条路径释放。
- replacement 提交前不得删除旧文件；必须 same-volume stage + backup。
- index replacement 必须校验 expected songID 与 expected scoreFileVersionID，防止并发选择/音频/删除覆盖。
- progress 不参与文件/index transaction，旧 progress/metadata 保留，由 version mismatch 自然隔离。
- bundled entries 永远不能进入 replacement transaction。
- 不允许调用方再用旧 index snapshot 整份 `save`。

**State / lifecycle:**
- Queue owner：`SongLibraryViewModel` 或专用 MainActor coordinator，顺序处理用户本次多选。
- Transaction owner：`SongLibraryImportTransactionService` actor。
- Inspect：actor 立即取得 session-scoped lease，验证扩展名/安全文件名/冲突。
- Await confirmation：actor 保留 pending operation 与 lease；UI 只持 operation ID。
- Commit：stage → journal → backup/target swap → conditional index mutation → cleanup。
- Cancel/teardown：取消 pending/current operation，恢复/清理临时状态，释放 lease，继续或结束队列。
- Bootstrap：recovery 完成后才能读取并发布 index snapshot。

**Threading / actor:**
- FileManager copy/move/remove、journal JSON、index mutation、security-scoped start/stop 都不在 MainActor。
- UI confirmation 与队列 presentation 在 MainActor；每次 await 返回后检查 queue generation。
- 不使用 `Task.detached` 逃避隔离；长操作支持 cancellation checkpoints。

**Debug / observability:**
- 为 access、conflict、stage、backup、target replace、index commit、cleanup、recovery 定义 typed diagnostic code/stage。
- 可导出日志只包含 songID、operation ID、相对文件名、token 和 phase，不含绝对路径或原始曲谱。
- cleanup warning 与 rollback failure 必须区分；recovery failure 阻止 snapshot 发布。

**Testing strategy:**
- 使用 temporary directory、fake security-scope provider、deterministic clock/UUID、fault-injecting file system/index store。
- 每个 transaction phase 都有 before/after crash fixture；不依赖真实进程崩溃即可重建 service 并运行 recovery。
- 使用目标临时卷真实目录覆盖 exact/case/Unicode 文件名 lookup；不硬编码假设某个开发机卷一定大小写敏感或不敏感。
- Simulator/实机人工验证真实 fileImporter security-scoped URL、确认文案、快速离开窗口与多选队列。

---

## P3-T1 定义原名、冲突与导入队列纯模型

**Files:**
- Create: `HappyPianistAVP/Models/Library/SongLibraryImportModels.swift`
- Create: `HappyPianistAVP/Services/Library/SongLibraryFileNamePolicy.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryFileNamePolicyTests.swift`

**Step 1: 定义安全原名规则**

保存名只使用 `sourceURL.lastPathComponent` 经路径分量安全化后的结果；保留扩展名和用户可见字符。拒绝空文件名、目录分量、非支持扩展名；不追加时间、随机数或 songID。

**Step 2: 定义 UI-safe operation models**

定义 import operation ID、source display name、conflicting songID/displayName、kind（new/replace）、pending confirmation 与队列 outcome。模型不得暴露长期 URL、FileHandle 或 lease。

**Step 3: 定义目标卷冲突检查边界**

冲突检查同时考虑用户 index 与目标 scores 目录。生产 policy 通过目标目录实际 lookup/resource values 判断 proposed name 是否可与已有项共存；不要仅用 `.lowercased()`。bundled entry 只可作为“不可替换”来源提示，不进入用户 target conflict。

**Step 4: 测试**

覆盖 `.musicxml/.xml/.mxl`、路径穿越安全化、exact conflict、case variant、precomposed/decomposed Unicode、缺失 target 文件但 index 仍有条目、目录已有 orphan 文件、bundled 不可替换。测试根据临时卷能力断言“实际可共存结果”，不假定固定大小写语义。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: filename policy 不生成后缀；冲突测试与临时卷实际行为一致。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongLibraryImportModels.swift HappyPianistAVP/Services/Library/SongLibraryFileNamePolicy.swift HappyPianistAVPTests/Library/SongLibraryFileNamePolicyTests.swift`

Run: `git commit -m "feat: P3-T1 - 定义原名导入与文件冲突规则"`

---

## P3-T2 收口 SongLibraryIndexStore 为 actor 内原子 mutation

**Files:**
- Modify: `HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryIndexStoreTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryEntriesTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryProgressCleanupTests.swift`
- Modify: `HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`

**Step 1: 增加原子 mutation API**

在现有 last-selected mutation 基础上增加：
- append new entry；
- remove user entry；
- update audio binding；
- conditionally replace entry（expected songID + expected current fileVersion/token）；
- 提供 bootstrap/recovery 使用的条件 mutation，只接受 expected songID/token，不开放整份 save。

每个方法在 actor 内 load latest → mutate one concern → atomic write → return updated index/entry。

**Step 2: 删除公开整份 save**

`SongLibraryIndexStoreProtocol` 不再允许业务调用方传 `SongLibraryIndex` 整份覆盖。保留私有 encode/write helper。更新所有 production callers 与 fakes。

**Step 3: 迁移现有选择/删除/音频/旧导入 append**

P3-T4 替换 import service 前，旧 import path 临时改用 append mutation；selection/delete/audio 全部使用对应 actor API。删除时返回被删 entry 供后续文件/progress cleanup，避免使用 stale index 计算。

**Step 4: 条件 replacement 语义测试**

测试并发 last-selected、audio binding 与 append 不丢字段；expected token mismatch 拒绝 replacement；remove 不影响其他条目顺序；legacy nil token 可作为 expected nil；bundled 不在用户 index mutation。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 业务代码不再调用整份 `save`；并发 mutation tests 无字段丢失。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Services/Library/SongLibraryIndexStore.swift HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVPTests/Library HappyPianistAVPTests/Support/SongLibraryViewModelTestHarness.swift`

Run: `git commit -m "refactor: P3-T2 - 将曲库索引改为原子字段级更新"`

---

## P3-T3 定义 transaction journal 与确定性 recovery planner

**Files:**
- Create: `HappyPianistAVP/Models/Library/SongLibraryImportTransactionModels.swift`
- Create: `HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryPaths.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryPlannerTests.swift`

**Step 1: 定义持久化 journal schema**

journal 至少记录：operation ID、new/replace kind、songID、expected old token、新 token、target/temp/backup 相对文件名、phase、创建时间。只记录 App 相对路径分量，不记录 security-scoped source URL。

**Step 2: 定义 recovery 事实输入**

planner 输入必须包括 index 当前 entry/token、target/temp/backup 是否存在和 journal operation kind。journal phase 只是提示，事实优先。

**Step 3: 实现纯 recovery 决策**

- replacement：index 未提交新 token → 恢复 backup；index 已提交 → 保留 target，清理 backup/temp/journal。
- new import：index 未包含新 entry/token → 删除 orphan target/temp；index 已提交 → 保留 target并清理。
- target 缺失但 index 已提交且 backup 可用：按 journal/token 规则恢复或判定不可安全发布。
- 事实矛盾且无法无损决定：返回 blocking failure，bootstrap 不发布 snapshot。

**Step 4: 测试完整矩阵**

对每个 phase 构造 before/after crash 事实，覆盖 cleanup failure、missing backup、stale journal、token mismatch、重复 recovery 幂等。

**Step 5: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: recovery planner 为纯确定性函数，重复执行同一事实不会改变结论。

**Step 6: 原子提交**

Run: `git add HappyPianistAVP/Models/Library/SongLibraryImportTransactionModels.swift HappyPianistAVP/Services/Library/SongLibraryTransactionRecoveryPlanner.swift HappyPianistAVP/Services/Library/SongLibraryPaths.swift HappyPianistAVPTests/Library/SongLibraryTransactionRecoveryPlannerTests.swift`

Run: `git commit -m "feat: P3-T3 - 定义曲库导入事务与恢复决策"`

---

## P3-T4 原子接入 import/replace actor、确认队列与 bootstrap recovery

**Files:**
- Create: `HappyPianistAVP/Services/Library/SongLibraryImportTransactionService.swift`
- Create: `HappyPianistAVP/Services/Library/SecurityScopedResourceLease.swift`
- Modify: `HappyPianistAVP/Services/Library/SongFileStore.swift`
- Modify: `HappyPianistAVP/Services/Library/SongLibraryBootstrapLoader.swift`
- Modify: `HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift`
- Modify: `HappyPianistAVP/ViewModels/LiveAppGraph.swift`
- Modify: `HappyPianistAVP/Views/Library/LibraryWindowView.swift`
- Modify: `HappyPianistAVP/Views/Library/SongLibraryView.swift`
- Modify: `HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift`
- Delete: old `SongFileStoreProtocol.importMusicXML` timestamp/UUID destination implementation
- Create: `HappyPianistAVPTests/Library/SongLibraryImportTransactionServiceTests.swift`
- Create: `HappyPianistAVPTests/Library/SongLibraryImportQueueTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongFileStoreTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryBootstrapLoadingTests.swift`
- Modify: `docs/storage.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/modules/happypianist-avp.md`

**Step 1: 创建完整 actor，不留半接入服务**

`SongLibraryImportTransactionService` 在同一 task 完成并接入：security-scoped lease、冲突 inspect、new import commit、replacement commit、journal write/update/delete、rollback、cleanup、recovery。不要先创建孤立 service 再留后续 task 接线。

**Step 2: security-scoped lease 生命周期**

fileImporter 返回后，队列立刻调用 actor `begin`，actor 内 start access 并保留 lease。所有 confirm/cancel/error/cancellation/disappear/queue completion 路径通过单一 finalize helper 恰好 stop 一次。测试 fake provider 记录 start/stop 平衡。

**Step 3: 无冲突 new import transaction**

- safe original filename；
- same-volume temp copy；
- 写 journal；
- 原子 move temp→target；
- index append 新 songID、新 non-nil scoreFileVersionID；
- cleanup journal/temp；
- index commit 失败则删除未提交 target并保留旧 index。

**Step 4: 有冲突 replacement transaction**

inspect 只发布 pending confirmation，不改 target/index/progress。confirm 后：
- 重新验证 expected songID/token 与 target 事实；
- stage temp；
- 写 journal；
- target→backup，temp→target；
- conditional replace entry，保留顺序/displayName/audio/last-selected/songID，更新 importedAt/token/原始文件名；
- commit 前失败恢复 backup；commit 后 cleanup 失败保留新版本与 journal。

**Step 5: 顺序 confirmation queue**

`SongLibraryViewModel` 按用户多选顺序处理。当前冲突状态只包含 UI-safe operation ID 与文件名；确认/取消恢复 suspended queue。取消跳过当前项继续下一项。Library disappear 取消队列并要求 actor finalize 所有 pending lease。

**Step 6: bootstrap recovery gate**

`LiveSongLibraryBootstrapLoader` 在 bundled/index snapshot 发布前调用同一 transaction service recovery。blocking recovery failure 返回 Library load failure，不发布潜在损坏 index；成功 cleanup 后再 load index。

**Step 7: 删除旧 import 路径**

删除时间戳/UUID 命名、`uniqueScoreDestinationURL` 与 ViewModel 手工 copy+save+rollback 逻辑。`SongFileStore` 仅保留被 transaction/service 或试听/删除需要的最小 URL/文件能力，避免第二套 import service。

**Step 8: typed diagnostics**

为 access/stage/backup/replace/indexCommit/cleanup/recovery 记录区分明确的 diagnostic。cleanup warning 不显示为整次 replacement 失败；recovery blocking failure 必须可重试。日志禁止绝对路径。

**Step 9: 故障注入测试**

覆盖：原名、三扩展、多选顺序、exact/case/Unicode conflict、取消继续、确认替换字段保留、lease 平衡、stage/backup/replace/index commit/cleanup 各失败点、new orphan 删除、replacement backup 恢复、已提交 cleanup failure、service 重建后的 recovery、recovery 幂等与 blocking failure。

**Step 10: 文档**

storage/data-flow/AVP module 写明原名、version token、actor transaction、journal/recovery 与 conflict confirmation；明确不迁移旧时间戳文件。

**Step 11: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: 故障矩阵测试全部通过；生产调用图中只有 transaction actor 执行 score import/replace。

**Step 12: 原子提交**

Run: `git add -A HappyPianistAVP/Services/Library HappyPianistAVP/ViewModels/Library/SongLibraryViewModel.swift HappyPianistAVP/ViewModels/LiveAppGraph.swift HappyPianistAVP/Views/Library HappyPianistAVP/Models/Diagnostics/DiagnosticModels.swift HappyPianistAVPTests/Library docs/storage.md docs/data-flow.md docs/modules/happypianist-avp.md`

Run: `git commit -m "feat: P3-T4 - 接入可恢复的原名导入与同名替换"`

---

## P3-T5 replacement 后只恢复跨 revision 通用偏好

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Progress/PracticeProgressCoordinator.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift`
- Modify: `HappyPianistAVP/Services/Practice/Session/PracticeRoundConfigurationController.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift`
- Create/Modify: `HappyPianistAVPTests/Practice/PracticeReplacementPreferenceRestoreTests.swift`
- Modify: `docs/modules/happypianist-avp-practice.md`

**Step 1: 扩展 begin result**

progress coordinator 对当前 identity 返回 exact progress，并在 exact 缺失时可返回同 songID 最新有效 historical progress 作为偏好候选。repository 已在 P2 提供 deterministic latest 查询。

**Step 2: 定义通用偏好值对象**

只提取 handMode、tempoScale、loopEnabled、requiredSuccesses。不得携带 passage、resumePoint、measure facts、source/occurrence identity。

**Step 3: 恢复策略**

- exact revision：保持现有完整 activeConfiguration + resume restore。
- exact 缺失、historical preference 有效：使用当前 prepared score 的 full passage，加历史通用偏好；currentStepIndex 从全曲开头；sessionProgress 不注入旧 facts。
- historical 配置无效/损坏：使用 `installFreshFullScoreConfiguration` 默认值。

**Step 4: 测试**

覆盖 exact 优先、replacement fallback、passage 强制全曲、resume/facts 不跨 revision、invalid historical fallback、最新 revision deterministic、legacy nil token 不改变 identity 隔离。

**Step 5: 文档**

Practice canonical doc 明确 replacement 的通用偏好与结构数据边界。

**Step 6: 验证**

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:HappyPianistAVPTests`

Expected: replacement tests 证明 hand/tempo/loop/requiredSuccesses 恢复，但 passage/resume/facts 全部来自新 revision/default。

**Step 7: 原子提交**

Run: `git add HappyPianistAVP/Services/Practice/Progress/PracticeProgressCoordinator.swift HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift HappyPianistAVP/Services/Practice/Session/PracticeRoundConfigurationController.swift HappyPianistAVPTests/Practice docs/modules/happypianist-avp-practice.md`

Run: `git commit -m "feat: P3-T5 - 跨曲谱版本仅恢复通用练习偏好"`

---

## P3-T6 完成端到端回归、人工事务验证与 phase gate

**Files:**
- Modify: `HappyPianistAVPTests/Library/SongLibraryImportTransactionServiceTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibraryImportQueueTests.swift`
- Modify: `HappyPianistAVPTests/Library/SongLibrarySnapshotLoadingTests.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeReplacementPreferenceRestoreTests.swift`
- Modify: `docs/testing/core-function-checklist.md`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/overview.md`

**Step 1: 端到端 regression matrix**

串起：import original name → Library selected/试听 → Practice prepare 写 metadata → 同名 replacement → Ornament needs-rebuild → Practice 新 revision 使用通用偏好 → 新 attempt 后 Ornament current。断言旧 progress JSON 保留且不应用到新 revision。

**Step 2: legacy regression**

覆盖已有时间戳文件仍能读取/删除/试听/练习；不自动改名。覆盖 bundled discovery 仍只扫描 `.musicxml`，无 bundled production resource 时人工项标记 Not Run。

**Step 3: privacy 与 MainActor 检查**

故障 diagnostics 不含绝对 source URL、原始 score 内容或逐小节 facts。测试/调用图确认 copy/replace/journal/index IO 不在 MainActor。

**Step 4: 更新人工清单**

加入真实 fileImporter security scope、exact/case/Unicode confirmation、取消继续、多选、快速关闭 Library、模拟 cleanup/relaunch recovery、replacement 字段保留、旧文件兼容。无法模拟真实进程中断时记录替代证据与 Not Run 项。

**Step 5: Phase 验证**

Run: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`

Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

Run: `xcodebuild build -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO`

Expected: test/build 通过；canonical docs 与最终数据流一致；未执行 Simulator/实机项明确标记 Not Run。

**Step 6: 原子提交**

Run: `git add HappyPianistAVPTests/Library HappyPianistAVPTests/Practice/PracticeReplacementPreferenceRestoreTests.swift docs/testing/core-function-checklist.md README.md docs/architecture.md docs/overview.md`

Run: `git commit -m "test: P3-T6 - 验证导入替换与跨版本练习闭环"`

---

## Phase Audit

- Audit file: `audit-p3.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环
- Audit focus:
  1. 检查新导入是否严格保留安全化原名且无时间戳/UUID fallback。
  2. 检查 conflict 是否同时覆盖 index 与目标目录，并遵循实际目标卷语义。
  3. 检查 confirm 前零 target/index/progress mutation，cancel 是否继续队列并释放 lease。
  4. 对每个 transaction phase 复核 journal、rollback、commit 后 cleanup 与 recovery 幂等。
  5. 检查 index 条件更新是否保留 songID/顺序/displayName/audio/last-selected，且不被并发 mutation 覆盖。
  6. 检查 replacement 后旧 progress 保留但 passage/resume/facts 不跨 revision。
  7. 检查 MainActor IO、diagnostic privacy、旧 API/旧时间戳 import 实现是否完全删除。
- Flow:
  1. 先记录发现
  2. 再修复问题
  3. 再运行本 phase 完整 `xcodebuild test` 与 `xcodebuild build`
