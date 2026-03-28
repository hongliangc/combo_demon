extends BKBaseState

## BladeKeeper 3段连击状态
## atk_1 → atk_2 → atk_3，每段之间可被打断

var _combo_step := 0
const COMBO_ANIMS := ["atk_1", "atk_2", "atk_3"]

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_combo_step = 0
	if _bk:
		_bk.velocity = Vector2.ZERO
		update_sprite_facing(false)
	_play_combo_step()

func _play_combo_step() -> void:
	if _combo_step >= COMBO_ANIMS.size():
		_finish_attack()
		return
	play_anim(COMBO_ANIMS[_combo_step])
	if _bk and _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_anim_finished):
			_bk.sprite.animation_finished.connect(_on_anim_finished)

func _on_anim_finished() -> void:
	_combo_step += 1
	if _combo_step < COMBO_ANIMS.size():
		if is_target_alive() and get_distance_to_target() <= _bk.attack_range * 1.5:
			_play_combo_step()
		else:
			_finish_attack()
	else:
		_finish_attack()

func _finish_attack() -> void:
	_try_melee_damage()
	if _bk:
		var mgr := get_attack_manager() as BladeKeeperAttackManager
		_bk.attack_cooldown = mgr.get_cooldown() if mgr else 1.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func _try_melee_damage() -> void:
	if not is_target_alive() or not _bk:
		return
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if not mgr or not mgr.melee_damage:
		return
	var dist := get_distance_to_target()
	if dist > _bk.attack_range:
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		var dmg := mgr.melee_damage.duplicate(true)
		dmg.randomize_damage()
		hurtbox.take_damage(dmg, _bk.global_position)

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_anim_finished):
		_bk.sprite.animation_finished.disconnect(_on_anim_finished)
