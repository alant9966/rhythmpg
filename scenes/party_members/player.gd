extends CharacterBody2D

var direction = Vector2.ZERO
const SPEED = 150.0

func _physics_process(_delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	
	if direction:
		velocity = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	animate()
	move_and_slide()

func animate():
	if !velocity:
		$AnimatedSprite2D.frame = 0
	else:
		if direction.x:
			$AnimatedSprite2D.animation = "overworld_left"
			$AnimatedSprite2D.flip_h = direction.x > 0
		else:
			$AnimatedSprite2D.animation = "overworld_down" if direction.y > 0 else "overworld_up"
