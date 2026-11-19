class_name Weapon
extends RefCounted
## One weapon a unit carries: stats from data/weapons.json plus its current ammo/jam state.

const METRES_PER_TILE := 1.5

var weapon_name: String
var skill: String
var damage  # String like "2d6", or an Array of {"max_m", "dice"} bands
var range_m: float
var mag: int
var malf: int
var properties: Array
var edge: String
var point_blank: String
var armour_mode: String  # "normal", "piercing" or "ignore"

var ammo: int
var jammed := false


static func create(name: String) -> Weapon:
	var d := DataDB.entry("weapons", name)
	if d.is_empty():
		push_error("Unknown weapon: %s" % name)
		return null
	var w := Weapon.new()
	w.weapon_name = name
	w.skill = d["skill"]
	w.damage = d["damage"]
	w.range_m = d["range_m"]
	w.mag = d["mag"]
	w.malf = d["malf"]
	w.properties = d.get("properties", [])
	w.edge = d.get("edge", "")
	w.point_blank = d.get("point_blank", "")
	w.armour_mode = d.get("armour", "normal")
	w.ammo = w.mag
	return w


func has(property: String) -> bool:
	return property in properties


## Damage dice at a given distance (shotguns get weaker with range).
func damage_dice(distance_m: float) -> String:
	if damage is String:
		return damage
	for band in damage:
		if distance_m <= band["max_m"]:
			return band["dice"]
	return damage.back()["dice"]


## Armour after this weapon's piercing/energy rules.
func effective_armour(armour: int) -> int:
	match armour_mode:
		"piercing": return armour / 2
		"ignore": return 0
	return armour


func ammo_text() -> String:
	return "%s %d/%d%s" % [weapon_name, ammo, mag, "  JAMMED" if jammed else ""]
