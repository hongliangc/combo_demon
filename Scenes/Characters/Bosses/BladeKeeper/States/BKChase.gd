extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## BladeKeeper Chase 状态 — 继承通用 ChaseState
## 每次 enter 读取 Boss 参数（支持阶段变速），重写攻击路由

func _init():
	super._init()
	enable_sprite_flip = true
	give_up_state_name = "idle"

func enter() -> void:
	# 每次进入 chase 时读取当前 Boss 参数（支持阶段变速）
	var boss := owner_node as BossBase
	if boss:
		default_chase_speed = (boss as BladeKeeper).move_speed if boss is BladeKeeper else 180.0
		default_attack_range = boss.attack_range
		default_give_up_range = boss.detection_radius
	super.enter()

## 检测玩家是否在空中 → 跳追
func physics_process_state(delta: float) -> void:
	if target_node and target_node is CharacterBody2D:
		var target_body := target_node as CharacterBody2D
		if not target_body.is_on_floor() and state_machine.states.has("jump"):
			transition_to("jump")
			return
	super.physics_process_state(delta)

## 重写：到达攻击范围时，从 BossAttackManager 选择攻击模式并路由
func _on_reached_attack_range() -> String:
	var boss := owner_node as BossBase
	if not boss or boss.attack_cooldown > 0:
		return ""  # 冷却中，留在 chase

	# 查找 BossAttackManager（BKChase 继承 BaseState，无 get_attack_manager()）
	var mgr: BossAttackManager = null
	for child in boss.get_children():
		if child is BossAttackManager:
			mgr = child
			break

	if not mgr:
		return "attack"

	var entry: Dictionary = mgr.pick_attack()
	var mode: String = entry.get("mode", "attack")
	boss.attack_cooldown = mgr.get_cooldown()

	match mode:
		"projectile":
			return "projectile"
		"trap":
			return "trap"
		_:
			# attack, combo, special 统一由 BKAttack 处理
			return "attack"
