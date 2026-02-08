extends BaseStateMachine
class_name EnemyStateMachine

## 敌人状态机模板
## 预配置的敌人状态机，包含常用状态组合
##
## 使用方法:
## 1. 在敌人场景中添加 EnemyStateMachine 节点
## 2. 选择预设类型（BASIC, RANGED, BOSS）
## 3. 根据需要调整参数
## 4. 状态机会自动创建所需的状态节点

# ============ 预设类型 ============
enum Preset {
	CUSTOM,   # 自定义（不自动创建状态）
	BASIC,    # 基础敌人（idle, wander, chase, attack, hit, knockback, stun）
	RANGED,   # 远程敌人（增加 retreat 状态）
	BOSS      # Boss（增加更多状态）
}

# ============ 导出参数 ============
@export_group("预设配置")
## 敌人预设类型
@export var preset: Preset = Preset.BASIC
## 是否在 ready 时自动创建状态
@export var auto_create_states := true

@export_group("状态参数")
## Idle 状态的待机时间范围
@export var idle_time_range := Vector2(1.0, 3.0)
## Wander 状态的巡游时间范围
@export var wander_time_range := Vector2(2.0, 5.0)
## Stun 状态的眩晕时间
@export var stun_duration := 1.0
## Hit 状态的硬直时间
@export var hit_duration := 0.2


func _ready() -> void:
	# 如果启用自动创建且没有子状态，则根据预设创建
	if auto_create_states and get_child_count() == 0:
		_create_preset_states()

	# 调用父类的 _ready
	super._ready()


## 根据预设创建状态节点
func _create_preset_states() -> void:
	match preset:
		Preset.BASIC:
			_create_basic_states()
		Preset.RANGED:
			_create_ranged_states()
		Preset.BOSS:
			_create_boss_states()
		Preset.CUSTOM:
			pass  # 不自动创建


## 创建基础敌人状态
func _create_basic_states() -> void:
	# Idle
	var idle = _create_state("res://Core/StateMachine/CommonStates/IdleState.gd", "Idle")
	idle.min_idle_time = idle_time_range.x
	idle.max_idle_time = idle_time_range.y

	# Wander
	var wander = _create_state("res://Core/StateMachine/CommonStates/WanderState.gd", "Wander")
	wander.min_wander_time = wander_time_range.x
	wander.max_wander_time = wander_time_range.y

	# Chase
	_create_state("res://Core/StateMachine/CommonStates/ChaseState.gd", "Chase")

	# Attack
	_create_state("res://Core/StateMachine/CommonStates/AttackState.gd", "Attack")

	# Hit (反应层)
	var hit = _create_state("res://Core/StateMachine/CommonStates/HitState.gd", "Hit")
	hit.hit_duration = hit_duration

	# Knockback (反应层)
	_create_state("res://Core/StateMachine/CommonStates/KnockbackState.gd", "Knockback")

	# Stun (控制层)
	var stun = _create_state("res://Core/StateMachine/CommonStates/StunState.gd", "Stun")
	stun.stun_duration = stun_duration

	# 设置初始状态
	init_state = idle


## 创建远程敌人状态
func _create_ranged_states() -> void:
	_create_basic_states()

	# 可以在这里添加远程敌人特有的状态
	# 例如: Retreat, RangedAttack 等


## 创建 Boss 状态
func _create_boss_states() -> void:
	_create_basic_states()

	# 可以在这里添加 Boss 特有的状态
	# 例如: SpecialAttack, Enrage, PhaseTransition 等


## 创建状态节点的辅助方法
func _create_state(script_path: String, state_name: String) -> BaseState:
	var script = load(script_path)
	if not script:
		push_error("[EnemyStateMachine] 无法加载脚本: %s" % script_path)
		return null

	var state = script.new() as BaseState
	state.name = state_name
	add_child(state)
	return state


# ============ 便捷方法 ============
## 强制进入眩晕状态
func force_stun(duration: float = -1.0) -> void:
	if duration > 0 and states.has("stun"):
		var stun_state = states["stun"] as StunState
		stun_state.stun_duration = duration
	force_transition("stun")


## 强制进入受击状态
func force_hit() -> void:
	force_transition("hit")


## 强制进入击退状态
func force_knockback() -> void:
	force_transition("knockback")


## 检查是否处于控制状态（眩晕/冰冻）
func is_controlled() -> bool:
	return current_state and current_state.priority == BaseState.StatePriority.CONTROL


## 检查是否处于反应状态（受击/击退）
func is_reacting() -> bool:
	return current_state and current_state.priority == BaseState.StatePriority.REACTION


## 检查是否可以行动（不在控制或反应状态）
func can_act() -> bool:
	return current_state and current_state.priority == BaseState.StatePriority.BEHAVIOR
