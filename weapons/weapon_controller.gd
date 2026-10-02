class_name WeaponController
extends Node

signal fired
signal hit_confirmed(headshot: bool)
var weapons: Array[WeaponState] = []
var slot := 0
var player: CharacterBody3D
var camera_rig: ShoulderCamera
var world: Node3D
var rng := RandomNumberGenerator.new()
var fired_count := 0
var hit_count := 0

func setup(owner_player: CharacterBody3D, rig: ShoulderCamera, arena: Node3D) -> void:
	player = owner_player
	camera_rig = rig
	world = arena
	rng.randomize()
	for id in Profile.data.loadout:
		weapons.append(WeaponState.new(id, Catalog.weapon(id)))
	player.visual.equip_weapon(current().id)

func current() -> WeaponState:
	return weapons[slot]

func switch_weapon() -> void:
	current().cancel_reload()
	slot = (slot + 1) % weapons.size()
	current().trigger_down = true
	player.visual.equip_weapon(current().id)
	Audio.play("ui", "UI")

func reload() -> void:
	if current().reload():
		Audio.play("reload", "Weapon")
		if OS.is_debug_build(): print("IRONFALL_RELOAD ", current().id)

func update(delta: float, trigger: bool, aiming: bool) -> void:
	for weapon in weapons: weapon.tick(delta)
	if current().trigger(trigger): shoot(aiming)
	if current().magazine == 0 and current().reserve > 0: reload()

func shoot(aiming: bool) -> void:
	var data := current().config
	var origin := muzzle_origin()
	var target := camera_rig.ray_target(float(data.range))
	var direction := (target - origin).normalized()
	# Small cone correction only if the ray is close and the path is unobstructed.
	if Profile.data.settings.aim_assist and aiming:
		var best := 0.995
		for enemy in world.spawner.active:
			if enemy.health.dead: continue
			var aim_at: Vector3 = enemy.global_position + Vector3.UP * 1.35
			var dot := direction.dot((aim_at - origin).normalized())
			if dot > best and world.line_of_sight(origin, aim_at):
				best = dot
				direction = direction.lerp((aim_at - origin).normalized(), 0.28).normalized()
	fired_count += 1
	if OS.is_debug_build() and fired_count == 1: print("IRONFALL_FIRE ", current().id)
	if data.speed > 0:
		world.effects.projectile(origin, direction * float(data.speed), float(data.damage), player, 0.0)
	else:
		for pellet in range(int(data.pellets)):
			var spread: float = float(data.spread) * (0.5 if aiming else 1.0)
			var scattered := (direction + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))).normalized()
			var endpoint := origin + scattered * float(data.range)
			var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1 | 4 | 8, [player.get_rid()])
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				endpoint = hit.position
				if hit.collider.has_method("take_damage"):
					var headshot: bool = endpoint.y - hit.collider.global_position.y > 1.52 * hit.collider.get_meta("body_scale", 1.0)
					hit.collider.take_damage(float(data.damage), origin, headshot, float(data.headshot))
					hit_count += 1
					hit_confirmed.emit(headshot)
					Audio.play("hit")
				world.effects.impact(endpoint, hit.normal)
			world.effects.tracer(origin, endpoint, Color("ffd58a"))
	world.effects.flash(origin)
	camera_rig.kick(float(data.recoil))
	player.visual.shot = 1.0
	Audio.play("shot", "Weapon", rng.randf_range(0.9, 1.1))
	if Profile.data.settings.haptics: Input.vibrate_handheld(14)
	fired.emit()

func muzzle_origin() -> Vector3:
	var shoulder := player.global_position + Vector3(0, 1.45, 0)
	var desired: Vector3 = player.visual.muzzle_origin()
	# Keep the muzzle on the player's side of cover even if the visual gun clips.
	var ray := PhysicsRayQueryParameters3D.create(shoulder, desired, 1)
	var obstruction := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return obstruction.position + obstruction.normal * 0.025 if not obstruction.is_empty() else desired
