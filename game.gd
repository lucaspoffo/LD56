extends Node2D

var PLAYER_CORPSE_SCENE := preload("res://scenes/player_corpse.tscn")
var MUSHROOM_PROJECTILE_SCENE := preload("res://scenes/mushroom_projectile.tscn")
var MUSHROOM_GAS_SCENE := preload("res://scenes/mushroom_gas.tscn")

@export var PLAYER_SPEED: float = 100
@export var PLAYER_POISON_SPEED: float = 70
@export var SPIT_SPEED: float = 200

@export var WANDER_MOB_SPEED: float = 50
@export var WANDER_MOB_CHASE_RANGE: float = 120
@export var WANDER_MOB_CHASE_SPEED: float = 150
@export var WANDER_MOB_CHASE_DISTANCE: float = 150
@export var WANDER_MOB_AFRAID_RANGE: float = 60
@export var SPIT_DISTANCE: float = 200

@export var MUSHROOM_PROJECTILE_SPEED := 200

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var grass: Area2D = $Grass
var wander_mobs: Array[WanderMob]
var mushrooms: Array[Mushroom]
var camera_views: Array[CameraView]
var shit_areas: Array[Area2D]

@onready var player_start_position = player.global_position

func _ready() -> void:
	camera_views.assign(get_tree().get_nodes_in_group("camera-view"))
	wander_mobs.assign(get_tree().get_nodes_in_group("wander-mob"))
	shit_areas.assign(get_tree().get_nodes_in_group("shit-area"))
	mushrooms.assign(get_tree().get_nodes_in_group("mushroom"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Update player
	match player.state:
		Player.State.NORMAL:
			player.set_collision_mask_value(4, true) # enable hole collsion
			var input_direction = Input.get_vector("left", "right", "up", "down")
			var speed := PLAYER_SPEED
			if player.has_poison:
				speed = PLAYER_POISON_SPEED
			player.velocity = input_direction * speed
			player.move_and_slide()
			if input_direction:
				player.animated_sprite.flip_h = input_direction.x > 0
				player.animated_sprite.play("Run")
			else:
				player.animated_sprite.play("Idle")
				
		Player.State.SPIT:
			player.set_collision_mask_value(4, false) # disable hole collsion
			var direction = (player.spit_destination - player.global_position).normalized()
			player.velocity = direction * SPIT_SPEED
			player.move_and_slide()
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
			poison_player()
	
	# Update WanderMobs
	for mob in wander_mobs:
		match mob.state:
			WanderMob.State.WANDER:
				#if mob.global_position.distance_to(player.global_position) < WANDER_MOB_AFRAID_RANGE:
				#	mob.state = WanderMob.State.AFRAID
				#	continue
				if !player_in_grass and mob.global_position.distance_to(player.global_position) < WANDER_MOB_CHASE_RANGE:
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
				var player_distance := mob.global_position.distance_to(player.global_position)
				if player_in_grass || player_being_spat || player_distance > WANDER_MOB_CHASE_DISTANCE:
					mob.state = WanderMob.State.WANDER
					continue
				if mob.kill_area.overlaps_body(player):
					if player.has_poison:
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
	
	# Update Mushrooms
	for mushroom in mushrooms:
		match mushroom.state:
			Mushroom.State.IDLE:
				mushroom.animated_sprite.play("Idle")
				if mushroom.stomp_area.overlaps_body(player) and mushroom.stomp_cd.time_left == 0:
					mushroom.state = Mushroom.State.STOMP
					mushroom.animated_sprite.play("Stomp")
					mushroom.stomp_cd.start()
					continue
				if mushroom.shoot_area.overlaps_body(player) and !mushroom.stomp_area.overlaps_body(player) and mushroom.shoot_cd.time_left == 0:
					mushroom.state = Mushroom.State.SHOOT
					mushroom.animated_sprite.play("Shoot")
					mushroom.shoot_cd.start()
					continue
			Mushroom.State.SHOOT:
				if !mushroom.animated_sprite.is_playing():
					var projectile := MUSHROOM_PROJECTILE_SCENE.instantiate()
					var direction = mushroom.global_position.direction_to(player.global_position)
					projectile.direction = direction
					projectile.global_position = mushroom.global_position
					add_child(projectile)
					mushroom.state = Mushroom.State.IDLE
					
			Mushroom.State.STOMP:
				if !mushroom.animated_sprite.is_playing():
					if mushroom.stomp_area.overlaps_body(player):
						poison_player()
					var gas = MUSHROOM_GAS_SCENE.instantiate()
					mushroom.add_child(gas)
					mushroom.state = Mushroom.State.IDLE
					
	
	# Update Mushroom projectiles
	var projectile_mushrooms: Array[MushroomProjectile]
	projectile_mushrooms.assign(get_tree().get_nodes_in_group("mushroom-projectile"))
	for projectile in projectile_mushrooms:
		projectile.global_position += projectile.direction * MUSHROOM_PROJECTILE_SPEED * delta
		var bodies := projectile.area.get_overlapping_bodies()
		for body in bodies:
			if body is not Mushroom:
				projectile.queue_free()
			if body is Player:
				kill_player()
			if body is Vine:
				body.animated_sprite.play("Death")
				body.collision.disabled = true
				body.animated_sprite.modulate = Color(0, 1, 0, .1)
				body.death_timer.start()
	
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

func poison_player():
	player.has_poison = true
	player.poison_timer.start()
	player.modulate = Color.DARK_GREEN

func kill_player():
	var corpse = PLAYER_CORPSE_SCENE.instantiate()
	corpse.global_position = player.global_position
	add_child(corpse)
	
	player.has_poison = false
	player.poison_timer.stop()
	player.modulate = Color.WHITE
	player.global_position = player_start_position
	
