class_name Player extends CharacterBody2D

enum State {
	NORMAL,
	SPIT
}

@onready var poison_timer: Timer = $PoisonTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var grass: AnimatedSprite2D = $Grass

var state: State = State.NORMAL
var has_poison := false 
var spit_destination: Vector2	

func _on_shit_timer_timeout() -> void:
	has_poison = false
	modulate = Color.WHITE
