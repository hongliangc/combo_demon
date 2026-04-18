# Core/AI/SkillSet.gd
class_name SkillSet extends RefCounted

## 技能池管理器：过滤 → 加权选择 → 冷却管理

var _skills: Array[Skill] = []
var _cooldowns: Dictionary = {}   # { skill.id: float }

## 初始化技能池
func setup(skills: Array[Skill]) -> void:
	_skills = skills
	for s in skills:
		_cooldowns[s.id] = 0.0

## 从可用技能中加权随机选一个（weight=0 的技能被排除）
func pick(boss_ref: Node, bb: AIBlackboard) -> Skill:
	var pool := _filter(boss_ref, bb, false)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)

## 按 tag 过滤后选（含 weight=0 的技能）
func pick_tagged(tag: StringName, boss_ref: Node, bb: AIBlackboard) -> Skill:
	var pool := _filter(boss_ref, bb, true).filter(
		func(s: Skill) -> bool: return tag in s.tags
	)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)

## 查询是否有任何技能可用
func has_available(boss_ref: Node, bb: AIBlackboard) -> bool:
	return not _filter(boss_ref, bb, false).is_empty()

## 触发某技能的冷却
func start_cooldown(skill_id: StringName) -> void:
	var s := _find_skill(skill_id)
	if s:
		_cooldowns[s.id] = s.cooldown

## 每帧扣减冷却（由 AgentAIBase._physics_process 调用）
func tick(delta: float) -> void:
	for id in _cooldowns:
		if _cooldowns[id] > 0:
			_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)

## 读取某技能当前剩余冷却
func get_cooldown(skill_id: StringName) -> float:
	return _cooldowns.get(skill_id, 0.0)

# ---- 内部 ----

func _filter(boss_ref: Node, bb: AIBlackboard, include_zero_weight: bool) -> Array[Skill]:
	var phase: int = bb.get_var(&"current_phase", 0)
	var dist: float = bb.get_var(&"distance", INF)
	var result: Array[Skill] = []
	for s in _skills:
		if _cooldowns.get(s.id, 0.0) > 0:
			continue
		if phase < s.min_phase:
			continue
		if s.max_phase >= 0 and phase > s.max_phase:
			continue
		if s.max_range > 0 and dist > s.max_range:
			continue
		if s.min_range > 0 and dist < s.min_range:
			continue
		if not include_zero_weight and s.weight <= 0:
			continue
		if s.precondition_method != &"":
			# Fail-safe: missing precondition method blocks the skill (treat unconfigured boss as unsafe).
			if not boss_ref.has_method(s.precondition_method):
				continue
			if not boss_ref.call(s.precondition_method):
				continue
		result.append(s)
	return result

## 加权随机:weight<=0 在此处被提升为 1(避免除零)。pick_tagged 调用方注意:
## 多个 weight=0 技能落入此函数时,概率与 weight=1 等同,而非 0。
func _weighted_pick(pool: Array[Skill]) -> Skill:
	var total := 0
	for s in pool:
		total += maxi(s.weight, 1)
	var roll := randi() % total
	var acc := 0
	for s in pool:
		acc += maxi(s.weight, 1)
		if roll < acc:
			return s
	return pool.back()

func _find_skill(id: StringName) -> Skill:
	for s in _skills:
		if s.id == id:
			return s
	return null
