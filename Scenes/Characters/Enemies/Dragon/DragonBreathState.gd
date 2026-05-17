class_name DragonBreathState extends BaseAttackState

## Dragon 特殊技能: 火焰吐息 — 停步 → 蓄气脉冲 → 扇形发 fireball_count 个火球
## faithful port: 旧 DragonBreathState (SpecialSkillState 子类)。
## 30% 概率 / 距离门 / 6s 冷却已上移到 dragon_breath.tres
## (precondition_method / max_range / cooldown) —— 见 Dragon._can_dragon_breath。

const FIREBALL_SCENE: PackedScene = preload("res://Scenes/Characters/Enemies/Dragon/DragonFireball.tscn")

@export var spread_angle_deg := 20.0
@export var fireball_count := 3
@export var pre_fire_delay := 0.4

var _active := false
var _charge_tween: Tween = null

func enter() -> void:
	_active = true
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_face_target()
	_charge_pulse()
	# 蓄气短暂延迟
	await owner_node.get_tree().create_timer(pre_fire_delay).timeout
	# 蓄气期间状态被换走 (exit 已运行) → 放弃
	if not _active or not is_instance_valid(owner_node):
		return
	_fire_fan()
	await owner_node.get_tree().create_timer(0.3).timeout
	if not _active or not is_instance_valid(owner_node):
		return
	_finish()

func exit() -> void:
	_active = false
	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()
	_charge_tween = null
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		owner_node.sprite.modulate = Color(1, 1, 1, 1)

## 面向目标 (复用 AgentBase 的 flip_h / sprite_faces_right 约定)
func _face_target() -> void:
	if not (owner_node is Node2D) or not ("sprite" in owner_node) or not owner_node.sprite:
		return
	var tp: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
	var face_right: bool = tp.x > (owner_node as Node2D).global_position.x
	owner_node.sprite.flip_h = face_right != owner_node.sprite_faces_right

## 蓄气: 橙色脉冲提示 (2 个来回)
func _charge_pulse() -> void:
	if not (is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite):
		return
	_charge_tween = owner_node.create_tween().set_loops(2)
	_charge_tween.tween_property(owner_node.sprite, "modulate", Color(2.0, 0.8, 0.1, 1.0), 0.1)
	_charge_tween.tween_property(owner_node.sprite, "modulate", Color(1, 1, 1, 1), 0.1)

## 朝目标方向扇形发射 fireball_count 个 DragonFireball (±spread_angle_deg)
func _fire_fan() -> void:
	if not (owner_node is Node2D):
		return
	var origin: Vector2 = (owner_node as Node2D).global_position
	var tp: Vector2 = bb.get_var(&"target_position", origin)
	var base_dir: Vector2 = (tp - origin).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	for i in fireball_count:
		var angle_offset := deg_to_rad(
			-spread_angle_deg + spread_angle_deg * (float(i) / (fireball_count - 1)) * 2.0
		)
		var dir := base_dir.rotated(angle_offset)
		var fireball: DragonFireball = FIREBALL_SCENE.instantiate()
		fireball.global_position = origin
		fireball.setup(dir, origin)
		owner_node.get_parent().add_child(fireball)
