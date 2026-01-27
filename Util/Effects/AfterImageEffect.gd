extends Node
class_name AfterImageEffect

## 残影效果 - 在移动过程中创建半透明残影
## 用于冲刺、闪避等快速移动时的视觉效果

# ============ 配置参数 ============
## 残影生成间隔（秒）
@export var spawn_interval: float = 0.03
## 残影持续时间（秒）
@export var fade_duration: float = 0.3
## 残影初始透明度
@export var initial_alpha: float = 0.6
## 残影颜色调制（可以设置为蓝色、白色等）
@export var color_tint: Color = Color(0.5, 0.7, 1.0, 1.0)
## 最大同时存在的残影数量
@export var max_after_images: int = 10

# ============ 运行时变量 ============
var _is_active: bool = false
var _target_sprite: Node2D = null
var _spawn_timer: float = 0.0
var _after_images: Array[Sprite2D] = []

# ============ 公共 API ============
## 开始生成残影
## @param sprite: 要复制的 Sprite2D 或 AnimatedSprite2D
func start(sprite: Node2D) -> void:
	if _is_active:
		return

	_target_sprite = sprite
	_is_active = true
	_spawn_timer = 0.0

	DebugConfig.debug("残影效果开始", "", "effect")

## 停止生成残影
func stop() -> void:
	_is_active = false
	_target_sprite = null

	DebugConfig.debug("残影效果停止", "", "effect")

## 立即清除所有残影
func clear_all() -> void:
	for after_image in _after_images:
		if is_instance_valid(after_image):
			after_image.queue_free()
	_after_images.clear()

## 检查是否正在运行
func is_active() -> bool:
	return _is_active

# ============ 生命周期 ============
func _process(delta: float) -> void:
	if not _is_active or not is_instance_valid(_target_sprite):
		return

	_spawn_timer += delta

	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_create_after_image()

# ============ 内部方法 ============
## 创建一个残影
## 使用 duplicate() 方法复制精灵，添加到当前场景根节点
func _create_after_image() -> void:
	if not _target_sprite:
		return

	# 限制残影数量
	if _after_images.size() >= max_after_images:
		var oldest = _after_images.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# 获取角色的全局位置（用于残影位置）
	# 优先使用角色的 CharacterBody2D 位置，确保残影在角色位置
	var owner_node = _target_sprite.get_owner()
	var after_image_position = _target_sprite.global_position
	if owner_node and owner_node is CharacterBody2D:
		after_image_position = owner_node.global_position

	# 使用 duplicate() 创建精灵副本（参考 whak-a-mole 实现）
	var after_image: Sprite2D = null

	if _target_sprite is AnimatedSprite2D:
		# AnimatedSprite2D 需要提取当前帧纹理创建 Sprite2D
		var animated_sprite = _target_sprite as AnimatedSprite2D
		var frames = animated_sprite.sprite_frames
		if frames:
			after_image = Sprite2D.new()
			var anim_name = animated_sprite.animation
			var frame_idx = animated_sprite.frame
			after_image.texture = frames.get_frame_texture(anim_name, frame_idx)
			after_image.flip_h = animated_sprite.flip_h
			after_image.flip_v = animated_sprite.flip_v
			# 复制 centered 和 offset 确保锚点一致
			after_image.centered = animated_sprite.centered
			after_image.offset = animated_sprite.offset
	elif _target_sprite is Sprite2D:
		# Sprite2D 直接 duplicate
		after_image = _target_sprite.duplicate() as Sprite2D

	if not after_image:
		return

	# 设置残影位置（使用角色位置，而非精灵位置）
	after_image.global_position = after_image_position
	after_image.global_rotation = _target_sprite.global_rotation
	after_image.scale = _target_sprite.scale

	# 设置初始外观
	after_image.modulate = Color(color_tint.r, color_tint.g, color_tint.b, initial_alpha)
	after_image.z_index = _target_sprite.z_index

	# 添加到当前场景根节点（而非角色父节点，避免跟随角色移动）
	# 使用 call_deferred 避免 "Parent node is busy" 错误
	var current_scene = _target_sprite.get_tree().current_scene
	if current_scene:
		# 先记录到数组，防止在 call_deferred 执行前被清理
		_after_images.append(after_image)
		# 延迟添加到场景
		current_scene.call_deferred("add_child", after_image)
		# 延迟启动渐隐动画（等待节点添加到场景后）
		_start_fade_deferred(after_image)

## 延迟启动渐隐动画（等待节点添加到场景后）
func _start_fade_deferred(after_image: Sprite2D) -> void:
	# 使用 call_deferred 确保在节点添加到场景后再创建 tween
	call_deferred("_fade_out_after_image", after_image)

## 残影渐隐动画
func _fade_out_after_image(after_image: Sprite2D) -> void:
	if not is_instance_valid(after_image) or not after_image.is_inside_tree():
		return
	var tween = after_image.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 渐隐
	tween.tween_property(after_image, "modulate:a", 0.0, fade_duration)

	# 完成后删除
	tween.tween_callback(func():
		if is_instance_valid(after_image):
			_after_images.erase(after_image)
			after_image.queue_free()
	)

# ============ 静态工厂方法 ============
## 创建并启动残影效果（一次性使用）
## @param sprite: 目标精灵
## @param duration: 持续时间
## @return: AfterImageEffect 实例
static func create_and_start(sprite: Node2D, duration: float = 1.0) -> AfterImageEffect:
	var effect = AfterImageEffect.new()
	sprite.add_child(effect)
	effect.start(sprite)

	# 在指定时间后停止
	var timer = sprite.get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(effect):
			effect.stop()
			# 等待残影消失后删除
			var cleanup_timer = sprite.get_tree().create_timer(effect.fade_duration + 0.1)
			cleanup_timer.timeout.connect(func():
				if is_instance_valid(effect):
					effect.queue_free()
			)
	)

	return effect
