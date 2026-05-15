class_name AnimationPlayerBackend extends AnimationBackend

@export var player_path: NodePath = ^"../../AnimationPlayer"
@export var idle_anim: StringName = &"idle"
@export var walk_anim: StringName = &"walk"
@export var idle_speed_threshold: float = 5.0

var player: AnimationPlayer

func _ready() -> void:
	player = get_node_or_null(player_path) as AnimationPlayer
	if player:
		player.animation_finished.connect(_on_anim_finished)

func update_locomotion(velocity: Vector2) -> void:
	if _current_action != &"" or player == null:
		return
	var target := walk_anim if velocity.length() > idle_speed_threshold else idle_anim
	if player.current_animation != target and player.has_animation(target):
		player.play(target)

func play_action(action_id: StringName, speed_scale: float = 1.0) -> void:
	if player == null or not player.has_animation(action_id):
		action_finished.emit.call_deferred(action_id)
		return
	_current_action = action_id
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
