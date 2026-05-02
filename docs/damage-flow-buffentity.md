# Damage Flow — BuffEntity (Pointer)

> **正文已迁移至 Obsidian wiki**, 本文件仅作指针。

## 当前权威来源 (wiki)

- 项目侧叙述 → `[[damage-flow]]`
  - 路径: `E:\workspace\knowledge-wiki\wiki\projects\combo-demon\damage-flow.md`
- 源记录 → `wiki/sources/combo-demon-damage-flow-buffentity.md`
- 通用 signal-pipeline 模式 → `[[signal-pipeline-pattern]]`

## 涵盖内容 (摘要)

- 顶层数据流 (attacker → DamagePipeline → 5 阶段 → 双桥接路径)
- HitBoxComponent 构造 DamageContext
- pre_calc / pre_apply / apply / post_apply / react 各阶段订阅者
- Player 路径: `BaseStateMachine._on_pipeline_react`
- AI 路径:    `AgentAIBase._on_pipeline_react`
- ctx.blocked 短路语义 + 信号连接全表

## 约定 (2026-05-02 起)

新数据流程图等**直接写到 wiki**, 本地 `docs/` 仅保留指针 stub。
