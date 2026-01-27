extends CharacterBody2D
class_name Hahashin

## Player 类 - 自治组件架构
## 组件自动运行，Player 只负责组件协调和生命周期管理
##
## 架构设计参考状态机模式：
## - 组件完全自治，自动运行 _process/_physics_process
## - 组件间通过信号解耦
## - Player 作为组件容器，提供最小化的协调逻辑

# ============ 组件引用 ============
@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var skill_manager: SkillManager = $SkillManager

# ============ 核心状态 ============
var alive: bool = true

func _ready() -> void:
	# 连接组件信号
	_connect_component_signals()

	# 连接 Hurtbox 的受伤信号到 HealthComponent
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox.has_signal("damaged"):
		hurtbox.damaged.connect(health_component.take_damage)

## 连接组件信号
func _connect_component_signals() -> void:
	# 健康组件信号
	if health_component:
		health_component.died.connect(_on_died)

	# 移动组件信号（可选，用于调试）
	if movement_component:
		movement_component.movement_ability_changed.connect(_on_movement_ability_changed)

# ============ 组件生命周期由组件自己管理 ============
# MovementComponent 自动处理 _process 和 _physics_process
# CombatComponent 自动处理技能输入
# SkillManager 自动处理特殊攻击
# Player 不需要手动调用组件方法

# ============ 公共 API（委托给组件） ============
## 伤害类型切换（委托给 CombatComponent）
func switch_to_physical() -> void:
	if combat_component:
		combat_component.switch_to_physical()

func switch_to_knockup() -> void:
	if combat_component:
		combat_component.switch_to_knockup()

func switch_to_special_attack() -> void:
	if combat_component:
		combat_component.switch_to_special_attack()

## 特殊攻击相关（委托给 SkillManager）
## 注意：这些方法保留用于外部兼容，但 SkillManager 已自动处理整个流程
func perform_special_attack() -> void:
	if skill_manager:
		skill_manager.perform_special_attack()

# ============ 信号处理 ============
func _on_died() -> void:
	alive = false

	# 隐藏玩家
	visible = false

	# 禁用碰撞
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# 显示游戏结束UI
	show_game_over_ui()

func _on_movement_ability_changed(can_move_now: bool) -> void:
	# 可选：在这里添加移动能力变化时的逻辑
	DebugConfig.debug("Player 移动能力变化: %s" % can_move_now, "", "player")

## 显示游戏结束UI
func show_game_over_ui() -> void:
	# 加载游戏结束UI场景
	var game_over_scene = load("res://Scenes/UI/GameOverUI.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		get_tree().root.add_child(game_over_ui)
	else:
		push_error("无法加载 GameOverUI 场景")

# ============ 调试工具 ============
## 调试打印玩家状态信息
func debug_print() -> void:
	print("========== Player 状态信息（自治组件架构） ==========")
	print("存活状态: ", alive)

	if health_component:
		print("生命值: ", health_component.health, "/", health_component.max_health)

	if movement_component:
		print("可移动: ", movement_component.can_move)
		print("速度: ", velocity, " (最大速度: ", movement_component.max_speed, ")")
		print("面对方向: ", movement_component.last_face_direction)
		print("输入方向: ", movement_component.input_direction)

	if combat_component and combat_component.current_damage:
		combat_component.current_damage.debug_print()
	else:
		print("当前伤害: null")

	if animation_component:
		print("当前动画: ", animation_component.get_current_state())

	print("====================================")
