extends EnemyBase

## ForestSnail - 缓慢地面敌人
## 所有通用逻辑由 EnemyBase 提供
## 参数通过场景 Inspector 配置（health=80, wander_speed=20, chase_speed=30...）
## 在 Inspector 中设置 has_gravity=true, gravity=800

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# 无方向动画，始终由代码控制 flip_h
	_update_sprite_facing()
