extends BaseCharacter
class_name EnemyBase

## 所有标准敌人的基类
## 在 BaseCharacter 基础上增加：AI参数、状态机集成、精灵管理、死亡动画
##
## 使用方法:
##   1. 继承此类或使用 EnemyBase.tscn 模板场景
##   2. 在 Inspector 中配置 AI 参数
##   3. 重写 _on_enemy_ready() 进行敌人特定初始化
##   4. 精灵自动查找 AnimatedSprite2D（优先）或 Sprite2D
##
## 节点要求:
##   必需: HealthComponent, HurtBoxComponent, AnimationPlayer
##   可选: AnimationTree, EnemyStateMachine, HealthBar, DamageNumbersAnchor

# ============ 行为配置（优先于散落 @export）============
@export var behavior_config: BehaviorConfig = null

# ============ AI 配置参数 ============
@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_abandon_distance := 200.0
@export var attack_activation_radius := 25.0
@export var chase_speed := 75

@export_group("Physics")
@export var has_gravity := false
@export var gravity := 800.0

# ============ 运行时变量 ============
var stunned: bool = false
var can_move: bool = true  # 用于技能聚集时强制停止移动

# ============ 节点引用 ============
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

## 精灵节点（自动查找 Sprite2D 或 AnimatedSprite2D）
var sprite: Node2D

func _on_character_ready() -> void:
	assert(anim_player != null, "%s: missing AnimationPlayer child node" % name)
	assert(anim_tree != null, "%s: missing AnimationTree child node" % name)

	# 应用行为配置（如果有）
	if behavior_config:
		_apply_behavior_config()

	# 查找精灵节点
	_find_sprite()

	# 子类钩子
	_on_enemy_ready()

func _physics_process(delta: float) -> void:
	# 应用重力（如果启用）
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif velocity.y > 0:
			velocity.y = 0

	# 自动翻转精灵朝向（仅在 AnimationTree 未激活时）
	# BlendSpace2D 已通过 left_walk/right_walk 处理方向，不需要额外 flip_h
	if not (anim_tree and anim_tree.active):
		_update_sprite_facing()

## 白闪 fallback（重写 BaseCharacter._play_fallback_death）
func _play_fallback_death() -> void:
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

# ============ 精灵管理 ============
## 自动查找精灵节点（优先 AnimatedSprite2D，其次 Sprite2D）
func _find_sprite() -> void:
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null("Sprite2D")

## 根据移动方向翻转精灵（子类可重写）
func _update_sprite_facing() -> void:
	if not sprite or not alive or velocity.x == 0:
		return
	if "flip_h" in sprite:
		sprite.flip_h = velocity.x < 0

# ============ 数据驱动 ============
## 从 BehaviorConfig 应用配置到本地属性（向后兼容）
func _apply_behavior_config() -> void:
	if not behavior_config:
		return
	max_health = behavior_config.max_health
	health = behavior_config.health
	min_wander_time = behavior_config.min_wander_time
	max_wander_time = behavior_config.max_wander_time
	wander_speed = behavior_config.wander_speed
	detection_radius = behavior_config.detection_radius
	chase_abandon_distance = behavior_config.chase_abandon_distance
	attack_activation_radius = behavior_config.attack_activation_radius
	chase_speed = int(behavior_config.chase_speed)
	has_gravity = behavior_config.has_gravity
	gravity = behavior_config.gravity
	# 同步到 HealthComponent
	if health_component:
		health_component.max_health = max_health
		health_component.health = health

# ============ 子类钩子 ============
## 敌人特定初始化（在 _on_character_ready 末尾调用）
func _on_enemy_ready() -> void:
	pass
