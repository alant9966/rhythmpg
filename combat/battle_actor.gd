extends Node2D
## Visuals and frame animations are authored in the reusable actor scene.
@export var has_timpani := false
@export var idle_animation: StringName = &"idle"
@onready var sprite: Sprite2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timpani: Node2D = $TimpaniProps
var ground := Vector2.ZERO
var motion := -1
var flash := 0.0
var dead := false
const MOTIONS := {1: "idle", 2: "chant", 3: "guard", 4: "hurt", 7: "attack",
	9: "drum", 10: "cast", 13: "victory", 17: "defeat"}

func _ready() -> void:
	ground = position
	timpani.visible = has_timpani
	play(1)

func play(value: int) -> void:
	if motion == value and (animation_player.is_playing() or value in [4, 7, 10, 17]):
		return
	motion = value
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector2.ONE
	animation_player.play(idle_animation if value == 1 else MOTIONS.get(value, "idle"))

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	sprite.modulate = Color(3, 1.5, 1.2) if flash > 0 else (Color("858595") if dead else Color.WHITE)
	timpani.visible = has_timpani and not dead
