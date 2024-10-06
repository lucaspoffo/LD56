class_name MushroomProjectile extends Node2D

@onready var area: Area2D = $Area2D

var direction: Vector2

func _on_duration_timer_timeout() -> void:
	queue_free()
