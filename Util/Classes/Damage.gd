extends Resource
class_name Damage

@export var max_amount: float = 50.0
@export var min_amount: float = 1.0
@export var amount: float = 10.0
@export_enum("Physical", "KnockUp", "KnockBack") var type: String = "Physical"
