extends Node2D

## 落地灰尘特效
## 使用 CPUParticles2D 生成灰尘粒子效果
## 自动播放并在 1 秒后销毁

func _ready() -> void:
	# 启动粒子发射
	if has_node("CPUParticles2D"):
		$CPUParticles2D.emitting = true

	# 1秒后自动销毁
	await get_tree().create_timer(1.0).timeout
	queue_free()
