# Boss Sprite 统一 AnimatedSprite2D 设计

> **Date:** 2026-03-29
> **Goal:** 统一所有 Boss 使用 AnimatedSprite2D + SpriteFrames，替换 Sprite2D，减少维护成本。

## 方案

所有 Boss（Cyclops / BladeKeeper / DemonSlime）及 BossBase 模板统一使用 AnimatedSprite2D。
对齐项目中已有的 ForestSnail/ForestBee/ForestBoar 模式：AnimatedSprite2D + SpriteFrames + AnimationPlayer + AnimationTree。

## 代码改动

### 1. BossBase.tscn
- `Sprite2D` 节点 → `AnimatedSprite2D` 类型

### 2. BaseState.gd — update_sprite_facing()
- `is Sprite2D` 检查改为兼容 AnimatedSprite2D（检查 `flip_h` 属性存在性）

### 3. Cyclops.gd
- `@onready var sprite: Sprite2D = $Sprite2D` → `@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D`
- 移除 `@export var textures: Array[Texture2D]` 及 `sprite.texture = textures.pick_random()` 逻辑

### 4. Cyclops.tscn
- Sprite2D → AnimatedSprite2D，关联 SpriteFrames .tres

### 5. BladeKeeper.tscn / DemonSlime.tscn
- Sprite2D → AnimatedSprite2D，关联 SpriteFrames .tres

## AnimationPlayer Track 模式

每个 AnimationPlayer 动画包含 2 条 track（ForestSnail 模式）：
- Track 1: `AnimatedSprite2D:animation` — 帧 0 设动画名
- Track 2: `AnimatedSprite2D:frame` — 逐帧递增

## 动画映射

| Boss | SpriteFrames 动画 | control_sm 状态 |
|------|------------------|----------------|
| BladeKeeper | idle(8f), run(8f), atk_1(6f), atk_2(8f), atk_3(18f), sp_atk(11f), defend(12f), roll(7f), projectile_cast(7f), trap_cast(10f), hit(6f), death(12f) | idle, walk, atk_1, atk_2, atk_3, sp_atk, defend, roll, projectile, trap, hit, death |
| DemonSlime | idle(6f), walk(12f), cleave(15f), hit(5f), death(22f) | idle, walk, cleave, hit, death |
| Cyclops | idle(4f), walk(4f), hit(3f) | idle, walk, hit |

## AnimationTree BlendTree

结构不变：`locomotion → loco_timescale → control_blend ← ctrl_timescale ← control_sm → output`

## 编辑器手动操作

- 创建 3 个 SpriteFrames .tres 资源
- 每个 SpriteFrames 按动画组导入 PNG 帧
- AnimationPlayer 创建对应动画条目
