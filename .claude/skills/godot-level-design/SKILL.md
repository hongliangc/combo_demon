---
name: godot-level-design
description: "Production-grade Godot 4 level design skill for 2D Platformer games. Use when designing, generating, documenting, or reviewing game levels — including tilemap layout, enemy placement, encounter design, screenshot-to-level reconstruction. Triggers on: level, tilemap, encounter, checkpoint, screenshot to level."
---

# Godot 4 — 2D Platformer Level Design

## 两种模式

- **Mode A (从零设计)**: 明确上下文 → 空间布局 → 遭遇设计 → 技术规格 → 产出
- **Mode B (截图转关卡)**: 视觉分析 → 资产清单 → 坐标映射 → 代码生成 → 验证

## 按需加载

根据任务阶段 Read 对应 reference：

| 场景 | 读取文件 |
|------|---------|
| 截图/参考图提供时（**必读**） | `references/screenshot-to-level.md` |
| 空间布局、宏观结构、高低差 | `references/spatial-design.md` |
| 敌人配置、节奏、战斗房间 | `references/encounter-design.md` |
| TileMapLayer API、地形、自动贴图 | `references/tilemap-implementation.md` |
| 场景树、节点命名、export 变量 | `references/scene-architecture.md` |
| 魂系/银河城垂直设计、快捷路线 | `references/souls-platformer-patterns.md` |

## 核心原则速查

- 先输出 level skeleton（YAML），确认后再转 tile
- 节奏组: REST → CHALLENGE → REWARD → REST（3+ CHALLENGE 后必须 REST ≥ 4 tiles）
- 场景树: Level.tscn → World → TileMapLayer_Background/Terrain/Foreground + Encounters + Hazards
- 每个 TileMapLayer 单一用途（bg/terrain/fg），物理碰撞只在 terrain 层
- 验证报告必须含实际数值，不只 pass/fail
