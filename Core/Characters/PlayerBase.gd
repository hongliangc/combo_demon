extends BaseCharacter
class_name PlayerBase

## 所有玩家角色的基类
## 提供：重力系统、组件引用、状态机协调变量、死亡处理
## 动画状态切换由 PlayerStateMachine 的各状态脚本控制

# ============ 物理配置 ============
@export_group("Physics")
@export var has_gravity := true
@export var gravity := 980.0

# ============ 组件引用 ============
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var skill_manager: SkillManager = $SkillManager

# ============ 状态机通信 ============
## 待执行的战斗技能名（由 Ground/Air 状态设置，Combat 状态读取）
var pending_combat_skill: String = ""

func _on_character_ready() -> void:
	# 落地灰尘特效
	if movement_component:
		movement_component.landed.connect(_on_landed)
	_on_player_ready()

func _physics_process(delta: float) -> void:
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif velocity.y > 0:
			velocity.y = 0

# ============ 信号回调 ============
func _on_landed() -> void:
	spawn_landing_dust()

# ============ 委托 API（动画 method track 调用）============
func switch_to_physical() -> void:
	if combat_component:
		combat_component.switch_to_physical()

func switch_to_knockup() -> void:
	if combat_component:
		combat_component.switch_to_knockup()

func switch_to_special_attack() -> void:
	if combat_component:
		combat_component.switch_to_special_attack()

# ============ 死亡处理 ============
func _handle_death() -> void:
	visible = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	_show_game_over()

func _show_game_over() -> void:
	var game_over_scene = load("res://Scenes/UI/Screens/GameOver/GameOverUI.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		get_tree().root.add_child(game_over_ui)

# ============ 特效 ============
func spawn_landing_dust() -> void:
	var dust_scene = preload("res://Effects/LandingDust.tscn")
	if dust_scene:
		var dust = dust_scene.instantiate()
		get_parent().add_child(dust)
		dust.global_position = global_position + Vector2(0, 15)

# ============ 子类钩子 ============
func _on_player_ready() -> void:
	pass
