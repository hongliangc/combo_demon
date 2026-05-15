class_name HahashinFallDeathState extends AIState

## 坠落死亡状态：停止移动 + 呼出 GameOverUI。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = false
	agent.velocity = Vector2.ZERO
	GameManager.game_over()
