extends Node

## 全局日志系统
## 支持日志级别、目录层级配置、运行时动态控制

# ============ 日志级别枚举 ============
enum LogLevel {
	DEBUG = 0,    # 调试信息：详细的开发调试信息
	INFO = 1,     # 一般信息：重要的运行状态信息
	WARNING = 2,  # 警告信息：可能的问题或异常
	ERROR = 3     # 错误信息：严重错误
}

# 日志级别名称映射
const LEVEL_NAMES := {
	LogLevel.DEBUG: "DEBUG",
	LogLevel.INFO: "INFO",
	LogLevel.WARNING: "WARNING",
	LogLevel.ERROR: "ERROR"
}

# 日志级别颜色（用于控制台输出）
const LEVEL_COLORS := {
	LogLevel.DEBUG: "\u001b[36m",    # 青色
	LogLevel.INFO: "\u001b[32m",     # 绿色
	LogLevel.WARNING: "\u001b[33m",  # 黄色
	LogLevel.ERROR: "\u001b[31m"     # 红色
}
const COLOR_RESET := "\u001b[0m"

# ============ 配置数据 ============
var config := {}
var global_enabled := true
var global_min_level := LogLevel.DEBUG
var output_to_file := false
var log_file_path := "user://debug.log"
var log_file: FileAccess = null

# 路径配置缓存 {path: {enabled: bool, min_level: int}}
var path_configs := {}
# 分类配置缓存 {category: {enabled: bool, min_level: int}}
var category_configs := {}


# ============ 初始化 ============
func _ready() -> void:
	load_config()
	if output_to_file:
		_open_log_file()


func _exit_tree() -> void:
	if log_file:
		log_file.close()


# ============ 配置加载 ============
func load_config() -> void:
	var config_path := "res://Util/AutoLoad/debug_config.json"

	if not FileAccess.file_exists(config_path):
		push_warning("[DebugConfig] 配置文件不存在: %s，使用默认配置" % config_path)
		_use_default_config()
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("[DebugConfig] 无法打开配置文件: %s" % config_path)
		_use_default_config()
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("[DebugConfig] JSON 解析失败: %s" % json.get_error_message())
		_use_default_config()
		return

	config = json.data
	_parse_config()
	print("[DebugConfig] 配置加载成功")


func _use_default_config() -> void:
	global_enabled = true
	global_min_level = LogLevel.DEBUG
	output_to_file = false
	print("[DebugConfig] 使用默认配置")


func _parse_config() -> void:
	# 解析全局配置
	if config.has("global"):
		var global: Dictionary = config.global
		global_enabled = global.get("enabled", true)
		global_min_level = _parse_level(global.get("min_level", "DEBUG"))
		output_to_file = global.get("output_to_file", false)
		log_file_path = global.get("file_path", "user://debug.log")

	# 解析路径配置
	if config.has("path_configs"):
		for path in config.path_configs:
			if path.begins_with("_"):
				continue
			var cfg = config.path_configs[path]
			path_configs[path] = {
				"enabled": cfg.get("enabled", true),
				"min_level": _parse_level(cfg.get("min_level", "DEBUG"))
			}

	# 解析分类配置
	if config.has("category_configs"):
		for category in config.category_configs:
			if category.begins_with("_"):
				continue
			var cfg = config.category_configs[category]
			category_configs[category] = {
				"enabled": cfg.get("enabled", true),
				"min_level": _parse_level(cfg.get("min_level", "DEBUG"))
			}


func _parse_level(level_str: String) -> LogLevel:
	match level_str.to_upper():
		"DEBUG":
			return LogLevel.DEBUG
		"INFO":
			return LogLevel.INFO
		"WARNING":
			return LogLevel.WARNING
		"ERROR":
			return LogLevel.ERROR
		_:
			return LogLevel.DEBUG


# ============ 日志打印核心方法 ============
## 主要的日志打印方法
## @param message: 日志消息
## @param level: 日志级别 (LogLevel 枚举)
## @param caller_path: 调用者的脚本路径（自动获取）
## @param category: 可选的分类标签
func print_log(message: String, level: LogLevel = LogLevel.INFO, caller_path: String = "", category: String = "") -> void:
	if not global_enabled:
		return

	# 获取调用者路径（如果没有提供）
	if caller_path.is_empty():
		caller_path = _get_caller_path()

	# 检查是否应该打印
	if not _should_print(caller_path, category, level):
		return

	# 格式化日志消息
	var formatted_msg := _format_message(message, level, caller_path, category)

	# 输出到控制台
	print_rich(formatted_msg)

	# 输出到文件
	if output_to_file and log_file:
		var plain_msg := _format_message(message, level, caller_path, category, false)
		log_file.store_line(plain_msg)
		log_file.flush()


## 调试级别日志
func debug(message: String, caller_path: String = "", category: String = "") -> void:
	print_log(message, LogLevel.DEBUG, caller_path, category)


## 信息级别日志
func info(message: String, caller_path: String = "", category: String = "") -> void:
	print_log(message, LogLevel.INFO, caller_path, category)


## 警告级别日志
func warn(message: String, caller_path: String = "", category: String = "") -> void:
	print_log(message, LogLevel.WARNING, caller_path, category)


## 错误级别日志
func error(message: String, caller_path: String = "", category: String = "") -> void:
	print_log(message, LogLevel.ERROR, caller_path, category)


# ============ 辅助方法 ============
## 判断是否应该打印日志
func _should_print(caller_path: String, category: String, level: LogLevel) -> bool:
	# 检查全局最低级别
	if level < global_min_level:
		return false

	# 检查分类配置（优先级最高）
	if not category.is_empty() and category_configs.has(category):
		var cfg = category_configs[category]
		if not cfg.enabled:
			return false
		if level < cfg.min_level:
			return false
		return true

	# 检查路径配置（从最具体到最不具体）
	var path_cfg = _find_path_config(caller_path)
	if path_cfg:
		if not path_cfg.enabled:
			return false
		if level < path_cfg.min_level:
			return false

	return true


## 查找匹配的路径配置（最长匹配优先）
func _find_path_config(caller_path: String) -> Dictionary:
	var best_match := ""
	var best_config: Dictionary = {}

	# 标准化路径
	var normalized_path := caller_path.replace("\\", "/")
	if normalized_path.begins_with("res://"):
		normalized_path = normalized_path.substr(6)

	# 查找最长匹配的路径
	for path in path_configs:
		var normalized_config_path: String = path.replace("\\", "/")
		if normalized_path.begins_with(normalized_config_path):
			if normalized_config_path.length() > best_match.length():
				best_match = normalized_config_path
				best_config = path_configs[path]

	return best_config


## 格式化日志消息
func _format_message(message: String, level: LogLevel, caller_path: String, category: String, with_color: bool = true) -> String:
	var timestamp := Time.get_time_string_from_system()
	var level_name: String = LEVEL_NAMES[level]
	var file_name := caller_path.get_file()

	var parts := []

	# 时间戳
	parts.append("[%s]" % timestamp)

	# 日志级别
	if with_color:
		parts.append("%s[%s]%s" % [LEVEL_COLORS[level], level_name, COLOR_RESET])
	else:
		parts.append("[%s]" % level_name)

	# 分类标签
	if not category.is_empty():
		parts.append("[%s]" % category)

	# 文件名
	if not file_name.is_empty():
		parts.append("[%s]" % file_name)

	# 消息内容
	parts.append(message)

	return " ".join(parts)


## 获取调用者的脚本路径
func _get_caller_path() -> String:
	var stack := get_stack()
	# stack[0] 是当前函数
	# stack[1] 是 log/debug/info 等方法
	# stack[2] 是实际调用者
	if stack.size() > 2:
		return stack[2].get("source", "")
	return ""


## 打开日志文件
func _open_log_file() -> void:
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not log_file:
		push_error("[DebugConfig] 无法打开日志文件: %s" % log_file_path)
		output_to_file = false
	else:
		log_file.store_line("=== 日志开始 %s ===" % Time.get_datetime_string_from_system())


# ============ 运行时配置 ============
## 重新加载配置文件
func reload_config() -> void:
	if log_file:
		log_file.close()
		log_file = null
	load_config()
	if output_to_file:
		_open_log_file()


## 设置全局开关
func set_global_enabled(enabled: bool) -> void:
	global_enabled = enabled


## 设置全局最低级别
func set_global_min_level(level: LogLevel) -> void:
	global_min_level = level


## 设置路径配置
func set_path_config(path: String, enabled: bool, min_level: LogLevel = LogLevel.DEBUG) -> void:
	path_configs[path] = {
		"enabled": enabled,
		"min_level": min_level
	}


## 设置分类配置
func set_category_config(category: String, enabled: bool, min_level: LogLevel = LogLevel.DEBUG) -> void:
	category_configs[category] = {
		"enabled": enabled,
		"min_level": min_level
	}


## 启用/禁用文件输出
func set_file_output(enabled: bool) -> void:
	if enabled and not output_to_file:
		output_to_file = true
		_open_log_file()
	elif not enabled and output_to_file:
		output_to_file = false
		if log_file:
			log_file.close()
			log_file = null
