extends AIState

## Stock Death — 播放死亡动画后释放 owner

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if owner_node:
		owner_node.set_physics_process(false)
		var col: CollisionShape2D = owner_node.get_node_or_null(^"CollisionShape2D")
		if col:
			col.set_deferred(&"disabled", true)

	if agent.anim.has_action(&"death"):
		agent.anim.play_action(&"death")
		await agent.anim.action_finished
	else:
		await _play_fallback_death()

	if is_instance_valid(owner_node):
		owner_node.queue_free()


## 白闪 fallback
func _play_fallback_death() -> void:
	var sprite = owner_node.get_node_or_null(^"AnimatedSprite2D")
	if not sprite:
		sprite = owner_node.get_node_or_null(^"Sprite2D")
	if not sprite:
		await get_tree().create_timer(0.5).timeout
		return

	var tween = get_tree().create_tween()

	# 白闪3次（每次0.1秒）
	for i in range(3):
		tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)  # 变白
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)    # 恢复

	# 最后淡出消失
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished
