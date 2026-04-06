extends Node2D
class_name CounterFlashEffect

## 反击蓄力闪光效果 — 红色描边脉冲 + 微缩放
## 复用 golden_outline_flash.gdshader，红色调

signal effect_finished()

@export var duration: float = 0.4
@export var thickness: float = 1.5
@export var flash_color: Color = Color(1.0, 0.2, 0.1, 1.0)  ## 红橙色

var _source_sprite: Node2D = null
var _original_material: Material = null
var _shader_material: ShaderMaterial = null
var _original_scale: Vector2 = Vector2.ONE

static var _shader: Shader = null

## 对目标精灵应用反击闪光效果
func create_from_sprite(source_sprite: Node2D, _spawn_position: Vector2) -> void:
	_source_sprite = source_sprite
	_original_scale = source_sprite.scale

	if _shader == null:
		_shader = load("res://Assets/Shaders/golden_outline_flash.gdshader")

	_original_material = source_sprite.material

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _shader
	_shader_material.set_shader_parameter("outline_color", flash_color)
	_shader_material.set_shader_parameter("thickness", 0.0)
	source_sprite.material = _shader_material

	_play_counter_flash()

func _play_counter_flash() -> void:
	var tween = create_tween()
	var peak := thickness

	# 快速亮起红色描边
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, 0.0, peak, duration * 0.2)

	# 缩放脉冲 (1.0 → 1.1 → 1.0)
	tween.parallel().tween_property(_source_sprite, "scale", _original_scale * 1.1, duration * 0.2)

	# 保持高亮
	tween.tween_interval(duration * 0.4)

	# 渐隐 + 恢复缩放
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, peak, 0.0, duration * 0.4)
	tween.parallel().tween_property(_source_sprite, "scale", _original_scale, duration * 0.4)

	tween.tween_callback(_cleanup)

func _set_thickness(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("thickness", value)

func _cleanup() -> void:
	if is_instance_valid(_source_sprite):
		_source_sprite.material = _original_material
		_source_sprite.scale = _original_scale
	_source_sprite = null
	_original_material = null
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null
	effect_finished.emit()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_source_sprite) and _source_sprite.material == _shader_material:
		_source_sprite.material = _original_material
		_source_sprite.scale = _original_scale
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null

# ============ 静态工厂方法 ============
static func create(source_sprite: Node2D, spawn_position: Vector2, parent: Node) -> CounterFlashEffect:
	var effect = CounterFlashEffect.new()
	effect._pending_source_sprite = source_sprite
	effect._pending_spawn_position = spawn_position
	parent.call_deferred("add_child", effect)
	return effect

var _pending_source_sprite: Node2D = null
var _pending_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if _pending_source_sprite:
		create_from_sprite(_pending_source_sprite, _pending_spawn_position)
		_pending_source_sprite = null
