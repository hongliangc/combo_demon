extends Node
class_name EnemyHighlightEffect

## 敌人高亮闪烁效果 - 镜头切换到敌人时的标记效果
## 使用 modulate 实现白色闪烁

# ============ 配置参数 ============
## 闪烁次数
@export var flash_count: int = 2
## 单次闪烁持续时间
@export var flash_duration: float = 0.08
## 闪烁高亮颜色
@export var highlight_color: Color = Color(2.0, 2.0, 2.0, 1.0)  # 超亮白色
## 闪烁间隔
@export var flash_interval: float = 0.05

# ============ 运行时变量 ============
var _original_modulate: Color = Color.WHITE
var _target: Node2D = null
var _tween: Tween = null

# ============ 公共 API ============
## 对目标应用闪烁效果
## @param target: 目标节点（需要有 modulate 属性）
func apply(target: Node2D) -> void:
	if not target:
		return

	_target = target
	_original_modulate = target.modulate

	_start_flash_sequence()

## 立即停止效果并恢复原状
func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	if is_instance_valid(_target):
		_target.modulate = _original_modulate

# ============ 内部方法 ============
## 开始闪烁序列
func _start_flash_sequence() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)

	for i in range(flash_count):
		# 闪烁到高亮
		_tween.tween_property(_target, "modulate", highlight_color, flash_duration * 0.5)
		# 恢复
		_tween.tween_property(_target, "modulate", _original_modulate, flash_duration * 0.5)
		# 间隔
		if i < flash_count - 1:
			_tween.tween_interval(flash_interval)

	# 完成后自动清理
	_tween.tween_callback(_on_flash_complete)

## 闪烁完成回调
func _on_flash_complete() -> void:
	if is_instance_valid(_target):
		_target.modulate = _original_modulate
	queue_free()

# ============ 静态工厂方法 ============
## 对目标应用闪烁效果（一次性）
## @param target: 目标节点
## @param flash_count: 闪烁次数（可选）
## @return: EnemyHighlightEffect 实例
static func flash(target: Node2D, custom_flash_count: int = 2) -> EnemyHighlightEffect:
	var effect = EnemyHighlightEffect.new()
	effect.flash_count = custom_flash_count
	target.add_child(effect)
	effect.apply(target)
	return effect

## 对目标应用闪烁效果并等待完成
## @param target: 目标节点
## @return: 等待闪烁完成的时间
static func flash_and_get_duration(target: Node2D, custom_flash_count: int = 2) -> float:
	var effect = EnemyHighlightEffect.new()
	effect.flash_count = custom_flash_count
	target.add_child(effect)
	effect.apply(target)

	# 计算总持续时间
	var total_duration = custom_flash_count * effect.flash_duration
	total_duration += (custom_flash_count - 1) * effect.flash_interval
	return total_duration
