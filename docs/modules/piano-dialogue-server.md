# 模块：piano_dialogue_server

## 边界
- 负责：`GET /health`、`POST /generate`、`WS /ws`、`POST /upload-expand`、协议校验、推理和调试包、Bonjour 广播与最小静态前端。
- 不负责：macOS / AVP UI。

## 目录地图
| 路径 | 角色 |
| --- | --- |
| `server/api/main.py` | FastAPI / WS 入口（挂载 static、协议校验、策略分流） |
| `server/api/protocol.py` | Pydantic 契约（`strategy=model/deterministic/rule`） |
| `server/api/test_client.py` | WS 回环测试（`python -m server.api.test_client`） |
| `server/engines/model_inference.py` | 模型策略（`model`）+ deterministic 策略（`deterministic`） |
| `server/engines/rule_inference.py` | 规则策略（`rule`）的 API 适配层 |
| `server/engines/rule_backend.py` | 规则即兴器核心（harmonic/rhythm/motif rules） |
| `server/media/bonjour.py` | Bonjour（mDNS/DNS-SD）广播 |
| `server/media/debug_artifacts.py` | 调试落盘（request/response/midi/summary） |
| `server/media/midi_generation.py` | MIDI 解析、分析与扩展生成（含 deterministic 的素材生成） |
| `server/media/midi_utils.py` | MIDI 读写/切窗/合并/（可选）WAV 合成工具 |
| `server/media/musicxml_generation.py` | 从 MIDI/分析生成最小 MusicXML（用于上传扩展工具链） |
| `scripts/run_server.sh` | 一键启动（venv + install + uvicorn） |
| `scripts/expand_midi.py` | 离线扩展 MIDI 脚本入口 |
| `static/index.html` | `GET /` 对应的最小前端页面（Playground） |
| `static/app.js` | `/generate` + `/upload-expand` 的浏览器侧测试逻辑 |
| `static/styles.css` | Playground 样式 |

## 入口与生命周期
| 入口 | 行为 |
| --- | --- |
| `/health` | 返回 `{"status":"ok"}` |
| `/` | 若存在 `static/index.html` 则返回页面，否则返回 fallback HTML |
| `/generate` | 接收 `GenerateRequest`（HTTP JSON），返回 `ResultResponse` |
| `/ws` | 收到 `generate` 请求后返回 `result` / `error` |
| `/upload-expand` | 上传 MIDI（multipart），返回 base64 MIDI 与 analysis（用于前端下载） |
| `BonjourServiceBroadcaster` | 服务启动时 best-effort 广播 `_lonelypianist._tcp.local.`（TXT: `path=/generate` 等） |
| `get_inference_engine()` | 懒加载并缓存模型 |
| `write_debug_bundle()` | 在 debug 开启时落盘工件 |

## Protocol

### 数据模型
| 模型 | 字段 |
| --- | --- |
| `DialogueNote` | `note`, `velocity`, `time`, `duration` |
| `GenerateParams` | `top_p`, `max_tokens`, `strategy` |
| `GenerateRequest` | `type`, `protocol_version`, `notes`, `params`, `session_id` |
| `ResultResponse` | `type`, `protocol_version`, `notes`, `latency_ms` |
| `ErrorResponse` | `type`, `protocol_version`, `message` |

### 协议约束
- `type` 固定为 `generate` / `result` / `error`。
- `protocol_version` 固定为 `1`。
- `extra="ignore"` 允许兼容扩展字段。

### 序列化边界
| 方向 | 说明 |
| --- | --- |
| macOS -> Python | JSON 编码后经 WS 发送 |
| AVP -> Python | JSON 编码后经 HTTP `POST /generate` 发送（host/port 通过 Bonjour 解析得到） |
| Python -> macOS | JSON 文本或 binary 都可解析 |

### 生成策略（`GenerateParams.strategy`）
| 值 | 行为 | 成本 |
| --- | --- | --- |
| `deterministic` | 走本地规则/分析生成（不初始化大模型） | 更轻、更稳定 |
| `rule` | 走规则即兴器生成（不初始化大模型） | 更轻，更可控 |
| `model` | 初始化并使用模型生成 | 更重，受权重/设备影响 |

## Inference

### 范围
三种生成策略的实现位置与关键逻辑：`model`（神经网络）、`deterministic`（现有算法/分析）、`rule`（规则即兴器）。

### 关键逻辑
| 逻辑 | 行为 |
| --- | --- |
| `_resolve_model_ref()` | `AMT_MODEL_DIR` 优先，其次仓库内 `models/music-large-800k`，最后 `AMT_MODEL_ID`（`server/engines/model_inference.py`） |
| `_resolve_device()` | `AMT_DEVICE` > mps > cuda > cpu（`server/engines/model_inference.py`） |
| `_patch_safe_logits()` | 屏蔽非法 REST token 组合（`server/engines/model_inference.py`） |
| `InferenceEngine.generate_response()` | `strategy=model`：模型生成 reply notes（`server/engines/model_inference.py`） |
| `InferenceEngine.generate_response_with_debug()` | `strategy=model`：模型生成 + debug 统计（`server/engines/model_inference.py`） |
| `generate_deterministic_response()` | `strategy=deterministic`：基于 `media/midi_generation.generate_expanded_midi` 做轻量续写，并把返回时间轴平移到从 0 开始（`server/engines/model_inference.py`） |
| `generate_rule_response()` | `strategy=rule`：把协议 `DialogueNote` 转成 `media/midi_utils.NoteEvent`，调用 `run_rule_improviser`，再转回协议 notes（`server/engines/rule_inference.py`） |
| `run_rule_improviser(...)` | 规则即兴器核心（和声/节奏/动机规则 + 风格 preset），产出 `RuleResult`（`server/engines/rule_backend.py`） |
| `_derive_response_length_sec()` | 将协议 `max_tokens` 映射为 “续写时长（秒）” 的启发式窗口 |

### 输出约束
- 只接受 piano instrument。
- 只允许 MIDI 21..108。
- 负时间和短事件会被丢弃。
- 默认 velocity 从 prompt 均值推导。

### 调试统计
| 字段 | 含义 |
| --- | --- |
| `prompt_end_sec` | 输入结束时间 |
| `effective_start_sec` | 生成起点 |
| `generated_events_len` | 输出 token 数 |
| `dropped_notes` | 丢弃原因统计 |
| `generate_ms` | 推理耗时 |

### 与 API 的连接点
- `POST /generate` 与 `WS /ws` 的策略分流在 `server/api/main.py`（`params.strategy`）。
- 仅当 `strategy=model` 时会初始化模型引擎；`deterministic` 与 `rule` 都不会加载权重。

## Debug artifacts

### 产物
| 产物 | 说明 |
| --- | --- |
| `requests/<req_id>/request.json` | 原始请求 |
| `requests/<req_id>/response.json` | 原始响应 |
| `requests/<req_id>/summary.json` | 延迟和统计摘要 |
| `requests/<req_id>/prompt.mid` | prompt MIDI |
| `requests/<req_id>/reply.mid` | reply MIDI |
| `index.jsonl` | 请求索引 |

### 触发条件
- `DIALOGUE_DEBUG=1` 时写盘。
- 写盘失败不会中断主请求。

### 参考脚本
- `python -m server.api.test_client` 会把结果写成 `out/server_reply.mid`。
- `scripts/test_generate.py` / `scripts/test_infilling.py` 可离线生成验证。

### 代码位置
- 调试写盘逻辑在 `server/media/debug_artifacts.py`（best-effort：失败不影响主路径）。

## 风险点
- 模型目录存在但缺权重
- 安全 logits patch
- debug 写盘失败
- Bonjour 广播失败（应不影响主路径；仅影响自动发现）


## Coverage Gaps
- 没有并发压测和高负载稳定性数据。
- `/upload-expand` 的行为（生成质量/参数）主要面向手工使用与前端自测，缺少系统性回归基线。
