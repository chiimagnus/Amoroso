# OMR 打包 PoC（PyInstaller）

本目录用于验证：把 OMR 转换器打包成一个可分发的命令行工具，让用户不必手动管理 Python 环境。

## 决策

- 打包路线：**PyInstaller one-folder（目录式）CLI**
- checkpoints 策略：**首次运行下载**（在未确认再分发条款前，不把 checkpoint 随包分发）

## 构建步骤

```bash
cd piano_dialogue_server
./.venv/bin/pip install -U pyinstaller
./omr/packaging/build_pyinstaller.sh
```

期望产物：

- `piano_dialogue_server/omr/packaging/dist/lp-omr-convert`

## 冒烟运行（已打包二进制）

```bash
cd piano_dialogue_server/omr/packaging/dist/lp-omr-convert
./lp-omr-convert --help
```

## 备注

- 首次转换可能会因为下载 checkpoint 而更慢。
- 如果网络不可用，会报清晰的运行时错误；可以按 `omr/CHECKPOINTS.md` 预置 checkpoint 实现离线。
- 产品化目标缓存目录：`~/Library/Application Support/LonelyPianistOMR/checkpoints/`（等合规确认后再决定是否接入/是否可随包分发）。
