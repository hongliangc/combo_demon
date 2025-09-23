extends Node

@onready var animation_tree: AnimationTree = $"../AnimationTree"
var playback: AnimationNodeStateMachinePlayback


var skill_config = {
	"atk_sp" :{	
		"sound_effect": preload("res://Sound/face_the_wind.mp3"),
		"time_scale": 2
	},
	"atk_1" :{
		"sound_effect": "",
		"time_scale": 2
	},
	"atk_2" :{
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2
	},
	"atk_3" :{
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2
	},
	"roll" :{
		"sound_effect": preload("res://Sound/sp_atk.mp3"),
		"time_scale": 2,
		"func": set_roll_speed
	}
}

func set_roll_speed(roll_speed: int):
	var movement_handler = get_parent().get_node("MovementHandler")
	if movement_handler:
		movement_handler.set_speed(roll_speed)
	

func _ready():
	animation_tree.active = true  # 激活 AnimationTree
	playback = animation_tree.get("parameters/StateMachine/playback")
	animation_tree.connect("animation_finished", self.on_animation_finished)

# 切换到指定状态，并支持 timescale 和 blend_time
func play_animation(animation_name: String):
	var config = skill_config.get(animation_name)
	if playback and config:
		if config.get("func"):
			config["func"].call(400)
		playback.travel(animation_name)  # 切换状态
		animation_tree.set("parameters/TimeScale/scale", config.get("time_scale", 1))  # 设置播放速度
		if config["sound_effect"]:
			SoundManager.play_sound(config["sound_effect"])

func on_animation_finished(animation_name: String):
	animation_tree.set("parameters/TimeScale/scale", 1)  # 设置播放速度
	if animation_name in skill_config.keys():  # 检查是否是技能动画
		var movement_handler = get_parent().get_node("MovementHandler")
		if movement_handler:
			movement_handler.on_animation_finished()
	
