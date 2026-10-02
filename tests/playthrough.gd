extends Node

# End-to-end mission runs: only normal controls, physics, shooting, interaction
# and save flow. No teleports, direct enemy damage or invulnerability.
var game: Node
var saved: Dictionary
var waypoints := PackedVector3Array()
var waypoint := 0
var repath := 0
var goal := Vector3.ZERO

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	await get_tree().process_frame
	saved = Profile.data.duplicate(true)
	Profile.data = Profile.defaults()
	Profile.data.settings.difficulty = "Easy"
	game = load("res://core/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().create_timer(0.7).timeout
	var operations: int = 10 if "--campaign" in OS.get_cmdline_user_args() else 1
	var success := true
	for operation in range(operations):
		var result: bool = await play_operation(operation)
		success = success and result
		if not result: break
	Profile.data = saved
	Profile.commit()
	get_tree().paused = false
	game.queue_free()
	for i in range(3): await get_tree().physics_frame
	get_tree().quit(0 if success else 1)

func play_operation(operation: int) -> bool:
	game.start_mission(operation)
	var arena: CombatArena = game.arena
	repath = 0
	waypoints.clear()
	waypoint = 0
	var frames := 0
	while game.state == game.State.PLAYING and frames < 10000:
		frames += 1
		var controls: MobileInput = game.ui.controls
		var player: PlayerController = arena.player
		controls.move_touch = 991
		controls.movement = Vector2.ZERO
		controls.fire = false
		controls.aim = false
		var enemy: EnemyController
		var nearest := INF
		for candidate in arena.spawner.active:
			var distance: float = candidate.global_position.distance_to(player.global_position)
			if distance < nearest:
				nearest = distance
				enemy = candidate
		var step := arena.objectives.current()
		var destination := arena.objectives._position(step)
		if step.type in ["eliminate", "waves", "boss"] and is_instance_valid(enemy): destination = enemy.global_position
		var combat_target: Node3D = arena.objectives.target if step.type == "destroy" else enemy
		var target_height := 0.9 if step.type == "destroy" else 1.64 * float(combat_target.get_meta("body_scale", 1)) if is_instance_valid(combat_target) else 1.64
		var can_shoot := is_instance_valid(combat_target) and arena.line_of_sight(player.weapons.muzzle_origin(), combat_target.global_position + Vector3.UP * target_height) and player.global_position.distance_to(combat_target.global_position) < 25
		var clear_shot := false
		if is_instance_valid(combat_target):
			controls.aim = true
			var camera: Camera3D = player.camera_rig.camera
			var direction := combat_target.global_position + Vector3.UP * target_height - camera.global_position
			var wanted_yaw := atan2(-direction.x, -direction.z)
			var wanted_pitch := asin(direction.normalized().y) - player.camera_rig.recoil
			var sensitivity: float = Profile.data.settings.sensitivity * Profile.data.settings.aim_sensitivity
			controls.look_delta = Vector2(wrapf(player.camera_rig.yaw - wanted_yaw, -PI, PI) / (0.004 * sensitivity), (player.camera_rig.pitch - wanted_pitch) / (0.0035 * sensitivity)).limit_length(60)
			var alignment := -camera.global_basis.z
			var aim_ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + alignment * 80, 1 | 4 | 8)
			var aim_hit := arena.get_world_3d().direct_space_state.intersect_ray(aim_ray)
			clear_shot = not aim_hit.is_empty() and aim_hit.collider == combat_target
			controls.fire = can_shoot and clear_shot and alignment.dot(direction.normalized()) > 0.995
			if player.weapons.current().magazine == 0: player.weapons.reload()
		if not can_shoot or not clear_shot or step.type not in ["eliminate", "waves", "boss", "destroy"]:
			repath -= 1
			if repath <= 0 or goal.distance_to(destination) > 2:
				repath = 24
				goal = destination
				waypoints = arena.navigation.path(player.global_position, destination)
				waypoint = mini(1, waypoints.size())
			if waypoint < waypoints.size():
				var direction := waypoints[waypoint] - player.global_position
				direction.y = 0
				if direction.length() < 0.5: waypoint += 1
				else:
					var local := Basis(Vector3.UP, player.camera_rig.yaw).inverse() * direction.normalized()
					controls.movement = Vector2(local.x, local.z)
		if not arena.objectives.prompt().is_empty(): controls.action_requested.emit("interact")
		await get_tree().physics_frame
	for i in range(3): await get_tree().physics_frame
	var victory: bool = game.ui.screen == "complete" and Profile.data.ratings.has(str(operation))
	print("PLAYTHROUGH OP %02d: %s | %.1fs | HP %.1f | shots %d | hits %d | kills %d | frames %d" % [operation + 1, "PASS" if victory else "FAIL", arena.elapsed, arena.player.health.current, arena.player.weapons.fired_count, arena.player.weapons.hit_count, arena.spawner.kill_count, frames])
	if not victory: print("Stopped at ", arena.objectives.description(), " / ", game.ui.screen)
	Profile.load_profile()
	var persisted: bool = Profile.data.ratings.has(str(operation))
	print("PLAYTHROUGH SAVE: ", "PASS" if persisted else "FAIL")
	return victory and persisted
