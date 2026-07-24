# 文档同步元数据

## 本次运行

| 项目 | 值 |
| --- | --- |
| 仓库来源 | 当前 Git 工作树 |
| 源提交 | `b9db3d8ecc56e79ff2f3aebb20f777b26b836ee6` |
| 本地同步基线 | `b9db3d8e`（上一份完整文档同步） |
| 生成时间 | 2026-07-24T15:10:14Z |
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
- `docs/testing.md`

## 同步摘要

- 对齐当前工程 target、Swift 版本、RealityKit 内容包工具版本与手动 CI 的实际配置。
- 以 CodeGraph 作为源码目录、符号与调用关系的结构真源，不在文档重复维护源码清单和调用图。
- 重写架构、数据流、配置、存储、质量边界与核心 checklist，统一每页的唯一职责。
- 将能力声明门合并进质量边界，把 smoke、Simulator、真机、盲评、assessment、coaching 和 evidence 收拢到单一 `docs/testing.md`。
- 记录根目录 Makefile 作为本地与 CI 的 build/test/run 入口；CI 动态注入 Simulator UDID，Makefile 内部调用原生 `xcodebuild`。
- 保留代码标识、API、命令、协议名、文件名和上游专有名词的原始拼写。
- 保持演奏分析链路、持久化边界和验证结论不变；本次只收敛文档职责，不改变产品能力结论。

## 覆盖缺口

- 本次只做文档重构与链接/路径核对，未重新运行完整 `xcodebuild test`、visionOS Simulator 或 Apple Vision Pro 真机验证；已有自动化证据以 `docs/testing.md` 的 evidence section 为准。
- `python_backend/aria/README.md` 属于上游 Aria 项目说明，保留其原始英文，避免维护一份会漂移的本地翻译。
