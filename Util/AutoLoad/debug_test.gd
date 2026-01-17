extends Node

## 调试日志系统测试脚本
## 运行此脚本测试各种日志功能

func _ready() -> void:
	print("\n========== 调试日志系统测试 ==========\n")

	# 等待一帧，确保 DebugConfig 已初始化
	await get_tree().process_frame

	test_basic_logging()
	test_log_levels()
	test_categories()
	test_runtime_config()

	print("\n========== 测试完成 ==========\n")


## 测试基本日志功能
func test_basic_logging() -> void:
	print("\n--- 测试1: 基本日志功能 ---")

	DebugConfig.debug("这是 DEBUG 级别日志")
	DebugConfig.info("这是 INFO 级别日志")
	DebugConfig.warn("这是 WARNING 级别日志")
	DebugConfig.error("这是 ERROR 级别日志")


## 测试日志级别过滤
func test_log_levels() -> void:
	print("\n--- 测试2: 日志级别过滤 ---")

	# 保存原始配置
	var original_level = DebugConfig.global_min_level

	# 设置为 WARNING，应该只显示 WARNING 和 ERROR
	DebugConfig.set_global_min_level(DebugConfig.LogLevel.WARNING)
	print("设置最低级别为 WARNING，以下只应显示 WARNING 和 ERROR:")

	DebugConfig.debug("DEBUG - 不应显示")
	DebugConfig.info("INFO - 不应显示")
	DebugConfig.warn("WARNING - 应该显示")
	DebugConfig.error("ERROR - 应该显示")

	# 恢复配置
	DebugConfig.set_global_min_level(original_level)


## 测试分类标签
func test_categories() -> void:
	print("\n--- 测试3: 分类标签 ---")

	DebugConfig.info("战斗伤害: 50", "", "combat")
	DebugConfig.debug("状态转换: Idle -> Chase", "", "state_machine")
	DebugConfig.info("玩家血量: 100", "", "player")
	DebugConfig.debug("Boss AI 更新", "", "ai")


## 测试运行时配置
func test_runtime_config() -> void:
	print("\n--- 测试4: 运行时配置 ---")

	# 临时禁用某个分类
	print("\n禁用 'combat' 分类:")
	DebugConfig.set_category_config("combat", false)
	DebugConfig.info("这条 combat 日志不应显示", "", "combat")
	DebugConfig.info("其他日志正常显示", "", "player")

	# 重新启用
	DebugConfig.set_category_config("combat", true, DebugConfig.LogLevel.INFO)
	DebugConfig.info("重新启用后，combat 日志应该显示", "", "combat")

	# 测试路径配置
	print("\n设置路径配置:")
	DebugConfig.set_path_config("Scenes/enemies/boss/", true, DebugConfig.LogLevel.DEBUG)
	print("已设置 Boss 路径的日志级别为 DEBUG")


## 打印当前配置信息
func print_config_info() -> void:
	print("\n--- 当前配置信息 ---")
	print("全局开关: ", DebugConfig.global_enabled)
	print("全局最低级别: ", DebugConfig.LEVEL_NAMES[DebugConfig.global_min_level])
	print("文件输出: ", DebugConfig.output_to_file)
	print("路径配置: ", DebugConfig.path_configs)
	print("分类配置: ", DebugConfig.category_configs)
