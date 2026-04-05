extends Node
class_name BossAttackManager

## Boss 攻击管理器通用基���
## 提供攻击池选择、冷却管理、玩家缓存
## 子类实现 _execute_attack() 执行具体攻击

@export var phase_configs: Dictionary = {}  ## Phase枚举 → BossPhaseConfig

var _boss_cache: BossBase
var _cached_player: Node2D
## 最近一次 pick_attack() 的结果（供状态读取，避免重复调用）
var last_picked_entry: Dictionary = {}

func _get_boss() -> BossBase:
	if not is_instance_valid(_boss_cache):
		_boss_cache = get_owner() as BossBase
	return _boss_cache

func get_player() -> Node2D:
	if is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = get_tree().get_first_node_in_group("player") as Node2D
	return _cached_player

## 获取当前阶段配置
func get_current_config() -> BossPhaseConfig:
	var boss := _get_boss()
	if not boss:
		return null
	return phase_configs.get(boss.current_phase)

## 获取当前阶段冷却
func get_cooldown() -> float:
	var config := get_current_config()
	return config.cooldown if config else 1.5

## 从当前阶段攻击池加权选取（结果缓存到 last_picked_entry）
func pick_attack() -> Dictionary:
	var config := get_current_config()
	if not config:
		last_picked_entry = {}
		return last_picked_entry
	last_picked_entry = config.pick_attack()
	return last_picked_entry

## 执行攻击入口（调用子类钩子）
func execute_attack(entry: Dictionary, target_pos: Vector2) -> void:
	_execute_attack(entry, target_pos)

## 子类钩子：执行具体攻击
func _execute_attack(_entry: Dictionary, _target_pos: Vector2) -> void:
	push_warning("[BossAttackManager] _execute_attack() not implemented")
