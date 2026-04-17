# 模块：OMR Pipeline（PDF/图片 -> MusicXML）

## 职责与边界
- **负责**：接收谱面文件（PDF/JPG/PNG），完成预处理、调用 oemer 推理、输出 MusicXML 与调试产物。
- **不负责**：乐谱消费端 UI（AVP）、对话推理、MIDI 监听。
- **位置**：`piano_dialogue_server/omr/` + `server/omr_routes.py` + macOS `OMRConversionService`。

## 目录范围
| 路径 | 角色 | 备注 |
| --- | --- | --- |
| `omr/preprocess.py` | 输入预处理 | PDF 渲染 / 图片归一化 |
| `omr/convert.py` | 转换主流程 | job 目录、oemer 调用、错误包装 |
| `omr/cli.py` | CLI 入口 | 命令行参数与结果输出 |
| `server/omr_routes.py` | HTTP 路由入口 | 上传校验与参数映射 |
| `omr/packaging/build_pyinstaller.sh` | 打包脚本 | 生成 `lp-omr-convert` |
| `LonelyPianist/Services/OMR/OMRConversionService.swift` | macOS 本地调用桥接 | 优先 binary，回退 Python 模式 |

## 入口点与生命周期
| 入口 / 类型 | 位置 | 何时触发 | 结果 |
| --- | --- | --- | --- |
| CLI | `python -m omr.cli --input ...` | 手工命令运行 | 打印 `job_dir` 与 `musicxml_path` |
| HTTP | `POST /omr/convert` | 上传文件请求 | 返回 JSON（可 inline xml） |
| macOS 面板 | `OMRPanelView` | App 内点击 Convert | 调用 binary/Python 并显示输出路径 |
| 打包流程 | `build_pyinstaller.sh` | 需要分发 CLI 时 | 产出 one-folder 可执行目录 |

## 关键文件
| 文件 | 用途 | 为什么值得看 |
| --- | --- | --- |
| `omr/convert.py` | 全流程编排 | MVP 规则、异常路径都在此 |
| `omr/preprocess.py` | 预处理策略 | 决定输入质量与可解析性 |
| `server/omr_routes.py` | 外部 API 边界 | 安全校验与 HTTP 错误映射 |
| `omr/cli.py` | 开发调试入口 | 最短路径复现问题 |
| `OMRConversionService.swift` | App 侧执行桥 | 本地环境兼容策略 |

## 上下游依赖
| 方向 | 对象 | 关系 | 影响 |
| --- | --- | --- | --- |
| 上游 | 用户上传/选中文件 | 输入源 | 文件类型与页码决定转换路径 |
| 下游 | `fitz` + `Pillow` | 预处理依赖 | PDF 渲染失败会中断流程 |
| 下游 | `oemer.ete` | 推理核心 | checkpoints 缺失或推理错误会失败 |
| 下游 | AVP 导入流程 | 消费输出 MusicXML | 输出格式/路径稳定性关键 |

## 对外接口与契约
| 接口 / 命令 / 类型 | 位置 | 调用方 | 含义 |
| --- | --- | --- | --- |
| CLI `--input --output-root --pdf-dpi --page --normalize-photo` | `omr/cli.py` | 开发者/打包工具 | 转换任务参数 |
| HTTP `POST /omr/convert` | `server/omr_routes.py` | macOS/外部客户端 | multipart 上传并返回路径 |
| `OMRJobPaths` | `omr/convert.py` | CLI/HTTP 内部 | 统一 job 目录结构 |
| `musicxml_path=` stdout 行 | `omr/cli.py` | macOS `OMRConversionService` | Swift 侧解析输出路径 |

## 数据契约、状态与存储
- job 目录结构固定：
  - `input/`：预处理后页面图像；
  - `debug/`：oemer teaser 等诊断产物；
  - `output/score.musicxml`：最终输出。
- HTTP 返回最小契约：
  - `status`
  - `musicxml_path`
  - `job_dir`
  - `musicxml`（可选，`inline_xml=true`）。

## 配置与功能开关
- `pdf_dpi`：PDF 渲染分辨率。
- `page`：1-based 页码；多页 PDF 当前仅允许 page=1。
- `normalize_photo`：是否对图片做灰度/自动对比增强。
- macOS 侧环境变量：
  - `LONELY_PIANIST_OMR_CONVERTER_BIN`
  - `LONELY_PIANIST_OMR_SERVER_DIR`

## 正常路径与边界情况
- 正常路径：输入校验 -> 预处理 -> 选页 -> oemer 提取 -> 输出 MusicXML -> 返回路径。
- 边界情况：
  - 非支持扩展名：HTTP 400。
  - 文件名非法：HTTP 400（防路径穿越）。
  - `page < 1` 或 `page > pages`：显式错误。
  - 多页且 `page != 1`：MVP 约束错误。
  - oemer 输出文件缺失：显式错误。

## 扩展点与修改热点
- 扩展点：
  - 多页合并（merge-pages）；
  - 更强图像增强策略；
  - 结果质量评估与后处理。
- 修改热点：
  - `convert_to_musicxml`（核心策略）
  - `preprocess_input`（输入标准化）
  - `omr_routes`（安全边界）
  - `OMRConversionService.convert`（客户端集成点）

## 测试与调试
- 最短调试：
  1. CLI 转换单个文件；
  2. 查看 `job_dir` 内 input/debug/output；
  3. 用 AVP 导入结果验证可用性。
- HTTP 调试：`curl -F file=@... -F inline_xml=true http://127.0.0.1:8765/omr/convert`。
- 打包验证：`build_pyinstaller.sh` 后执行 `dist/lp-omr-convert/lp-omr-convert --input ...`。

## 示例片段
```python
if len(rendered_pages) > 1 and page != 1:
    raise OMRConvertError("MVP currently supports only the first page of multi-page PDFs (use --page 1)")
```

```swift
let outputPath = output
    .split(separator: "\n")
    .first(where: { $0.hasPrefix("musicxml_path=") })
```

## Coverage Gaps
- 缺少自动化“识别质量指标”与样本集回归报告。
- checkpoints 管理策略目前偏开发态，产品级缓存与升级策略仍待固化。

## 来源引用（Source References）
- `piano_dialogue_server/omr/cli.py`
- `piano_dialogue_server/omr/convert.py`
- `piano_dialogue_server/omr/preprocess.py`
- `piano_dialogue_server/server/omr_routes.py`
- `piano_dialogue_server/omr/packaging/build_pyinstaller.sh`
- `piano_dialogue_server/README.md`
- `LonelyPianist/Services/OMR/OMRConversionService.swift`
- `LonelyPianist/Views/OMR/OMRPanelView.swift`
