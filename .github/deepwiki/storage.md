# 存储

## 存储面总览
| 存储 | 路径 | 写入方 | 读取方 |
| --- | --- | --- | --- |
| SwiftData store | `Application Support/<bundle>/LonelyPianist.store` | macOS repositories | macOS ViewModel |
| 世界锚点校准 | `Documents/piano-worldanchor-calibration.json` | `WorldAnchorCalibrationStore` | `AppState` / `ARGuideViewModel` |
| 曲库索引 | `Documents/SongLibrary/index.json` | `SongLibraryIndexStore` | `SongLibraryViewModel` |
| 曲谱文件 | `Documents/SongLibrary/scores/` | `SongFileStore` | 曲库 / parser |
| 音频文件 | `Documents/SongLibrary/audio/` | `AudioImportService` | 曲库播放 |
| Python debug | `piano_dialogue_server/out/dialogue_debug/*` | `write_debug_bundle()` | 本地排障 |

## macOS SwiftData
| 实体 | 作用 |
| --- | --- |
| `MappingConfigEntity` | mapping payload 持久化 |
| `RecordingTakeEntity` | take 元数据 |
| `RecordedNoteEntity` | take 音符明细 |

## AVP 曲库写入顺序
1. 内置曲目来自 app bundle（`Resources/SeedScores`），由 `BundledSongLibraryProvider` 在运行时提供；不写入 `index.json`。
2. 导入时 `SongFileStore` 复制 MusicXML 到 `scores/`。
3. `SongLibraryIndexStore` 原子写入 `index.json`（只记录用户导入条目）。
4. 绑定音频时 `AudioImportService` 复制音频到 `audio/` 并更新索引条目。
5. 删除用户导入曲目时先删索引，再删文件；文件删除失败会显式提示“索引已移除但文件删除失败”。

## 一致性和恢复
| 场景 | 策略 |
| --- | --- |
| SwiftData 容器损坏 | `ModelContainerFactory` 删除 store/wal/shm/journal 后重建 |
| 校准文件不存在 | 返回 `nil`，视为未设置 |
| 内置曲目缺失 | 退化为“只显示用户导入索引” |
| 索引和文件漂移 | 通过重新导入或手工清理恢复 |

## 命名和安全
- 导入文件统一加时间戳前缀避免覆盖。
- 文件名都走 `lastPathComponent` 过滤。
- index 用 ISO8601 日期编码和原子写入。

## Coverage Gaps
- 没有独立的 schema migration 页面；目前迁移逻辑分散在服务实现中。
