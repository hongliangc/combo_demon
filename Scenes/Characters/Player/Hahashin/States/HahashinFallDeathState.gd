class_name HahashinFallDeathState extends AIState

## 坠落死亡状态：停止移动 + 呼出 GameOverUI。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
	agent.velocity = Vector2.ZERO
	GameManager.game_over()
