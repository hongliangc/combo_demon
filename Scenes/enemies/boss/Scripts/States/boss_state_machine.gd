extends Node

## Boss 状态机 - 管理所有 Boss 状态的切换

@export var init_state: BossState
var current_state: BossState
var states: Dictionary = {}

# 阶段转换标志 - 防止阶段转换期间被打断
var is_transitioning_phase := false

@onready var boss: Boss = get_owner()
@onready var player: Hahashin = get_tree().get_first_node_in_group("player")

# 接收 boss.damaged 信号并转发给当前活动状态
func on_damaged(damage: Damage):
	# 阶段转换期间不接受伤害导致的状态切换
	if is_transitioning_phase:
		return

	if current_state and current_state.has_method("on_damaged"):
		current_state.on_damaged(damage)

func _ready() -> void:
	# 遍历子节点，添加状态节点到字典中，并注入 boss 和 player 引用
	for child in get_children():
		if child is BossState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(on_transition)
			# 统一注入引用
			child.boss = boss
			child.player = player

	# 状态机连接 boss.damaged 信号
	if boss:
		boss.damaged.connect(on_damaged)
		boss.phase_changed.connect(on_phase_changed)

	if init_state:
		current_state = init_state
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.process_state(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process_state(delta)

func on_transition(state: BossState, new_state_name: String):
	if state != current_state:
		return

	var new_state = states.get(new_state_name.to_lower())
	if not new_state:
		push_warning("状态 '%s' 不存在" % new_state_name)
		return

	# 退出当前状态
	if current_state:
		current_state.exit()

	# 进入新状态
	new_state.enter()
	current_state = new_state

	print("Boss 状态切换: %s" % new_state_name)

# 阶段改变时的回调
func on_phase_changed(new_phase: int):
	print("Boss 阶段改变回调: Phase %d" % (new_phase + 1))

	# 设置阶段转换标志，防止被伤害打断
	is_transitioning_phase = true

	# 根据阶段智能切换状态
	match new_phase:
		Boss.Phase.PHASE_2:
			# 第二阶段：根据当前距离选择合适的战斗状态
			if player and player.alive:
				var distance = boss.global_position.distance_to(player.global_position)
				if distance <= boss.attack_range:
					# 距离合适，进入绕圈或攻击
					if states.has("circle"):
						on_transition(current_state, "circle")
				else:
					# 距离较远，进入追击
					if states.has("chase"):
						on_transition(current_state, "chase")
		Boss.Phase.PHASE_3:
			# 第三阶段立即进入狂暴状态
			if states.has("enrage"):
				on_transition(current_state, "enrage")

	# 短暂延迟后清除标志，防止阶段转换瞬间的状态冲突
	await get_tree().create_timer(0.1).timeout
	is_transitioning_phase = false
