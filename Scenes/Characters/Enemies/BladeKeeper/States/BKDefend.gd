extends BKBaseState

## BladeKeeper 防御反击状态
## 举盾防御 1-2秒，期间受击伤害减半，防御结束 → sp_atk 反击

@export var defend_duration := 1.5
var _defending := false

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_defending = true
	if _bk:
		_bk.velocity = Vector2.ZERO
		update_sprite_facing(false)
	play_anim("defend")
	start_timer(defend_duration, _on_defend_timeout)

func _on_defend_timeout() -> void:
	_defending = false
	play_anim("sp_atk")
	if _bk and _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_counter_finished):
			_bk.sprite.animation_finished.connect(_on_counter_finished)
	_try_counter_damage()

func _try_counter_damage() -> void:
	if not is_target_alive() or not _bk:
		return
	var dist := get_distance_to_target()
	if dist > _bk.attack_range * 1.2:
		return
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if not mgr or not mgr.melee_damage:
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		var dmg := mgr.melee_damage.duplicate(true)
		dmg.amount *= 1.5
		dmg.min_amount *= 1.5
		dmg.max_amount *= 1.5
		dmg.randomize_damage()
		hurtbox.take_damage(dmg, _bk.global_position)

func _on_counter_finished() -> void:
	if _bk:
		var mgr := get_attack_manager() as BladeKeeperAttackManager
		_bk.attack_cooldown = mgr.get_cooldown() if mgr else 1.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func on_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if _defending:
		# 防御中：减半伤害（通过治疗弥补）
		if _bk and _bk.health_component:
			var heal_amount := damage.amount * 0.5
			_bk.health_component.heal(heal_amount)
		return
	super.on_damaged(damage, attacker_position)

func exit() -> void:
	stop_timer()
	_defending = false
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_counter_finished):
		_bk.sprite.animation_finished.disconnect(_on_counter_finished)
