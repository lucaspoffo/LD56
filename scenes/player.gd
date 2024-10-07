class_name Player extends CharacterBody2D

enum State {
	NORMAL,
	SPIT
}

@onready var poison_timer: Timer = $PoisonTimer
@onready var spit_timer: Timer = $SpitTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var grass: AnimatedSprite2D = $Grass

var state: State = State.NORMAL
var has_poison := false 
var spit_direction: Vector2 = Vector2.RIGHT
