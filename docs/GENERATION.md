# 文档同步元数据

## 本次运行

| 项目 | 值 |
| --- | --- |
| 仓库来源 | 当前 Git 工作树 |
| 源提交 | `98038bb8cf4472919dea2de6dbe4b8836d4f7259` |
| 本地同步基线 | `98038bb8`（上一份完整文档同步） |
| 生成时间 | 2026-07-24T14:56:31Z |
| 输出语言 | 中文 |
| 同步方式 | 使用 `neat-freak` 对齐当前源码、Xcode 配置、CI 配置与 canonical 文档 |

## 权威文档

- `AGENTS.md`
- `README.md`
- `docs/overview.md`
- `docs/architecture.md`
- `docs/data-flow.md`
- `docs/piano-performance-quality.md`
- `docs/configuration.md`
- `docs/storage.md`
- `docs/testing/core-function-checklist.md`
- `docs/testing/piano-performance-validation.md`

## 同步摘要

- 对齐当前工程 target、Swift 版本、RealityKit 内容包工具版本与手动 CI 的实际配置。
- 以 CodeGraph 作为源码目录、符号与调用关系的结构真源，移除重复的模块目录镜像页。
- 合并重复的 Simulator、assessment 与 coaching 验证入口；保留真机、盲评、能力门和证据索引等外部验收规则。
- 记录根目录 Makefile 作为本地与 CI 的 build/test/run 入口；CI 动态注入 Simulator UDID，Makefile 内部调用原生 `xcodebuild`。
- 保留代码标识、API、命令、协议名、文件名和上游专有名词的原始拼写。
- 保持演奏分析链路、持久化边界和验证结论不变；本次文档变更只收敛重复入口与验证页面。

## 覆盖缺口

- 本次只做文档精简与链接核对，未重新运行完整 `xcodebuild test`、visionOS Simulator 或 Apple Vision Pro 真机验证；已有自动化证据以 `docs/testing/piano-performance-evidence-index.md` 的实际 run record 为准。
- `python_backend/aria/README.md` 属于上游 Aria 项目说明，保留其原始英文，避免维护一份会漂移的本地翻译。
