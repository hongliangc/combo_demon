extends PlayerBaseState
class_name PlayerAirState

## 空中状态：j_up ↔ j_down，检测落地/攻击输入
## priority = BEHAVIOR(0), can_be_interrupted = true

func enter() -> void:
	var body := owner_node as CharacterBody2D
	if body and body.velocity.y < 0:
		enter_control_state("j_up")
	else:
		enter_control_state("j_down")
	var movement = get_movement()
	if movement:
		movement.can_move = true

func physics_process_state(_delta: float) -> void:
	var body := owner_node as CharacterBody2D
	if not body:
		return

	# 落地 → Ground
	if body.is_on_floor():
		transitioned.emit(self, "ground")
		return

	# 攻击输入 → 空中攻击（普通攻击键映射为 atk_air）
	for action in ["atk_1", "atk_2", "atk_3"]:
		if Input.is_action_just_pressed(action):
			owner_node.pending_combat_skill = "atk_air"
			transitioned.emit(self, "combat")
			return

	# V 技能 → SpecialAttack
	if Input.is_action_just_pressed("atk_sp"):
		transitioned.emit(self, "specialattack")
		return

	# j_up → j_down（下落时切换）
	if body.velocity.y > 0:
		var tree = get_anim_tree()
		if tree:
			var pb = tree.get("parameters/control_sm/playback")
			if pb and pb.get_current_node() != "j_down":
				pb.travel("j_down")
