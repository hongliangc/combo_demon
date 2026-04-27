class_name AgentAIBase extends CharacterBody2D

## AI 角色统一基类
## 职责：gravity + move_and_slide + facing + skill_set + AI 信号接线 + _register_rules

@export var has_gravity: bool = false
@export var gravity_force: float = 800.0
## 美术原图默认朝向：true=朝右，false=朝左
@export var sprite_faces_right: bool = false

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Node2D = get_node_or_null(^"HitBoxComponent")
@onready var pipeline: DamagePipeline = get_node_or_null(^"DamagePipeline")
@onready var status: StatusController = get_node_or_null(^"StatusController")
@onready var buff_controller: BuffController = get_node_or_null(^"BuffController")
var sprite: Node2D

var skill_set: SkillSet

# ---- 伤害统计 ----
var _damage_log: Array[Array] = []   # [[timestamp, amount], ...]
const DAMAGE_WINDOW: float = 3.0
var _hit_clear_timer: float = 0.0
const HIT_CLEAR_DELAY: float = 0.5

@onready var _floor_cast_l: RayCast2D = get_node_or_null(^"FloorCastL")
@onready var _floor_cast_r: RayCast2D = get_node_or_null(^"FloorCastR")
@onready var _wall_cast_l: RayCast2D = get_node_or_null(^"WallCastL")
@onready var _wall_cast_r: RayCast2D = get_node_or_null(^"WallCastR")

func _ready() -> void:
	_auto_find_sprite()
	_setup_skill_set()
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _physics_process(delta: float) -> void:
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity_force * delta
		elif velocity.y > 0:
			velocity.y = 0
	move_and_slide()
	if skill_set:
		skill_set.tick(delta)
	_tick_global_cooldown(delta)
	_tick_hit_clear(delta)
	_update_facing()

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

# ---- 平台移动助手 ----
## 判断 dir 方向(-1/+1)上是否可安全移动:前方有地面 + 无墙
## 未配置 RayCast 时视为可移动(兼容非平台敌人)
func can_move_dir(dir: int) -> bool:
	if dir == 0:
		return true
	if dir > 0:
		var has_floor := _floor_cast_r == null or _floor_cast_r.is_colliding()
		var hit_wall := _wall_cast_r != null and _wall_cast_r.is_colliding()
		return has_floor and not hit_wall
	else:
		var has_floor := _floor_cast_l == null or _floor_cast_l.is_colliding()
		var hit_wall := _wall_cast_l != null and _wall_cast_l.is_colliding()
		return has_floor and not hit_wall

# ---- 子类重写 ----
func _setup_skill_set() -> void:
	skill_set = SkillSet.new()

func _setup_blackboard() -> void:
	var bb := ai.blackboard
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

# ---- 事件处理 ----
func _on_pipeline_react(ctx: DamageContext) -> void:
	if ctx.blocked or ctx.is_heal:
		return
	if ctx.target != self:
		return
	if ctx.tags & DamageTags.DOT:
		return  # DoT 不进 HitState
	var bb := ai.blackboard
	bb.set_var(&"last_damage_amount", ctx.dealt)
	bb.set_var(&"last_attacker_pos", ctx.source_pos)
	bb.set_var(&"recently_hit", true)
	_hit_clear_timer = HIT_CLEAR_DELAY
	var now := Time.get_ticks_msec() / 1000.0
	_damage_log.append([now, ctx.dealt])
	_update_damage_recent()
	ai.dispatch(AIEvents.EV_DAMAGED)

func _on_legal_actions_changed(prev: int, new: int) -> void:
	var lost := prev & ~new
	var gained := new & ~prev
	if (lost & LegalAction.ATTACK) and ai.current_skill:
		ai.dispatch(AIEvents.EV_INTERRUPTED)
	if (gained & LegalAction.ATTACK) and prev != LegalAction.ALL:
		ai.dispatch(AIEvents.EV_RECOVERED)

func _on_agent_died() -> void:
	if buff_controller:
		buff_controller.clear_all()
	ai.dispatch(AIEvents.EV_DIED)

# ---- 伤害统计 ----
func _update_damage_recent() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cutoff := now - DAMAGE_WINDOW
	while not _damage_log.is_empty() and _damage_log[0][0] < cutoff:
		_damage_log.pop_front()
	var total := 0.0
	for entry in _damage_log:
		total += entry[1]
	ai.blackboard.set_var(&"damage_recent", total)

func _tick_hit_clear(delta: float) -> void:
	if _hit_clear_timer > 0:
		_hit_clear_timer -= delta
		if _hit_clear_timer <= 0:
			ai.blackboard.set_var(&"recently_hit", false)

func _tick_global_cooldown(delta: float) -> void:
	var gcd: float = ai.blackboard.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		ai.blackboard.set_var(&"global_cooldown", maxf(gcd - delta, 0.0))

# ---- 数据驱动转换表注册 ----
## rules 格式: [[from, to, event, guard_method, priority], ...]
## from="*" 表示 ANYSTATE; guard_method="" 表示无条件
## 自动跳过 StateMachine 中不存在的状态
func _register_rules(rules: Array) -> void:
	for r in rules:
		var from: AIState = null if r[0] == "*" else ai.get_state(StringName(r[0]))
		var to: AIState = ai.get_state(StringName(r[1]))
		if r[0] != "*" and from == null:
			continue
		if to == null:
			continue
		var guard := Callable(self, r[3]) if r[3] != "" else Callable()
		ai.add_transition(from, to, StringName(r[2]), guard, r[4])
