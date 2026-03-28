extends RefCounted
class_name VfxHelper

## 一次性粒子特效工具（静态方法）
## 在指定位置生成 CPUParticles2D 爆发特效并自动清理
## 用法: VfxHelper.spawn_burst(parent, pos, "res://Assets/Art/FX/Particle/Spark.png", 8, Color.WHITE, 80.0)


## 生成粒子爆发特效
## parent : 添加到的父节点（通常为关卡根节点）
## pos    : 全局坐标
## path   : 粒子贴图 res:// 路径
## count  : 粒子数量（默认 8）
## color  : 粒子调制颜色（默认白色）
## speed  : 散射速度（默认 80px/s）
static func spawn_burst(
		parent: Node,
		pos: Vector2,
		path: String,
		count: int = 8,
		color: Color = Color.WHITE,
		speed: float = 80.0
) -> void:
	var texture := load(path) as Texture2D
	if not texture:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.z_index = 10
	p.texture = texture
	p.amount = count
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed * 1.4
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.color = color
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(0.9).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.queue_free()
	)


## 在目标位置生成传送特效（使用 TeleportVfx.tscn，自动清理）
static func spawn_teleport(parent: Node, pos: Vector2) -> void:
	const TELEPORT_SCENE := "res://Effects/TeleportVfx.tscn"
	var scene := load(TELEPORT_SCENE) as PackedScene
	if not scene:
		return
	var vfx: GPUParticles2D = scene.instantiate()
	vfx.global_position = pos
	parent.add_child(vfx)
	vfx.emitting = true
	parent.get_tree().create_timer(1.5).timeout.connect(
		func() -> void:
			if is_instance_valid(vfx):
				vfx.queue_free()
	)
