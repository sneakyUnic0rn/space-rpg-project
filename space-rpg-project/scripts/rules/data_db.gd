class_name DataDB
## Loads JSON tables from res://data/ once and keeps them in memory.
## Keys starting with "_" (like "_readme") are notes and are skipped.
##   DataDB.table("weapons")["Assault Rifle"]

static var _tables: Dictionary = {}


static func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		_tables[table_name] = _load("res://data/%s.json" % table_name)
	return _tables[table_name]


static func entry(table_name: String, key: String) -> Dictionary:
	return table(table_name).get(key, {})


static func _load(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataDB: could not parse %s" % path)
		return {}
	var result := {}
	for key in parsed:
		if not String(key).begins_with("_"):
			result[key] = parsed[key]
	return result
