# Piano Dialogue Server（本机 Python 服务）

## 安装与初始化

```bash
cd piano_dialogue_server
python3.12 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

## 启动服务

在 `piano_dialogue_server/` 下启动：

```bash
source .venv/bin/activate
python -m uvicorn server.main:app --host 127.0.0.1 --port 8000 --reload
```

健康检查：

```bash
curl -s http://127.0.0.1:8000/health
```

## OMR（PDF/图片 → MusicXML）

- OMR 输出根目录：`out/omr/`
- 每次转换都会生成一个 job：`out/omr/<basename>-<timestamp>/`
- job 目录结构：
  - `input/`：PDF 渲染页或输入图片副本
  - `debug/`：oemer 与管线的调试产物
  - `output/score.musicxml`：最终输出（给 AVP 导入）

OMR 模块在 `omr/` 目录下。

### 通过 HTTP 转换

```bash
curl -s \
  -F "file=@/absolute/path/to/score.pdf" \
  -F "inline_xml=true" \
  http://127.0.0.1:8000/omr/convert
```

返回值里包含 `musicxml_path`（磁盘路径）；你可以在 AVP App 的 2D 窗口里通过 `Import MusicXML…` 导入这个文件。

## oemer checkpoints（离线/首次运行）

如果本机缺少 `oemer` 的 checkpoint 文件，首次转换时会自动下载（会多等一会儿）。

- 预期文件：`1st_model.onnx`、`1st_weights.h5`、`2nd_model.onnx`、`2nd_weights.h5`
- 默认缓存位置：`<venv>/lib/python3.12/site-packages/oemer/checkpoints/`
  - `unet_big/1st_model.onnx`
  - `unet_big/1st_weights.h5`
  - `seg_net/2nd_model.onnx`
  - `seg_net/2nd_weights.h5`

完全离线（手动预置）：

1. 按 `omr/CHECKPOINTS.md` 的清单下载 4 个文件
2. 复制到上面对应的目录里
3. 运行 `python -m omr.cli --input <score.pdf>` 验证

如果运行时下载失败，会以 OMR 错误退出；请保留 `out/omr/` 下对应的 job 目录用于排查。
