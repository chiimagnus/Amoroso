# Piano Dialogue — Python Workspace

本目录用于在本机跑通 **MIDI → AI → MIDI** 的离线验证（P1）与本地 WebSocket 服务（P2）。

## 目录结构（会逐步长出来）

- `requirements.txt`：Python 依赖
- `scripts/`：离线验证脚本（P1）
- `server/`：FastAPI WebSocket 服务（P2）
- `out/`：生成的 `.mid`（不会提交）

## 环境要求

- Python：建议 `3.10+`
- macOS（推荐 Apple Silicon）：可走 PyTorch `mps`；若不可用则退回 CPU

## 安装依赖

在仓库根目录：

```bash
cd piano_dialogue_server
python3.12 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

提示：

- 模型权重体积很大（GB 级），不要提交到仓库。
- 若你希望把权重缓存放在本目录内，可用 `piano_dialogue_server/models/`（已在 `.gitignore` 忽略）。
- Apple Silicon 上如遇到算子不支持，可尝试：
  - `export PYTORCH_ENABLE_MPS_FALLBACK=1`

## P1：离线验证（生成 MIDI）

### 1) 准备模型权重（不提交仓库）

默认脚本会优先读取本地目录：

- `piano_dialogue_server/models/music-small-800k/`

你可以二选一：

**A. 手动下载（浏览器/下载器）**

- 下载权重文件（通常为 `model.safetensors`；有些仓库为 `pytorch_model.bin`）放到：
  - `piano_dialogue_server/models/music-small-800k/model.safetensors`
  - 或 `piano_dialogue_server/models/music-small-800k/pytorch_model.bin`

**B. 用脚本下载（可断点续传，走 HF 镜像）**

```bash
source .venv/bin/activate
bash scripts/download_model.sh
```

```bash
source .venv/bin/activate
python scripts/test_generate.py
python scripts/test_infilling.py
```

输出：

- `out/output.mid`
- `out/output_infilling.mid`

## 变量/默认值

脚本会读取以下环境变量（可选）：

- `AMT_MODEL_ID`：HuggingFace 模型 ID（默认值以脚本里为准）
- `AMT_DEVICE`：`mps` / `cuda` / `cpu`（默认自动选择）
- `AMT_MODEL_DIR`：如果你把模型放在其他目录，用它指向本地目录（优先级最高）
