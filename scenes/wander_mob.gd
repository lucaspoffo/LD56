@tool
class_name WanderMob extends CharacterBody2D

enum State {
	WANDER,
	AFRAID,
	CHASE,
}

@onready var wander_timer: Timer = $WanderTimer
@onready var afraid_timer: Timer = $AfraidTimer
@onready var kill_area: Area2D = $KillArea
@onready var initial_position: Vector2 = global_position

var state := State.WANDER
var wander_destination: Vector2
@export var wander_range: float = 100

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

var current_left_leg := Vector2.ZERO

var current_legs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, wander_range, Color.RED, false, 1)
