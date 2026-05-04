extends AIState

## Stock Hit — 受击反应：查询 BuffController.get_top_hit_buff() 选动画 + 锁时长
## 不再 apply effects（已由 DamagePipeline.post_apply 阶段处理）

const HitFlashHelperRef := preload("res://Core/Effects/HitFlashHelper.gd")

@export var default_duration: float = 0.3

var _timer: Timer

func _init() -> void:
	reentrant = true

func enter() -> void:
	var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
	var preserve_vel := bc != null and bc.should_preserve_velocity()

	if owner_node is CharacterBody2D and not preserve_vel:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

	var anim_key: StringName = &"hit"
	var duration: float = default_duration

	if bc:
		var resolved := bc.resolve_hit_anim(anim_key, duration)
		anim_key = resolved[&"anim"]
		duration = resolved[&"duration"]

	_play_anim_or_fallback(anim_key)

	_ensure_timer()
	_timer.wait_time = duration
	_timer.start()


## 动画解析顺序: buff 指定 → 通用 "hit" → 白闪
func _play_anim_or_fallback(anim_key: StringName) -> void:
	if not ("anim_player" in owner_node) or not owner_node.anim_player:
		HitFlashHelperRef.flash(owner_node)
		return
	var ap = owner_node.anim_player
	if ap.has_animation(anim_key):
		ap.play(anim_key)
		ap.seek(0.0, true)
		return
	if anim_key != &"hit" and ap.has_animation(&"hit"):
		ap.play(&"hit")
		ap.seek(0.0, true)
		return
	HitFlashHelperRef.flash(owner_node)


func physics_update(delta: float) -> void:
	if not (owner_node is CharacterBody2D):
		return
	var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
	if bc and bc.should_preserve_velocity():
		return
	var body := owner_node as CharacterBody2D
	body.velocity = body.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
	if _timer:
		_timer.stop()
	bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_HIT_RECOVERED))
		add_child(_timer)
