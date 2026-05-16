class_name AnimationPlayerBackend extends AnimationBackend

@export var player_path: NodePath = ^"../../AnimationPlayer"
@export var idle_anim: StringName = &"idle"
@export var walk_anim: StringName = &"walk"
@export var jump_up_anim: StringName = &"j_up"
@export var jump_down_anim: StringName = &"j_down"
@export var idle_speed_threshold: float = 5.0

var player: AnimationPlayer
var owner_node: Node

## 上一次请求的 locomotion 动画 — 用它而非 player.current_animation 判定,
## 避免单次动画(j_up/j_down)播完后 current_animation 清空导致重复 replay。
var _locomotion_anim: StringName = &""

func _ready() -> void:
	player = get_node_or_null(player_path) as AnimationPlayer
	if player:
		player.animation_finished.connect(_on_anim_finished)
	owner_node = get_owner()

func update_locomotion(velocity: Vector2, on_floor: bool) -> void:
	if _current_action != &"" or player == null:
		return
	var target: StringName
	if on_floor:
		target = walk_anim if velocity.length() > idle_speed_threshold else idle_anim
	else:
		target = jump_up_anim if velocity.y < 0.0 else jump_down_anim
	if _locomotion_anim != target and player.has_animation(target):
		_locomotion_anim = target
		player.play(target)

func play_action(action_id: StringName, speed_scale: float = 1.0) -> void:
	if player == null or not player.has_animation(action_id):
		action_finished.emit.call_deferred(action_id)
		return
	_current_action = action_id
	_locomotion_anim = &""  # 动作结束后强制 locomotion 重新求值
	player.speed_scale = speed_scale
	player.play(action_id)
	player.seek(0.0, true)

func stop_action() -> void:
	if player:
		player.speed_scale = 1.0
	super.stop_action()

func has_action(action_id: StringName) -> bool:
	return player != null and player.has_animation(action_id)

func _on_anim_finished(anim_name: StringName) -> void:
	if player:
		player.speed_scale = 1.0
	super._on_anim_finished(anim_name)
