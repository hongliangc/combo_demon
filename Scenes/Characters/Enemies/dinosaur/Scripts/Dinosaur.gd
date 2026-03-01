extends EnemyBase

## Dinosaur 敌人 - 继承 EnemyBase
## 特有功能：随机纹理选择

@export_group("Textures")
@export var textures: Array[Texture2D] = []

func _on_enemy_ready() -> void:
	# 随机选择纹理
	if not textures.is_empty() and sprite is Sprite2D:
		(sprite as Sprite2D).texture = textures.pick_random()
