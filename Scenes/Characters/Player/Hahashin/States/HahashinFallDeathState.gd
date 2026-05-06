class_name HahashinFallDeathState extends AIState

## 坠落死亡状态 — 1.4a 占位桩，暂时停止移动。
## 1.4a 将替换为 GameOver UI 流程。

func enter() -> void:
	push_warning("HahashinFallDeathState: stub — no-op until 1.4a")
	if agent is CharacterBody2D:
		(agent as CharacterBody2D).velocity = Vector2.ZERO
