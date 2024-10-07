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

@export var BEETLE_CHASE_SPEED: float = 30

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var save_bunny_label: Label = $CanvasLayer/SaveBunnyLabel

var wander_mobs: Array[WanderMob]
var mushrooms: Array[Mushroom]
var beetles: Array[Beetle]
var camera_views: Array[CameraView]
var poison_areas: Array[Area2D]

var panning_camera := false

@onready var player_start_position = player.global_position

func _ready() -> void:
	camera_views.assign(get_tree().get_nodes_in_group("camera-view"))
	wander_mobs.assign(get_tree().get_nodes_in_group("wander-mob"))
	poison_areas.assign(get_tree().get_nodes_in_group("poison-area"))
	mushrooms.assign(get_tree().get_nodes_in_group("mushroom"))
	beetles.assign(get_tree().get_nodes_in_group("beetle"))
	
	camera_pan_bunnies()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if panning_camera:
		return
	# Update player
	match player.state:
		Player.State.NORMAL:
			player.set_collision_mask_value(4, true) # enable hole collision
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
	camera.global_position = player.global_position
	
	# Check bunnies collected
	var bunnies: Array[Area2D]
	bunnies.assign(get_tree().get_nodes_in_group("bunny"))
	if bunnies.is_empty():
		# TODO: show win window
		return
	
	for bunny in bunnies:
		if bunny.overlaps_body(player):
			bunny.queue_free()
			camera_pan_bunnies()
	
	# Check grass
	var player_in_grass := false
	var player_grass_cord: Vector2i = tile_map.local_to_map(tile_map.to_local(player.global_position))
	var player_tile: TileData = tile_map.get_cell_tile_data(player_grass_cord)
	if player_tile && player_tile.get_custom_data("grass"):
		player_in_grass = true
	
	var player_corpses: Array[PlayerCorpse]
	player_corpses.assign(get_tree().get_nodes_in_group("player-corpse"))
	for corpse in player_corpses:
		if corpse.grass_area.overlaps_body(player):
			player_in_grass = true
	
	# Collision layer for player not in grass
	player.set_collision_layer_value(6, !player_in_grass)
	player.grass.visible = player_in_grass
	
	# Check in poison
	for poison in poison_areas:
		if poison.overlaps_body(player):
			poison_player()
	
	# Update WanderMobs
	for mob in wander_mobs:
		match mob.state:
			WanderMob.State.WANDER:
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
				# Stomp
				if mushroom.stomp_area.overlaps_body(player) and mushroom.stomp_cd.time_left == 0:
					mushroom.state = Mushroom.State.STOMP
					mushroom.stomped = false
					mushroom.animated_sprite.play("Stomp")
					mushroom.stomp_cd.start()
					continue
				# Shoot
				var target
				var bodies := mushroom.shoot_area.get_overlapping_bodies()
				var has_target: bool = !bodies.is_empty()
				if has_target and !mushroom.stomp_area.overlaps_body(player) and mushroom.shoot_cd.time_left == 0:
					mushroom.shotted = false
					mushroom.state = Mushroom.State.SHOOT
					mushroom.target = bodies[0]
					mushroom.animated_sprite.play("Shoot")
					mushroom.shoot_cd.start()
					continue
			Mushroom.State.SHOOT:
				if mushroom.animated_sprite.frame == 7 and !mushroom.shotted:
					mushroom.shotted = true
					if mushroom.target:
						var projectile := MUSHROOM_PROJECTILE_SCENE.instantiate()
						var direction = mushroom.global_position.direction_to(mushroom.target.global_position)
						projectile.direction = direction
						projectile.global_position = mushroom.global_position
						add_child(projectile)
				if !mushroom.animated_sprite.is_playing():
					mushroom.state = Mushroom.State.IDLE
					
			Mushroom.State.STOMP:
				if mushroom.animated_sprite.frame == 7 and !mushroom.stomped:
					mushroom.stomped = true
					if mushroom.stomp_area.overlaps_body(player):
						poison_player()
					var gas = MUSHROOM_GAS_SCENE.instantiate()
					mushroom.add_child(gas)
				
				if !mushroom.animated_sprite.is_playing():
					mushroom.state = Mushroom.State.IDLE
	
	# Update Mushroom projectiles
	var projectile_mushrooms: Array[MushroomProjectile]
	projectile_mushrooms.assign(get_tree().get_nodes_in_group("mushroom-projectile"))
	for projectile in projectile_mushrooms:
		projectile.global_position += projectile.direction * MUSHROOM_PROJECTILE_SPEED * delta
		var bodies := projectile.area.get_overlapping_bodies()
		for body in bodies:
			if body is not Mushroom and body is not Beetle:
				projectile.queue_free()
			if body is Player:
				kill_player()
			if body is Vine:
				body.animated_sprite.play("Death")
				body.collision.disabled = true
				body.death_timer.start()
			if body is Beetle:
				projectile.direction = Vector2.from_angle(body.head.rotation)
	
	# Update Beetles
	for beetle in beetles:
		match beetle.state:
			Beetle.State.IDLE:
				beetle.animated_sprite.play("Idle")
				if !player_in_grass:
					beetle.head.look_at(player.global_position)
				
					if beetle.chase_area.overlaps_body(player):
						beetle.state = Beetle.State.CHASE
				
				if beetle.return_spawn_timer.time_left == 0 and beetle.global_position.distance_to(beetle.spawn_position) > 5:
					beetle.head.look_at(beetle.spawn_position)
					var direction = beetle.global_position.direction_to(beetle.spawn_position)
					beetle.velocity = direction * BEETLE_CHASE_SPEED
					beetle.move_and_slide()
					
			Beetle.State.CHASE:
				beetle.animated_sprite.play("Chase")
				if player_in_grass || player_being_spat || !beetle.chase_area.overlaps_body(player):
					beetle.state = Beetle.State.IDLE
					beetle.return_spawn_timer.start()
					continue
				
				if beetle.kill_area.overlaps_body(player):
					kill_player()
					beetle.state = Beetle.State.IDLE
					beetle.return_spawn_timer.start()
					continue
				
				beetle.head.look_at(player.global_position)
				var direction = beetle.global_position.direction_to(player.global_position)
				beetle.velocity = direction * BEETLE_CHASE_SPEED
				beetle.move_and_slide()

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

func camera_pan_bunnies():
	panning_camera = true
	save_bunny_label.visible = true
	save_bunny_label.modulate.a = 0
	
	await get_tree().create_timer(1).timeout
	
	var label_tween := get_tree().create_tween()
	label_tween.tween_property(save_bunny_label, "modulate:a", 1, 1)
	label_tween.tween_property(save_bunny_label, "modulate:a", 0, 3)
	
	await get_tree().create_timer(2).timeout
	
	if camera.global_position.distance_to(player_start_position) > 100:
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", player_start_position, 4)
		await tween.finished
		await get_tree().create_timer(1).timeout
	
	var bunnies = get_tree().get_nodes_in_group("bunny")
	for bunny in bunnies:
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", bunny.global_position, 4)
		await tween.finished
		await get_tree().create_timer(2).timeout
		
		tween = get_tree().create_tween()
		tween.tween_property(camera, "position", player_start_position, 2)
		await tween.finished
		await get_tree().create_timer(1).timeout

	save_bunny_label.visible = false
	panning_camera = false
