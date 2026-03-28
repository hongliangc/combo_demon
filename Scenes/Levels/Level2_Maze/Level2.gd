extends Node2D

## 关卡2: 迷宫探索 - 地下森林
##
## 目标：收集5把钥匙，解锁迷宫门，找到出口
## 玩法：平台跳跃 + 钥匙解谜 + 机关闯关
##
## 机关随机放置：每次游玩体验不同

@onready var spawn_point: Node2D = $PlayerSpawn
@onready var portal: Portal = $Portal
@onready var level_hud: LevelHUD = $LevelHUD

# ============ 机关场景预加载 ============
var _trap_scenes: Dictionary = {
	"spike": preload("res://Scenes/Levels/Components/Traps/SpikeTrap/SpikeTrap.tscn"),
	"flame": preload("res://Scenes/Levels/Components/Traps/FlameJet/FlameJet.tscn"),
	"platform": preload("res://Scenes/Levels/Components/Traps/FloatingPlatform/FloatingPlatform.tscn"),
	"spin": preload("res://Scenes/Levels/Components/Traps/SpinBlade/SpinBlade.tscn"),
	"rock": preload("res://Scenes/Levels/Components/Traps/FallingRock/FallingRock.tscn"),
	"dart": preload("res://Scenes/Levels/Components/Traps/DartTrap/DartTrap.tscn"),
	"conveyor": preload("res://Scenes/Levels/Components/Traps/ConveyorBelt/ConveyorBelt.tscn"),
	"crumble": preload("res://Scenes/Levels/Components/Traps/CrumblingPlatform/CrumblingPlatform.tscn"),
	"laser": preload("res://Scenes/Levels/Components/Traps/LaserFence/LaserFence.tscn"),
	"hammer": preload("res://Scenes/Levels/Components/Traps/SwingHammer/SwingHammer.tscn"),
	"launch": preload("res://Scenes/Levels/Components/Traps/LaunchPad/LaunchPad.tscn"),
	"saw": preload("res://Scenes/Levels/Components/Traps/SawRail/SawRail.tscn"),
}

## 地面 Y 坐标
const GROUND_Y := 420.0
## 关卡总宽度
const LEVEL_WIDTH := 1300.0
## 机关容器
var _traps_container: Node2D

func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 1
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()
	LevelManager.level_started.emit(1)

	# 构建地形和机关
	_traps_container = Node2D.new()
	_traps_container.name = "Traps"
	add_child(_traps_container)
	_build_terrain()
	_place_random_traps()

	print("Level2: Maze Exploration started! (with traps)")

# ============ 地形构建 ============

func _build_terrain() -> void:
	# 主地面 — 分段，中间留空作跳跃区
	_add_ground(0, GROUND_Y, 250)        # 起点区
	_add_ground(290, GROUND_Y, 150)       # Door1 区域
	_add_ground(480, GROUND_Y, 180)       # 中段
	_add_ground(700, GROUND_Y, 200)       # Door2-3 区域
	_add_ground(940, GROUND_Y, 120)       # 后段
	_add_ground(1100, GROUND_Y, 200)      # 终点区

	# 高台平台 — 放钥匙和制造跳跃挑战
	_add_ground(100, GROUND_Y - 60, 60)   # Key1 附近高台
	_add_ground(320, GROUND_Y - 80, 50)   # Key2 高台
	_add_ground(520, GROUND_Y - 70, 60)   # Key3 高台
	_add_ground(730, GROUND_Y - 90, 50)   # Key4 高台
	_add_ground(960, GROUND_Y - 60, 50)   # Key5 附近高台

	# 底部 KillZone
	var killzone := preload("res://Scenes/Levels/Components/KillZone.tscn").instantiate()
	killzone.position = Vector2(LEVEL_WIDTH * 0.5, GROUND_Y + 150)
	add_child(killzone)

func _add_ground(x: float, y: float, w: float, h: float = 24.0) -> void:
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
	visual.color = Color(0.2, 0.28, 0.15, 1.0)
	body.add_child(visual)
	add_child(body)

# ============ 随机机关放置 ============

func _place_random_traps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# 定义放置区域（避开玩家出生点和门/钥匙位置）
	# 每个区域: [x_start, x_end, 难度权重]
	var zones: Array[Dictionary] = [
		{"x_min": 60.0, "x_max": 230.0, "difficulty": 0},    # 起点区
		{"x_min": 300.0, "x_max": 420.0, "difficulty": 1},   # Door1 后
		{"x_min": 490.0, "x_max": 640.0, "difficulty": 1},   # 中段
		{"x_min": 710.0, "x_max": 880.0, "difficulty": 2},   # Door2-3 区
		{"x_min": 950.0, "x_max": 1050.0, "difficulty": 2},  # 后段
		{"x_min": 1110.0, "x_max": 1250.0, "difficulty": 2}, # 终点前
	]

	# 按难度分类机关
	var easy_traps: Array[String] = ["spike", "flame", "platform"]
	var medium_traps: Array[String] = ["spin", "dart", "conveyor", "launch", "rock"]
	var hard_traps: Array[String] = ["crumble", "laser", "hammer", "saw"]

	for zone in zones:
		var difficulty: int = zone["difficulty"]
		var x_min: float = zone["x_min"]
		var x_max: float = zone["x_max"]
		var zone_width: float = x_max - x_min

		# 根据难度决定放多少个机关
		var trap_count: int = rng.randi_range(1, 2 + difficulty)

		# 均匀分配机关位置
		for i in trap_count:
			var x: float = x_min + (zone_width / (trap_count + 1)) * (i + 1)

			# 根据难度选择机关池
			var pool: Array[String]
			match difficulty:
				0:
					pool = easy_traps
				1:
					# 中等难度：easy + medium
					pool = easy_traps + medium_traps
				2:
					# 高难度：medium + hard
					pool = medium_traps + hard_traps

			var trap_type: String = pool[rng.randi() % pool.size()]
			_spawn_trap(trap_type, x, rng)

func _spawn_trap(trap_type: String, x: float, rng: RandomNumberGenerator) -> void:
	var scene: PackedScene = _trap_scenes[trap_type]
	var trap: Node2D = scene.instantiate()

	match trap_type:
		"spike":
			trap.position = Vector2(x, GROUND_Y)
			trap.safe_time = rng.randf_range(1.5, 3.0)
			trap.stay_time = rng.randf_range(1.0, 2.0)

		"flame":
			trap.position = Vector2(x, GROUND_Y)
			trap.cooldown_duration = rng.randf_range(2.0, 4.0)
			trap.fire_duration = rng.randf_range(1.5, 3.0)

		"platform":
			trap.position = Vector2(x, GROUND_Y - 40)
			trap.move_offset = Vector2(0, -rng.randf_range(40.0, 80.0))
			trap.move_speed = rng.randf_range(25.0, 50.0)

		"spin":
			trap.position = Vector2(x, GROUND_Y - rng.randf_range(30.0, 60.0))
			trap.rotation_speed = rng.randf_range(1.5, 3.0)
			trap.blade_count = rng.randi_range(2, 3)
			trap.blade_length = rng.randf_range(32.0, 48.0)

		"rock":
			trap.position = Vector2(x, GROUND_Y - 128)
			trap.fall_speed = rng.randf_range(300.0, 500.0)
			trap.warning_time = rng.randf_range(0.3, 0.6)

		"dart":
			# 放在稍高位置，向左或向右射击
			trap.position = Vector2(x, GROUND_Y - rng.randf_range(20.0, 50.0))
			trap.fire_direction = Vector2.LEFT if rng.randi() % 2 == 0 else Vector2.RIGHT
			trap.fire_interval = rng.randf_range(1.5, 3.0)
			trap.projectile_speed = rng.randf_range(200.0, 350.0)

		"conveyor":
			trap.position = Vector2(x, GROUND_Y - 4)
			trap.push_direction = Vector2.LEFT if rng.randi() % 2 == 0 else Vector2.RIGHT
			trap.push_force = rng.randf_range(60.0, 120.0)

		"crumble":
			# 消失平台放在空隙上方作为桥
			trap.position = Vector2(x, GROUND_Y - 30)

		"laser":
			trap.position = Vector2(x, GROUND_Y)
			trap.end_point = Vector2(0, -rng.randf_range(60.0, 90.0))
			trap.on_duration = rng.randf_range(1.5, 2.5)
			trap.off_duration = rng.randf_range(2.0, 3.5)

		"hammer":
			trap.position = Vector2(x, GROUND_Y - 100)
			trap.swing_angle = rng.randf_range(45.0, 70.0)
			trap.swing_period = rng.randf_range(2.5, 4.0)

		"launch":
			trap.position = Vector2(x, GROUND_Y)
			trap.launch_force = rng.randf_range(500.0, 700.0)

		"saw":
			trap.position = Vector2(x, GROUND_Y - 20)
			trap.move_speed = rng.randf_range(80.0, 140.0)

	_traps_container.add_child(trap)
