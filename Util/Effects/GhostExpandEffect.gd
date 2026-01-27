extends Node2D
class_name GhostExpandEffect

## 残影放大消失效果 - 在原地创建角色残影，放大后渐隐消失
## 用于技能释放时的蓄力/释放视觉效果

# ============ 信号 ============
signal effect_finished()

# ============ 配置参数 ============
## 放大倍数
@export var scale_multiplier: float = 2.0
## 效果持续时间
@export var duration: float = 1.0
## 残影颜色
@export var ghost_color: Color = Color(0.8, 0.9, 1.0, 0.8)
## 是否添加发光效果
@export var enable_glow: bool = true

# ============ 运行时变量 ============
var _ghost_sprite: Sprite2D = null

# ============ 公共 API ============
## 从目标精灵创建残影效果
## @param source_sprite: 源精灵（AnimatedSprite2D 或 Sprite2D）
## @param spawn_position: 生成位置
func create_from_sprite(source_sprite: Node2D, spawn_position: Vector2) -> void:
	global_position = spawn_position

	# 创建残影精灵
	_ghost_sprite = Sprite2D.new()

	# 复制纹理
	if source_sprite is AnimatedSprite2D:
		var animated = source_sprite as AnimatedSprite2D
		var frames = animated.sprite_frames
		if frames:
			_ghost_sprite.texture = frames.get_frame_texture(animated.animation, animated.frame)
			_ghost_sprite.flip_h = animated.flip_h
			_ghost_sprite.flip_v = animated.flip_v
			# 复制centered和offset属性，确保锚点一致
			_ghost_sprite.centered = animated.centered
			_ghost_sprite.offset = animated.offset
	elif source_sprite is Sprite2D:
		var sprite = source_sprite as Sprite2D
		_ghost_sprite.texture = sprite.texture
		_ghost_sprite.flip_h = sprite.flip_h
		_ghost_sprite.flip_v = sprite.flip_v
		_ghost_sprite.region_enabled = sprite.region_enabled
		_ghost_sprite.region_rect = sprite.region_rect
		# 复制centered和offset属性，确保锚点一致
		_ghost_sprite.centered = sprite.centered
		_ghost_sprite.offset = sprite.offset

	# 设置初始状态
	_ghost_sprite.modulate = ghost_color
	_ghost_sprite.z_index = source_sprite.z_index + 1

	# 设置精灵位置为(0,0)，确保缩放以 GhostExpandEffect 的中心点（hahashin位置）为基准
	_ghost_sprite.position = Vector2.ZERO

	add_child(_ghost_sprite)

	# 开始动画
	_play_expand_animation()

## 播放放大后缩小动画
func _play_expand_animation() -> void:
	var tween = create_tween()

	# 阶段1：快速放大
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_ghost_sprite, "scale", Vector2.ONE * scale_multiplier, duration * 0.5)

	# 阶段2：缩小回原始大小并渐隐
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_ghost_sprite, "scale", Vector2.ONE, duration * 0.5)
	tween.parallel().tween_property(_ghost_sprite, "modulate:a", 0.0, duration * 0.5)

	# 完成后删除
	tween.tween_callback(func():
		effect_finished.emit()
		queue_free()
	)

# ============ 静态工厂方法 ============
## 在指定位置创建残影放大效果（使用call_deferred避免节点繁忙错误）
## @param source_sprite: 源精灵
## @param spawn_position: 生成位置
## @param parent: 父节点
## @return: GhostExpandEffect 实例
static func create(source_sprite: Node2D, spawn_position: Vector2, parent: Node) -> GhostExpandEffect:
	var effect = GhostExpandEffect.new()
	# 保存参数，在 _ready 中初始化
	effect._pending_source_sprite = source_sprite
	effect._pending_spawn_position = spawn_position
	# 使用 call_deferred 避免 "Parent node is busy" 错误
	parent.call_deferred("add_child", effect)
	return effect

# ============ 待初始化参数 ============
var _pending_source_sprite: Node2D = null
var _pending_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 如果有待初始化的参数，执行初始化
	if _pending_source_sprite:
		create_from_sprite(_pending_source_sprite, _pending_spawn_position)
		_pending_source_sprite = null
