# visionOS App：LonelyPianistAVP（AR Guide）

这里是 **Apple Vision Pro（visionOS）端**的原型工程目录，核心目标是：

**导入 MusicXML → 校准钢琴空间位置 → 手部追踪判定按键 → 用 AR 高亮提示下一步。**

## 功能范围（MVP）

- MusicXML 导入（来自 OMR 或人工准备）
- AR Guide：HUD + reticle + 指尖点位
- A0 / C8 两点校准（决定键位对齐）
- `Skip` / `Mark Correct` 推进（便于功能验收）

## 验收流程（最短闭环）

以根目录说明为准（避免重复与漂移）：

- `README.md` →「🕶️ Apple Vision Pro（AR Guide）」→「验收流程（最短闭环）」

## 依赖与输入

- 推荐输入：`MusicXML`
- 如果你只有 PDF/图片谱：先走 OMR 转换（见根目录）
  - `README.md` →「🧾 OMR：PDF/图片 → MusicXML」

