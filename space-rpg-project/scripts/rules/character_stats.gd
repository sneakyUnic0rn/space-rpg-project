class_name CharacterStats
extends Resource
## The numbers behind one character: attributes, luck and skill points.
## Being a Resource means a character can later be saved as a .tres file
## and edited in the Inspector.

const ATTRIBUTES: Array[String] = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const ATTRIBUTE_START := 40

@export var display_name: String = "Unnamed"
@export var attributes: Dictionary[String, int] = {
	"STR": ATTRIBUTE_START, "DEX": ATTRIBUTE_START, "CON": ATTRIBUTE_START,
	"INT": ATTRIBUTE_START, "WIS": ATTRIBUTE_START, "CHA": ATTRIBUTE_START,
}
@export var luck: int = 50
## Points invested in each skill ON TOP of its base value.
@export var skill_points: Dictionary[String, int] = {}


func get_attribute(attr: String) -> int:
	return attributes.get(attr, 0)


## HP = (CON + STR) / 10, from the core design doc.
func max_hp() -> int:
	return (get_attribute("CON") + get_attribute("STR")) / 10


## Final skill value = base (from data/skills.json) + invested points, capped 0..100.
## Base is attribute / 2 for weapon skills and Dodge, attribute / 5 for the rest.
## If a skill lists several attributes (Melee: STR or DEX), the highest is used.
## `attribute_override` forces one attribute.
func get_skill(skill_name: String, attribute_override: String = "") -> int:
	var def := SkillDB.get_def(skill_name)
	if def.is_empty():
		push_warning("Unknown skill: %s" % skill_name)
		return 0
	var attr_value := 0
	if attribute_override != "":
		attr_value = get_attribute(attribute_override)
	elif def["attribute"] is Array:
		for a in def["attribute"]:
			attr_value = maxi(attr_value, get_attribute(a))
	else:
		attr_value = get_attribute(def["attribute"])

	var base := 0
	match def["base"]:
		"half", "half_attribute":
			base = attr_value / 2
		"fifth":
			base = attr_value / 5
		_:
			base = int(def["base"])
	return clampi(base + skill_points.get(skill_name, 0), 0, 100)


## Roll a skill check for this character.
func check_skill(skill_name: String, required: SkillCheck.Level = SkillCheck.Level.REGULAR,
		bonus_penalty: int = 0, attribute_override: String = "") -> SkillCheck.Result:
	return SkillCheck.check(get_skill(skill_name, attribute_override), required, bonus_penalty)


## Roll straight against an attribute (e.g. a CON check to resist poison).
func check_attribute(attr: String, required: SkillCheck.Level = SkillCheck.Level.REGULAR,
		bonus_penalty: int = 0) -> SkillCheck.Result:
	return SkillCheck.check(get_attribute(attr), required, bonus_penalty)
