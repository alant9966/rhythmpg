extends Node2D

func _static_enemy_one_area_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		get_tree().change_scene_to_file.call_deferred("res://scenes/combat.tscn")

func _go_to_world_2_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		get_tree().change_scene_to_file.call_deferred("res://scenes/maps/overworld_map_2.tscn")
