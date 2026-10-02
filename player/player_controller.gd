class_name PlayerController
extends CharacterBody3D

signal damaged(origin: Vector3)
signal died
var health: CombatHealth
var visual: ActorVisual
var camera_rig: ShoulderCamera
var weapons: WeaponController
var controls: MobileInput
var world: Node3D
var grenades := 3
var dodge_remaining := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var step_time := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	health = CombatHealth.new(float(Catalog.player.health), float(Catalog.player.armor))
	health.died.connect(func(): died.emit())
	visual = ActorVisual.new()
	add_child(visual)
	visual.build(Color("6b8996"))
	camera_rig = ShoulderCamera.new()
	world.add_child(camera_rig)
	camera_rig.player = self
	camera_rig.global_position = global_position + Vector3.UP * 1.6
	weapons = WeaponController.new()
	add_child(weapons)
	weapons.setup(self, camera_rig, world)
	grenades = int(Catalog.player.grenades)
	controls.action_requested.connect(_action)

func _physics_process(delta: float) -> void:
	if health.dead:
		visual.animate(delta, 0, false, false, true)
		return
	camera_rig.update(delta, controls.consume_look(), controls.aim)
	var input_value := controls.sample_movement()
	var heading := Basis(Vector3.UP, camera_rig.yaw)
	var desired := heading * Vector3(input_value.x, 0, input_value.y)
	var speed: float = Catalog.player.aim_speed if controls.aim else Catalog.player.sprint if controls.sprint else Catalog.player.speed
	dodge_remaining = maxf(0, dodge_remaining - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	if dodge_remaining > 0:
		desired = dodge_direction
		speed = 11
	velocity.x = move_toward(velocity.x, desired.x * speed, float(Catalog.player.acceleration) * delta)
	velocity.z = move_toward(velocity.z, desired.z * speed, float(Catalog.player.acceleration) * delta)
	velocity.y -= float(Catalog.player.gravity) * delta
	if is_on_floor(): velocity.y = -0.5
	move_and_slide()
	global_position.x = clampf(global_position.x, -18.5, 18.5)
	global_position.z = clampf(global_position.z, -18.5, 18.5)
	if controls.aim or controls.fire:
		visual.rotation.y = lerp_angle(visual.rotation.y, camera_rig.yaw, minf(1, delta * 16))
	elif desired.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-desired.x, -desired.z), minf(1, delta * 12))
	# Muzzle uses the actor's facing, while aim is always obtained from the camera.
	visual.aim_pitch = camera_rig.pitch
	visual.local_movement = visual.global_basis.inverse() * velocity
	weapons.update(delta, controls.fire and dodge_remaining <= 0, controls.aim)
	visual.animate(delta, Vector2(velocity.x, velocity.z).length(), controls.aim or controls.fire, weapons.current().reload_remaining > 0, false)
	step_time -= delta
	if desired.length_squared() > 0.1 and step_time <= 0:
		step_time = 0.32 if controls.sprint else 0.48
		Audio.play("step", "Environment")

func _action(action: String) -> void:
	if health.dead: return
	match action:
		"reload": weapons.reload()
		"switch": weapons.switch_weapon()
		"interact": world.objectives.interact()
		"grenade":
			if grenades > 0:
				var origin := global_position + Vector3.UP * 1.5
				var direction := -camera_rig.camera.global_basis.z
				if world.effects.projectile(origin, direction * 13 + Vector3.UP * 3, float(Catalog.player.grenade_damage), self, 9.0):
					grenades -= 1
		"dodge":
			if dodge_cooldown <= 0:
				dodge_direction = Basis(Vector3.UP, camera_rig.yaw) * Vector3(controls.sample_movement().x, 0, controls.sample_movement().y)
				if dodge_direction.length_squared() < 0.01: dodge_direction = -camera_rig.global_basis.z
				dodge_direction.y = 0
				dodge_direction = dodge_direction.normalized()
				dodge_remaining = 0.3
				dodge_cooldown = 1.5
		"pause": world.game.pause_game()

func take_damage(amount: float, origin: Vector3, headshot: bool = false, multiplier: float = 1.0) -> void:
	if health.dead: return
	if dodge_remaining > 0: amount *= 0.5
	health.damage(amount, headshot, multiplier)
	visual.hurt = 1
	camera_rig.shake = 0.045
	damaged.emit(origin)
