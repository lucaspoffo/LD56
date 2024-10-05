class_name Player extends CharacterBody2D

enum State {
	NORMAL,
	SPIT
}

@onready var shit_timer: Timer = $ShitTimer

var state: State = State.NORMAL
var has_shit := false 
var spit_destination: Vector2

func reset():
	has_shit = false
	shit_timer.stop()
	modulate = Color.WHITE

func _on_shit_timer_timeout() -> void:
	has_shit = false
	modulate = Color.WHITE
