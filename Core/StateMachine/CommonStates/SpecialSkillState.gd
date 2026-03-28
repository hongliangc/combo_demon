extends BaseState
class_name SpecialSkillState

## 特殊技能状态基类
## 提供冷却时间 + 概率触发机制
## 子类重写 _check_condition() 和 execute_skill()

@export_group("触发配置")
@export var skill_cooldown := 8.0
@export var skill_probability := 0.2
## 概率检查失败后的短暂等待（避免每帧 roll）
@export var recheck_delay := 1.0

var _cooldown_remaining := 0.0
var _recheck_remaining := 0.0
var _executing := false


func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true


func enter() -> void:
	_executing = true
	execute_skill()


func process_state(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
	if _recheck_remaining > 0.0:
		_recheck_remaining -= delta


func physics_process_state(_delta: float) -> void:
	pass  # 技能执行由 execute_skill 异步控制


func exit() -> void:
	_executing = false


## 从 Chase/Attack 状态调用，检查是否可以触发技能
func can_trigger(distance: float) -> bool:
	if _cooldown_remaining > 0.0:
		return false
	if _recheck_remaining > 0.0:
		return false
	if not _check_condition(distance):
		return false
	if randf() >= skill_probability:
		_recheck_remaining = recheck_delay
		return false
	return true


## 子类重写：自定义触发条件
func _check_condition(_distance: float) -> bool:
	return true


## 子类重写：技能执行逻辑（可使用 await）
## 执行完毕后必须调用 finish_skill()
func execute_skill() -> void:
	finish_skill()


## 技能完成：重置冷却，转回 chase
func finish_skill() -> void:
	_cooldown_remaining = skill_cooldown
	_executing = false
	transition_to("chase")


## 对玩家施加伤害的工具方法
func _apply_damage_to_player(damage: Damage) -> void:
	if not is_instance_valid(target_node):
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		hurtbox.take_damage(damage, owner_node.global_position)


## 创建带击退效果的伤害对象
func _make_damage(amount: float, knockback: float = 0.0) -> Damage:
	var dmg := Damage.new()
	dmg.amount = amount
	dmg.min_amount = amount
	dmg.max_amount = amount
	if knockback > 0.0:
		var kb := KnockBackEffect.new()
		kb.knockback_force = knockback
		dmg.effects.append(kb)
	return dmg
