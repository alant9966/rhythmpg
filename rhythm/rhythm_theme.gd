extends RefCounted
## Shared battle/practice presentation. Coordinates use the 1200 x 800 canvas.
const GOLD := Color("c5ae7b")
const INK := Color("eee7d7")
const MUTED := Color("aaa595")
const TEAL := Color("9ba982")

static func panel(fill: Color = Color("20211c"), edge: Color = Color("5c5646")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	return style

static func button(control: Button) -> void:
	control.add_theme_font_size_override("font_size", 17)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", GOLD)
	control.add_theme_color_override("font_disabled_color", Color("6e8089"))
	control.add_theme_stylebox_override("normal", panel(Color("23251f")))
	control.add_theme_stylebox_override("hover", panel(Color("3d3d31"), GOLD))
	control.add_theme_stylebox_override("pressed", panel(Color("54513f"), GOLD))
	control.add_theme_stylebox_override("disabled", panel(Color("1b1c18"), Color("35372e")))
