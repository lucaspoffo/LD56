class_name Vine extends StaticBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var death_timer: Timer = $DeathTimer 

func _on_death_duration_timeout() -> void:
	collision.disabled = false
	animated_sprite.modulate = Color.GREEN
