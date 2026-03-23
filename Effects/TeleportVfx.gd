extends GPUParticles2D

## 传送特效 - 自动清理 process_material 防止纹理 RID 泄漏

func _exit_tree() -> void:
	process_material = null
