# HappyPianist

HappyPianist 是一个面向 Apple Vision Pro 的钢琴练习应用。它把 MusicXML 转成空间练习引导，并支持音频、蓝牙 MIDI 与虚拟钢琴三种输入方式。

![scene](docs/assets/scene1.jpg)

## 资源状态

仓库已包含 `HappyPianistAVP/Resources/Fonts/Bravura.otf`。以下私有或体积较大的资源不随源码分发：

| 资源 | 影响 |
| --- | --- |
| `HappyPianistAVP/Resources/SeedScores/` | 没有内置生产曲目；依赖私有曲谱的资源集成测试会跳过。 |
| `SalC5Light2.sf2` | 本地 sampler 无法加载钢琴音色。 |
| `AIDuetPerformanceRNN.mlpackage` / `.mlmodelc` | 本地 CoreML 对弹不可用；仍可使用本地规则或网络后端。 |

将所需资源加入 `HappyPianistAVP` target 后再进行对应验收。测试跳过不等于资源集成通过。

## 致谢

- [Anticipation](https://github.com/jthickstun/anticipation) 与 [Anticipatory Music Transformer](https://arxiv.org/abs/2306.08620)
- [stanford-crfm/music-large-800k](https://huggingface.co/stanford-crfm/music-large-800k)
- Apple CoreMIDI、RealityKit、ARKit 与 Salamander Grand Piano 音色采样
- 感谢南客松 S2、`njuer勇闯互联网`、`罗恩`、`大宝哥` 对项目的支持

## 许可证

本项目基于 [AGPL-3.0](LICENSE.APGLv3) 开源。
