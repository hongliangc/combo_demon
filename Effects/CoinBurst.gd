extends Node2D

## 金币爆散特效
## 金币向上抛洒后受重力下落，落地后淡出消失
## 可复用于宝箱、击杀掉落等场景

@export var coin_amount: int = 10

func _exit_tree() -> void:
	if has_node("GPUParticles2D"):
		$GPUParticles2D.process_material = null

func _ready() -> void:
	if has_node("GPUParticles2D"):
		var particles := $GPUParticles2D as GPUParticles2D
		particles.amount = coin_amount
		particles.emitting = true

	# lifetime(0.8) + 余量后自动销毁
	await get_tree().create_timer(1.5).timeout
	queue_free()
