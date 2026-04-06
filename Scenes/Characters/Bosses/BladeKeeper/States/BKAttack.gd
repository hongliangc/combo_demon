extends BossState

## BladeKeeper 统一攻击状态 — combo/jump/普通/特殊
## 内部步骤机驱动，所有攻击模式共用此状态

const NORMAL_ATKS := ["atk_1", "atk_2", "atk_3"]

## sp_atk 在 combo 中的触发概率（按阶段）
const SP_ATK_CHANCE := {
	BossBase.Phase.PHASE_1: 0.1,
	BossBase.Phase.PHASE_2: 0.3,
	BossBase.Phase.PHASE_3: 0.6,
}

## 落地后接地面 combo 的概率
const GROUND_COMBO_AFTER_JUMP_CHANCE := 0.5

## air_atk 触发概率
const AIR_ATK_CHANCE := 0.6

## dodge 后跳参数
@export var dodge_speed := 300.0
@export var dodge_duration := 0.5
@export var dodge_projectile_delay := 0.25  ## 空中投匕首时机

## jump 突进参数
@export var jump_approach_speed := 350.0

enum Step {
	NONE,
	ATK,           ## 普通攻击（随机 atk_1/2/3）
	SP_ATK,        ## 特殊攻击
	DODGE_START,   ## 后空翻起跳 + 放陷阱
	DODGE_AIR,     ## 空中投匕首
	DODGE_LAND,    ## 落地
	JUMP_UP,       ## 跳跃上升 + 靠近
	AIR_ATK,       ## 空中攻击
	JUMP_DOWN,     ## 下落
}

var _current_step: Step = Step.NONE
var _mode: String = "attack"
var _anim_tree_ref: AnimationTree
var _dodge_timer: SceneTreeTimer
var _jump_reached := false  ## jump_up 是否已到达 player 附近


func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false


func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	# 统一初始化：停止移动 + 禁止移动 + 面朝玩家
	boss.velocity = Vector2.ZERO
	boss.can_move = false
	_face_player(boss)

	_anim_tree_ref = get_anim_tree()
	_current_step = Step.NONE
	_jump_reached = false

	# 从 last_picked_entry 读取 mode
	var mgr := get_attack_manager()
	_mode = mgr.last_picked_entry.get("mode", "attack") if mgr else "attack"

	# 连接动画完成信号
	if _anim_tree_ref and not _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.connect(_on_animation_finished)

	# 根据 mode 启动第一步
	match _mode:
		"attack":
			_start_step(Step.ATK)
		"combo":
			_start_step(Step.ATK)
		"special":
			_start_step(Step.SP_ATK)
		"jump":
			_start_step(Step.JUMP_UP)
		_:
			_start_step(Step.ATK)


func physics_process_state(_delta: float) -> void:
	# jump_up 阶段：向 player 移动
	if _current_step == Step.JUMP_UP and not _jump_reached:
		var boss := get_boss()
		if boss and target_node:
			var direction: Vector2 = (target_node.global_position - boss.global_position).normalized()
			boss.velocity = direction * jump_approach_speed
			var distance := boss.global_position.distance_to(target_node.global_position)
			if distance <= boss.attack_range:
				_jump_reached = true
				boss.velocity = Vector2.ZERO
	# DODGE 阶段：velocity 在 _start_dodge_sequence() 中设置，由 BossBase.move_and_slide 处理


func _on_animation_finished(anim_name: StringName) -> void:
	match _current_step:
		Step.ATK:
			# 检查当前播放的动画是否是我们的攻击动画
			if str(anim_name) not in NORMAL_ATKS:
				return
			_on_atk_finished()
		Step.SP_ATK:
			if anim_name != &"sp_atk":
				return
			_on_sp_atk_finished()
		Step.JUMP_UP:
			if anim_name != &"jump_up":
				return
			_on_jump_up_finished()
		Step.AIR_ATK:
			if anim_name != &"air_atk":
				return
			_on_air_atk_finished()
		Step.JUMP_DOWN:
			if anim_name != &"jump_down":
				return
			_on_jump_down_finished()


## ============ 步骤启动 ============

func _start_step(step: Step) -> void:
	_current_step = step
	var boss := get_boss()
	match step:
		Step.ATK:
			var atk_name: String = NORMAL_ATKS[randi() % NORMAL_ATKS.size()]
			enter_control_state(atk_name)
			DebugConfig.debug("[BKAttack] ATK: %s" % atk_name, "", "combat")
		Step.SP_ATK:
			enter_control_state("sp_atk")
			DebugConfig.debug("[BKAttack] SP_ATK", "", "combat")
		Step.JUMP_UP:
			_jump_reached = false
			enter_control_state("jump_up")
			DebugConfig.debug("[BKAttack] JUMP_UP", "", "combat")
		Step.AIR_ATK:
			if boss:
				boss.velocity = Vector2.ZERO
			enter_control_state("air_atk")
			DebugConfig.debug("[BKAttack] AIR_ATK", "", "combat")
		Step.JUMP_DOWN:
			if boss:
				boss.velocity = Vector2.ZERO
			enter_control_state("jump_down")
			DebugConfig.debug("[BKAttack] JUMP_DOWN", "", "combat")


## ============ 步骤完成处理 ============

func _on_atk_finished() -> void:
	match _mode:
		"combo":
			var boss := get_boss()
			var chance: float = SP_ATK_CHANCE.get(boss.current_phase, 0.1) if boss else 0.1
			if randf() < chance:
				_start_step(Step.SP_ATK)
			else:
				_start_dodge_sequence()
		_:
			_finish_attack()


func _on_sp_atk_finished() -> void:
	match _mode:
		"combo":
			_start_dodge_sequence()
		_:
			_finish_attack()


func _on_jump_up_finished() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	# 概率触发空中攻击
	if randf() < AIR_ATK_CHANCE:
		_start_step(Step.AIR_ATK)
	else:
		_start_step(Step.JUMP_DOWN)


func _on_air_atk_finished() -> void:
	_start_step(Step.JUMP_DOWN)


func _on_jump_down_finished() -> void:
	var boss := get_boss()
	if boss:
		_face_player(boss)
	if randf() < GROUND_COMBO_AFTER_JUMP_CHANCE:
		_mode = "combo"
		_start_step(Step.ATK)
	else:
		_start_dodge_sequence()


## ============ DODGE 三阶段序列 ============

func _start_dodge_sequence() -> void:
	_current_step = Step.DODGE_START
	var boss := get_boss()
	if not boss:
		_force_exit_to_chase()
		return
	var dodge_dir := Vector2.RIGHT
	if target_node:
		dodge_dir = (boss.global_position - target_node.global_position).normalized()
	boss.velocity = dodge_dir * dodge_speed
	var mgr := get_attack_manager()
	if mgr:
		mgr.place_trap(boss.global_position)
	enter_control_state("trap_cast")
	DebugConfig.debug("[BKAttack] DODGE_START (trap placed)", "", "combat")
	var proj_timer := get_tree().create_timer(dodge_projectile_delay)
	proj_timer.timeout.connect(_on_dodge_projectile_time)
	_dodge_timer = get_tree().create_timer(dodge_duration)
	_dodge_timer.timeout.connect(_on_dodge_land)

func _on_dodge_projectile_time() -> void:
	if _current_step != Step.DODGE_START and _current_step != Step.DODGE_AIR:
		return
	_current_step = Step.DODGE_AIR
	var mgr := get_attack_manager()
	var target_pos: Vector2 = target_node.global_position if target_node else Vector2.ZERO
	if mgr:
		mgr.fire_sword_projectile(target_pos)
	DebugConfig.debug("[BKAttack] DODGE_AIR (projectile fired)", "", "combat")

func _on_dodge_land() -> void:
	_current_step = Step.DODGE_LAND
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	DebugConfig.debug("[BKAttack] DODGE_LAND → chase", "", "combat")
	_force_exit_to_chase()

func _force_exit_to_chase() -> void:
	exit_control_state()
	var boss := get_boss()
	if boss:
		boss.can_move = true
	transitioned.emit(self, "chase")


## ============ 结束攻击 ============

func _finish_attack() -> void:
	exit_control_state()
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "chase")
		return
	var distance := boss.global_position.distance_to(target_node.global_position) if target_node else 9999.0
	if distance <= boss.attack_range:
		_start_next_attack()
	else:
		boss.can_move = true
		transitioned.emit(self, "chase")

func _start_next_attack() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "chase")
		return
	if boss.attack_cooldown > 0:
		boss.can_move = true
		transitioned.emit(self, "chase")
		return
	var mgr := get_attack_manager()
	if not mgr:
		boss.can_move = true
		transitioned.emit(self, "chase")
		return
	var entry: Dictionary = mgr.pick_attack()
	_mode = entry.get("mode", "attack")
	boss.attack_cooldown = mgr.get_cooldown()
	_face_player(boss)
	match _mode:
		"attack":
			_start_step(Step.ATK)
		"combo":
			_start_step(Step.ATK)
		"special":
			_start_step(Step.SP_ATK)
		"projectile":
			exit_control_state()
			boss.can_move = true
			transitioned.emit(self, "projectile")
		"trap":
			exit_control_state()
			boss.can_move = true
			transitioned.emit(self, "trap")
		_:
			_start_step(Step.ATK)


## ============ 工具方法 ============

func _face_player(boss: BossBase) -> void:
	if not target_node:
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = boss.global_position.x > target_node.global_position.x


func exit() -> void:
	exit_control_state()
	_current_step = Step.NONE
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_animation_finished)
	if _dodge_timer and _dodge_timer.timeout.is_connected(_on_dodge_land):
		_dodge_timer.timeout.disconnect(_on_dodge_land)
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = true
