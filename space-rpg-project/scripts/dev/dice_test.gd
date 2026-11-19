extends Control
## Dev playground for the rules core. Not part of the real game.
## Pick a skill, difficulty and bonus/penalty dice, then roll and read the log.

var stats := CharacterStats.new()

var _skill_select := OptionButton.new()
var _difficulty_select := OptionButton.new()
var _bonus_penalty := SpinBox.new()
var _log := RichTextLabel.new()
var _summary := Label.new()


func _ready() -> void:
	# A sample character so the numbers mean something.
	stats.display_name = "Test Marine"
	stats.attributes = {"STR": 55, "DEX": 70, "CON": 50, "INT": 45, "WIS": 40, "CHA": 40}
	stats.skill_points = {"Firearms": 20, "Perception": 15}
	_build_ui()
	_refresh_summary()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Rules Core: d100 Skill Check Test"
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)
	col.add_child(_summary)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	for skill_name in SkillDB.all():
		_skill_select.add_item(skill_name)
	_skill_select.item_selected.connect(func(_i): _refresh_summary())
	row.add_child(_labeled("Skill", _skill_select))

	for level in [SkillCheck.Level.REGULAR, SkillCheck.Level.HARD, SkillCheck.Level.EXTREME]:
		_difficulty_select.add_item(SkillCheck.level_to_string(level), level)
	row.add_child(_labeled("Difficulty", _difficulty_select))

	_bonus_penalty.min_value = -SkillCheck.MAX_BONUS_PENALTY
	_bonus_penalty.max_value = SkillCheck.MAX_BONUS_PENALTY
	_bonus_penalty.tooltip_text = "Positive = bonus dice, negative = penalty dice"
	row.add_child(_labeled("Bonus/Penalty dice", _bonus_penalty))

	var roll_btn := Button.new()
	roll_btn.text = "Roll"
	roll_btn.pressed.connect(_on_roll)
	row.add_child(roll_btn)

	var sim_btn := Button.new()
	sim_btn.text = "Simulate 10,000 rolls"
	sim_btn.pressed.connect(_on_simulate)
	row.add_child(sim_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func(): _log.clear())
	row.add_child(clear_btn)

	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_log)


func _labeled(text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = text
	box.add_child(label)
	box.add_child(control)
	return box


func _current_skill() -> String:
	return _skill_select.get_item_text(_skill_select.selected)


func _current_difficulty() -> SkillCheck.Level:
	return _difficulty_select.get_item_id(_difficulty_select.selected) as SkillCheck.Level


func _refresh_summary() -> void:
	var attrs := []
	for a in CharacterStats.ATTRIBUTES:
		attrs.append("%s %d" % [a, stats.get_attribute(a)])
	_summary.text = "%s  |  %s  |  %s skill: %d" % [
		stats.display_name, "  ".join(attrs), _current_skill(), stats.get_skill(_current_skill())]


func _on_roll() -> void:
	var result := stats.check_skill(_current_skill(), _current_difficulty(), int(_bonus_penalty.value))
	var color := "green" if result.succeeded() else "red"
	_log.append_text("[b]%s[/b]: [color=%s]%s[/color]\n" % [_current_skill(), color, result.describe()])


func _on_simulate() -> void:
	var n := 10000
	var by_level := {}
	var successes := 0
	for i in n:
		var r := stats.check_skill(_current_skill(), _current_difficulty(), int(_bonus_penalty.value))
		by_level[r.level] = by_level.get(r.level, 0) + 1
		if r.succeeded():
			successes += 1
	var parts := []
	for level in range(SkillCheck.Level.CRITICAL, -1, -1):
		parts.append("%s %.1f%%" % [SkillCheck.level_to_string(level), by_level.get(level, 0) * 100.0 / n])
	_log.append_text("[b]Simulated %d %s checks[/b] (skill %d, need %s, dice %+d): [b]%.1f%% success[/b]\n    %s\n" % [
		n, _current_skill(), stats.get_skill(_current_skill()),
		SkillCheck.level_to_string(_current_difficulty()), int(_bonus_penalty.value),
		successes * 100.0 / n, "  |  ".join(parts)])
