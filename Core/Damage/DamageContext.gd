# Core/Damage/DamageContext.gd
class_name DamageContext extends RefCounted

## Mutable damage envelope passed through DamagePipeline.
## Pipeline stages may adjust amount, set blocked, fill dealt, attach buffs.

var source: Node = null                          # 攻击者
var target: Node = null                          # 受害者
var raw_amount: float = 0.0                      # 原始伤害（不可变参考）
var amount: float = 0.0                          # pipeline 中可变
var source_pos: Vector2 = Vector2.ZERO
var attached_buffs: Array[BuffEntity] = []       # buffs to apply on post_apply (target's BuffController consumes)
var tags: int = 0                                # DamageTags bitmask
var blocked: bool = false                        # 任一阶段可设
var dealt: float = 0.0                           # apply 后回填实际扣血量
var is_heal: bool = false                        # 治疗复用同管线
