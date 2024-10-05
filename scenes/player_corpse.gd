class_name PlayerCorpse extends Node2D

@onready var grass_area: Area2D = $Area2D


func _on_corpse_duration_timeout() -> void:
	queue_free()
