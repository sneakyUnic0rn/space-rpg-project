class_name SkillDB
## Reads skill definitions from data/skills.json once and keeps them in memory.
## Change numbers in the JSON, not in code.

const PATH := "res://data/skills.json"

static var _skills: Dictionary = {}


static func all() -> Dictionary:
	if _skills.is_empty():
		_load()
	return _skills


static func has(skill_name: String) -> bool:
	return all().has(skill_name)


static func get_def(skill_name: String) -> Dictionary:
	return all().get(skill_name, {})


static func _load() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SkillDB: could not parse %s" % PATH)
		return
	for key in parsed:
		if not String(key).begins_with("_"):
			_skills[key] = parsed[key]
