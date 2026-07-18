# Plan P9 - 逐指手部证据与表现力虚拟琴

**Goal:** 让真实与虚拟琴手部输入保留逐指、左右手、时间、置信度、运动与触键速度，并据此生成独立 velocity。

**Non-goals:** 本 phase 不声称手部追踪能等同真实 MIDI 键盘力度，也不把空间容差当音乐正确性。

**Approach:** 把 palm 与 finger sample 分离，建立 per-finger contact observation、dt-normalized motion filter、keyboard calibration 与 velocity curve。虚拟琴播放和 hand-separated matching 直接消费逐指 observation。

**Acceptance:**
- palm 永不生成 note-on。
- 每个 contact 保留 hand、finger、timestamp、confidence 与 kinematics。
- virtual piano 每音 velocity 可重复校准。
- 左右手判定不再消费合并的 pressed set。

**Rules:**
- 阈值必须可校准并带版本，不能假装硬件理想。
- 相邻半音只能表示候选或 unknown，不得判为正确。
- 原始逐帧手部数据不持久化或导出。

**State / lifecycle:** tracking generation 拥有 per-finger state；授权失败、tracking loss、placement change、stop 与 teardown 清空 contact 并 all-notes-off。

**Threading / actor:** ARKit provider 可在其 actor；运动滤波、hit test 与 velocity calculation 不在 MainActor；RealityKit 渲染只消费汇总。

**Debug / observability:** 记录 tracking confidence bucket、contact latency、candidate ambiguity、velocity range 与 reset count，不记录逐指轨迹。

**Testing strategy:** synthetic hand traces 加 deterministic time；Simulator 只测逻辑，真机校准与 latency 留 P15。

**Audit focus:**
- FingerTipsSnapshot.forEach 是否仍包含 palm。
- velocity 是否仍固定 90 或 96。
- 同一指重复触键和双手同时和弦是否稳定。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p9-t1"></a>
## P9-T1 分离 finger joints 与 palm sample 模型

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/Tracking/TrackedFinger.swift`
- Modify: `HappyPianistAVP/Models/Tracking/FingerTipsSnapshot.swift`
- Modify: `HappyPianistAVPTests/Tracking/FingerTipsSnapshotTests.swift`

**Implementation:**
1. 定义 left 或 right hand 与 thumb 到 little finger identity；palm 作为单独可选 hand pose sample。
2. forEachFinger 只遍历五指；调用方需要 palm 时显式访问。
3. 删除会混合 palm 的通用遍历 API。

**Validation:**
- Focus: HappyPianistAVPTests/Tracking/FingerTipsSnapshotTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Tracking/TrackedFinger.swift' 'HappyPianistAVP/Models/Tracking/FingerTipsSnapshot.swift' 'HappyPianistAVPTests/Tracking/FingerTipsSnapshotTests.swift'`
- Run: `git commit -m "refactor: P9-T1 - 分离 finger joints 与 palm sample 模型"`

---

<a id="p9-t2"></a>
## P9-T2 禁止 palm 进入接触与琴键命中

**Requirements:** OBS-004
**Primary owner:** OBS-004

**Files:**
- Modify: `HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift`
- Modify: `HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/HandPianoActivityGate.swift`
- Modify: `HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift`

**Implementation:**
1. 所有 contact candidate 只来自 TrackedFinger。
2. palm 仅可用于 hand pose 或 activity context，不产生 midi key。
3. 增加 palm 穿过键面但五指未接触的反例。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift, HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift' 'HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift' 'HappyPianistAVP/Services/Practice/Matching/HandPianoActivityGate.swift' 'HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift'`
- Run: `git commit -m "fix: P9-T2 - 禁止 palm 进入接触与琴键命中"`

---

<a id="p9-t3"></a>
## P9-T3 定义逐指 PianoKeyContactObservation

**Requirements:** OBS-005
**Primary owner:** OBS-005

**Files:**
- Create: `HappyPianistAVP/Models/Tracking/PianoKeyContactObservation.swift`
- Modify: `HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift`
- Modify: `HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift`

**Implementation:**
1. 事件保留 hand、finger、key candidate、timestamp、confidence、position、plane distance、normal velocity 与 calibration ID。
2. started、held 与 ended 均有稳定 contact identity。
3. 两个检测服务立即输出新事件，删除只返回 Set<Int> 的生产 API。

**Validation:**
- Focus: HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift, HappyPianistAVPTests/HandTracking/PressDetectionServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/Tracking/PianoKeyContactObservation.swift' 'HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift' 'HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift'`
- Run: `git commit -m "refactor: P9-T3 - 定义逐指 PianoKeyContactObservation"`

---

<a id="p9-t4"></a>
## P9-T4 实现 per-finger contact state 与重触发

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Services/HandTracking/PianoKeyContactTracker.swift`
- Modify: `HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift`
- Modify: `HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift`

**Implementation:**
1. 每个 hand 与 finger 独立管理 candidate、down、release、debounce 与 retrigger。
2. 同一物理键可接受不同手指的独立接触，但播放层按 transport 规则管理物理输出。
3. tracking loss 产生 ended 或 reset，而不是留下 down set。

**Validation:**
- Focus: HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/HandTracking/PianoKeyContactTracker.swift' 'HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift' 'HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift'`
- Run: `git commit -m "feat: P9-T4 - 实现 per-finger contact state 与重触发"`

---

<a id="p9-t5"></a>
## P9-T5 按 delta-time 计算运动与稳定性

**Requirements:** OBS-006
**Primary owner:** OBS-006

**Files:**
- Create: `HappyPianistAVP/Services/HandTracking/FingerMotionEstimator.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/HandPianoActivityGate.swift`
- Modify: `HappyPianistAVP/Services/HandTracking/PressDetectionService.swift`
- Modify: `HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift`

**Implementation:**
1. 用 monotonic delta-time 计算法向速度、加速度和有效采样间隔。
2. 异常间隔、tracking jump 与低 confidence 返回 unknown 或 reset。
3. 删除按相邻 frame displacement 直接比较固定阈值的旧路径。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift, HappyPianistAVPTests/HandTracking/PressDetectionServiceTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/HandTracking/FingerMotionEstimator.swift' 'HappyPianistAVP/Services/Practice/Matching/HandPianoActivityGate.swift' 'HappyPianistAVP/Services/HandTracking/PressDetectionService.swift' 'HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift'`
- Run: `git commit -m "fix: P9-T5 - 按 delta-time 计算运动与稳定性"`

---

<a id="p9-t6"></a>
## P9-T6 建立键盘接触校准与 velocity curve

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVP/Models/PianoMode/PianoTouchCalibration.swift`
- Create: `HappyPianistAVP/Services/HandTracking/PianoTouchVelocityResolver.swift`
- Modify: `HappyPianistAVP/Services/PianoModeServices.swift`
- Modify: `HappyPianistAVP/ViewModels/PianoSetupCoordinator.swift`
- Modify: `HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift`

**Implementation:**
1. 校准 plane offset、hysteresis、minimum strike speed、velocity min、max 与 curve。
2. 使用现有 JSON calibration store 或 settings 边界，不引入第二持久化体系。
3. 提供保守默认 curve 与 calibration version，真实硬件可调。

**Validation:**
- Focus: HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Models/PianoMode/PianoTouchCalibration.swift' 'HappyPianistAVP/Services/HandTracking/PianoTouchVelocityResolver.swift' 'HappyPianistAVP/Services/PianoModeServices.swift' 'HappyPianistAVP/ViewModels/PianoSetupCoordinator.swift' 'HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift'`
- Run: `git commit -m "feat: P9-T6 - 建立键盘接触校准与 velocity curve"`

---

<a id="p9-t7"></a>
## P9-T7 让虚拟琴按每音 velocity 发声

**Requirements:** PERF-008
**Primary owner:** PERF-008

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`
- Modify: `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- Modify: `HappyPianistAVP/Services/HandTracking/PianoTouchVelocityResolver.swift`
- Modify: `HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift`

**Implementation:**
1. live note API 接受 contact identity、midi、velocity 与 timestamp，不再接受 Set<Int> 加默认 96。
2. 同帧和弦每音独立 velocity；retrigger 使用 per-finger state。
3. 录制与 AI phrase 复用同一 resolved velocity。

**Validation:**
- Focus: HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift, HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift' 'HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift' 'HappyPianistAVP/Services/HandTracking/PianoTouchVelocityResolver.swift' 'HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift'`
- Run: `git commit -m "feat: P9-T7 - 让虚拟琴按每音 velocity 发声"`

---

<a id="p9-t8"></a>
## P9-T8 让 hand-separated matcher 消费逐手证据

**Requirements:** OBS-008
**Primary owner:** OBS-008

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Matching/PracticeHandGateController.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/ChordAttemptAccumulator.swift`
- Modify: `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`
- Modify: `HappyPianistAVPTests/Practice/PracticeSessionHandSeparatedMatchingTests.swift`

**Implementation:**
1. 按 observation.hand 分组，不再把 merged pressed set 同时与左右手目标比较。
2. score hand unknown 时不强行归手；只做整体 pitch 或 insufficient evidence。
3. 删除旧 handSeparated 名称下的合并实现。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PracticeSessionHandSeparatedMatchingTests.swift, HappyPianistAVPTests/Practice/PracticeHandGateControllerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Matching/PracticeHandGateController.swift' 'HappyPianistAVP/Services/Practice/Matching/ChordAttemptAccumulator.swift' 'HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift' 'HappyPianistAVPTests/Practice/PracticeSessionHandSeparatedMatchingTests.swift'`
- Run: `git commit -m "fix: P9-T8 - 让 hand-separated matcher 消费逐手证据"`

---

<a id="p9-t9"></a>
## P9-T9 用不确定性替代相邻半音正确性容差

**Requirements:** OBS-007
**Primary owner:** OBS-007

**Files:**
- Modify: `HappyPianistAVP/Services/Practice/Matching/StepMatcher.swift`
- Modify: `HappyPianistAVP/Services/Practice/Matching/PracticeHandGateController.swift`
- Modify: `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift`
- Modify: `HappyPianistAVPTests/Practice/StepMatcherTests.swift`
- Delete: `PracticeSessionStateStore.noteMatchTolerance 默认半音正确性路径`

**Implementation:**
1. 精确音乐 pitch matching 与空间 key candidate confidence 分开。
2. 多个相邻 candidate 时返回 ambiguous 或 insufficient evidence，不把 midi 正负 1 当目标。
3. 删除默认 tolerance=1 和相关通过测试。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/StepMatcherTests.swift, HappyPianistAVPTests/Practice/PracticeHandGateControllerTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVP/Services/Practice/Matching/StepMatcher.swift' 'HappyPianistAVP/Services/Practice/Matching/PracticeHandGateController.swift' 'HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift' 'HappyPianistAVPTests/Practice/StepMatcherTests.swift'`
- Run: `git commit -m "fix: P9-T9 - 用不确定性替代相邻半音正确性容差"`

---

<a id="p9-t10"></a>
## P9-T10 建立 synthetic hand traces 与真机校准清单

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/SyntheticHandContactTraces.json`
- Modify: `HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift`
- Modify: `HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift`
- Modify: `docs/testing/piano-performance-validation.md`
- Modify: `docs/configuration.md`

**Implementation:**
1. 覆盖轻触、重击、慢压、同时和弦、重复音、palm crossing、tracking loss 和左右手交叉。
2. 测试 velocity monotonicity、false positive、release、retrigger 与 unknown。
3. 文档列出真机 calibration knobs、记录方式与隐私边界。

**Validation:**
- Focus: HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift, HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/SyntheticHandContactTraces.json' 'HappyPianistAVPTests/Support/PerformanceInputReplaySupport.swift' 'HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift' 'docs/testing/piano-performance-validation.md' 'docs/configuration.md'`
- Run: `git commit -m "test: P9-T10 - 建立 synthetic hand traces 与真机校准清单"`

---

## Phase Audit

- Audit file: `audit-p9.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: FingerTipsSnapshot.forEach 是否仍包含 palm。；velocity 是否仍固定 90 或 96。；同一指重复触键和双手同时和弦是否稳定。
