# oemer checkpoints 策略

## 来源与下载链接

运行时使用 `oemer` 上游仓库 Release 里发布的 checkpoint 文件：

- `1st_model.onnx` — <https://github.com/BreezeWhite/oemer/releases/download/checkpoints/1st_model.onnx>
- `1st_weights.h5` — <https://github.com/BreezeWhite/oemer/releases/download/checkpoints/1st_weights.h5>
- `2nd_model.onnx` — <https://github.com/BreezeWhite/oemer/releases/download/checkpoints/2nd_model.onnx>
- `2nd_weights.h5` — <https://github.com/BreezeWhite/oemer/releases/download/checkpoints/2nd_weights.h5>

## 缓存与安装路径

当前 MVP 使用 Python 虚拟环境内的默认目录（`oemer` 包内的 checkpoints 目录）：

- `<venv>/lib/python3.12/site-packages/oemer/checkpoints/unet_big/`
- `<venv>/lib/python3.12/site-packages/oemer/checkpoints/seg_net/`

`oemer` 首次运行如果缺文件会自动下载；要完全离线，请手动预置这些文件。

## 离线预置清单

1. 如果目录不存在，先创建上述两个子目录
2. 从上面的链接下载 4 个文件
3. 把文件放到 `oemer` 期望的准确目录中
4. 运行 `python -m omr.cli --input <path-to-score>` 验证

## 许可证与再分发说明

- `oemer` 代码许可证：MIT（来自 `pip show oemer` 元数据，版本 0.1.5）。
- checkpoint 文件由 `oemer` 上游仓库的 Release assets 提供。
- 本仓库未声明 checkpoint 的再分发条款；如果要把 checkpoint 打进产品安装包，请先做合规确认（默认视为“未知/需确认”）。
- 产品化默认策略：checkpoint 采用首次运行下载（除非法律/合规确认允许随包再分发）。
