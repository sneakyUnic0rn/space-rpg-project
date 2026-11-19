class_name BattleHUD
extends Control
## On-screen UI for the battle: info at the top, combat log on the right,
## action bar at the bottom. Sends button presses to the battle scene via signals.

signal action_pressed(action: BattleAction)
signal end_turn_pressed

var info_label := Label.new()
var _log := RichTextLabel.new()
var _unit_label := Label.new()
var _budget_label := RichTextLabel.new()
var _action_row := HBoxContainer.new()
var _end_turn := Button.new()
var _buttons := {}  # BattleAction -> Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Top-left info
	info_label.position = Vector2(16, 12)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 4)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_label)

	# Right: combat log
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	log_panel.offset_left = -380
	log_panel.offset_top = 12
	log_panel.offset_right = -12
	log_panel.offset_bottom = -116
	log_panel.add_theme_stylebox_override("panel", _panel_style(0.7))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_panel)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	log_panel.add_child(_log)

	# Bottom: action bar
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -100
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_bottom = -12
	bar.add_theme_stylebox_override("panel", _panel_style(0.9))
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	var unit_box := VBoxContainer.new()
	unit_box.custom_minimum_size.x = 280
	_unit_label.add_theme_font_size_override("font_size", 16)
	unit_box.add_child(_unit_label)
	_budget_label.bbcode_enabled = true
	_budget_label.fit_content = true
	_budget_label.scroll_active = false
	_budget_label.custom_minimum_size = Vector2(280, 44)
	unit_box.add_child(_budget_label)
	row.add_child(unit_box)

	_action_row.add_theme_constant_override("separation", 8)
	_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_action_row)

	_end_turn.text = "End Turn"
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn.tooltip_text = "Enter"
	_end_turn.custom_minimum_size = Vector2(100, 0)
	_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	row.add_child(_end_turn)


func _panel_style(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, alpha)
	sb.border_color = Color(0.3, 0.35, 0.45, alpha)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb


func set_actions(actions: Array[BattleAction]) -> void:
	for child in _action_row.get_children():
		child.queue_free()
	_buttons.clear()
	for i in actions.size():
		var action := actions[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, action.button_text()]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func(): action_pressed.emit(action))
		_action_row.add_child(b)
		_buttons[action] = b


## Redraw the action bar for the selected unit.
func refresh(unit: Unit, is_player_phase: bool) -> void:
	_end_turn.disabled = not is_player_phase
	if unit == null or not is_player_phase:
		_unit_label.text = "Enemy turn..." if not is_player_phase else "No unit selected"
		_budget_label.text = ""
		for action in _buttons:
			_buttons[action].disabled = true
		return

	var b := unit.budget
	_unit_label.text = "%s   HP %d/%d   Armour %d" % [unit.name, unit.hp, unit.max_hp, unit.armour]
	var move_text := "[color=#7fd3ff]Move ●[/color]" if b.can_move() else "[color=#666]Move ○[/color]"
	var pips := ""
	for i in TurnBudget.ACTIONS_PER_TURN:
		pips += "●" if i < b.actions_left else "○"
	var weapon_text := unit.weapon.ammo_text() if unit.weapon else "Unarmed"
	if unit.aim_bonus > 0:
		weapon_text += "  [color=#9f9]Aimed[/color]"
	_budget_label.text = "%s   [color=#ffd24d]Actions %s[/color]\n%s" % [move_text, pips, weapon_text]

	for action in _buttons:
		var reason := b.why_not(action)
		if reason == "":
			reason = action.blocked_reason(unit)
		_buttons[action].disabled = reason != ""
		_buttons[action].tooltip_text = action.description + ("" if reason == "" else "\n\n" + reason)


func log_line(text: String, color: String = "") -> void:
	if color != "":
		_log.append_text("[color=%s]%s[/color]\n" % [color, text])
	else:
		_log.append_text(text + "\n")


func log_text() -> String:
	return _log.get_parsed_text()
