extends Node
class_name CombatComponent

## 自治战斗组件 - 参考 BaseState 设计模式
## 自动处理技能输入、伤害类型切换、技能执行
## 子类可重载 process_skill_input() 等方法实现自定义逻辑

# ============ 信号 ============
## 伤害类型切换时发出
signal damage_type_changed(new_damage: Damage)
## 技能开始执行
signal skill_started(skill_name: String)
## 技能执行完成
signal skill_finished(skill_name: String)

# ============ 配置参数 ============
@export_group("Damage")
## 可用的伤害类型列表
@export var damage_types: Array[Damage] = []

@export_group("Skills")
## 是否自动处理技能输入
@export var auto_process_input: bool = true

## 技能配置字典（技能名 -> 配置）
## 格式: { "skill_name": { "input_action": "", "sound_effect": Resource, "time_scale": 1.0 } }
var skill_configs: Dictionary = {}

# ============ 运行时变量 ============
## 当前使用的伤害类型
var current_damage: Damage = null
## 当前伤害类型索引
var current_damage_index: int = 0

# ============ 节点引用（组件间通信）============
var owner_node: Node = null
var animation_component: AnimationComponent = null
var movement_component: MovementComponent = null

# ============ 生命周期 ============
func _ready() -> void:
	# 依赖注入：自动获取 owner 节点
	owner_node = get_parent()

	# 查找其他组件（延迟到下一帧，确保所有组件都已 ready）
	call_deferred("_find_components")

	# 初始化为第一个伤害类型
	if damage_types.size() > 0:
		switch_to_damage_type(0)

	# 初始化默认技能配置
	_setup_default_skills()

func _process(_delta: float) -> void:
	# 自动处理技能输入
	if auto_process_input:
		process_skill_input()

# ============ 初始化方法 ============
func _find_components() -> void:
	if not owner_node:
		return

	# 查找 AnimationComponent
	animation_component = owner_node.get_node_or_null("AnimationComponent")

	# 查找 MovementComponent
	movement_component = owner_node.get_node_or_null("MovementComponent")

## 设置默认技能配置（子类可重载）
func _setup_default_skills() -> void:
	# 普通攻击组合技（使用project.godot中定义的输入动作）
	add_skill("atk_1", {
		"input_action": "atk_1",  # X键
		"sound_effect": null,
		"time_scale": 2.0,
		"disable_movement": true
	})

	add_skill("atk_2", {
		"input_action": "atk_2",  # W键
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2.0,
		"disable_movement": true
	})

	add_skill("atk_3", {
		"input_action": "atk_3",  # E键
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2.0,
		"disable_movement": true
	})

	# 翻滚技能
	add_skill("roll", {
		"input_action": "roll",  # R键
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2.0,
		"disable_movement": false,  # 翻滚不禁用移动（内部会设置速度）
		"roll_speed": 400
	})

	# 特殊攻击（由 SkillManager 处理）
	add_skill("atk_sp", {
		"input_action": "atk_sp",  # V键
		"sound_effect": preload("res://Sound/face_the_wind.mp3"),
		"time_scale": 2.0,
		"needs_preparation": true,  # 需要 SkillManager 预处理
		"disable_movement": false  # 移动由 SkillManager 控制
	})

# ============ 核心方法（子类可重载）============
## 处理技能输入（子类可重载）
func process_skill_input() -> void:
	if not movement_component or not movement_component.can_move:
		return

	# 遍历所有技能配置，检测输入
	for skill_name in skill_configs.keys():
		var config = skill_configs[skill_name]
		var input_action = config.get("input_action", "")

		if input_action != "" and Input.is_action_just_pressed(input_action):
			execute_skill(skill_name)
			break  # 一帧只执行一个技能

## 执行技能
func execute_skill(skill_name: String) -> void:
	var config = skill_configs.get(skill_name)
	if not config:
		push_warning("CombatComponent: 未找到技能配置: %s" % skill_name)
		return

	# 发射信号（特殊技能由 SkillManager 通过监听此信号接管）
	skill_started.emit(skill_name)

	# 特殊技能只发信号，由 SkillManager 完全接管
	if config.get("needs_preparation", false):
		DebugConfig.debug("请求特殊技能: %s (委托给 SkillManager)" % skill_name, "", "combat")
		return

	# 普通技能直接执行
	_execute_normal_skill(skill_name, config)

## 执行普通技能（内部方法）
func _execute_normal_skill(skill_name: String, config: Dictionary) -> void:
	# 禁用移动（如果配置要求）
	if config.get("disable_movement", false) and movement_component:
		movement_component.can_move = false

	# 特殊处理：翻滚技能设置速度
	if skill_name == "roll" and movement_component:
		var roll_speed = config.get("roll_speed", 400)
		movement_component.apply_dash_speed(roll_speed)

	# 播放动画
	if animation_component:
		var time_scale = config.get("time_scale", 1.0)
		animation_component.play(skill_name, time_scale)

		# 连接动画完成信号（单次）
		if not animation_component.is_connected("animation_finished", _on_skill_animation_finished):
			animation_component.animation_finished.connect(_on_skill_animation_finished)

	# 播放音效
	var sound_effect = config.get("sound_effect")
	if sound_effect:
		SoundManager.play_sound(sound_effect)

	DebugConfig.debug("执行技能: %s" % skill_name, "", "combat")

# ============ 回调方法 ============
func _on_skill_animation_finished(animation_name: String) -> void:
	# 恢复移动能力
	if movement_component:
		movement_component.can_move = true

	# 发射技能完成信号
	skill_finished.emit(animation_name)

	DebugConfig.debug("技能完成: %s" % animation_name, "", "combat")

# ============ 公共 API ============
## 添加/更新技能配置
func add_skill(skill_name: String, config: Dictionary) -> void:
	skill_configs[skill_name] = config

## 移除技能配置
func remove_skill(skill_name: String) -> void:
	skill_configs.erase(skill_name)

## 获取技能配置
func get_skill_config(skill_name: String) -> Dictionary:
	return skill_configs.get(skill_name, {})

## 切换到指定索引的伤害类型
func switch_to_damage_type(index: int) -> void:
	if index < 0 or index >= damage_types.size():
		push_warning("CombatComponent: 无效的伤害类型索引 %d" % index)
		return

	current_damage_index = index
	current_damage = damage_types[index]
	damage_type_changed.emit(current_damage)

	var damage_desc = "null"
	if current_damage:
		damage_desc = "伤害:%.1f 特效:%s" % [current_damage.amount, current_damage.get_effects_description()]
	DebugConfig.debug("切换伤害类型: [%d] %s" % [index, damage_desc], "", "combat")

## 切换到物理伤害（索引0）
func switch_to_physical() -> void:
	switch_to_damage_type(0)

## 切换到击飞伤害（索引1）
func switch_to_knockup() -> void:
	switch_to_damage_type(1)

## 切换到特殊攻击伤害（索引2）
func switch_to_special_attack() -> void:
	if damage_types.size() > 2:
		switch_to_damage_type(2)
	else:
		push_warning("CombatComponent: 没有配置特殊攻击伤害类型")

## 获取当前伤害类型
func get_current_damage() -> Damage:
	return current_damage
