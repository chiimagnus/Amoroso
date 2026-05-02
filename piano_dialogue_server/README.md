# 本机 Python：piano_dialogue_server

这里是 LonelyPianist 的本地推理工作区，提供 Piano Dialogue 所需的 HTTP 健康检查和 WebSocket 生成接口。

## 它做什么

- `GET /health`：健康检查
- `POST /generate`：标准 HTTP 生成接口，接收 `generate` 请求并返回结果
- `WS /ws`：接收 `generate` 请求并返回回复音符
- `server/debug_artifacts.py`：在调试模式下写出 request / response / MIDI / summary bundle

## 准备环境

```bash
cd piano_dialogue_server
python3.12 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

## 模型加载顺序

1. `AMT_MODEL_DIR`
2. 仓库内 `models/music-large-800k`
3. `AMT_MODEL_ID`，默认 `stanford-crfm/music-large-800k`

可选环境变量：

| 变量 | 作用 |
| --- | --- |
| `AMT_MODEL_DIR` | 本地模型目录 |
| `AMT_MODEL_ID` | Hugging Face 模型 ID |
| `AMT_DEVICE` | `mps` / `cuda` / `cpu` |
| `DIALOGUE_DEBUG` | 是否写出调试包 |
| `HF_ENDPOINT` | 镜像地址 |

## 启动服务

```bash
cd piano_dialogue_server
source .venv/bin/activate
python -m uvicorn server.main:app --host 0.0.0.0 --port 8765
```

健康检查：

```bash
curl -s http://127.0.0.1:8765/health
```

HTTP 生成接口示例：

```bash
curl -X POST http://127.0.0.1:8765/generate \
  -H "Content-Type: application/json" \
  -d '{
    "type": "generate",
    "protocol_version": 1,
    "notes": [
      {"note": 60, "velocity": 90, "time": 0.0, "duration": 0.5}
    ],
    "params": {
      "top_p": 0.95,
      "max_tokens": 256,
      "strategy": "deterministic"
    }
  }'
```

其中 `strategy` 可选值：
- `model`：使用原始模型生成
- `deterministic`：使用本地规则/分析生成，更稳定、保留原片段风格

## 离线验证

```bash
cd piano_dialogue_server
source .venv/bin/activate
python scripts/test_generate.py
python scripts/test_infilling.py
```

## MIDI 解析与扩展

```bash
cd piano_dialogue_server
source .venv/bin/activate
python scripts/expand_midi.py path/to/input.mid path/to/output.mid --mode variation
```

可选参数：
- `--mode`: `continue`, `accompaniment`, `variation`, `emotion`
- `--analysis-json`: 写出 MIDI 特征分析结果
- `--extra-duration`: 生成的扩展时长（秒）

## 端到端回环

```bash
cd piano_dialogue_server/server
../.venv/bin/python test_client.py
```

## 备注

- 协议版本当前为 `1`
- 这个工作区只负责生成和调试，不负责 macOS / visionOS UI
- AVP 侧不再内置 PDF / 图片转 MusicXML 流程
