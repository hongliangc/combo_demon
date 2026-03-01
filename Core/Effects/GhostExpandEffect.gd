extends Node2D
class_name GhostExpandEffect

## 金色边框高亮闪动效果 - 在源精灵上叠加金色描边并脉冲闪烁
## 用于V技能释放时的蓄力/释放视觉效果

# ============ 信号 ============
signal effect_finished()

# ============ 配置参数 ============
## 效果持续时间
@export var duration: float = 0.8
## 描边宽度（像素），对应 shader 的 thickness
@export var thickness: float = 1
## 金色边框颜色
@export var outline_color: Color = Color(1.0, 0.84, 0.0, 1.0)

# ============ 运行时变量 ============
var _source_sprite: Node2D = null
var _original_material: Material = null
var _shader_material: ShaderMaterial = null

static var _shader: Shader = null

# ============ 公共 API ============

## 对目标精灵应用金色边框高亮闪动效果
## @param source_sprite: 源精灵（AnimatedSprite2D 或 Sprite2D）
## @param _spawn_position: 未使用，保留接口兼容
func create_from_sprite(source_sprite: Node2D, _spawn_position: Vector2) -> void:
	_source_sprite = source_sprite

	# 懒加载 shader
	if _shader == null:
		_shader = load("res://Assets/Shaders/golden_outline_flash.gdshader")

	# 保存原始 material 以便恢复
	_original_material = source_sprite.material

	# 创建并应用 ShaderMaterial
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _shader
	_shader_material.set_shader_parameter("outline_color", outline_color)
	_shader_material.set_shader_parameter("thickness", 0.0)
	source_sprite.material = _shader_material

	# 开始闪动动画
	_play_flash_animation()

## 播放金色边框脉冲闪动动画
func _play_flash_animation() -> void:
	var tween = create_tween()

	var peak := thickness

	# 阶段1：快速亮起
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, 0.0, peak, duration * 0.12)

	# 阶段2：脉冲闪烁 (3次闪动)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_thickness, peak, peak * 0.4, duration * 0.12)
	tween.tween_method(_set_thickness, peak * 0.4, peak * 1.2, duration * 0.12)
	tween.tween_method(_set_thickness, peak * 1.2, peak * 0.3, duration * 0.12)
	tween.tween_method(_set_thickness, peak * 0.3, peak * 1.4, duration * 0.12)

	# 阶段3：最强闪光后渐隐
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, peak * 1.4, 0.0, duration * 0.28)

	# 完成后清理
	tween.tween_callback(_cleanup)

func _set_thickness(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("thickness", value)

func _cleanup() -> void:
	# 恢复原始 material
	if is_instance_valid(_source_sprite):
		_source_sprite.material = _original_material
	_source_sprite = null
	_original_material = null
	# 断开 shader 引用，确保 ShaderMaterial RID 被释放
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null
	effect_finished.emit()
	queue_free()

func _exit_tree() -> void:
	# 防止效果被中断时 ShaderMaterial 泄漏
	if is_instance_valid(_source_sprite) and _source_sprite.material == _shader_material:
		_source_sprite.material = _original_material
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null

# ============ 静态工厂方法 ============
## 在源精灵上创建金色边框闪动效果（使用call_deferred避免节点繁忙错误）
## @param source_sprite: 源精灵
## @param spawn_position: 保留参数（未使用）
## @param parent: 父节点
## @return: GhostExpandEffect 实例
static func create(source_sprite: Node2D, spawn_position: Vector2, parent: Node) -> GhostExpandEffect:
	var effect = GhostExpandEffect.new()
	effect._pending_source_sprite = source_sprite
	effect._pending_spawn_position = spawn_position
	parent.call_deferred("add_child", effect)
	return effect

# ============ 待初始化参数 ============
var _pending_source_sprite: Node2D = null
var _pending_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if _pending_source_sprite:
		create_from_sprite(_pending_source_sprite, _pending_spawn_position)
		_pending_source_sprite = null
