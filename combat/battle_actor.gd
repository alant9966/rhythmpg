extends Node2D
## RPG Maker-style side-view sheet: 9 columns x 6 rows, 3 frames per motion.
const MOTION_WALK := 0
const MOTION_IDLE := 1

var texture: Texture2D
var cell := Vector2(48, 48)
var motion := 1
var clock := 0.0
var flash := 0.0
var dead := false
var facing_right := false
var sprite: Sprite2D
var ground := Vector2.ZERO

func setup(path: String, feet: Vector2, depth_scale: float, enemy: bool = false) -> void:
	texture = load(path)
	cell = texture.get_size() / Vector2(9, 6)
	position = feet
	ground = feet
	scale = Vector2.ONE * depth_scale
	facing_right = enemy

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.position = Vector2(0, -cell.y * 0.5)
	sprite.flip_h = facing_right
	add_child(sprite)

func play(value: int) -> void:
	motion = value
	clock = 0.0

func face_direction(direction: Vector2) -> void:
	if absf(direction.x) < 0.01:
		return
	facing_right = direction.x > 0
	if is_instance_valid(sprite):
		sprite.flip_h = facing_right

func _process(delta: float) -> void:
	clock += delta
	flash = maxf(0, flash - delta)
	var frame := mini(2, int(clock * 8)) if motion in [4, 7, 10, 17] else int(clock * 5) % 3
	var column := (motion / 6) * 3 + frame
	var row := motion % 6
	sprite.region_rect = Rect2(Vector2(column * cell.x, row * cell.y), cell)
	sprite.modulate = Color(3, 1.5, 1.2) if flash > 0 else (Color("858595") if dead else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, -2), 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, cell.x * 0.26, Color(0.02, 0.03, 0.04, 0.48))
	draw_set_transform(Vector2.ZERO)
