class_name EnemyController
extends CharacterBody3D

signal killed(enemy: EnemyController)
enum State { IDLE, PATROL, SUSPICIOUS, ALERT, SEARCH, COVER, ATTACK, REPOSITION, RETREAT, DEAD }
var state := State.PATROL
var kind := "soldier"
var config: Dictionary
var health: CombatHealth
var visual: ActorVisual
var world: Node3D
var target: PlayerController
var last_known := Vector3.ZERO
var destination := Vector3.ZERO
var route := PackedVector3Array()
var route_index := 0
var decision_timer := 0.0
var fire_timer := 0.0
var alert_time := 0.0
var magazine := 8
var reload_time := 0.0
var corpse_time := 0.0
var rng := RandomNumberGenerator.new()
var boss_phase := 1
var special_timer := 6.0
var telegraph_remaining := 0.0
var telegraph_position := Vector3.ZERO
var weakness_remaining := 0.0
var boss_ring: MeshInstance3D
var visible_player := false

func _ready() -> void:
	rng.randomize()
	config = Catalog.enemies[kind].duplicate(true)
	target = world.player
	var body_scale := 1.8 if kind == "boss" else 1.25 if kind == "heavy" else 1.0
	set_meta("body_scale", body_scale)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32 * body_scale
	capsule.height = 1.85 * body_scale
	collider.shape = capsule
	collider.position.y = capsule.height / 2
	add_child(collider)
	health = CombatHealth.new(float(config.health), float(config.armor))
	health.died.connect(_die)
	visual = ActorVisual.new()
	add_child(visual)
	visual.build(Color(config.color), kind == "heavy")
	visual.equip_weapon(config.get("weapon", "rifle"))
	if kind == "boss":
		visual.scale *= 1.2
		boss_ring = Geometry.ring(world, float(Catalog.player.grenade_radius), Vector3.ZERO, Color("df785d"))
		boss_ring.visible = false
	decision_timer = rng.randf_range(0, 0.2)
	_set_destination(global_position + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))

func _physics_process(delta: float) -> void:
	if health.dead:
		corpse_time += delta
		visual.animate(delta, 0, false, false, true)
		if corpse_time > 3: queue_free()
		return
	decision_timer -= delta
	alert_time = maxf(0, alert_time - delta)
	fire_timer = maxf(0, fire_timer - delta)
	reload_time = maxf(0, reload_time - delta)
	if reload_time == 0 and magazine == 0: magazine = 8
	if decision_timer <= 0:
		decision_timer = 0.2
		_decide()
	var direction := Vector3.ZERO
	if route_index < route.size() and state not in [State.ATTACK, State.IDLE, State.ALERT, State.SUSPICIOUS]:
		var next := route[route_index]
		direction = next - global_position
		direction.y = 0
		if direction.length() < 0.45: route_index += 1
		else: direction = direction.normalized()
	var speed: float = float(config.speed) * float(world.difficulty.aggression)
	if kind == "boss" and weakness_remaining > 0: speed *= 0.25
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 20 * delta
	if is_on_floor(): velocity.y = -0.5
	move_and_slide()
	var facing: Vector3 = last_known - global_position if state in [State.ATTACK, State.ALERT] else direction
	facing.y = 0
	if facing.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1, delta * 7))
	if state == State.ATTACK and visible_player and fire_timer <= 0 and reload_time == 0 and not target.health.dead:
		_shoot()
	if kind == "boss": _boss_update(delta)
	visual.local_movement = visual.global_basis.inverse() * velocity
	visual.aim_pitch = asin((target.global_position + Vector3.UP * 1.1 - visual.muzzle_origin()).normalized().y)
	visual.animate(delta, Vector2(velocity.x, velocity.z).length(), state == State.ATTACK, reload_time > 0, false)

func _decide() -> void:
	if target.health.dead: return
	var distance := global_position.distance_to(target.global_position)
	var eye := global_position + Vector3.UP * (1.5 * float(get_meta("body_scale", 1)))
	var player_eye := target.global_position + Vector3.UP * 1.25
	var facing := -visual.global_basis.z
	var sees_cone := facing.dot((player_eye - eye).normalized()) > 0.15 or distance < 7
	visible_player = distance < 38 + int(kind == "sniper") * 30 and (sees_cone or alert_time > 0) and world.line_of_sight(eye, player_eye)
	if visible_player:
		last_known = target.global_position
		alert_time = 7
		if state in [State.IDLE, State.PATROL, State.SUSPICIOUS, State.SEARCH]:
			state = State.ALERT
			fire_timer = float(config.reaction) * float(world.difficulty.reaction)
			world.spawner.alert_nearby(global_position, last_known)
			return
		if state == State.ALERT and fire_timer > 0: return
		if health.current / health.maximum < 0.28 and kind not in ["rusher", "boss"] and rng.randf() < 0.12:
			state = State.RETREAT
			_move_to_cover()
		elif kind == "rusher" and distance > 2.5 or kind == "shotgun" and distance > 9 or distance > float(config.range):
			state = State.REPOSITION
			_set_destination(last_known)
		elif kind == "sniper" and distance < 10:
			state = State.RETREAT
			_set_destination(global_position + (global_position - last_known).normalized() * 8)
		elif state in [State.COVER, State.RETREAT, State.REPOSITION] and route_index < route.size():
			pass
		elif kind == "elite" and rng.randf() < 0.08:
			state = State.REPOSITION
			var offset := (global_position - last_known).normalized().rotated(Vector3.UP, rng.randf_range(-1, 1)) * 12
			_set_destination(last_known + offset)
		elif rng.randf() < 0.04 and kind not in ["rusher", "boss"]:
			state = State.COVER
			_move_to_cover()
		else: state = State.ATTACK
	elif alert_time > 0:
		state = State.SEARCH
		_set_destination(last_known)
	elif state != State.PATROL or route_index >= route.size():
		state = State.PATROL
		_set_destination(global_position + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))

func _move_to_cover() -> void:
	var best := INF
	var position_value := global_position
	for cover in world.navigation.covers:
		var cost: float = cover.distance_to(global_position)
		if cover.distance_to(last_known) < 5: continue
		if world.line_of_sight(cover + Vector3.UP, last_known + Vector3.UP): cost += 12
		if cost < best:
			best = cost
			position_value = cover
	_set_destination(position_value)

func _set_destination(position_value: Vector3) -> void:
	destination = position_value
	route = world.navigation.path(global_position, destination)
	route_index = mini(1, route.size())

func _shoot() -> void:
	magazine -= 1
	if magazine == 0: reload_time = 2.4
	fire_timer = 1.0 / (float(config.rate) * (1.0 + (boss_phase - 1) * 0.15))
	var origin := visual.muzzle_origin()
	var endpoint := target.global_position + Vector3.UP * 1.1
	var accuracy := clampf(float(config.accuracy) * float(world.difficulty.accuracy), 0.1, 0.94)
	if rng.randf() > accuracy:
		endpoint += Vector3(rng.randf_range(-2, 2), rng.randf_range(0.5, 2.4), rng.randf_range(-2, 2))
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint + (endpoint - origin).normalized(), 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
		if hit.collider == target:
			target.take_damage(float(config.damage) * float(world.difficulty.damage), global_position)
	world.effects.tracer(origin, endpoint, Color("e08c64"))
	world.effects.flash(origin, (endpoint - origin).normalized())
	visual.shot = 1
	if global_position.distance_to(target.global_position) < 22: Audio.play("shot", "Weapon", 0.75)

func _boss_update(delta: float) -> void:
	weakness_remaining = maxf(0, weakness_remaining - delta)
	var desired_phase := 3 if health.current / health.maximum < 0.33 else 2 if health.current / health.maximum < 0.66 else 1
	if desired_phase > boss_phase:
		boss_phase = desired_phase
		world.game.ui.toast("WARDEN • PHASE %d / %s" % [boss_phase, "ARTILLERY" if boss_phase == 2 else "OVERDRIVE"])
		Audio.play("alert")
		world.spawner.enqueue(["rusher", "elite"] if boss_phase == 3 else ["soldier", "soldier"])
	if telegraph_remaining > 0:
		telegraph_remaining -= delta
		boss_ring.scale = Vector3.ONE * (1.0 + sin(telegraph_remaining * 24) * 0.04)
		if telegraph_remaining <= 0:
			world.effects.explosion(telegraph_position, 45 * float(world.difficulty.damage), self)
			boss_ring.visible = false
			weakness_remaining = 2.5
	else:
		special_timer -= delta
		if special_timer <= 0 and alert_time > 0:
			special_timer = 7.0 - boss_phase
			telegraph_position = target.global_position
			telegraph_position.y = 0.07
			telegraph_remaining = 1.5
			boss_ring.global_position = telegraph_position
			boss_ring.visible = true
			Audio.play("alert")
			if boss_phase >= 2:
				world.effects.projectile(global_position + Vector3.UP * 2, (target.global_position - global_position).normalized() * 13 + Vector3.UP * 2, 28, self, 4)

func take_damage(amount: float, origin: Vector3, headshot: bool = false, multiplier: float = 1.0) -> void:
	if health.dead: return
	if kind == "boss" and weakness_remaining > 0: amount *= 1.65
	health.damage(amount, headshot, multiplier)
	visual.hurt = 1
	last_known = origin
	alert_time = 8
	if state in [State.PATROL, State.IDLE]: state = State.SUSPICIOUS

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(boss_ring): boss_ring.queue_free()
	killed.emit(self)
