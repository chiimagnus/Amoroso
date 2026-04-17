# 存储

## 存储面总览
| 存储面 | 路径 / 载体 | 写入方 | 读取方 | 主要内容 |
| --- | --- | --- | --- | --- |
| SwiftData Store | `Application Support/<bundle>/LonelyPianist.store` | macOS repositories | macOS ViewModel/Services | 映射配置、录音 take、录音 notes |
| AVP 校准文件 | Documents `piano-calibration.json` | `PianoCalibrationStore` | `AppModel` | A0/C8、平面参数、键宽 |
| AVP 导入谱面 | Documents `ImportedScores/*` | `MusicXMLImportService` | `ContentView` + parser | 用户导入的 MusicXML 副本 |
| OMR 输出目录 | `piano_dialogue_server/out/omr/*` | OMR pipeline | 用户/HTTP 返回 | input/debug/output/score.musicxml |
| Dialogue 调试目录 | `piano_dialogue_server/out/dialogue_debug/*` | `debug_artifacts.py` | 开发排障流程 | request/response/summary/prompt.mid/reply.mid |
| 脚本调试产物 | `piano_dialogue_server/out/*.mid` | test scripts/test_client | 人工试听验证 | 离线生成或回环回复 MIDI |

## SwiftData 模型与关系
| 实体 | 位置 | 关键字段 | 关系 |
| --- | --- | --- | --- |
| `MappingConfigEntity` | `Models/Storage/MappingConfigEntity.swift` | `id/updatedAt/payloadData` | 单条配置记录 |
| `RecordingTakeEntity` | `Models/Storage/RecordingTakeEntity.swift` | `id/name/createdAt/updatedAt/durationSec` | 1 -> N notes |
| `RecordedNoteEntity` | `Models/Storage/RecordedNoteEntity.swift` | `note/velocity/channel/startOffsetSec/durationSec` | 属于某 take |

## 持久化读写路径
- `SwiftDataMappingConfigRepository`：
  - 首次空库时 seed 默认配置；
  - 解码失败会 destructive reset 后 reseed，避免坏数据持续污染。
- `SwiftDataRecordingTakeRepository`：
  - `saveTake` 对已有 take 先删旧 notes 再写新 notes；
  - `fetchTakes` 按 `updatedAt` / `createdAt` 倒序返回。
- `ModelContainerFactory`：
  - 容器初始化失败会尝试删除 store/wal/shm/journal 后重建。

## 文件型存储流程
1. AVP 导入：
   - 通过 fileImporter 拿到 security-scoped URL；
   - 复制到 Documents `ImportedScores/<timestamp>-<filename>`；
   - 再解析构建练习步骤。
2. OMR：
   - 为每次输入创建唯一 job 目录；
   - 预处理文件写 `input/`；
   - debug 图写 `debug/`；
   - MusicXML 写 `output/score.musicxml`。

## 数据一致性与恢复
- SwiftData：
  - 配置解码失败时自动重置（有日志）；
  - 数据库损坏时可通过容器重建策略恢复。
- AVP 校准：
  - 未找到文件返回 `nil`，不会硬失败；
  - 文件不可读/不可写时通过 status message 暴露错误。
- OMR：
  - 输入不存在、页码无效、模型推理失败均抛显式 `OMRConvertError`。

## 风险与注意事项
- `ModelContainerFactory` 的自动删库重建对损坏恢复友好，但会丢失历史数据。
- OMR `out/` 与 dialogue debug 目录可能增长较快，需定期清理。
- AVP 文档目录可能累积大量导入谱面副本，当前无内建清理策略。

## 示例片段
```swift
let schema = Schema([
    MappingConfigEntity.self,
    RecordingTakeEntity.self,
    RecordedNoteEntity.self
])
```

```python
job_root = root / f"{basename}-{timestamp}-{uuid4().hex[:8]}"
input_dir = job_root / "input"
debug_dir = job_root / "debug"
output_dir = job_root / "output"
```

## Coverage Gaps
- 当前未见“数据迁移版本化策略”文档（例如 schema 版本演进说明）。
- 目录清理策略（OMR/debug/imported scores）尚未产品化。

## 来源引用（Source References）
- `LonelyPianist/Services/Storage/ModelContainerFactory.swift`
- `LonelyPianist/Services/Storage/SwiftDataMappingConfigRepository.swift`
- `LonelyPianist/Services/Storage/SwiftDataRecordingTakeRepository.swift`
- `LonelyPianist/Models/Storage/MappingConfigEntity.swift`
- `LonelyPianist/Models/Storage/RecordingTakeEntity.swift`
- `LonelyPianist/Models/Storage/RecordedNoteEntity.swift`
- `LonelyPianistAVP/Services/PianoCalibrationStore.swift`
- `LonelyPianistAVP/Services/MusicXMLImportService.swift`
- `piano_dialogue_server/omr/convert.py`
- `piano_dialogue_server/server/debug_artifacts.py`
