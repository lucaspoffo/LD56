extends Node2D

var PLAYER_CORPSE_SCENE := preload("res://scenes/player_corpse.tscn")

@export var PLAYER_SPEED: float = 100
@export var SPIT_SPEED: float = 200
@export var SHIT_DURATION: float = 5

@export var WANDER_MOB_SPEED: float = 50
@export var WANDER_MOB_CHASE_SPEED: float = 150
@export var WANDER_MOB_AFRAID_RANGE: float = 60
@export var SPIT_DISTANCE: float = 200

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var grass: Area2D = $Grass
var wander_mobs: Array[WanderMob]
var camera_views: Array[CameraView]
var shit_areas: Array[Area2D]

@onready var player_start_position = player.global_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera_views.assign(get_tree().get_nodes_in_group("camera-view"))
	wander_mobs.assign(get_tree().get_nodes_in_group("wander-mob"))
	shit_areas.assign(get_tree().get_nodes_in_group("shit-area"))
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Update player
	match player.state:
		Player.State.NORMAL:
			var input_direction = Input.get_vector("left", "right", "up", "down")
			player.velocity = input_direction * PLAYER_SPEED
			player.move_and_slide()
		Player.State.SPIT:
			var direction = (player.spit_destination - player.global_position).normalized()
			player.velocity = direction * SPIT_SPEED
			player.move_and_slide()
			print(player.global_position.distance_to(player.spit_destination))
			if player.global_position.distance_to(player.spit_destination) < 5:
				player.state = Player.State.NORMAL
	
	var player_being_spat = player.state == Player.State.SPIT
	var player_in_grass := false
	if grass.overlaps_body(player):
		player_in_grass = true
	
	var player_corpses: Array[PlayerCorpse]
	player_corpses.assign(get_tree().get_nodes_in_group("player-corpse"))
	for corpse in player_corpses:
		if corpse.grass_area.overlaps_body(player):
			player_in_grass = true
	
	# Check in shit
	for shit in shit_areas:
		if shit.overlaps_body(player):
			player.has_shit = true
			player.shit_timer.start(SHIT_DURATION)
			player.modulate = Color.SADDLE_BROWN
	
	# Update mobs
	for mob in wander_mobs:
		
		match mob.state:
			WanderMob.State.WANDER:
				#if mob.global_position.distance_to(player.global_position) < WANDER_MOB_AFRAID_RANGE:
				#	mob.state = WanderMob.State.AFRAID
				#	continue
				if !player_in_grass and mob.global_position.distance_to(player.global_position) < WANDER_MOB_AFRAID_RANGE * 2:
					mob.state = WanderMob.State.CHASE
					continue
				if mob.wander_timer.time_left == 0:
					mob.wander_timer.start(3)
					mob.wander_destination = mob.initial_position + Vector2(randf_range(-mob.wander_range, mob.wander_range), randf_range(-mob.wander_range, mob.wander_range))
				
				if mob.global_position.distance_to(mob.wander_destination) > 5:
					var direction = mob.global_position.direction_to(mob.wander_destination)
					mob.velocity = direction * WANDER_MOB_SPEED
					mob.move_and_slide()
				
			WanderMob.State.AFRAID:
				if mob.afraid_timer.time_left == 0:
					mob.afraid_timer.start(1)
					if mob.global_position.distance_to(player.global_position) >= WANDER_MOB_AFRAID_RANGE:
						mob.state = WanderMob.State.WANDER
						mob.wander_timer.start(0)
						continue
			
				
				var direction = player.global_position.direction_to(mob.global_position)
				mob.velocity = direction * WANDER_MOB_SPEED
				mob.move_and_slide()
			WanderMob.State.CHASE:
				if player_in_grass || player_being_spat:
					mob.state = WanderMob.State.WANDER
					continue
				if mob.kill_area.overlaps_body(player):
					if player.has_shit:
						var direction = mob.global_position.direction_to(player.global_position)
						var destination = mob.global_position + direction.normalized() * SPIT_DISTANCE
						player.spit_destination = destination
						player.state = Player.State.SPIT
						mob.state = WanderMob.State.WANDER
						continue
					else:
						kill_player()
						mob.state = WanderMob.State.WANDER
						continue
				var direction = mob.global_position.direction_to(player.global_position)
				mob.velocity = direction * WANDER_MOB_CHASE_SPEED
				mob.move_and_slide()
				
	
	var active_view: CameraView = null
	var view_rect: Rect2i = Rect2i()
	for view in camera_views:
		var camera_rect: Rect2i = view.rect
		camera_rect.position = Vector2i(view.global_position)
		if camera_rect.has_point(player.global_position + Vector2(8, 8)):
			view_rect = camera_rect
	
	if view_rect:
		var position := player.global_position
		position.x = min(position.x, view_rect.get_center().x + (view_rect.size.x / 2. - 160))
		position.x = max(position.x, view_rect.get_center().x - (view_rect.size.x / 2. - 160))
		position.y = min(position.y, view_rect.get_center().y + (view_rect.size.y / 2. - 120))
		position.y = max(position.y, view_rect.get_center().y - (view_rect.size.y / 2. - 120))
		camera.global_position = position
	else:
		camera.global_position = player.global_position
		
func kill_player():
	var corpse = PLAYER_CORPSE_SCENE.instantiate()
	corpse.global_position = player.global_position
	add_child(corpse)
	player.reset()
	player.global_position = player_start_position
	
