extends Node2D

## 机关演示关卡 — 4 个区域，难度递进展示全部 12 种机关
## 横向卷轴约 4000×600px

# 预加载所有机关场景
var _spike_scene := preload("res://Scenes/Levels/Components/Traps/SpikeTrap/SpikeTrap.tscn")
var _flame_scene := preload("res://Scenes/Levels/Components/Traps/FlameJet/FlameJet.tscn")
var _platform_scene := preload("res://Scenes/Levels/Components/Traps/FloatingPlatform/FloatingPlatform.tscn")
var _spin_scene := preload("res://Scenes/Levels/Components/Traps/SpinBlade/SpinBlade.tscn")
var _rock_scene := preload("res://Scenes/Levels/Components/Traps/FallingRock/FallingRock.tscn")
var _dart_scene := preload("res://Scenes/Levels/Components/Traps/DartTrap/DartTrap.tscn")
var _conveyor_scene := preload("res://Scenes/Levels/Components/Traps/ConveyorBelt/ConveyorBelt.tscn")
var _crumble_scene := preload("res://Scenes/Levels/Components/Traps/CrumblingPlatform/CrumblingPlatform.tscn")
var _laser_scene := preload("res://Scenes/Levels/Components/Traps/LaserFence/LaserFence.tscn")
var _hammer_scene := preload("res://Scenes/Levels/Components/Traps/SwingHammer/SwingHammer.tscn")
var _launch_scene := preload("res://Scenes/Levels/Components/Traps/LaunchPad/LaunchPad.tscn")
var _saw_scene := preload("res://Scenes/Levels/Components/Traps/SawRail/SawRail.tscn")

## 地面 Y 坐标
const GROUND_Y := 280.0
## 关卡总宽度
const LEVEL_WIDTH := 4200.0

func _ready() -> void:
	_build_ground()
	_build_zone_labels()
	_build_zone1_beginner()
	_build_zone2_intermediate()
	_build_zone3_advanced()
	_build_zone4_ultimate()

# ============ 地形构建 ============

func _build_ground() -> void:
	# 通栏主地面
	_add_platform(0, GROUND_Y, LEVEL_WIDTH, 32)
	# 底部 KillZone
	var killzone := preload("res://Scenes/Levels/Components/KillZone.tscn").instantiate()
	killzone.position = Vector2(LEVEL_WIDTH * 0.5, GROUND_Y + 200)
	add_child(killzone)

func _add_platform(x: float, y: float, w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w * 0.5, y + h * 0.5)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(w, h)
	visual.position = Vector2(-w * 0.5, -h * 0.5)
	visual.color = Color(0.25, 0.2, 0.15, 1.0)
	body.add_child(visual)
	add_child(body)
	return body

func _add_elevated_platform(x: float, y: float, w: float = 80.0) -> StaticBody2D:
	return _add_platform(x, y, w, 8)

# ============ 区域标签 ============

func _build_zone_labels() -> void:
	_add_label(50, GROUND_Y - 200, "区域1: 入门 ★☆☆", Color(0.3, 0.9, 0.5))
	_add_label(950, GROUND_Y - 200, "区域2: 进阶 ★★☆", Color(0.98, 0.8, 0.08))
	_add_label(2050, GROUND_Y - 200, "区域3: 高阶 ★★★", Color(0.98, 0.45, 0.09))
	_add_label(3150, GROUND_Y - 200, "区域4: 终极 ★★★", Color(0.94, 0.27, 0.27))

func _add_label(x: float, y: float, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	add_child(label)

# ============ 区域 1: 入门 (0 ~ 800) ============

func _build_zone1_beginner() -> void:
	# 地刺 ×3 — 慢节奏，间距大
	for i in 3:
		var spike: BaseTrap = _spike_scene.instantiate()
		spike.position = Vector2(150 + i * 120, GROUND_Y)
		spike.safe_time = 2.5  # 慢节奏
		add_child(spike)

	# 浮动平台 ×2 — 需要跳上去
	_add_elevated_platform(580, GROUND_Y - 60, 40)  # 起跳台
	for i in 2:
		var plat: FloatingPlatform = _platform_scene.instantiate()
		plat.position = Vector2(650 + i * 100, GROUND_Y - 80)
		plat.move_offset = Vector2(0, -60)
		plat.move_speed = 30.0  # 慢速
		add_child(plat)

	# 火焰喷射 ×1 — 长间隔
	var flame: BaseTrap = _flame_scene.instantiate()
	flame.position = Vector2(880, GROUND_Y)
	flame.cooldown_duration = 4.0  # 长冷却
	add_child(flame)

# ============ 区域 2: 进阶 (900 ~ 1900) ============

func _build_zone2_intermediate() -> void:
	# 旋转刀刃 ×2 — 不同转速
	var spin1: BaseTrap = _spin_scene.instantiate()
	spin1.position = Vector2(1050, GROUND_Y - 50)
	spin1.rotation_speed = 1.8
	add_child(spin1)

	var spin2: BaseTrap = _spin_scene.instantiate()
	spin2.position = Vector2(1220, GROUND_Y - 50)
	spin2.rotation_speed = 2.5
	spin2.blade_count = 3
	add_child(spin2)

	# 箭矢 + 浮动平台组合
	_add_elevated_platform(1350, GROUND_Y - 40, 40)
	var plat_dart: FloatingPlatform = _platform_scene.instantiate()
	plat_dart.position = Vector2(1430, GROUND_Y - 60)
	plat_dart.move_offset = Vector2(100, 0)  # 水平移动
	plat_dart.move_speed = 40.0
	add_child(plat_dart)

	var dart: BaseTrap = _dart_scene.instantiate()
	dart.position = Vector2(1600, GROUND_Y - 80)
	dart.fire_direction = Vector2.LEFT
	dart.fire_interval = 1.5
	add_child(dart)

	# 传送带 + 地刺组合
	var conveyor: ConveyorBelt = _conveyor_scene.instantiate()
	conveyor.position = Vector2(1750, GROUND_Y - 4)
	conveyor.push_direction = Vector2.RIGHT
	conveyor.push_force = 100.0
	add_child(conveyor)

	# 传送带末端的地刺
	var spike_end: BaseTrap = _spike_scene.instantiate()
	spike_end.position = Vector2(1870, GROUND_Y)
	spike_end.safe_time = 1.5
	add_child(spike_end)

# ============ 区域 3: 高阶 (2000 ~ 3000) ============

func _build_zone3_advanced() -> void:
	# 消失平台连跳 ×5
	for i in 5:
		var crumble: CrumblingPlatform = _crumble_scene.instantiate()
		crumble.position = Vector2(2100 + i * 70, GROUND_Y - 50 - i * 20)
		crumble.shake_time = 0.6
		crumble.respawn_time = 3.0
		add_child(crumble)

	# 落石 + 激光栅栏
	var rock: BaseTrap = _rock_scene.instantiate()
	rock.position = Vector2(2550, GROUND_Y - 128)
	rock.fall_distance = 128.0
	add_child(rock)

	var laser: BaseTrap = _laser_scene.instantiate()
	laser.position = Vector2(2650, GROUND_Y)
	laser.end_point = Vector2(0, -80)
	laser.on_duration = 1.5
	laser.off_duration = 2.0
	add_child(laser)

	var laser2: BaseTrap = _laser_scene.instantiate()
	laser2.position = Vector2(2730, GROUND_Y)
	laser2.end_point = Vector2(0, -80)
	laser2.on_duration = 1.5
	laser2.off_duration = 2.0
	laser2.activation_delay = 1.0  # 与第一个错开
	add_child(laser2)

	# 锤摆走廊 ×3 — 不同相位
	for i in 3:
		var hammer: BaseTrap = _hammer_scene.instantiate()
		hammer.position = Vector2(2850 + i * 80, GROUND_Y - 100)
		add_child(hammer)

# ============ 区域 4: 终极 (3100 ~ 4200) ============

func _build_zone4_ultimate() -> void:
	# 锯齿轨道
	var saw: BaseTrap = _saw_scene.instantiate()
	saw.position = Vector2(3200, GROUND_Y - 20)
	add_child(saw)

	var saw2: BaseTrap = _saw_scene.instantiate()
	saw2.position = Vector2(3350, GROUND_Y - 60)
	saw2.move_speed = 130.0
	add_child(saw2)

	# 弹射器 + 旋转刀刃
	var launch: BaseTrap = _launch_scene.instantiate()
	launch.position = Vector2(3550, GROUND_Y)
	launch.launch_force = 650.0
	add_child(launch)

	var spin_high: BaseTrap = _spin_scene.instantiate()
	spin_high.position = Vector2(3600, GROUND_Y - 120)
	spin_high.rotation_speed = 2.0
	add_child(spin_high)

	# 终点区：混合机关
	var spike_final: BaseTrap = _spike_scene.instantiate()
	spike_final.position = Vector2(3750, GROUND_Y)
	spike_final.safe_time = 1.0
	spike_final.stay_time = 1.0
	add_child(spike_final)

	var flame_final: BaseTrap = _flame_scene.instantiate()
	flame_final.position = Vector2(3850, GROUND_Y)
	flame_final.cooldown_duration = 2.0
	add_child(flame_final)

	var dart_final: BaseTrap = _dart_scene.instantiate()
	dart_final.position = Vector2(4000, GROUND_Y - 60)
	dart_final.fire_direction = Vector2.LEFT
	dart_final.fire_interval = 1.0
	add_child(dart_final)

	# 终点标记
	_add_label(4100, GROUND_Y - 60, "★ GOAL ★", Color(1, 0.85, 0))
