class_name Beetle extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
}

@onready var head: Node2D = $Head
@onready var animated_sprite: AnimatedSprite2D = $Head/AnimatedSprite2D
@onready var chase_area: Area2D = $ChaseArea
@onready var kill_area: Area2D = $KillArea
@onready var return_spawn_timer: Timer = $ReturnSpawnTimer
@onready var spawn_position: Vector2 = global_position

var state: State = State.IDLE
