extends Node2D
class_name BaseTrap

## 所有机关的基类
## 处理：伤害构建、冷却计时、激活延迟、碰撞后伤害传递
##
## 使用方法:
##   1. 子类继承此类
##   2. 场景中添加 DamageZone (Area2D) 子节点
##   3. 子类在 body_entered 回调中调用 _apply_damage_to(body)
##   4. 重写 _on_trap_ready() 进行子类初始化

@export_group("伤害配置")
## 伤害值
@export var damage_amount: float = 10.0
## 命中时附加的 Buff 列表（击退、眩晕等通过 BuffEntity 表达）
@export var effects: Array[BuffEntity] = []

@export_group("时序配置")
## 场景启动后延迟激活（秒）
@export var activation_delay: float = 0.0
## 两次伤害的最小间隔（秒）
@export var damage_cooldown: float = 1.0

## 是否处于激活状态
var is_active: bool = true
## 冷却计时器
var _cooldown_timer: float = 0.0

func _ready() -> void:
	if activation_delay > 0.0:
		is_active = false
		get_tree().create_timer(activation_delay).timeout.connect(
			func(): is_active = true, CONNECT_ONE_SHOT
		)
	_on_trap_ready()

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

## 子类重写此方法做额外初始化
func _on_trap_ready() -> void:
	pass

## 对目标造成伤害（子类在碰撞回调中调用）
## @param body: 碰撞到的 CharacterBody2D（通常是玩家，"player" 组）
func _apply_damage_to(body: Node2D) -> void:
	if not is_active or _cooldown_timer > 0.0:
		return
	if not body.is_in_group(&"player"):
		return
	# v2 伤害路径: 经受击者的 DamagePipeline (旧 HurtBox.take_damage 已废弃)
	var pipe: DamagePipeline = body.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return
	_cooldown_timer = damage_cooldown
	var ctx := DamageContext.new()
	ctx.source = self
	ctx.target = body
	ctx.raw_amount = damage_amount
	ctx.amount = damage_amount
	ctx.tags = DamageTags.PHYSICAL
	ctx.source_pos = global_position
	ctx.attached_buffs = effects
	pipe.process(ctx)
