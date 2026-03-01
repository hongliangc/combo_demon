extends Node
class_name AfterImageEffect

## 残影效果 - 在移动过程中创建半透明残影
## 用于冲刺、闪避等快速移动时的视觉效果

# ============ 配置参数 ============
## 残影生成间隔（秒）
@export var spawn_interval: float = 0.03
## 残影持续时间（秒）
@export var fade_duration: float = 0.8
## 残影初始透明度
@export var initial_alpha: float = 1
## 残影颜色调制（可以设置为蓝色、白色等）
@export var color_tint: Color = Color(1.0, 0.84, 0.0, 1.0)
## 最大同时存在的残影数量
@export var max_after_images: int = 10

# ============ 运行时变量 ============
var _is_active: bool = false
var _target_sprite: Node2D = null
var _spawn_timer: float = 0.0
var _after_images: Array[Node2D] = []

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
## 创建一个残影（参考 whak-a-mole 的 spawn_dash_trail 实现）
## 使用 duplicate() 复制精灵，直接添加到场景根节点
func _create_after_image() -> void:
	if not _target_sprite:
		return

	# 限制残影数量
	if _after_images.size() >= max_after_images:
		var oldest = _after_images.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# 直接 duplicate 精灵（适用于 Sprite2D 和 AnimatedSprite2D）
	var effect: Node2D = _target_sprite.duplicate()
	if not effect:
		return

	# AnimatedSprite2D 需要停止动画播放，冻结在当前帧
	if effect is AnimatedSprite2D:
		(effect as AnimatedSprite2D).pause()

	# 设置位置和外观
	effect.global_position = _target_sprite.global_position
	effect.modulate = Color(color_tint.r, color_tint.g, color_tint.b, initial_alpha)

	# 添加到场景根节点
	_target_sprite.get_tree().current_scene.add_child(effect)
	_after_images.append(effect)

	# 使用场景树级别的 tween 渐隐
	var fade_tween: Tween = _target_sprite.get_tree().create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(effect, "modulate", Color(color_tint.r, color_tint.g, color_tint.b, 0.0), fade_duration)
	fade_tween.chain().tween_callback(func():
		if is_instance_valid(effect):
			_after_images.erase(effect)
			effect.queue_free()
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
