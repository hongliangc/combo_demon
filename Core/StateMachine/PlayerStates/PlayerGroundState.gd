extends PlayerBaseState
class_name PlayerGroundState

## 地面状态：idle ↔ run，检测跳跃/攻击/翻滚输入
## priority = BEHAVIOR(0), can_be_interrupted = true

func enter() -> void:
	exit_control_state()
	set_locomotion_state("idle")
	var movement = get_movement()
	if movement:
		movement.can_move = true

func physics_process_state(_delta: float) -> void:
	var body := owner_node as CharacterBody2D
	if not body:
		return

	# 不在地面 → Air
	if not body.is_on_floor():
		transitioned.emit(self, "air")
		return

	# V 技能 → SpecialAttack
	if Input.is_action_just_pressed("atk_sp"):
		transitioned.emit(self, "specialattack")
		return

	# 普通攻击 → Combat
	for action in ["atk_1", "atk_2", "atk_3"]:
		if Input.is_action_just_pressed(action):
			owner_node.pending_combat_skill = action
			transitioned.emit(self, "combat")
			return

	# 翻滚输入 → Roll
	if Input.is_action_just_pressed("roll"):
		transitioned.emit(self, "roll")
		return

	# 更新 locomotion 动画：idle ↔ run
	if abs(body.velocity.x) > 1.0:
		set_locomotion_state("run")
	else:
		set_locomotion_state("idle")
