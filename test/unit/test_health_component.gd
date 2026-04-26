extends GutTest

## HealthComponent unit tests — only non-obvious branch logic.
## Damage / heal / death flow is covered by test_buff_pipeline_integration.gd.

const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _pipe: DamagePipeline
var _hc: HealthComponent

func before_each() -> void:
	_actor = H.build_actor_with_pipeline()
	_pipe = _actor.get_node(^"DamagePipeline")
	_hc = _actor.get_node(^"HealthComponent")
	add_child_autofree(_actor)

func test_reset_health_revives_dead_actor() -> void:
	# Revive-from-dead is a non-obvious state transition: HC must come back
	# to max HP and re-enable is_alive so subsequent pipeline events land.
	_pipe.process(H.create_damage_ctx(_actor, 150.0))
	assert_eq(_hc.health, 0.0)
	assert_false(_hc.is_alive)

	_hc.reset_health()
	assert_eq(_hc.health, _hc.max_health)
	assert_true(_hc.is_alive)
