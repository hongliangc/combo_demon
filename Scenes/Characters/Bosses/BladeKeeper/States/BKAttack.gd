extends BossState

## BladeKeeper Attack 状态 — 3 段连击或特殊攻击

const COMBO_ANIMS := ["atk_1", "atk_2", "atk_3"]

var _current_combo_step := 0
var _is_special := false
var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	_anim_tree_ref = get_anim_tree()

	# 从攻击管理器选择攻击类型
	var mgr := get_attack_manager()
	var entry := mgr.pick_attack() if mgr else {}
	var mode: String = entry.get("mode", "attack")

	boss.attack_cooldown = mgr.get_cooldown() if mgr else 1.5

	if mode == "special":
		_is_special = true
		_current_combo_step = 0
		enter_control_state("sp_atk")
	elif mode == "defend":
		transitioned.emit(self, "defend")
		return
	elif mode.begins_with("roll"):
		transitioned.emit(self, "roll")
		return
	elif mode.begins_with("combo"):
		# TODO: combo 序列由 BossComboAttack 驱动
		_is_special = false
		_current_combo_step = 0
		enter_control_state(COMBO_ANIMS[0])
	else:
		_is_special = false
		_current_combo_step = 0
		enter_control_state(COMBO_ANIMS[0])

	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name: StringName) -> void:
	if _is_special:
		_finish_attack()
		return

	_current_combo_step += 1
	if _current_combo_step < COMBO_ANIMS.size():
		enter_control_state(COMBO_ANIMS[_current_combo_step])
	else:
		_finish_attack()

func _finish_attack() -> void:
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func exit() -> void:
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_animation_finished)
	_current_combo_step = 0
	_is_special = false
