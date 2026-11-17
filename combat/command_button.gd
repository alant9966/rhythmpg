extends Button
## Traditional battle-menu rows, with independently aligned hotkey and MP cost.
const BODY = preload("res://ui/clear_font.tres")
var key_label := ""
var command_name := ""
var price := ""
func configure(key: String, label: String, cost: String) -> void:
	key_label = key
	command_name = label
	price = cost
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("e5dcc8")
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("c5ae7b")
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover", selected)
	add_theme_stylebox_override("focus", selected)
	add_theme_stylebox_override("pressed", pressed)
func _draw() -> void:
	var selected := not disabled and (is_hovered() or has_focus())
	var ink := Color("27241e") if selected else (Color("6e6b63") if disabled else Color("eee7d7"))
	var secondary := Color("625844") if selected else Color("9c9482")
	if selected:
		draw_colored_polygon(PackedVector2Array([Vector2(10, 10), Vector2(10, 21), Vector2(17, 15.5)]), ink)
	draw_string(BODY, Vector2(24, 21), key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, secondary)
	draw_string(BODY, Vector2(48, 22), command_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	if not price.is_empty():
		draw_string(BODY, Vector2(size.x - 78, 21), price, HORIZONTAL_ALIGNMENT_RIGHT, 66, 14, secondary)
