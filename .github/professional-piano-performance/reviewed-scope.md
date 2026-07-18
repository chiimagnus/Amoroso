# 计划前源码与文档审查范围

## 审查方法

- 领域需求真源：`docs/piano-performance-quality.md`（1254 行，SHA-256 `7801e321bbc9ec976fa9c646b1dcfca253cf910967ddf6fc883385a8ae188fa6`）。
- 先读取仓库根与 visionOS 增量 `AGENTS.md`，再读取架构、数据流、存储、配置、测试清单与模块文档。
- 使用 `.codegraph/codegraph.db` 追踪 `PracticePreparationService`、`PreparedPractice`、`PianoHighlightGuideBuilderService`、`AutoplayPerformanceTimeline` 及其调用方 / 被调用方；避免仅按文件名猜测执行流。
- 对与 MusicXML、播放、输入、手部追踪、记谱、进度、反馈、AI、录制和 diagnostics 相关的 Swift 文件进行符号、import、调用关系与源文本审查。
- 对现有相关测试和 fixtures 建立覆盖清单，识别 characterization、golden、重放、真机与专业验收缺口。

## 关键调用链结论

1. `PracticePreparationService` 当前是 MusicXML → route / step / tempo / pedal / fermata / attribute / note spans / guides → `PreparedPractice` 的汇合点；note spans 构建后未进入正式准备结果。
2. `AutoplayPerformanceTimeline` 当前从 highlight guides 重建 note events，并按 `onTick + midi` 合并与截断同音，导致 UI 投影影响声音真值。
3. `PreparedPractice`、`PracticeSessionStateStore` 与 `PracticeSessionViewModel` 是迁移消费者的关键边界；计划必须先扩展数据，再逐消费者切换并删除旧路径。
4. MIDI、麦克风和手部链路最终都被压缩到 step matching；MIDI 的 velocity / release / controller、手部的 hand / finger / time / confidence / motion 等证据在此之前丢失。
5. 录制模型保存了部分 MIDI 表现数据，但缺 score identity、source / channel / group、统一时钟、calibration 与 alignment，不能直接当专业评价真值。
6. AI MIDI phrase 可保留 velocity / duration / controller；手部 phrase 仍固定 velocity。AI 质量门属于创意生成，不可复用为忠实示范验收。
7. Xcode 工程使用文件系统同步分组；新文件仍必须在创建 task 中接入实际 consumer / composition root，不能仅依赖自动入 target。

## 已审查文档

| 路径 | 行数 |
|---|---:|
| `AGENTS.md` | 123 |
| `HappyPianistAVP/AGENTS.md` | 293 |
| `README.md` | 97 |
| `README.en.md` | 43 |
| `docs/overview.md` | 48 |
| `docs/architecture.md` | 158 |
| `docs/data-flow.md` | 261 |
| `docs/storage.md` | 97 |
| `docs/configuration.md` | 148 |
| `docs/testing/core-function-checklist.md` | 303 |
| `docs/piano-performance-quality.md` | 1254 |
| `docs/modules/happypianist-avp-practice.md` | 174 |
| `docs/modules/happypianist-avp.md` | 135 |

## 已审查生产 Swift 文件（208）

- `HappyPianistAVP/Models/Immersive/PianoGuideBeamDescriptor.swift`（60 行）
- `HappyPianistAVP/Models/Library/SongPracticeLibraryPresentation.swift`（87 行）
- `HappyPianistAVP/Models/MIDI/MIDI1InputEvent.swift`（71 行）
- `HappyPianistAVP/Models/MIDI/MIDI2InputEvent.swift`（71 行）
- `HappyPianistAVP/Models/MIDI/MIDIInputSource.swift`（9 行）
- `HappyPianistAVP/Models/MusicXML/MusicXMLModels.swift`（320 行）
- `HappyPianistAVP/Models/MusicXML/MusicXMLScore+PartFiltering.swift`（46 行）
- `HappyPianistAVP/Models/PianoMode/PianoModeModels.swift`（74 行）
- `HappyPianistAVP/Models/Practice/GrandStaffNotationModels.swift`（121 行）
- `HappyPianistAVP/Models/Practice/PianoGuideHighlightStyle.swift`（36 行）
- `HappyPianistAVP/Models/Practice/PianoGuideHighlightTintToken.swift`（7 行）
- `HappyPianistAVP/Models/Practice/PianoGuideKeyHighlight.swift`（7 行）
- `HappyPianistAVP/Models/Practice/PianoHighlightGuide.swift`（89 行）
- `HappyPianistAVP/Models/Practice/PracticeLaunchModels.swift`（308 行）
- `HappyPianistAVP/Models/Practice/PracticeModels.swift`（180 行）
- `HappyPianistAVP/Models/Practice/PracticeProgressModels.swift`（489 行）
- `HappyPianistAVP/Models/Recording/RecordingModels.swift`（41 行）
- `HappyPianistAVP/Models/Tracking/FingerTipsSnapshot.swift`（119 行）
- `HappyPianistAVP/Services/Audio/AudioOutputVolumeSettings.swift`（16 行）
- `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`（260 行）
- `HappyPianistAVP/Services/Audio/NoopPracticeSequencerPlaybackService.swift`（17 行）
- `HappyPianistAVP/Services/Audio/PracticeAudioError.swift`（15 行）
- `HappyPianistAVP/Services/Audio/PracticeManualReplaySequenceBuilder.swift`（70 行）
- `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`（244 行）
- `HappyPianistAVP/Services/Audio/PracticeSequencerSequenceBuilder.swift`（282 行）
- `HappyPianistAVP/Services/AudioRecognition/AudioRecognitionTypes.swift`（35 行）
- `HappyPianistAVP/Services/AudioRecognition/AudioSpectrumFrame.swift`（103 行）
- `HappyPianistAVP/Services/AudioRecognition/HarmonicTemplateModels.swift`（177 行）
- `HappyPianistAVP/Services/AudioRecognition/HarmonicTemplateScorer.swift`（101 行）
- `HappyPianistAVP/Services/AudioRecognition/PracticeAudioRecognitionService.swift`（312 行）
- `HappyPianistAVP/Services/AudioRecognition/TargetedHarmonicTemplateDetector.swift`（80 行）
- `HappyPianistAVP/Services/AudioRecognition/VDSPAudioSpectrumAnalyzer.swift`（137 行）
- `HappyPianistAVP/Services/HandTracking/PianoKeyHitTestIndex.swift`（141 行）
- `HappyPianistAVP/Services/HandTracking/PressDetectionService.swift`（77 行）
- `HappyPianistAVP/Services/HandTracking/RealPianoContactDetectionService.swift`（26 行）
- `HappyPianistAVP/Services/Immersive/PianoGuideDecalMeshFactory.swift`（6 行）
- `HappyPianistAVP/Services/Immersive/PianoGuideHighlightTintToken+UIKit.swift`（15 行）
- `HappyPianistAVP/Services/Immersive/PianoGuideOverlayController.swift`（199 行）
- `HappyPianistAVP/Services/Immersive/PianoKeyEntityFactory.swift`（48 行）
- `HappyPianistAVP/Services/Immersive/PracticeRestorationEffectRenderer.swift`（61 行）
- `HappyPianistAVP/Services/Immersive/VirtualPianoOverlayController.swift`（124 行）
- `HappyPianistAVP/Services/Library/AudioImportService.swift`（52 行）
- `HappyPianistAVP/Services/Library/SongAudioPlayer.swift`（178 行）
- `HappyPianistAVP/Services/Library/SongPracticeFocusMeasureBuilder.swift`（140 行）
- `HappyPianistAVP/Services/Library/SongPracticeLibrarySnapshotBuilder.swift`（162 行）
- `HappyPianistAVP/Services/Library/SongPracticeSessionSummaryBuilder.swift`（113 行）
- `HappyPianistAVP/Services/MIDI/BluetoothMIDIInputEventSourceService.swift`（533 行）
- `HappyPianistAVP/Services/MIDI/CoreMIDIOutputService.swift`（264 行）
- `HappyPianistAVP/Services/MIDI/CoreMIDISourceMonitoringService.swift`（215 行）
- `HappyPianistAVP/Services/MIDI/MIDIUtilities.swift`（182 行）
- `HappyPianistAVP/Services/MusicXML/MXLReader.swift`（94 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLAttributeTimeline.swift`（102 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLFermataTimeline.swift`（106 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLHandRouter.swift`（79 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLImportModels.swift`（18 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLNoteSpanBuilder.swift`（366 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLPedalTimeline.swift`（91 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLPianoGrandStaffNormalizer.swift`（85 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLPlaybackDefaults.swift`（20 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLStructureExpander.swift`（532 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLTempoMap.swift`（306 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLTimewiseConverter.swift`（251 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLVelocityResolver.swift`（189 行）
- `HappyPianistAVP/Services/MusicXML/MusicXMLWordsSemanticsInterpreter.swift`（298 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParser.swift`（66 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Directions.swift`（542 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Elements.swift`（505 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Notes.swift`（180 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+Timing.swift`（26 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate+XMLParserDelegate.swift`（36 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegate.swift`（82 行）
- `HappyPianistAVP/Services/MusicXML/Parser/MusicXMLParserDelegateState.swift`（128 行）
- `HappyPianistAVP/Services/PianoKeyGeometryService.swift`（122 行）
- `HappyPianistAVP/Services/PianoModeServices.swift`（79 行）
- `HappyPianistAVP/Services/Practice/AI/AIPerformanceService.swift`（683 行）
- `HappyPianistAVP/Services/Practice/AI/CoreMLDuet/CoreMLPerformanceRNNStepModel.swift`（146 行）
- `HappyPianistAVP/Services/Practice/AI/CoreMLDuet/PerformanceRNNCoreMLModelLoader.swift`（123 行）
- `HappyPianistAVP/Services/Practice/AI/CoreMLDuet/PerformanceRNNEventCodec.swift`（209 行）
- `HappyPianistAVP/Services/Practice/AI/CoreMLDuet/PerformanceRNNImprovGenerator.swift`（152 行）
- `HappyPianistAVP/Services/Practice/AI/CoreMLDuet/PerformanceRNNStepModelProtocol.swift`（94 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/AriaNetworkBonjourHTTPImprovBackend.swift`（100 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/AriaNetworkBonjourWebSocketImprovBackend.swift`（120 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendKind.swift`（12 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendPlaybackPlan.swift`（5 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendProtocol.swift`（11 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendRegistry.swift`（15 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovBackendSelection.swift`（25 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/ImprovSeedResolver.swift`（31 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/LocalCoreMLDuetImprovBackend.swift`（81 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovBackends/LocalRuleImprovBackend.swift`（81 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovEngine/PythonRandom.swift`（169 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleConstants.swift`（165 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleImprovGenerator.swift`（1428 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleNoteEvent.swift`（15 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovEngine/Rule/RuleTypes.swift`（37 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovProtocol/ImprovProtocol.swift`（257 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovProtocol/ImprovStreamingProtocol.swift`（95 行）
- `HappyPianistAVP/Services/Practice/AI/ImprovScheduleBuilder.swift`（103 行）
- `HappyPianistAVP/Services/Practice/AI/Playback/DuetAIPlaybackQueue.swift`（198 行）
- `HappyPianistAVP/Services/Practice/AI/Playback/DuetAIPlaybackServiceFactory.swift`（48 行）
- `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseBuffer.swift`（240 行）
- `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhraseEventBuffer.swift`（93 行）
- `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetPhrasePolicy.swift`（467 行）
- `HappyPianistAVP/Services/Practice/AI/TurnTaking/DuetTurnTakingCore.swift`（120 行）
- `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`（223 行）
- `HappyPianistAVP/Services/Practice/Autoplay/AutoplayTimelineTimeCursor.swift`（74 行）
- `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackModels.swift`（32 行）
- `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift`（70 行）
- `HappyPianistAVP/Services/Practice/Feedback/PracticeHotspotPolicy.swift`（26 行）
- `HappyPianistAVP/Services/Practice/Feedback/PracticeNextActionPolicy.swift`（25 行）
- `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationLayoutService.swift`（520 行）
- `HappyPianistAVP/Services/Practice/Guides/GrandStaffNotationViewportLayoutService.swift`（259 行）
- `HappyPianistAVP/Services/Practice/Guides/PianoGuideKeyHighlightResolver.swift`（30 行）
- `HappyPianistAVP/Services/Practice/Guides/PianoHighlightGuideBuilderService.swift`（218 行）
- `HappyPianistAVP/Services/Practice/Guides/PracticeHighlightGuideController.swift`（82 行）
- `HappyPianistAVP/Services/Practice/Input/PracticeAudioRecognitionInputService.swift`（216 行）
- `HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift`（222 行）
- `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`（90 行）
- `HappyPianistAVP/Services/Practice/ManualAdvance/ManualAdvanceStrategies.swift`（68 行）
- `HappyPianistAVP/Services/Practice/Matching/AudioStepAttemptAccumulator.swift`（203 行）
- `HappyPianistAVP/Services/Practice/Matching/ChordAttemptAccumulator.swift`（105 行）
- `HappyPianistAVP/Services/Practice/Matching/HandPianoActivityGate.swift`（127 行）
- `HappyPianistAVP/Services/Practice/Matching/MIDIPracticeStepMatcher.swift`（108 行）
- `HappyPianistAVP/Services/Practice/Matching/PracticeHandGateController.swift`（95 行）
- `HappyPianistAVP/Services/Practice/Matching/StepMatcher.swift`（36 行）
- `HappyPianistAVP/Services/Practice/Navigation/PracticeActiveRange.swift`（35 行）
- `HappyPianistAVP/Services/Practice/Navigation/PracticeMeasureIndex.swift`（69 行）
- `HappyPianistAVP/Services/Practice/Navigation/PracticeStepNavigator.swift`（49 行）
- `HappyPianistAVP/Services/Practice/Playback/PlaybackSequenceBuilder.swift`（48 行）
- `HappyPianistAVP/Services/Practice/Playback/PracticeManualReplayService.swift`（242 行）
- `HappyPianistAVP/Services/Practice/Playback/PracticePlaybackControlService.swift`（468 行）
- `HappyPianistAVP/Services/Practice/Progress/PracticeAttemptReducer.swift`（204 行）
- `HappyPianistAVP/Services/Practice/Progress/PracticeHistoricalPreferencesResolver.swift`（62 行）
- `HappyPianistAVP/Services/Practice/Progress/PracticeProgressCoordinator.swift`（158 行）
- `HappyPianistAVP/Services/Practice/Progress/PracticeProgressPaths.swift`（30 行）
- `HappyPianistAVP/Services/Practice/Progress/PracticeProgressRepository.swift`（363 行）
- `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`（213 行）
- `HappyPianistAVP/Services/Practice/Session/PracticeRoundConfigurationController.swift`（194 行）
- `HappyPianistAVP/Services/Practice/Session/PracticeSessionContracts.swift`（36 行）
- `HappyPianistAVP/Services/Practice/Session/PracticeSessionRecorder.swift`（519 行）
- `HappyPianistAVP/Services/Practice/Session/PracticeSessionSharedHelpers.swift`（42 行）
- `HappyPianistAVP/Services/Practice/Settings/PracticeSessionSettingsProvider.swift`（62 行）
- `HappyPianistAVP/Services/Practice/Settings/PracticeSoundRoutingSettings.swift`（25 行）
- `HappyPianistAVP/Services/PracticeStepBuilder.swift`（220 行）
- `HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift`（153 行）
- `HappyPianistAVP/Services/Recording/RecordingSupport.swift`（243 行）
- `HappyPianistAVP/Services/Recording/RecordingTakeRecorder.swift`（146 行）
- `HappyPianistAVP/Services/Recording/TakePlaybackController.swift`（76 行）
- `HappyPianistAVP/Services/Tracking/ARTrackingService.swift`（404 行）
- `HappyPianistAVP/Services/Tracking/ARTrackingServiceProtocol.swift`（22 行）
- `HappyPianistAVP/Services/VirtualPiano/KeyContactDetectionService.swift`（32 行）
- `HappyPianistAVP/Services/VirtualPiano/VirtualPianoKeyGeometryService.swift`（111 行）
- `HappyPianistAVP/ViewModels/ARGuide/ARGuidePracticeViewModel.swift`（297 行）
- `HappyPianistAVP/ViewModels/ARGuide/ARGuideRecordingViewModel.swift`（137 行）
- `HappyPianistAVP/ViewModels/ARGuide/PracticeLocalizationViewModel.swift`（320 行）
- `HappyPianistAVP/ViewModels/ARGuide/VirtualPianoPlacementViewModel.swift`（325 行）
- `HappyPianistAVP/ViewModels/LiveAppGraph.swift`（243 行）
- `HappyPianistAVP/ViewModels/MIDI/MIDIDestinationConnectionViewModel.swift`（63 行）
- `HappyPianistAVP/ViewModels/MIDI/MIDISourceConnectionViewModel.swift`（67 行）
- `HappyPianistAVP/ViewModels/PianoSetupCoordinator.swift`（35 行）
- `HappyPianistAVP/ViewModels/PracticeFeedback/PracticeFeedbackViewModel.swift`（33 行）
- `HappyPianistAVP/ViewModels/PracticeFeedback/PracticeMeasureMapViewModel.swift`（47 行）
- `HappyPianistAVP/ViewModels/PracticeFeedback/PracticePassagePresentation.swift`（21 行）
- `HappyPianistAVP/ViewModels/PracticeFeedback/PracticeRoundSummaryViewModel.swift`（51 行）
- `HappyPianistAVP/ViewModels/PracticeLaunch/PracticeLaunchViewModel.swift`（615 行）
- `HappyPianistAVP/ViewModels/PracticeNotation/GrandStaffNotationPresentation.swift`（12 行）
- `HappyPianistAVP/ViewModels/PracticeNotation/GrandStaffNotationPresentationViewModel.swift`（124 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift`（105 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel+AIPerformance.swift`（30 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift`（229 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelCommands.swift`（876 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelHandInput.swift`（49 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelHighlightGuides.swift`（23 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelInputRefresh.swift`（111 行）
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModelPlayback.swift`（50 行）
- `HappyPianistAVP/ViewModels/PracticeSetupState+PianoModeReadiness.swift`（10 行）
- `HappyPianistAVP/ViewModels/PracticeSetupState.swift`（29 行）
- `HappyPianistAVP/ViewModels/Recording/TakeLibraryPresentationViewModel.swift`（19 行）
- `HappyPianistAVP/ViewModels/Recording/TakeLibraryViewModel.swift`（86 行）
- `HappyPianistAVP/ViewModels/Recording/TakePlaybackViewModel.swift`（156 行）
- `HappyPianistAVP/Views/Library/LibraryPracticeEmptyAnimationView.swift`（197 行）
- `HappyPianistAVP/Views/Library/LibraryPracticeProgressOrnamentView.swift`（947 行）
- `HappyPianistAVP/Views/PianoChoose/BluetoothPianoPreparationView.swift`（309 行）
- `HappyPianistAVP/Views/PianoChoose/Calibration/CalibrationStageCard.swift`（138 行）
- `HappyPianistAVP/Views/PianoChoose/Calibration/CalibrationStepView.swift`（164 行）
- `HappyPianistAVP/Views/PianoChoose/Calibration/KeyboardMovingGlowOverlay.swift`（60 行）
- `HappyPianistAVP/Views/PianoChoose/MicrophonePianoPreparationView.swift`（41 行）
- `HappyPianistAVP/Views/PianoChoose/PianoModePreparationRouterView.swift`（22 行）
- `HappyPianistAVP/Views/PianoChoose/PianoTypePickerView.swift`（52 行）
- `HappyPianistAVP/Views/PianoChoose/Preparation/PreparationNavigationEnvironment.swift`（15 行）
- `HappyPianistAVP/Views/PianoChoose/Preparation/PreparationWindowRootView.swift`（51 行）
- `HappyPianistAVP/Views/PianoChoose/VirtualPianoPreparationView.swift`（59 行）
- `HappyPianistAVP/Views/Practice/GrandStaffNotationRenderer.swift`（574 行）
- `HappyPianistAVP/Views/Practice/GrandStaffNotationView.swift`（114 行）
- `HappyPianistAVP/Views/Practice/PracticeFeedbackCueView.swift`（42 行）
- `HappyPianistAVP/Views/Practice/PracticeLaunchContainerView.swift`（59 行）
- `HappyPianistAVP/Views/Practice/PracticeLaunchFailureView.swift`（97 行）
- `HappyPianistAVP/Views/Practice/PracticeMeasureMapView.swift`（36 行）
- `HappyPianistAVP/Views/Practice/PracticeRoundSummaryView.swift`（29 行）
- `HappyPianistAVP/Views/Practice/PracticeSettingsView.swift`（342 行）
- `HappyPianistAVP/Views/Practice/PracticeStepView.swift`（319 行）
- `HappyPianistAVP/Views/Practice/PracticeWindowRootView.swift`（258 行）
- `HappyPianistAVP/Views/Recording/MIDIFileDocument.swift`（29 行）
- `HappyPianistAVP/Views/Recording/TakeLibraryRowView.swift`（48 行）
- `HappyPianistAVP/Views/Recording/TakeLibraryView.swift`（219 行）
- `HappyPianistAVP/Views/Recording/TakeNowPlayingBarView.swift`（52 行）
- `HappyPianistAVP/Views/Shared/PianoGuideHighlightTintToken+SwiftUI.swift`（14 行）
- `HappyPianistAVP/Views/Shared/PianoKeyboard88View.swift`（197 行）

## 已审查相关测试与 fixture（154）

- `HappyPianistAVPTests/Audio/AudioImportServiceTests.swift`（56 行）
- `HappyPianistAVPTests/Audio/AudioOutputVolumeSettingsTests.swift`（41 行）
- `HappyPianistAVPTests/Audio/AudioSampleRollingBufferTests.swift`（39 行）
- `HappyPianistAVPTests/AudioRecognition/HarmonicTemplateFactoryTests.swift`（17 行）
- `HappyPianistAVPTests/AudioRecognition/HarmonicTemplateModelTests.swift`（12 行）
- `HappyPianistAVPTests/AudioRecognition/HarmonicTemplateScorerTests.swift`（61 行）
- `HappyPianistAVPTests/AudioRecognition/TargetedHarmonicTemplateDetectorTests.swift`（121 行）
- `HappyPianistAVPTests/AudioRecognition/VDSPAudioSpectrumAnalyzerTests.swift`（37 行）
- `HappyPianistAVPTests/Fakes/FakePracticeAudioRecognitionService.swift`（91 行）
- `HappyPianistAVPTests/Fakes/FakeProtocolSeparatedPracticeInputEventSource.swift`（59 行）
- `HappyPianistAVPTests/Fixtures/MusicXMLAutoplayRegression.musicxml`（44 行）
- `HappyPianistAVPTests/Fixtures/PracticeLearningLoopEightMeasures.musicxml`（67 行）
- `HappyPianistAVPTests/Fixtures/PracticeMeasureIdentityRepeats.musicxml`（26 行）
- `HappyPianistAVPTests/HandTracking/ARKitAuthorizationRequirementsTests.swift`（26 行）
- `HappyPianistAVPTests/HandTracking/PianoKeyHitTestIndexTests.swift`（48 行）
- `HappyPianistAVPTests/HandTracking/PressDetectionServiceTests.swift`（251 行）
- `HappyPianistAVPTests/Immersive/PracticeRestorationEffectRendererTests.swift`（25 行）
- `HappyPianistAVPTests/Immersive/PracticeRestorationLifecycleTests.swift`（42 行）
- `HappyPianistAVPTests/Library/SongAudioPlayerStateTests.swift`（126 行）
- `HappyPianistAVPTests/Library/SongPracticeFocusMeasureBuilderTests.swift`（132 行）
- `HappyPianistAVPTests/Library/SongPracticeLibrarySnapshotBuilderTests.swift`（499 行）
- `HappyPianistAVPTests/Library/SongPracticeSessionSummaryBuilderTests.swift`（233 行）
- `HappyPianistAVPTests/MIDI/CoreMIDIPracticePlaybackServiceStopTests.swift`（82 行）
- `HappyPianistAVPTests/MIDI/MIDI2ValueMappingTests.swift`（32 行）
- `HappyPianistAVPTests/MIDI/MIDIEndpointConnectionPolicyTests.swift`（23 行）
- `HappyPianistAVPTests/MIDI/MIDIEndpointPropertyReaderTests.swift`（59 行）
- `HappyPianistAVPTests/MIDI/MIDIRecordingCoordinatorTests.swift`（70 行）
- `HappyPianistAVPTests/MusicXML/MXLReaderTests.swift`（143 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLAttributeTimelineTests.swift`（58 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLAutoplayRegressionTests.swift`（219 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLExpressivityIntegrationTests.swift`（108 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLHandRouterTests.swift`（45 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLNoteSpanBuilderTests.swift`（275 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserArticulationsTests.swift`（40 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserDynamicsTests.swift`（95 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserFermataArpeggiateTests.swift`（72 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserGraceDetailsTests.swift`（35 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserGraceTupletTests.swift`（108 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserMXLTests.swift`（60 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserPerformanceTimingTests.swift`（31 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserScoreVersionTests.swift`（53 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserTests.swift`（794 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserTimewiseTests.swift`（65 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserUIInfoTests.swift`（72 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserWedgeTests.swift`（46 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLParserWordsTests.swift`（33 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLPedalTimelineTests.swift`（81 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLPianoGrandStaffNormalizerTests.swift`（58 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLRealisticPlaybackDefaultsTests.swift`（18 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLStructureExpanderTests.swift`（320 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLTempoMapTests.swift`（81 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLVelocityResolverTests.swift`（161 行）
- `HappyPianistAVPTests/MusicXML/MusicXMLWordsSemanticsInterpreterTests.swift`（94 行）
- `HappyPianistAVPTests/MusicXML/PracticeMeasureIdentityTests.swift`（25 行）
- `HappyPianistAVPTests/Notation/GrandStaffNotationLayoutServiceTests.swift`（74 行）
- `HappyPianistAVPTests/Notation/GrandStaffNotationViewportLayoutServiceTests.swift`（84 行）
- `HappyPianistAVPTests/Notation/ScoreHandTests.swift`（18 行）
- `HappyPianistAVPTests/Piano/AppModelKeyboardGeometryTests.swift`（133 行）
- `HappyPianistAVPTests/Piano/PianoGuideBeamDescriptorTests.swift`（138 行）
- `HappyPianistAVPTests/Piano/PianoHighlightGuideBuilderServiceTests.swift`（282 行）
- `HappyPianistAVPTests/Piano/PianoHighlightRealScoreRegressionTests.swift`（39 行）
- `HappyPianistAVPTests/Piano/PianoHighlightViewConsistencyTests.swift`（152 行）
- `HappyPianistAVPTests/Piano/PianoKeyGeometryServiceTests.swift`（226 行）
- `HappyPianistAVPTests/Piano/PianoModePreparationRouteTests.swift`（26 行）
- `HappyPianistAVPTests/Piano/PianoSetupCoordinatorTests.swift`（82 行）
- `HappyPianistAVPTests/Practice/AIPerformanceCoordinatorTests.swift`（719 行）
- `HappyPianistAVPTests/Practice/AudioStepAttemptAccumulatorTests.swift`（417 行）
- `HappyPianistAVPTests/Practice/ChordAttemptAccumulatorTests.swift`（54 行）
- `HappyPianistAVPTests/Practice/CoreMLDuet/FakePerformanceRNNStepModel.swift`（15 行）
- `HappyPianistAVPTests/Practice/CoreMLDuet/PerformanceRNNCoreMLModelLoaderTests.swift`（13 行）
- `HappyPianistAVPTests/Practice/CoreMLDuet/PerformanceRNNImprovGeneratorTests.swift`（111 行）
- `HappyPianistAVPTests/Practice/CoreMLDuet/PerformanceRNNStepModelProtocolTests.swift`（32 行）
- `HappyPianistAVPTests/Practice/DuetAIPlaybackQueueTests.swift`（198 行）
- `HappyPianistAVPTests/Practice/DuetDisableTeardownTests.swift`（448 行）
- `HappyPianistAVPTests/Practice/DuetOutOfOrderResponseTests.swift`（205 行）
- `HappyPianistAVPTests/Practice/DuetParallelInputWhilePlaybackTests.swift`（174 行）
- `HappyPianistAVPTests/Practice/DuetPhraseEventBufferTests.swift`（59 行）
- `HappyPianistAVPTests/Practice/DuetPhrasePolicyTests.swift`（413 行）
- `HappyPianistAVPTests/Practice/DuetQualityRegressionFixtures.swift`（135 行）
- `HappyPianistAVPTests/Practice/DuetQualityRegressionTests.swift`（56 行）
- `HappyPianistAVPTests/Practice/DuetTurnTakingCoreTests.swift`（114 行）
- `HappyPianistAVPTests/Practice/HandPianoActivityGateTests.swift`（186 行）
- `HappyPianistAVPTests/Practice/ImprovScheduleBuilderTests.swift`（48 行）
- `HappyPianistAVPTests/Practice/ImprovScheduleBuilderV2Tests.swift`（41 行）
- `HappyPianistAVPTests/Practice/ImprovSeedResolverTests.swift`（20 行）
- `HappyPianistAVPTests/Practice/ManualAdvanceStrategyTests.swift`（151 行）
- `HappyPianistAVPTests/Practice/PerformanceRNNEventDecodingTests.swift`（37 行）
- `HappyPianistAVPTests/Practice/PerformanceRNNEventEncodingTests.swift`（43 行）
- `HappyPianistAVPTests/Practice/PianoGuideHighlightStyleTests.swift`（40 行）
- `HappyPianistAVPTests/Practice/PianoGuideKeyHighlightResolverTests.swift`（111 行）
- `HappyPianistAVPTests/Practice/PracticeActiveRangeTests.swift`（99 行）
- `HappyPianistAVPTests/Practice/PracticeAttemptReducerTests.swift`（309 行）
- `HappyPianistAVPTests/Practice/PracticeAudioRecognitionCoordinatorTests.swift`（249 行）
- `HappyPianistAVPTests/Practice/PracticeFeedbackPolicyTests.swift`（140 行）
- `HappyPianistAVPTests/Practice/PracticeFeedbackViewModelTests.swift`（43 行）
- `HappyPianistAVPTests/Practice/PracticeFlowCoordinatorTests.swift`（70 行）
- `HappyPianistAVPTests/Practice/PracticeHandGateControllerTests.swift`（84 行）
- `HappyPianistAVPTests/Practice/PracticeHighlightGuideControllerTests.swift`（143 行）
- `HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesApplicationTests.swift`（215 行）
- `HappyPianistAVPTests/Practice/PracticeHistoricalPreferencesResolverTests.swift`（161 行）
- `HappyPianistAVPTests/Practice/PracticeHotspotPolicyTests.swift`（36 行）
- `HappyPianistAVPTests/Practice/PracticeLaunchFailureTests.swift`（127 行）
- `HappyPianistAVPTests/Practice/PracticeLaunchLifecycleTests.swift`（788 行）
- `HappyPianistAVPTests/Practice/PracticeLaunchViewModelTests.swift`（1560 行）
- `HappyPianistAVPTests/Practice/PracticeLearningLoopFixtureTests.swift`（47 行）
- `HappyPianistAVPTests/Practice/PracticeLearningLoopIntegrationTests.swift`（179 行）
- `HappyPianistAVPTests/Practice/PracticeLocalizationPolicyTests.swift`（139 行）
- `HappyPianistAVPTests/Practice/PracticeLocalizationViewModelTests.swift`（212 行）
- `HappyPianistAVPTests/Practice/PracticeMIDIInputCoordinatorTests.swift`（189 行）
- `HappyPianistAVPTests/Practice/PracticeManualReplayCoordinatorTests.swift`（155 行）
- `HappyPianistAVPTests/Practice/PracticeManualReplaySequenceBuilderTests.swift`（59 行）
- `HappyPianistAVPTests/Practice/PracticeMeasureMapViewModelTests.swift`（49 行）
- `HappyPianistAVPTests/Practice/PracticeNextActionPolicyTests.swift`（47 行）
- `HappyPianistAVPTests/Practice/PracticePlaybackCoordinatorTests.swift`（241 行）
- `HappyPianistAVPTests/Practice/PracticePositiveFeedbackIntegrationTests.swift`（34 行）
- `HappyPianistAVPTests/Practice/PracticePreparationCancellationTests.swift`（31 行）
- `HappyPianistAVPTests/Practice/PracticePreparationIdentityTests.swift`（99 行）
- `HappyPianistAVPTests/Practice/PracticeProgressCoordinatorTests.swift`（337 行）
- `HappyPianistAVPTests/Practice/PracticeProgressModelsTests.swift`（370 行）
- `HappyPianistAVPTests/Practice/PracticeProgressRepositoryTests.swift`（434 行）
- `HappyPianistAVPTests/Practice/PracticeResumeLifecycleTests.swift`（662 行）
- `HappyPianistAVPTests/Practice/PracticeRoundConfigurationControllerTests.swift`（166 行）
- `HappyPianistAVPTests/Practice/PracticeRoundSummaryViewModelTests.swift`（154 行）
- `HappyPianistAVPTests/Practice/PracticeSequencerPlaybackServiceProtocolTests.swift`（29 行）
- `HappyPianistAVPTests/Practice/PracticeSequencerSequenceBuilderTests.swift`（89 行）
- `HappyPianistAVPTests/Practice/PracticeSessionAudioRecognitionTests.swift`（463 行）
- `HappyPianistAVPTests/Practice/PracticeSessionHandSeparatedMatchingTests.swift`（80 行）
- `HappyPianistAVPTests/Practice/PracticeSessionMIDIOnlyModeTests.swift`（238 行）
- `HappyPianistAVPTests/Practice/PracticeSessionRecorderTests.swift`（487 行）
- `HappyPianistAVPTests/Practice/PracticeSessionReplayGateTests.swift`（238 行）
- `HappyPianistAVPTests/Practice/PracticeSessionViewModelTests.swift`（1890 行）
- `HappyPianistAVPTests/Practice/PracticeSoundRoutingSettingsTests.swift`（85 行）
- `HappyPianistAVPTests/Practice/PracticeStepBuilderTests.swift`（322 行）
- `HappyPianistAVPTests/Practice/PracticeStepNavigatorTests.swift`（42 行）
- `HappyPianistAVPTests/Practice/PreparedPracticeLifecycleTests.swift`（442 行）
- `HappyPianistAVPTests/Practice/StepMatcherTests.swift`（23 行）
- `HappyPianistAVPTests/Recording/RecordingMIDIInputTests.swift`（176 行）
- `HappyPianistAVPTests/Recording/RecordingTakeIntegrationTests.swift`（88 行）
- `HappyPianistAVPTests/Recording/RecordingTakeRecorderTests.swift`（105 行）
- `HappyPianistAVPTests/Recording/RecordingTakeSequenceAdapterTests.swift`（63 行）
- `HappyPianistAVPTests/Recording/RecordingTakeStoreTests.swift`（151 行）
- `HappyPianistAVPTests/Support/PracticeAttemptTestSupport.swift`（10 行）
- `HappyPianistAVPTests/Support/PracticeSessionViewModel+TestConvenienceInit.swift`（111 行）
- `HappyPianistAVPTests/Support/SyntheticAudioFixtures.swift`（83 行）
- `HappyPianistAVPTests/Tracking/ARGuideImmersiveLifecycleTests.swift`（71 行）
- `HappyPianistAVPTests/Tracking/ARTrackingRequirementsTests.swift`（26 行）
- `HappyPianistAVPTests/Tracking/ARTrackingServiceLifecycleTests.swift`（25 行）
- `HappyPianistAVPTests/Tracking/CurrentValueAsyncStreamRelayTests.swift`（56 行）
- `HappyPianistAVPTests/Tracking/FingerTipsSnapshotTests.swift`（37 行）
- `HappyPianistAVPTests/VirtualPiano/KeyboardFrameTests.swift`（50 行）
- `HappyPianistAVPTests/VirtualPiano/VirtualKeyboardPoseServiceTests.swift`（126 行）
- `HappyPianistAVPTests/VirtualPiano/VirtualPianoInputControllerTests.swift`（163 行）
- `HappyPianistAVPTests/VirtualPiano/VirtualPianoKeyGeometryServiceTests.swift`（86 行）
- `HappyPianistAVPTests/VirtualPiano/VirtualPianoTests.swift`（408 行）

## 计划审查时必须再次核对的高风险汇合点

- `HappyPianistAVP/Services/Practice/Session/PracticePreparationService.swift`
- `HappyPianistAVP/Models/Practice/PracticeModels.swift`
- `HappyPianistAVP/Services/Practice/Autoplay/AutoplayPerformanceTimeline.swift`
- `HappyPianistAVP/Services/Practice/Guides/PianoHighlightGuideBuilderService.swift`
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionStateStore.swift`
- `HappyPianistAVP/ViewModels/PracticeSession/PracticeSessionViewModel.swift`
- `HappyPianistAVP/Services/Audio/PracticeSequencerPlaybackService.swift`
- `HappyPianistAVP/Services/Audio/CoreMIDIPracticePlaybackService.swift`
- `HappyPianistAVP/Services/Practice/Input/PracticeMIDIInputService.swift`
- `HappyPianistAVP/Services/Practice/Input/PracticeAudioRecognitionInputService.swift`
- `HappyPianistAVP/Services/Practice/Input/VirtualPianoInputController.swift`
- `HappyPianistAVP/Services/Recording/MIDIRecordingCoordinator.swift`
- `HappyPianistAVP/Services/Recording/RecordingTakeRecorder.swift`
- `HappyPianistAVP/Services/Practice/Progress/PracticeAttemptReducer.swift`
- `HappyPianistAVP/Services/Practice/Feedback/PracticeFeedbackPolicy.swift`
- `HappyPianistAVP/ViewModels/LiveAppGraph.swift`

## 证据边界

本文件记录计划制定前已审查范围，不等于运行验证。当前环境未运行 Xcode、visionOS Simulator、真机、音频测量或钢琴家盲听；计划中所有这类验收仍须在可用环境中产生证据。

## 计划审计后补充核对

- `HappyPianist.xcodeproj/project.pbxproj` 中 `HappyPianistAVP` 与 `HappyPianistAVPTests` 均使用 `PBXFileSystemSynchronizedRootGroup`；新增文件会由同步分组进入工程，但每个创建 task 仍要求同时接入实际 consumer 或 composition root。
- 录制相关 `RecordingTakeStore`、MIDI adapter 与 sequence adapter 并非独立源码文件；实际类型和实现集中在 `HappyPianistAVP/Services/Recording/RecordingSupport.swift`，计划中的路径已全部修正。
- `PreparedPractice` 的直接成员构造点已通过 source search 与 codegraph 交叉核对；`P5-T4` 覆盖生产构造服务、全部直接测试构造文件与共享 test factory，不引入无 plan 的兼容 initializer。
- `ScorePerformancePlan` 的 step、highlight 与 notation 输出继续通过 Service 投影，不把副作用或业务转换逻辑挂回 Model。
- alignment candidate、cost、incremental 与 recorded-take 路径复用同一 engine；assessment 各维度复用同一 service，避免单实现协议和一层 wrapper 膨胀。
- final plan 不创建 `Package.swift`，不迁移 SwiftPM，不提交 `.github/features/**`，不新增用户可见音高 / 节奏 / 力度模式。
- 计划最终覆盖 15 phases、158 tasks、54/54 唯一 primary requirement owners；所有 task anchor、文件创建顺序、测试入口、Git scope 与本地 Markdown 链接均进入最终自动审计。
- 本次仅核对与编写计划；未运行 `xcodebuild test`、Simulator、真机、音频测量、盲听或教学实验，所有此类证据仍保持 pending。
