class_name SkillDB
## Skill definitions from data/skills.json. Change numbers in the JSON, not in code.


static func all() -> Dictionary:
	return DataDB.table("skills")


static func has(skill_name: String) -> bool:
	return all().has(skill_name)


static func get_def(skill_name: String) -> Dictionary:
	return all().get(skill_name, {})
