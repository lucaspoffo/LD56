class_name Mushroom extends StaticBody2D

enum State {
	IDLE,
	SHOOT,
	STOMP
}

var state = State.IDLE

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_area: Area2D = $ShootRange
@onready var stomp_area: Area2D = $StompRange
@onready var stomp_cd: Timer = $StompCD
@onready var shoot_cd: Timer = $ShootCD
