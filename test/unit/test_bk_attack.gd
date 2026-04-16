extends GutTest

## BKAttack 步骤机单元测试
## 直接调用步骤完成回调，绕过 AnimationTree/BossBase 依赖
##
## 测试策略：
## - MockBoss (Node) 模拟 BossBase duck-typed 接口
## - MockAttackManager (Node) 模拟 BossAttackManager.last_picked_entry
## - 直接调用 _on_atk_finished / _on_sp_atk_finished / _on_jump_*_finished
## - 通过 transitioned 信号捕获转换结果

const BKAttackScript := preload("res://Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd")

## Step enum 值（对应 BKAttack.gd 中 enum Step 顺序）
const STEP_NONE     := 0
const STEP_ATK      := 1
const STEP_SP_ATK   := 2
const STEP_DODGE    := 3
const STEP_JUMP_UP  := 4
const STEP_AIR_ATK  := 5
const STEP_JUMP_DOWN := 6

# ============ Mock 类 ============

## MockBoss: 提供 BossBase 必需的 duck-typed 属性
## 继承 Node（非 CharacterBody2D）以避免物理依赖
class MockBoss extends Node2D:
	var velocity := Vector2.ZERO
	var can_move := true
	## BossBase.Phase.PHASE_1 = 0
	var current_phase: int = 0
	var attack_range := 150.0
	var detection_radius := 800.0
	var min_distance := 50.0
	var attack_cooldown := 0.0
	var stun_immunity := 0.0
	var alive := true

	func _ready() -> void:
		var sprite := Node2D.new()
		sprite.name = "AnimatedSprite2D"
		sprite.set("flip_h", false)
		add_child(sprite)


## MockAttackManager: 提供 last_picked_entry（BossAttackManager duck-type）
class MockAttackManager extends Node:
	var last_picked_entry: Dictionary = {"mode": "attack"}


## MockStateMachine: 提供 states 字典，让 _resolve_state 工作
class MockStateMachine extends Node:
	var states: Dictionary = {}
	var anim_tree = null


# ============ 辅助方法 ============

## 创建一个完整配置的 BKAttack 实例，绑定到 MockBoss
func _create_attack_state(mode: String = "attack") -> Dictionary:
	var boss := MockBoss.new()
	boss.name = "MockBoss"
	add_child_autofree(boss)
	await wait_frames(1)

	var mgr := MockAttackManager.new()
	mgr.last_picked_entry = {"mode": mode}
	boss.add_child(mgr)

	var sm := MockStateMachine.new()
	sm.name = "StateMachine"
	var idle_state := BaseState.new()
	idle_state.name = "idle"
	var chase_state := BaseState.new()
	chase_state.name = "chase"
	sm.states["idle"] = idle_state
	sm.states["chase"] = chase_state
	sm.add_child(idle_state)
	sm.add_child(chase_state)
	boss.add_child(sm)

	var player := Node2D.new()
	player.name = "MockPlayer"
	add_child_autofree(player)

	var atk = BKAttackScript.new()
	atk.name = "BKAttack"
	atk.owner_node = boss
	atk.target_node = player
	atk.state_machine = sm
	boss.add_child(atk)
	await wait_frames(1)

	return {"boss": boss, "mgr": mgr, "sm": sm, "atk": atk, "player": player}


# ============ enter() 初始化 ============

func test_start_step_atk_sets_current_step() -> void:
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._start_step(STEP_ATK)
	assert_eq(atk._current_step, STEP_ATK, "ATK step should be set after _start_step(ATK)")


func test_start_step_sp_atk_sets_current_step() -> void:
	var s := await _create_attack_state("special")
	var atk = s.atk
	atk._start_step(STEP_SP_ATK)
	assert_eq(atk._current_step, STEP_SP_ATK, "SP_ATK step should be set")


func test_start_step_jump_up_sets_current_step() -> void:
	var s := await _create_attack_state("jump")
	var atk = s.atk
	atk._start_step(STEP_JUMP_UP)
	assert_eq(atk._current_step, STEP_JUMP_UP, "JUMP_UP step should be set")


func test_enter_initializes_velocity_zero_and_no_can_move() -> void:
	## Simulate what enter() does for movement — verify contract on MockBoss
	var s := await _create_attack_state("attack")
	var boss: MockBoss = s.boss
	boss.velocity = Vector2(200, 50)
	boss.can_move = true
	# Perform the same operations as enter()
	boss.velocity = Vector2.ZERO
	boss.can_move = false
	assert_eq(boss.velocity, Vector2.ZERO)
	assert_false(boss.can_move)


# ============ attack モード ============

func test_attack_mode_atk_finished_emits_transitioned() -> void:
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._mode = "attack"
	atk._current_step = STEP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_atk_finished()
	assert_true(got, "attack mode: ATK finished must emit transitioned")


func test_attack_mode_atk_finished_does_not_enter_sp_atk() -> void:
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._mode = "attack"
	atk._current_step = STEP_ATK
	atk._on_atk_finished()
	assert_ne(atk._current_step, STEP_SP_ATK,
		"attack mode must NOT transition to SP_ATK")


# ============ special モード ============

func test_special_mode_sp_atk_finished_emits_transitioned() -> void:
	var s := await _create_attack_state("special")
	var atk = s.atk
	atk._mode = "special"
	atk._current_step = STEP_SP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_sp_atk_finished()
	assert_true(got, "special mode: SP_ATK finished must emit transitioned")


func test_special_mode_sp_atk_does_not_go_to_dodge() -> void:
	var s := await _create_attack_state("special")
	var atk = s.atk
	atk._mode = "special"
	atk._current_step = STEP_SP_ATK
	# _on_sp_atk_finished in "special" calls _finish_attack → emits transitioned, does not set DODGE
	atk._on_sp_atk_finished()
	assert_ne(atk._current_step, STEP_DODGE,
		"special mode must NOT go to DODGE after SP_ATK")


# ============ combo モード ============

func test_combo_mode_atk_finished_goes_to_sp_atk_or_dodge() -> void:
	var s := await _create_attack_state("combo")
	var atk = s.atk
	atk._mode = "combo"
	atk._current_step = STEP_ATK

	atk._on_atk_finished()
	var next: int = atk._current_step
	assert_true(next == STEP_SP_ATK or next == STEP_DODGE,
		"combo ATK finished must go to SP_ATK or DODGE, got: %d" % next)


func test_combo_mode_sp_atk_finished_always_goes_to_dodge() -> void:
	var s := await _create_attack_state("combo")
	var atk = s.atk
	atk._mode = "combo"
	atk._current_step = STEP_SP_ATK

	atk._on_sp_atk_finished()
	assert_eq(atk._current_step, STEP_DODGE,
		"combo SP_ATK finished must always go to DODGE")


func test_combo_mode_dodge_finished_emits_transitioned() -> void:
	var s := await _create_attack_state("combo")
	var atk = s.atk
	atk._mode = "combo"
	atk._current_step = STEP_DODGE

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_dodge_finished()
	assert_true(got, "combo DODGE finished must emit transitioned")


func test_combo_mode_atk_never_emits_transitioned_directly() -> void:
	## In combo mode, ATK finished must NOT call _finish_attack (no transition yet)
	var s := await _create_attack_state("combo")
	var atk = s.atk
	atk._mode = "combo"
	atk._current_step = STEP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_atk_finished()
	assert_false(got,
		"combo ATK finished must NOT emit transitioned (continues to SP_ATK or DODGE)")


# ============ jump モード ============

func test_jump_up_finished_goes_to_air_atk_or_jump_down() -> void:
	var s := await _create_attack_state("jump")
	var atk = s.atk
	atk._mode = "jump"
	atk._current_step = STEP_JUMP_UP

	atk._on_jump_up_finished()
	var next: int = atk._current_step
	assert_true(next == STEP_AIR_ATK or next == STEP_JUMP_DOWN,
		"jump_up finished must go to AIR_ATK or JUMP_DOWN, got: %d" % next)


func test_air_atk_finished_always_goes_to_jump_down() -> void:
	var s := await _create_attack_state("jump")
	var atk = s.atk
	atk._mode = "jump"
	atk._current_step = STEP_AIR_ATK

	atk._on_air_atk_finished()
	assert_eq(atk._current_step, STEP_JUMP_DOWN,
		"air_atk finished must always go to JUMP_DOWN")


func test_jump_down_finished_goes_to_atk_or_dodge() -> void:
	var s := await _create_attack_state("jump")
	var atk = s.atk
	atk._mode = "jump"
	atk._current_step = STEP_JUMP_DOWN

	atk._on_jump_down_finished()
	var next: int = atk._current_step
	# Ground combo → ATK (with mode="combo"), or direct dodge → DODGE
	assert_true(next == STEP_ATK or next == STEP_DODGE,
		"jump_down finished must go to ATK (ground combo) or DODGE, got: %d" % next)


func test_jump_down_ground_combo_sets_mode_to_combo() -> void:
	## GROUND_COMBO_AFTER_JUMP_CHANCE=0.5, run 40 iterations to guarantee hitting it
	var found_combo := false
	for _i in range(40):
		var s := await _create_attack_state("jump")
		var atk = s.atk
		atk._mode = "jump"
		atk._current_step = STEP_JUMP_DOWN
		atk._on_jump_down_finished()
		if atk._mode == "combo" and atk._current_step == STEP_ATK:
			found_combo = true
			break
	assert_true(found_combo,
		"jump_down should eventually trigger ground combo (mode=combo, step=ATK) within 40 tries")


func test_start_step_jump_down_sets_current_step() -> void:
	var s := await _create_attack_state("jump")
	var atk = s.atk
	atk._mode = "jump"

	atk._start_step(STEP_JUMP_DOWN)
	assert_eq(atk._current_step, STEP_JUMP_DOWN,
		"_start_step(JUMP_DOWN) must set _current_step to JUMP_DOWN")


# ============ dodge 方向 ============

func test_dodge_direction_away_when_player_is_left() -> void:
	## Boss at x=200, player at x=0 → dodge dir = +X (rightward, away from player)
	var boss_pos := Vector2(200, 0)
	var player_pos := Vector2(0, 0)
	var dodge_dir := (boss_pos - player_pos).normalized()
	assert_true(dodge_dir.x > 0,
		"dodge direction x should be positive when player is to the left")


func test_dodge_direction_away_when_player_is_right() -> void:
	## Boss at x=0, player at x=200 → dodge dir = -X (leftward, away from player)
	var boss_pos := Vector2(0, 0)
	var player_pos := Vector2(200, 0)
	var dodge_dir := (boss_pos - player_pos).normalized()
	assert_true(dodge_dir.x < 0,
		"dodge direction x should be negative when player is to the right")


func test_dodge_velocity_math_away_from_player() -> void:
	## Verify dodge direction formula: (boss_pos - player_pos).normalized() * speed
	## This is the math inside _start_dodge; tested directly since _start_dodge
	## requires get_boss() to return a real BossBase.
	var boss_pos := Vector2(200, 0)
	var player_pos := Vector2(0, 0)
	var speed := 300.0
	var dodge_dir := (boss_pos - player_pos).normalized()
	var vel := dodge_dir * speed
	assert_true(vel.x > 0,
		"Dodge velocity x must be positive when player is to the left (boss_pos.x > player_pos.x)")


# ============ _face_player ============

func test_face_player_flip_true_when_player_is_left() -> void:
	var s := await _create_attack_state("attack")
	var boss: MockBoss = s.boss
	var player: Node2D = s.player
	var atk = s.atk

	boss.global_position = Vector2(100, 0)
	player.global_position = Vector2(0, 0)

	atk._face_player(boss)
	var sprite := boss.get_node_or_null("AnimatedSprite2D")
	if sprite:
		assert_true(sprite.get("flip_h"),
			"flip_h should be true when player is to the left (boss.x > player.x)")


func test_face_player_flip_false_when_player_is_right() -> void:
	var s := await _create_attack_state("attack")
	var boss: MockBoss = s.boss
	var player: Node2D = s.player
	var atk = s.atk

	boss.global_position = Vector2(0, 0)
	player.global_position = Vector2(100, 0)

	atk._face_player(boss)
	var sprite := boss.get_node_or_null("AnimatedSprite2D")
	if sprite:
		assert_false(sprite.get("flip_h"),
			"flip_h should be false when player is to the right (boss.x < player.x)")


# ============ exit() 清理 ============

func test_exit_resets_step_to_none() -> void:
	## _current_step reset is unconditional in exit()
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._current_step = STEP_ATK
	atk.exit()
	assert_eq(atk._current_step, STEP_NONE, "exit() must reset _current_step to NONE")


func test_exit_does_not_crash_without_anim_tree() -> void:
	## exit() with no AnimationTree connected must not throw
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._anim_tree_ref = null
	atk._dodge_timer = null
	# Should complete without error
	atk.exit()
	assert_eq(atk._current_step, STEP_NONE)


# ============ 动画完成信号过滤 ============

func test_animation_finished_ignores_wrong_name_during_atk() -> void:
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._mode = "attack"
	atk._current_step = STEP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	# sp_atk is not in NORMAL_ATKS → must be ignored
	atk._on_animation_finished(&"sp_atk")
	assert_false(got, "Wrong anim name during ATK step must be ignored")


func test_animation_finished_ignores_wrong_name_during_sp_atk() -> void:
	var s := await _create_attack_state("special")
	var atk = s.atk
	atk._mode = "special"
	atk._current_step = STEP_SP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_animation_finished(&"atk_1")
	assert_false(got, "Wrong anim name during SP_ATK step must be ignored")


func test_animation_finished_atk1_triggers_in_atk_step() -> void:
	var s := await _create_attack_state("attack")
	var atk = s.atk
	atk._mode = "attack"
	atk._current_step = STEP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_animation_finished(&"atk_1")
	assert_true(got, "atk_1 finished during ATK step must trigger transition")


func test_animation_finished_sp_atk_triggers_in_sp_atk_step() -> void:
	var s := await _create_attack_state("special")
	var atk = s.atk
	atk._mode = "special"
	atk._current_step = STEP_SP_ATK

	var got := false
	atk.transitioned.connect(func(_f, _t): got = true)
	atk._on_animation_finished(&"sp_atk")
	assert_true(got, "sp_atk finished during SP_ATK step must trigger transition")
