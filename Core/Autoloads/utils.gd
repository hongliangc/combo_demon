extends Node
class_name Utils

func time():
	var dt = Time.get_datetime_dict_from_system()
	print("%04d-%02d-%02d %02d:%02d:%02d.%03d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second,
		dt.millisecond
	])

#static func 是线程安全的前提（没有使用共享状态）。
static func has_member_variable(obj: Object, var_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == var_name:
			return true
	return false
