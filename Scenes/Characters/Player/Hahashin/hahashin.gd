class_name Hahashin extends AgentBase

## Player character — input-driven state machine on top of AgentBase architecture.
## 架构: AgentBase → Hahashin
## 状态机由 StateController 节点管理（AIState 子节点）

## 待执行技能 id（Ground/Air 写入，Combat 消费）。D-1: 字段在角色类上，不用黑板。
var pending_skill_id: StringName = &""

## MovementComponent 引用（D-4）
@onready var movement_component: MovementComponent = $MovementComponent

func _ready() -> void:
	super._ready()
	# InputController does not call enter_initial (AIController does); do it here.
	if state_controller:
		state_controller.enter_initial()

func _setup_transitions() -> void:
	_register_rules([
		# Ground 退出
		[&"ground", &"air",          AIEvents.EV_LEFT_GROUND,     &"",               0],
		[&"ground", &"combat",       AIEvents.EV_INPUT_ATTACK,    &"",               0],
		[&"ground", &"roll",         AIEvents.EV_INPUT_DASH,      &"",               0],
		[&"ground", &"specialattack",AIEvents.EV_INPUT_SPECIAL,   &"",               0],
		# Air 退出
		[&"air",    &"ground",       AIEvents.EV_LANDED,          &"_guard_on_floor", 0],
		[&"air",    &"combat",       AIEvents.EV_INPUT_ATTACK,    &"",               0],
		[&"air",    &"specialattack",AIEvents.EV_INPUT_SPECIAL,   &"",               0],
		# Combat 退出
		[&"combat", &"ground",       AIEvents.EV_ATTACK_FINISHED, &"_guard_on_floor", 0],
		[&"combat", &"air",          AIEvents.EV_ATTACK_FINISHED, &"_guard_in_air",   0],
		# Roll 退出 (D-5: reuse EV_ATTACK_FINISHED)
		[&"roll",   &"ground",       AIEvents.EV_ATTACK_FINISHED, &"_guard_on_floor", 0],
		[&"roll",   &"air",          AIEvents.EV_ATTACK_FINISHED, &"_guard_in_air",   0],
		# Hit 退出
		[&"hit",    &"ground",       AIEvents.EV_HIT_RECOVERED,   &"_guard_on_floor", 0],
		[&"hit",    &"air",          AIEvents.EV_HIT_RECOVERED,   &"_guard_in_air",   0],
		# SpecialAttack 退出
		[&"specialattack", &"ground", AIEvents.EV_ATTACK_FINISHED, &"_guard_on_floor", 0],
		[&"specialattack", &"air",    AIEvents.EV_ATTACK_FINISHED, &"_guard_in_air",   0],
		# 全局: 受击 → hit (优先级 10, 覆盖 Combat/Roll)
		[&"*",      &"hit",          AIEvents.EV_DAMAGED,         &"",               10],
		# 全局: 死亡 → falldeath (优先级 100)
		[&"*",      &"falldeath",    AIEvents.EV_DIED,            &"",              100],
	])

func _guard_on_floor() -> bool:
	return is_on_floor()

func _guard_in_air() -> bool:
	return not is_on_floor()

## KillZone 兼容入口 — 保持 trigger_fall_death() 接口存活
func trigger_fall_death() -> void:
	if state_controller:
		state_controller.goto(&"falldeath")
