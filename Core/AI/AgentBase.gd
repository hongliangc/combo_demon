class_name AgentBase extends CharacterBody2D

## Unified base: gravity + move_and_slide + facing + skill_set + StateController + Controller wiring.

@export var has_gravity: bool = false
@export var gravity_force: float = 800.0
## 美术原图默认朝向：true=朝右，false=朝左
@export var sprite_faces_right: bool = false

@export_group("Movement")
@export var max_speed: float = 100.0
@export var acceleration_time: float = 0.1

@export_group("Jump")
@export var enable_jump: bool = true
@export var jump_force: float = -400.0
@export var max_jump_count: int = 1
@export var air_jump_force: float = -350.0

signal jump_started
signal jump_apex_reached
signal landed

@onready var state_controller: StateController = $StateController
@onready var controller: BaseController = $Controller
@onready var health_comp: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim: AnimationDriver = get_node_or_null(^"AnimationDriver")
@onready var hitbox: Node2D = get_node_or_null(^"HitBoxComponent")
@onready var pipeline: DamagePipeline = get_node_or_null(^"DamagePipeline")
@onready var status: StatusController = get_node_or_null(^"StatusController")
@onready var buff_controller: BuffController = get_node_or_null(^"BuffController")
var sprite: Node2D

@export var skill_resources: Array[Skill] = []
var skill_set: SkillSet

# 伤害统计 (黑板共享)
var _damage_log: Array[Array] = []
const DAMAGE_WINDOW: float = 3.0
var _hit_clear_timer: float = 0.0
const HIT_CLEAR_DELAY: float = 0.5

# ---- 跳跃 / 移动能力运行时状态 ----
var _is_jumping: bool = false
var _is_falling: bool = false
var _was_on_floor: bool = false
var _current_jump_count: int = 0
## 是否允许 InputController 驱动水平移动 + 跳跃 (受击 / 攻击 / 翻滚 期间置 false)
var can_move: bool = true

func _ready() -> void:
	_auto_find_sprite()
	if anim:
		anim.setup()
	skill_set = SkillSet.new()
	skill_set.setup(skill_resources)
	state_controller.setup(self)
	controller.bind(self, state_controller, skill_set)
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _physics_process(delta: float) -> void:
	# ---- 重力 ----
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity_force * delta
		elif velocity.y > 0:
			velocity.y = 0

	# ---- 跳跃输入(仅 InputController 驱动)----
	if enable_jump and can_move and controller is InputController:
		if (controller as InputController).consume_jump():
			try_jump()

	# ---- 水平移动(仅 InputController 驱动)----
	# AI state 自管 velocity, 不在此被覆盖.
	if can_move and controller is InputController:
		var target_vx: float = (controller as InputController).input_dir * max_speed
		var accel: float = (1.0 / acceleration_time) * max_speed * delta
		velocity.x = move_toward(velocity.x, target_vx, accel)

	move_and_slide()
	_update_jump_state()

	if anim:
		anim.tick(velocity)
	if skill_set:
		skill_set.tick(delta)
	if controller:
		controller.tick(delta)
	_tick_global_cooldown(delta)
	_tick_hit_clear(delta)
	_update_facing()

# ---- Possession 接口 ----
func swap_controller(new_c: BaseController) -> void:
	if controller:
		controller.queue_free()
	add_child(new_c)
	controller = new_c
	new_c.bind(self, state_controller, skill_set)

# ---- 子类钩子 ----
func _setup_blackboard() -> void:
	if controller is AIController:
		var bb: AIBlackboard = (controller as AIController).blackboard
		if bb and health_comp:
			bb.bind_var(&"health", health_comp, &"health")
			bb.bind_var(&"max_health", health_comp, &"max_health")
			bb.set_var(&"global_cooldown", 0.0)
			bb.set_var(&"recently_hit", false)
			bb.set_var(&"damage_recent", 0.0)

func _setup_transitions() -> void:
	pass

func _setup_signals() -> void:
	if pipeline:
		pipeline.react.connect(_on_pipeline_react)
	if status:
		status.legal_actions_changed.connect(_on_legal_actions_changed)
	if health_comp:
		health_comp.died.connect(_on_agent_died)

func _update_facing() -> void:
	if not sprite or not "flip_h" in sprite:
		return
	if abs(velocity.x) > 0.1:
		var moving_right := velocity.x > 0
		sprite.flip_h = moving_right != sprite_faces_right
	if hitbox:
		hitbox.scale.x = -1.0 if sprite.flip_h else 1.0

func _auto_find_sprite() -> void:
	sprite = get_node_or_null(^"AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null(^"Sprite2D")

# ---- 事件处理 ----
func _on_pipeline_react(ctx: DamageContext) -> void:
	if ctx.blocked or ctx.is_heal:
		return
	if ctx.target != self:
		return
	if ctx.tags & DamageTags.DOT:
		return
	var bb: AIBlackboard = _get_blackboard()
	if bb:
		bb.set_var(&"last_damage_amount", ctx.dealt)
		bb.set_var(&"last_attacker_pos", ctx.source_pos)
		bb.set_var(&"recently_hit", true)
	_hit_clear_timer = HIT_CLEAR_DELAY
	var now := Time.get_ticks_msec() / 1000.0
	_damage_log.append([now, ctx.dealt])
	_update_damage_recent()
	if controller:
		controller.dispatch(AIEvents.EV_DAMAGED)

func _on_legal_actions_changed(prev: int, new: int) -> void:
	var lost := prev & ~new
	var gained := new & ~prev
	if (lost & LegalAction.ATTACK) and state_controller and state_controller.current_skill:
		controller.dispatch(AIEvents.EV_INTERRUPTED)
	if (gained & LegalAction.ATTACK) and prev != LegalAction.ALL:
		controller.dispatch(AIEvents.EV_RECOVERED)

func _on_agent_died() -> void:
	if buff_controller:
		buff_controller.clear_all()
	if controller:
		controller.dispatch(AIEvents.EV_DIED)

# ---- 伤害统计 ----
func _update_damage_recent() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cutoff := now - DAMAGE_WINDOW
	while not _damage_log.is_empty() and _damage_log[0][0] < cutoff:
		_damage_log.pop_front()
	var total := 0.0
	for entry in _damage_log:
		total += entry[1]
	var bb: AIBlackboard = _get_blackboard()
	if bb:
		bb.set_var(&"damage_recent", total)

func _tick_hit_clear(delta: float) -> void:
	if _hit_clear_timer > 0:
		_hit_clear_timer -= delta
		if _hit_clear_timer <= 0:
			var bb: AIBlackboard = _get_blackboard()
			if bb:
				bb.set_var(&"recently_hit", false)

func _tick_global_cooldown(delta: float) -> void:
	var bb: AIBlackboard = _get_blackboard()
	if bb == null:
		return
	var gcd: float = bb.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		bb.set_var(&"global_cooldown", maxf(gcd - delta, 0.0))

func _get_blackboard() -> AIBlackboard:
	if controller is AIController:
		return (controller as AIController).blackboard
	return null

# ---- 数据驱动转换表注册 ----
func _register_rules(rules: Array) -> void:
	for r in rules:
		var from: AIState = null if r[0] == "*" else state_controller.get_state(StringName(r[0]))
		var to: AIState = state_controller.get_state(StringName(r[1]))
		if r[0] != "*" and from == null:
			continue
		if to == null:
			continue
		var guard := Callable(self, r[3]) if r[3] != "" else Callable()
		state_controller.add_transition(from, to, StringName(r[2]), guard, r[4])

# ---- 跳跃 / 公共能力 API ----
## 尝试跳跃 (地面跳 or 空中跳). 由 _physics_process / State 调用.
func try_jump() -> void:
	var on_floor := is_on_floor()
	if on_floor:
		velocity.y = jump_force
		_current_jump_count = 1
		_is_jumping = true
		_is_falling = false
		jump_started.emit()
	elif _current_jump_count > 0 and _current_jump_count < max_jump_count:
		velocity.y = air_jump_force
		_current_jump_count += 1
		_is_jumping = true
		_is_falling = false
		jump_started.emit()

## 当前剩余的空中跳跃次数检查 (例如二段跳还可用).
func can_air_jump() -> bool:
	return enable_jump and _current_jump_count > 0 and _current_jump_count < max_jump_count

## 当前已使用的跳跃次数 getter.
func get_jump_count() -> int:
	return _current_jump_count

## 当前朝向符号: +1 = 朝右, -1 = 朝左.
## 由 sprite.flip_h 推导, 与 sprite_faces_right 配合 (与 _update_facing 一致).
func get_facing_sign() -> int:
	if not sprite or not "flip_h" in sprite:
		return 1
	if sprite_faces_right:
		return -1 if sprite.flip_h else 1
	return 1 if sprite.flip_h else -1

## 应用冲刺/翻滚速度: 沿当前朝向给 velocity.x 一个固定值.
func apply_dash_speed(speed: float) -> void:
	velocity.x = float(get_facing_sign()) * speed

func _update_jump_state() -> void:
	var on_floor := is_on_floor()
	# 顶点检测
	if _is_jumping and not _is_falling and velocity.y > 0:
		_is_falling = true
		_is_jumping = false
		jump_apex_reached.emit()
	# 落地检测
	if not _was_on_floor and on_floor:
		_is_jumping = false
		_is_falling = false
		_current_jump_count = 0
		landed.emit()
	_was_on_floor = on_floor
