# test/unit/test_damage_pipeline.gd
extends GutTest

var _pipe: DamagePipeline
var _ordering: Array

func before_each() -> void:
	_pipe = DamagePipeline.new()
	add_child_autofree(_pipe)
	_ordering = []

func _record(stage: String) -> Callable:
	return func(_ctx: DamageContext) -> void: _ordering.append(stage)

func test_emits_in_order() -> void:
	_pipe.pre_calc.connect(_record("pre_calc"))
	_pipe.pre_apply.connect(_record("pre_apply"))
	_pipe.apply.connect(_record("apply"))
	_pipe.post_apply.connect(_record("post_apply"))
	_pipe.react.connect(_record("react"))
	_pipe.process(DamageContext.new())
	assert_eq(_ordering, ["pre_calc", "pre_apply", "apply", "post_apply", "react"])

func test_blocked_in_pre_calc_short_circuits() -> void:
	_pipe.pre_calc.connect(func(ctx): ctx.blocked = true)
	_pipe.pre_apply.connect(_record("pre_apply"))
	_pipe.apply.connect(_record("apply"))
	_pipe.post_apply.connect(_record("post_apply"))
	_pipe.react.connect(_record("react"))
	_pipe.process(DamageContext.new())
	assert_eq(_ordering, [], "no further stages after pre_calc block")

func test_blocked_in_pre_apply_short_circuits() -> void:
	_pipe.pre_apply.connect(func(ctx): ctx.blocked = true)
	_pipe.apply.connect(_record("apply"))
	_pipe.post_apply.connect(_record("post_apply"))
	_pipe.react.connect(_record("react"))
	_pipe.process(DamageContext.new())
	assert_eq(_ordering, [], "apply / post_apply / react all skipped after pre_apply block")

func test_apply_runs_even_after_subscribers_modify_amount() -> void:
	var ctx := DamageContext.new()
	ctx.amount = 10.0
	_pipe.pre_calc.connect(func(c): c.amount *= 0.5)
	_pipe.apply.connect(_record("apply"))
	_pipe.process(ctx)
	assert_eq(ctx.amount, 5.0)
	assert_eq(_ordering, ["apply"], "apply stage still emitted after pre_calc mutation")

func test_null_context_no_crash() -> void:
	_pipe.process(null)
	pass_test("survived null ctx")
