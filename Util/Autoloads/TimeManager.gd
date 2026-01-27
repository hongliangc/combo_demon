extends Node

## 时间管理器 - 控制全局时间缩放（子弹时间）
## 作为 Autoload 使用，通过 TimeManager 全局访问

# ============ 信号 ============
## 子弹时间开始
signal bullet_time_started(scale: float)
## 子弹时间结束
signal bullet_time_ended()
## 时间缩放变化
signal time_scale_changed(new_scale: float)

# ============ 配置参数 ============
## 默认子弹时间缩放
const DEFAULT_BULLET_TIME_SCALE: float = 0.3
## 时间缩放过渡持续时间
const TRANSITION_DURATION: float = 0.1

# ============ 运行时变量 ============
## 是否处于子弹时间
var is_bullet_time_active: bool = false
## 原始时间缩放
var _original_time_scale: float = 1.0
## 当前过渡 Tween
var _transition_tween: Tween = null

# ============ 生命周期 ============
func _ready() -> void:
	# 确保初始时间缩放为 1.0
	Engine.time_scale = 1.0

# ============ 公共 API ============
## 开启子弹时间
## @param scale: 时间缩放（默认 0.3，即 30% 速度）
## @param transition_duration: 过渡时间（默认 0.1s）
func start_bullet_time(scale: float = DEFAULT_BULLET_TIME_SCALE, transition_duration: float = TRANSITION_DURATION) -> void:
	if is_bullet_time_active:
		return

	is_bullet_time_active = true
	_original_time_scale = Engine.time_scale

	# 平滑过渡到子弹时间
	_transition_time_scale(scale, transition_duration)

	bullet_time_started.emit(scale)
	DebugConfig.info("子弹时间开启: %.1f%%" % (scale * 100), "", "time")

## 结束子弹时间
## @param transition_duration: 过渡时间（默认 0.1s）
func end_bullet_time(transition_duration: float = TRANSITION_DURATION) -> void:
	if not is_bullet_time_active:
		return

	is_bullet_time_active = false

	# 平滑恢复到原始时间
	_transition_time_scale(_original_time_scale, transition_duration)

	bullet_time_ended.emit()
	DebugConfig.info("子弹时间结束", "", "time")

## 设置时间缩放（带平滑过渡）
## @param scale: 目标时间缩放
## @param duration: 过渡持续时间
func set_time_scale(scale: float, duration: float = 0.0) -> void:
	if duration <= 0:
		Engine.time_scale = scale
		time_scale_changed.emit(scale)
	else:
		_transition_time_scale(scale, duration)

## 获取当前时间缩放
func get_time_scale() -> float:
	return Engine.time_scale

## 暂停游戏（时间缩放为 0）
func pause_time() -> void:
	Engine.time_scale = 0.0
	time_scale_changed.emit(0.0)

## 恢复游戏时间
func resume_time() -> void:
	Engine.time_scale = _original_time_scale if _original_time_scale > 0 else 1.0
	time_scale_changed.emit(Engine.time_scale)

# ============ 内部方法 ============
## 平滑过渡时间缩放
func _transition_time_scale(target_scale: float, duration: float) -> void:
	# 取消之前的过渡
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	# 创建新的过渡
	# 注意：使用 process_mode 确保在慢动作时也能正常过渡
	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_QUAD)

	# 使用 real time 避免受时间缩放影响
	_transition_tween.tween_method(_set_engine_time_scale, Engine.time_scale, target_scale, duration).set_trans(Tween.TRANS_LINEAR)

## 设置引擎时间缩放（Tween 回调）
func _set_engine_time_scale(scale: float) -> void:
	Engine.time_scale = scale
	time_scale_changed.emit(scale)
