extends RefCounted
## Shared battle/practice presentation. Coordinates use the 1200 x 800 canvas.
const GOLD := Color("eaca8a")
const INK := Color("eef0e9")
const MUTED := Color("a5b4bd")
const TEAL := Color("83d4c4")

static func panel(fill: Color = Color("152530"), edge: Color = Color("52615f")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

static func button(control: Button) -> void:
	control.add_theme_font_size_override("font_size", 17)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", GOLD)
	control.add_theme_color_override("font_disabled_color", Color("6e8089"))
	control.add_theme_stylebox_override("normal", panel(Color("1c2c37")))
	control.add_theme_stylebox_override("hover", panel(Color("31434b"), GOLD))
	control.add_theme_stylebox_override("pressed", panel(Color("41534e"), GOLD))
	control.add_theme_stylebox_override("disabled", panel(Color("17242d"), Color("303f47")))
