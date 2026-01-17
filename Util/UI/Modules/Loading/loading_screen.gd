extends Control
class_name LoadingScreen

## 加载界面 - 显示场景加载进度
##
## 特性：
## - 进度条显示
## - 加载提示轮播
## - 异步场景加载
## - 淡入淡出动画
##
## 使用示例：
## ```gdscript
## var loading = preload("res://Util/UI/Modules/Loading/loading_screen.tscn").instantiate()
## UIManager.open_panel(loading, UIManager.UILayer.LOADING)
## loading.load_scene_async("res://Scenes/main.tscn")
## ```

# 信号
signal loading_completed()
signal loading_failed(error_message: String)

# 配置
@export var loading_tips: Array[String] = [
	"提示：使用技能组合可以造成更高伤害",
	"提示：闪避可以避免大部分伤害",
	"提示：击败Boss可以获得强力装备",
	"提示：合理利用环境可以获得优势",
]

@export var tip_change_interval: float = 3.0  ## 提示切换间隔（秒）

# 节点引用
@onready var background: ColorRect = $Background
@onready var progress_bar: ProgressBar = $CenterContainer/VBox/ProgressBar
@onready var tip_label: Label = $CenterContainer/VBox/TipLabel
@onready var status_label: Label = $CenterContainer/VBox/StatusLabel

# 私有变量
var _current_tip_index: int = 0
var _tip_timer: Timer
var _is_loading: bool = false


func _ready() -> void:
	# 设置全屏
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 初始化提示计时器
	_tip_timer = Timer.new()
	_tip_timer.wait_time = tip_change_interval
	_tip_timer.timeout.connect(_on_tip_timer_timeout)
	add_child(_tip_timer)

	# 初始化进度条
	progress_bar.value = 0
	progress_bar.max_value = 100

	# 显示第一条提示
	_update_tip()

	# 播放进入动画
	play_enter_animation()


## 异步加载场景
## @param scene_path: 场景路径
func load_scene_async(scene_path: String) -> void:
	if _is_loading:
		push_warning("LoadingScreen: Already loading a scene")
		return

	_is_loading = true
	status_label.text = "加载中..."
	progress_bar.value = 0
	_tip_timer.start()

	# 开始异步加载
	var error := ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		_on_loading_failed("无法加载场景: " + scene_path)
		return

	# 轮询加载进度
	_poll_loading_progress(scene_path)


## 轮询加载进度
func _poll_loading_progress(scene_path: String) -> void:
	while _is_loading:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# 更新进度
				if progress.size() > 0:
					progress_bar.value = progress[0] * 100
				await get_tree().process_frame

			ResourceLoader.THREAD_LOAD_LOADED:
				# 加载完成
				progress_bar.value = 100
				status_label.text = "加载完成！"
				await get_tree().create_timer(0.5).timeout
				_on_loading_completed(scene_path)
				return

			ResourceLoader.THREAD_LOAD_FAILED:
				_on_loading_failed("场景加载失败")
				return

			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_on_loading_failed("无效的资源路径")
				return


## 加载完成
func _on_loading_completed(scene_path: String) -> void:
	_is_loading = false
	_tip_timer.stop()

	# 获取加载的场景
	var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene:
		# 切换场景
		await play_exit_animation()
		get_tree().change_scene_to_packed(scene)
		loading_completed.emit()
		queue_free()
	else:
		_on_loading_failed("无法实例化场景")


## 加载失败
func _on_loading_failed(error_message: String) -> void:
	_is_loading = false
	_tip_timer.stop()
	status_label.text = "加载失败"
	push_error("LoadingScreen: " + error_message)
	loading_failed.emit(error_message)


## 更新提示文本
func _update_tip() -> void:
	if loading_tips.is_empty():
		return

	tip_label.text = loading_tips[_current_tip_index]
	_current_tip_index = (_current_tip_index + 1) % loading_tips.size()


## 提示计时器超时
func _on_tip_timer_timeout() -> void:
	_update_tip()


## 进入动画
func play_enter_animation() -> void:
	background.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 1.0, 0.3)


## 退出动画
func play_exit_animation() -> void:
	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 0.0, 0.3)
	await tween.finished
