# ForestBoar 接触玩家后自毁修复

**日期**: 2026-03-13
**类型**: Bug修复
**文件**: `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn`

## 问题

ForestBoar 碰到 Hahashin 后立即死亡（自毁），而非对玩家造成接触伤害。

## 根因

ForestBoar 的 HitBoxComponent 错误配置了 `destroy_owner_on_hit = true`。该属性是为子弹等投射物设计的（命中后销毁自身），用在近战敌人上会导致敌人碰到玩家就自毁。

**碰撞链条**：Boar HitBoxComponent(`mask=2`) 检测到 Player HurtBoxComponent(`layer=2`) → 造成伤害 → `destroy_owner_on_hit` 触发 `queue_free()` → Boar 自毁

## 修复

移除 `destroy_owner_on_hit = true`，恢复基类默认值 `false`。

## 教训

`destroy_owner_on_hit` 仅适用于投射物（FireBullet、BubbleBullet），不应用于近战/接触伤害型敌人。
