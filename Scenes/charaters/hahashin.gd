extends CharacterBody2D
class_name Hahashin

# 预加载血条场景
const HealthBarScene = preload("res://Scenes/UI/HealthBar.tscn")

var alive: bool = true
var last_face_direction:Vector2 = Vector2.RIGHT
var input_direction: Vector2 = Vector2.RIGHT

@export_group("Speed")
@export var max_speed: float = 100

@export_group("Health")
@export var max_health:float
@export var health:float

@export_group("Damage")
@export var damage_types : Array[Damage]
@export var current_damage: Damage


var can_move: bool = true

# 血条引用
var health_bar = null

func _ready() -> void:
	# 初始化为默认物理伤害
	if damage_types.size() > 0:
		current_damage = damage_types[0]

	# 连接 Hurtbox 的受伤信号
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox.has_signal("damaged"):
		hurtbox.damaged.connect(on_damaged)

	# 初始化血条
	setup_health_bar()

## 设置血条UI
func setup_health_bar() -> void:
	# 实例化血条
	if HealthBarScene:
		health_bar = HealthBarScene.instantiate()
		add_child(health_bar)

		# 设置血条位置（在角色上方）
		health_bar.position = Vector2(-100, -80)

		# 初始化血条数值
		health_bar.set_max_value(max_health)
		health_bar.set_value(health)
		health_bar.bar_color = Color(0.2, 0.8, 0.2)  # 绿色
		health_bar.show_text = true

## 更新血条显示
func update_health_bar() -> void:
	if health_bar:
		health_bar.tween_to_value(health, 0.2)

# 接收伤害处理
func on_damaged(damage: Damage, attacker_position: Vector2) -> void:
	if !alive:
		return

	# 扣除生命值
	var damage_amount = damage.amount
	health -= damage_amount

	# 更新血条
	update_health_bar()

	# 显示伤害数字
	var damage_anchor = get_node_or_null("DamageNumbersAnchor")
	if damage_anchor:
		DamageNumbers.display_number(damage_amount, damage_anchor.global_position)

	# 应用特效（击退、击飞等）- 使用通用特效系统
	for effect in damage.effects:
		if effect != null:
			# 检查是否有 apply_effect 方法（鸭子类型，支持通用特效）
			if effect.has_method("apply_effect"):
				effect.apply_effect(self, attacker_position)
			# 兼容旧的特效属性
			elif "knockback_force" in effect:
				var direction = (global_position - attacker_position).normalized()
				velocity = direction * effect.knockback_force
			elif "launch_force" in effect:
				velocity.y = -effect.launch_force

	print("Player 受到伤害: ", damage_amount, " 剩余生命: ", health)

	# 检查死亡
	if health <= 0:
		die()

# 获取用户输入，控制方向
func _process(delta: float) -> void:
	if alive:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

# 控制移动
func _physics_process(delta: float) -> void:
	if alive:
		# 根据输入更新速度
		if can_move:
			velocity = input_direction * max_speed

		# 移动状态才有方向
		if velocity:
			last_face_direction = velocity.normalized()

		move_and_slide()

func switch_to_physical() -> void:
	current_damage = damage_types[0]

func switch_to_knockup() -> void:
	current_damage = damage_types[1]

## 玩家死亡处理
func die() -> void:
	if !alive:
		return

	alive = false
	print("Player 死亡!")

	# 隐藏玩家
	visible = false

	# 禁用碰撞
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# 显示游戏结束UI
	show_game_over_ui()

## 显示游戏结束UI
func show_game_over_ui() -> void:
	# 加载游戏结束UI场景
	var game_over_scene = load("res://Scenes/UI/GameOverUI.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		get_tree().root.add_child(game_over_ui)
	else:
		push_error("无法加载 GameOverUI 场景")

## 调试打印玩家状态信息
func debug_print() -> void:
	print("========== Player 状态信息 ==========")
	print("存活状态: ", alive)
	print("生命值: ", health, "/", max_health)
	print("可移动: ", can_move)
	print("速度: ", velocity, " (最大速度: ", max_speed, ")")
	print("面对方向: ", last_face_direction)
	print("输入方向: ", input_direction)
	if current_damage:
		current_damage.debug_print()
	else:
		print("当前伤害: null")
	print("====================================")
