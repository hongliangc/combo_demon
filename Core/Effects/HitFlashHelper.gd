extends RefCounted
class_name HitFlashHelper

## 通用受击白闪 — HitState fallback 用
## 用法: HitFlashHelper.flash(owner_node)
##       HitFlashHelper.flash(owner_node, 3, 0.05)


static func flash(owner_node: Node, flash_count: int = 3, flash_dur: float = 0.05) -> void:
	var sprite := _find_sprite(owner_node)
	if not sprite:
		return
	var tween := owner_node.create_tween()
	for i in range(flash_count):
		tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), flash_dur)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), flash_dur)


static func _find_sprite(owner_node: Node) -> Node2D:
	var sprite := owner_node.get_node_or_null(^"AnimatedSprite2D") as Node2D
	if not sprite:
		sprite = owner_node.get_node_or_null(^"Sprite2D") as Node2D
	return sprite
