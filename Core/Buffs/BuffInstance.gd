# Core/Buffs/BuffInstance.gd
class_name BuffInstance extends RefCounted

## Per-application runtime state. Multiple instances may share one BuffEntity.

var entity: BuffEntity = null
var remaining: float = 0.0           # 剩余时长（duration > 0 时）
var tick_accums: Dictionary = {}     # effect index → accumulator (float)
var stacks: int = 1
var source_actor: Node = null
var source_pos: Vector2 = Vector2.ZERO
var gen_id: int = 0                  # 同 id 多实例时唯一 ID（STACK 模式用）
