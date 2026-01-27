extends ProgressBar

## Enemy 血条 - 兼容 HealthComponent 的 health_changed 信号

func on_health_changed(current_health: float, max_health: float) -> void:
	if max_health > 0:
		value = current_health / max_health
