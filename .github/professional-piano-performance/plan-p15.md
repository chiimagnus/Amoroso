# Plan P15 - 专业 corpus、真机与钢琴家验证及能力声明门

**Goal:** 建立能证明系统专业性的完整证据链，并以证据决定文档和产品声明。

**Non-goals:** 本 phase 不通过伪造阈值、单一 demo 或未执行的人工清单宣布完成。

**Approach:** 扩充 exporter 与 repertoire corpus，统一 score / performance snapshots、input replay、Simulator matrix、hardware metrics、pianist blind test、assessment agreement 与 coaching efficacy。最后执行 traceability closeout、清理旧实现并同步文档。

**Acceptance:**
- golden corpus 覆盖审查列出的高风险语义和多个导出器。
- 自动化测试、真机指标、盲听、评分一致性与教学有效性分别有证据。
- 能力声明逐项通过 completion definition。
- 54 个审查编号均有 resolved、accepted limitation 或 blocked evidence 状态。

**Rules:**
- 没有实际执行的真机或钢琴家步骤只能标记 pending evidence。
- 第三方 fixtures 必须有来源和授权。
- 测试结果不写入长期架构文档作为流水账。

**State / lifecycle:** 验证工具按单次 run 创建；真机 session 明确 warm-up、start、stop 与 export。人工研究数据匿名化并单独授权。

**Threading / actor:** 自动化 runner 不阻塞 MainActor；硬件 timestamps 使用 monotonic clock；报告生成可后台执行。

**Debug / observability:** 报告只包含聚合指标、匿名 fixture 或 participant IDs 和版本；禁止原始曲谱、逐音人体数据与密钥。

**Testing strategy:** xcodebuild full suite、corpus snapshots、replay matrix、hardware checklist、blinded pianist protocol 与 assessment / coaching studies。

**Audit focus:**
- 是否把工具已存在误当证据已通过。
- claim gate 是否允许缺少关键证据。
- docs 是否与最终代码和限制一致。
- 是否残留 dual paths 或 obsolete tests。

**Phase validation commands:**
- Destinations: `xcodebuild -showdestinations -project HappyPianist.xcodeproj -scheme HappyPianistAVP`
- Tests: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`

---

<a id="p15-t1"></a>
## P15-T1 建立专业 corpus manifest 与授权检查

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json`
- Create: `HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift`
- Modify: `HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json`

**Implementation:**
1. 为每个 score 记录 exporter 与 version、来源、授权、语义标签、expected outputs 和允许分发范围。
2. CI 或 tests 拒绝未登记、重复或缺授权字段的 fixture。
3. 外部研究数据只登记方法参考，不直接复制为产品真值。

**Validation:**
- Focus: HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json' 'HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift' 'HappyPianistAVPTests/Fixtures/PianoPerformanceFixtureManifest.json'`
- Run: `git commit -m "test: P15-T1 - 建立专业 corpus manifest 与授权检查"`

---

<a id="p15-t2"></a>
## P15-T2 导入 MuseScore 可授权最小 golden scores

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/MuseScore/`
- Modify: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json`

**Implementation:**
1. 收集或自行导出可授权的 MuseScore 最小 scores，并记录 exporter version、来源与授权。
2. 优先覆盖尚未由其他 exporter fixture 覆盖的 cross-staff、voice、grace、pedal、repeat、transpose、meter 或 ornament 语义。
3. 无法获得合法 fixture 时将证据标记 blocked，不复制不明来源文件或伪造 exporter provenance。

**Validation:**
- Focus: HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/MuseScore/' 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json'`
- Run: `git commit -m "test: P15-T2 - 导入 MuseScore 可授权最小 golden scores"`

---

<a id="p15-t3"></a>
## P15-T3 导入 Dorico 可授权最小 golden scores

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Dorico/`
- Modify: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json`

**Implementation:**
1. 收集或自行导出可授权的 Dorico 最小 scores，并记录 exporter version、来源与授权。
2. 优先覆盖尚未由其他 exporter fixture 覆盖的 cross-staff、voice、grace、pedal、repeat、transpose、meter 或 ornament 语义。
3. 无法获得合法 fixture 时将证据标记 blocked，不复制不明来源文件或伪造 exporter provenance。

**Validation:**
- Focus: HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Dorico/' 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json'`
- Run: `git commit -m "test: P15-T3 - 导入 Dorico 可授权最小 golden scores"`

---

<a id="p15-t4"></a>
## P15-T4 导入 Sibelius 可授权最小 golden scores

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Sibelius/`
- Modify: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json`

**Implementation:**
1. 收集或自行导出可授权的 Sibelius 最小 scores，并记录 exporter version、来源与授权。
2. 优先覆盖尚未由其他 exporter fixture 覆盖的 cross-staff、voice、grace、pedal、repeat、transpose、meter 或 ornament 语义。
3. 无法获得合法 fixture 时将证据标记 blocked，不复制不明来源文件或伪造 exporter provenance。

**Validation:**
- Focus: HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Sibelius/' 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json'`
- Run: `git commit -m "test: P15-T4 - 导入 Sibelius 可授权最小 golden scores"`

---

<a id="p15-t5"></a>
## P15-T5 导入 Finale 可授权最小 golden scores

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Finale/`
- Modify: `HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json`

**Implementation:**
1. 收集或自行导出可授权的 Finale 最小 scores，并记录 exporter version、来源与授权。
2. 优先覆盖尚未由其他 exporter fixture 覆盖的 cross-staff、voice、grace、pedal、repeat、transpose、meter 或 ornament 语义。
3. 无法获得合法 fixture 时将证据标记 blocked，不复制不明来源文件或伪造 exporter provenance。

**Validation:**
- Focus: HappyPianistAVPTests/Support/ProfessionalCorpusManifestTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/Finale/' 'HappyPianistAVPTests/Fixtures/ProfessionalCorpus/manifest.json'`
- Run: `git commit -m "test: P15-T5 - 导入 Finale 可授权最小 golden scores"`

---

<a id="p15-t6"></a>
## P15-T6 建立全 corpus score snapshot runner

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/MusicXML/ProfessionalCorpusScoreSnapshotTests.swift`
- Modify: `HappyPianistAVPTests/Support/MusicXMLScoreSnapshot.swift`

**Implementation:**
1. 遍历 manifest 生成 source facts、normalization、performed order 与 notation snapshots。
2. 失败按 fixture 和 requirement ID 输出最小 diff。
3. 更新 snapshot 需要显式 review，不提供 blanket overwrite。

**Validation:**
- Focus: HappyPianistAVPTests/MusicXML/ProfessionalCorpusScoreSnapshotTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/MusicXML/ProfessionalCorpusScoreSnapshotTests.swift' 'HappyPianistAVPTests/Support/MusicXMLScoreSnapshot.swift'`
- Run: `git commit -m "test: P15-T6 - 建立全 corpus score snapshot runner"`

---

<a id="p15-t7"></a>
## P15-T7 建立全 corpus performance event runner

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Playback/ProfessionalCorpusPerformanceSnapshotTests.swift`
- Modify: `HappyPianistAVPTests/Support/PerformanceEventSnapshot.swift`

**Implementation:**
1. 断言 note IDs、on/off、velocity、tempo、controllers、pause、order 与 approximation provenance。
2. 应用内与 CoreMIDI sequence 使用同一 expected event stream。
3. active range、seek 与 loop 至少覆盖每个高风险 fixture。

**Validation:**
- Focus: HappyPianistAVPTests/Playback/ProfessionalCorpusPerformanceSnapshotTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Playback/ProfessionalCorpusPerformanceSnapshotTests.swift' 'HappyPianistAVPTests/Support/PerformanceEventSnapshot.swift'`
- Run: `git commit -m "test: P15-T7 - 建立全 corpus performance event runner"`

---

<a id="p15-t8"></a>
## P15-T8 建立输入重放混淆矩阵 runner

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `HappyPianistAVPTests/Practice/PerformanceObservationConfusionMatrixTests.swift`
- Modify: `HappyPianistAVPTests/Fixtures/PerformanceObservationReplays.json`
- Modify: `HappyPianistAVPTests/Fixtures/SyntheticHandContactTraces.json`

**Implementation:**
1. 分别统计 MIDI、target audio 与 hand 的 hit、miss、false positive、ambiguous 和 insufficient。
2. 按 capability 与 calibration version 分层，不混成总准确率。
3. 阈值变化必须更新 expected matrix 并解释。

**Validation:**
- Focus: HappyPianistAVPTests/Practice/PerformanceObservationConfusionMatrixTests.swift
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'HappyPianistAVPTests/Practice/PerformanceObservationConfusionMatrixTests.swift' 'HappyPianistAVPTests/Fixtures/PerformanceObservationReplays.json' 'HappyPianistAVPTests/Fixtures/SyntheticHandContactTraces.json'`
- Run: `git commit -m "test: P15-T8 - 建立输入重放混淆矩阵 runner"`

---

<a id="p15-t9"></a>
## P15-T9 建立 visionOS Simulator 全链路矩阵

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/visionos-piano-performance-matrix.md`
- Modify: `docs/testing/core-function-checklist.md`

**Implementation:**
1. 列出准备、playback、seek、loop、MIDI fake、audio failure、tracking lifecycle、recording、alignment、assessment、coaching 与 AI 的自动化矩阵。
2. 记录可执行 xcodebuild test 命令和 destination 获取方法。
3. 只有实际 run log 才可标记通过。

**Validation:**
- Focus: docs/testing/visionos-piano-performance-matrix.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/visionos-piano-performance-matrix.md' 'docs/testing/core-function-checklist.md'`
- Run: `git commit -m "docs: P15-T9 - 建立 visionOS Simulator 全链路矩阵"`

---

<a id="p15-t10"></a>
## P15-T10 建立真机 latency、jitter 与可靠性协议

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/piano-hardware-latency-protocol.md`
- Modify: `HappyPianistAVP/Models/Diagnostics/PianoOutputMetrics.swift`
- Modify: `docs/testing/piano-performance-validation.md`

**Implementation:**
1. 定义 event-to-audio、hand-motion-to-audio、MIDI jitter、chord spread、miss、stuck note 与 route recovery 的测量方法。
2. 保留 calibration knob、sample count、设备、OS 与 audio route 元数据。
3. 不预填未测阈值；先建立 baseline，再由钢琴家和产品验收锁定。

**Validation:**
- Focus: docs/testing/piano-hardware-latency-protocol.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/piano-hardware-latency-protocol.md' 'HappyPianistAVP/Models/Diagnostics/PianoOutputMetrics.swift' 'docs/testing/piano-performance-validation.md'`
- Run: `git commit -m "docs: P15-T10 - 建立真机 latency、jitter 与可靠性协议"`

---

<a id="p15-t11"></a>
## P15-T11 建立钢琴家盲听与演奏验证协议

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/pianist-blind-evaluation-protocol.md`
- Modify: `docs/testing/piano-performance-validation.md`

**Implementation:**
1. 曲目覆盖 Bach、Mozart 或 Haydn、Beethoven、Chopin、Debussy 或 Ravel、Liszt 或 Rachmaninoff 类织体。
2. 盲评 fidelity、timing、voicing、pedal、articulation、style plausibility 与可练习性。
3. 记录匿名参与者、设备和版本；不得把未执行协议称为通过。

**Validation:**
- Focus: docs/testing/pianist-blind-evaluation-protocol.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/pianist-blind-evaluation-protocol.md' 'docs/testing/piano-performance-validation.md'`
- Run: `git commit -m "docs: P15-T11 - 建立钢琴家盲听与演奏验证协议"`

---

<a id="p15-t12"></a>
## P15-T12 建立 assessment 与教师标注一致性协议

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/performance-assessment-validity-protocol.md`
- Modify: `docs/testing/piano-performance-validation.md`

**Implementation:**
1. 定义专家标注集、inter-rater agreement、系统 precision、recall、correlation 与 unknown handling。
2. 按 pitch、timing、duration、dynamics、voicing 与 pedal 分维，不只给总分。
3. 阈值和 rubric version 与结果绑定。

**Validation:**
- Focus: docs/testing/performance-assessment-validity-protocol.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/performance-assessment-validity-protocol.md' 'docs/testing/piano-performance-validation.md'`
- Run: `git commit -m "docs: P15-T12 - 建立 assessment 与教师标注一致性协议"`

---

<a id="p15-t13"></a>
## P15-T13 建立 coaching 教学有效性协议

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/coaching-efficacy-protocol.md`
- Modify: `docs/testing/piano-performance-validation.md`

**Implementation:**
1. 定义 before assessment、action、练习剂量、after assessment 与对照条件。
2. 衡量问题是否改善、是否迁移到完整段落、是否出现负面副作用。
3. 不以用户点击建议当教学有效。

**Validation:**
- Focus: docs/testing/coaching-efficacy-protocol.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/coaching-efficacy-protocol.md' 'docs/testing/piano-performance-validation.md'`
- Run: `git commit -m "docs: P15-T13 - 建立 coaching 教学有效性协议"`

---

<a id="p15-t14"></a>
## P15-T14 建立专业能力声明 gate

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/piano-capability-claim-gates.md`
- Modify: `docs/piano-performance-quality.md`

**Implementation:**
1. 为乐谱忠实示范、MIDI 演奏评价、表现力虚拟琴与专业虚拟指导逐项定义自动化、Simulator、真机与钢琴家证据门。
2. 每个 gate 绑定 requirement ID、证据文件、版本和 pending / passed / blocked 语义，禁止以功能存在替代证据通过。
3. 更新质量审查文档的完成定义与当前能力措辞；未满足 gate 的能力继续使用准确受限描述。

**Validation:**
- Focus: docs/testing/piano-capability-claim-gates.md, docs/piano-performance-quality.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/testing/piano-capability-claim-gates.md' 'docs/piano-performance-quality.md'`
- Run: `git commit -m "docs: P15-T14 - 建立专业能力声明 gate"`

---

<a id="p15-t15"></a>
## P15-T15 同步公开入口与能力边界文档

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `docs/overview.md`

**Implementation:**
1. 按 claim gate 同步中英文 README 的当前能力、限制和验证状态，删除已过期或超出证据的描述。
2. 在 docs/overview.md 中接入新增验证协议与能力 gate，保持知识库导航可达。
3. 只描述当前实现边界与长期质量基线，不追加 phase 流水账或未执行的通过结论。

**Validation:**
- Focus: README.md, README.en.md, docs/overview.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'README.md' 'README.en.md' 'docs/overview.md'`
- Run: `git commit -m "docs: P15-T15 - 同步公开入口与能力边界文档"`

---

<a id="p15-t16"></a>
## P15-T16 同步架构、数据流与持久化文档

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Modify: `docs/architecture.md`
- Modify: `docs/data-flow.md`
- Modify: `docs/storage.md`
- Modify: `docs/configuration.md`
- Modify: `docs/modules/happypianist-avp.md`

**Implementation:**
1. 同步最终 ScorePerformancePlan、PerformanceObservation、alignment、assessment、coaching 与平台 adapter 的真实依赖方向。
2. 同步准备、播放、输入、录制、评价和指导的数据流，以及小节事实持久化和派生状态不落盘边界。
3. 同步实际存在的配置与诊断入口，删除旧双轨路径、旧模型名和已经失效的架构说明。

**Validation:**
- Focus: docs/architecture.md, docs/data-flow.md, docs/storage.md, docs/configuration.md, docs/modules/happypianist-avp.md
- Run: `python3 - <<'PY'`（执行 task 时编写临时 Markdown 链接与引用检查，不入库）
- Integration: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`（文档涉及实现边界时仍执行）
- Expected: 目标测试通过，现有相关回归测试无新增失败。

**Atomic commit:**
- Run: `git add 'docs/architecture.md' 'docs/data-flow.md' 'docs/storage.md' 'docs/configuration.md' 'docs/modules/happypianist-avp.md'`
- Run: `git commit -m "docs: P15-T16 - 同步架构、数据流与持久化文档"`

---

<a id="p15-t17"></a>
## P15-T17 执行最终全回归、清理与 traceability closeout

**Requirements:** 阶段基础设施 / 验收要求

**Files:**
- Create: `docs/testing/piano-performance-evidence-index.md`
- Modify: `docs/testing/piano-capability-claim-gates.md`

**Implementation:**
1. 运行完整 xcodebuild test，再按条件执行 Simulator、真机、盲听与研究协议；未执行项明确标记 pending evidence。
2. 在可提交的 evidence index 与 claim gates 中引用具体测试、指标和协议结果；同时由执行器本地回写 requirements-traceability.md 与 reviewed-scope.md，但不得 git add 计划目录。
3. 使用 codegraph 复查旧调用方、孤立文件和依赖方向；若发现残留，先以 P15 audit finding 记录具体路径、完成修复与验证，再关闭本 feature。

**Validation:**
- Focus: HappyPianistAVPTests 全部测试, docs/testing/piano-capability-claim-gates.md, docs/testing/piano-performance-evidence-index.md
- Run: `xcodebuild test -project HappyPianist.xcodeproj -scheme HappyPianistAVP -destination 'platform=visionOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- Expected: 完整 Xcode 测试实际通过；真机与人工证据按真实执行状态记录；本地计划状态已回写但未提交。

**Atomic commit:**
- Run: `git add 'docs/testing/piano-performance-evidence-index.md' 'docs/testing/piano-capability-claim-gates.md'`
- Run: `git commit -m "docs: P15-T17 - 执行最终全回归、清理与 traceability closeout"`

---

## Phase Audit

- Audit file: `audit-p15.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环。
- Flow: 先记录发现 → 修复问题 → 运行本 phase 验证命令 → 回填 evidence。
- Required focus: 是否把工具已存在误当证据已通过。；claim gate 是否允许缺少关键证据。；docs 是否与最终代码和限制一致。；是否残留 dual paths 或 obsolete tests。
