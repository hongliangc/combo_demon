extends Area2D
class_name KillZone

## 坠落死亡区域 - 放在关卡底部，玩家进入后触发坠落死亡
## 使用方法：在关卡场景中添加 KillZone.tscn，调整位置到地图底部

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerBase:
		body.trigger_fall_death()
