extends Node

## 调试日志系统使用示例
## 这个文件展示了如何在实际游戏代码中使用新的日志系统

# ========================================
# 示例 1: 在玩家脚本中使用
# ========================================
class PlayerExample:
	var health: int = 100

	func _ready() -> void:
		# 初始化信息
		DebugConfig.info("玩家初始化完成")

	func take_damage(amount: int) -> void:
		health -= amount

		# 战斗日志 - 使用分类标签
		DebugConfig.info("受到伤害: %d, 剩余血量: %d" % [amount, health], "", "combat")

		if health <= 0:
			# 警告级别
			DebugConfig.warn("玩家血量为0", "", "player")
			die()

	func die() -> void:
		# 错误级别（用于重要事件）
		DebugConfig.error("玩家死亡!", "", "player")


# ========================================
# 示例 2: 在状态机中使用
# ========================================
class StateMachineExample:
	var current_state: String = "Idle"

	func change_state(new_state: String) -> void:
		var old_state := current_state
		current_state = new_state

		# 使用 DEBUG 级别记录状态转换
		DebugConfig.debug("状态转换: %s -> %s" % [old_state, new_state], "", "state_machine")


# ========================================
# 示例 3: 在 Boss AI 中使用
# ========================================
class BossAIExample:
	func update_ai(_delta: float) -> void:
		# Boss AI 调试信息
		DebugConfig.debug("Boss AI 更新", "", "ai")

	func attack_player() -> void:
		# 使用 INFO 级别记录重要行为
		DebugConfig.info("Boss 发动攻击!", "", "ai")

	func enter_enrage_mode() -> void:
		# 使用 WARNING 级别标记特殊状态
		DebugConfig.warn("Boss 进入狂暴模式!", "", "ai")


# ========================================
# 示例 4: 在 UI 系统中使用
# ========================================
class UIExample:
	func show_menu() -> void:
		DebugConfig.info("显示主菜单", "", "ui")

	func load_screen_failed(error: String) -> void:
		# 使用 ERROR 级别记录失败
		DebugConfig.error("加载界面失败: %s" % error, "", "ui")


# ========================================
# 示例 5: 运行时配置控制
# ========================================
class RuntimeConfigExample:
	func _ready() -> void:
		# 只在 Debug 构建时启用详细日志
		if OS.is_debug_build():
			DebugConfig.set_global_enabled(true)
			DebugConfig.set_global_min_level(DebugConfig.LogLevel.DEBUG)
		else:
			# 发布版本只显示错误
			DebugConfig.set_global_min_level(DebugConfig.LogLevel.ERROR)

	func enable_combat_debug() -> void:
		# 临时启用战斗调试
		DebugConfig.set_category_config("combat", true, DebugConfig.LogLevel.DEBUG)

	func disable_state_machine_spam() -> void:
		# 关闭状态机的频繁日志
		DebugConfig.set_category_config("state_machine", false)

	func debug_boss_only() -> void:
		# 只调试 Boss，关闭其他日志
		DebugConfig.set_global_min_level(DebugConfig.LogLevel.ERROR)
		DebugConfig.set_path_config("Scenes/enemies/boss/", true, DebugConfig.LogLevel.DEBUG)


# ========================================
# 示例 6: 条件日志（性能优化）
# ========================================
class PerformanceExample:
	# 不好的做法：每帧都打印
	func _process_bad(_delta: float) -> void:
		# 这会严重影响性能！
		DebugConfig.debug("每帧更新")

	# 好的做法：只在必要时打印
	func _process_good(_delta: float) -> void:
		# 正常逻辑，不打印日志
		pass

	func on_event_occurred() -> void:
		# 只在事件发生时打印
		DebugConfig.info("事件触发")

	# 条件调试：只在特定条件下打印
	var debug_movement: bool = false
	func update_position(pos: Vector2) -> void:
		if debug_movement:
			DebugConfig.debug("位置更新: %v" % pos)


# ========================================
# 示例 7: 使用主方法（更灵活）
# ========================================
class AdvancedExample:
	func custom_logging() -> void:
		# 直接使用 print_log 方法，完全控制
		DebugConfig.print_log(
			"自定义消息",
			DebugConfig.LogLevel.INFO,
			"Scenes/custom/script.gd",  # 可以指定调用者路径
			"custom_category"           # 自定义分类
		)

	func log_with_caller_path() -> void:
		# 通常不需要手动指定路径，会自动获取
		DebugConfig.info("自动获取调用者路径")


# ========================================
# 示例 8: 格式化日志消息
# ========================================
class FormattingExample:
	func log_complex_data() -> void:
		var player_data := {
			"name": "Player1",
			"health": 100,
			"position": Vector2(10, 20)
		}

		# 使用字符串格式化
		DebugConfig.info("玩家数据: %s" % str(player_data))

		# 或者分行打印
		DebugConfig.info("玩家状态:")
		DebugConfig.info("  名称: %s" % player_data.name)
		DebugConfig.info("  血量: %d" % player_data.health)
		DebugConfig.info("  位置: %v" % player_data.position)


# ========================================
# 示例 9: 调试技巧
# ========================================
class DebuggingTips:
	# 技巧1: 使用不同级别区分重要性
	func example_levels() -> void:
		DebugConfig.debug("详细的内部状态")      # 开发时查看
		DebugConfig.info("重要的游戏事件")       # 测试时查看
		DebugConfig.warn("可能的问题")          # 总是关注
		DebugConfig.error("严重错误")           # 必须修复

	# 技巧2: 使用分类标签组织日志
	func example_categories() -> void:
		DebugConfig.info("伤害计算", "", "combat")
		DebugConfig.info("UI 更新", "", "ui")
		DebugConfig.debug("AI 决策", "", "ai")

	# 技巧3: 在关键点添加日志
	func critical_function() -> void:
		DebugConfig.info("开始执行关键操作")

		# ... 复杂逻辑 ...

		DebugConfig.info("关键操作完成")

	# 技巧4: 错误处理中添加日志
	func load_resource(path: String) -> void:
		var resource = load(path)
		if not resource:
			DebugConfig.error("无法加载资源: %s" % path)
			return

		DebugConfig.debug("成功加载资源: %s" % path)
