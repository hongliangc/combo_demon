extends GutTest

## AIBlackboard 单元测试

var _bb: AIBlackboard

func before_each() -> void:
	_bb = AIBlackboard.new()

func after_each() -> void:
	_bb = null

# ============ get_var / set_var ============

func test_set_and_get_var() -> void:
	_bb.set_var(&"health", 100.0)
	assert_eq(_bb.get_var(&"health"), 100.0)

func test_get_var_default() -> void:
	assert_eq(_bb.get_var(&"missing", 42), 42)

func test_get_var_missing_no_default() -> void:
	assert_eq(_bb.get_var(&"missing"), null)

func test_has_var() -> void:
	assert_false(_bb.has_var(&"x"))
	_bb.set_var(&"x", 1)
	assert_true(_bb.has_var(&"x"))

func test_overwrite_var() -> void:
	_bb.set_var(&"x", 1)
	_bb.set_var(&"x", 2)
	assert_eq(_bb.get_var(&"x"), 2)

# ============ bind_var ============

func test_bind_var_reads_property() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	node.visible = false
	_bb.bind_var(&"visible", node, &"visible")
	assert_eq(_bb.get_var(&"visible"), false)
	node.visible = true
	assert_eq(_bb.get_var(&"visible"), true)

func test_bind_var_auto_sync_health() -> void:
	var parent := Node.new()
	add_child_autofree(parent)
	var hc := HealthComponent.new()
	hc.max_health = 100.0
	hc.health = 75.0
	parent.add_child(hc)
	_bb.bind_var(&"hp", hc, &"health")
	assert_eq(_bb.get_var(&"hp"), 75.0)
	hc.health = 50.0
	assert_eq(_bb.get_var(&"hp"), 50.0)

func test_bind_var_destroyed_object_returns_local() -> void:
	var node := Node2D.new()
	add_child(node)
	node.visible = true
	_bb.bind_var(&"vis", node, &"visible")
	assert_eq(_bb.get_var(&"vis"), true)
	node.queue_free()
	await get_tree().process_frame
	# After object destroyed, should return cached local value
	assert_eq(_bb.get_var(&"vis"), true)

# ============ parent scope ============

func test_parent_scope_fallback() -> void:
	var parent_bb := AIBlackboard.new()
	parent_bb.set_var(&"shared", "from_parent")
	_bb.parent = parent_bb
	assert_eq(_bb.get_var(&"shared"), "from_parent")

func test_local_overrides_parent() -> void:
	var parent_bb := AIBlackboard.new()
	parent_bb.set_var(&"x", 1)
	_bb.parent = parent_bb
	_bb.set_var(&"x", 2)
	assert_eq(_bb.get_var(&"x"), 2)

func test_has_var_checks_parent() -> void:
	var parent_bb := AIBlackboard.new()
	parent_bb.set_var(&"y", 99)
	_bb.parent = parent_bb
	assert_true(_bb.has_var(&"y"))
