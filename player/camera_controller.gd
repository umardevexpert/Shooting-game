class_name ShoulderCamera
extends Node3D

var camera: Camera3D
var yaw := 0.0
var pitch := -0.12
var recoil := 0.0
var shake := 0.0
var distance := 4.2
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = 0.08
	camera.far = 120.0
	camera.fov = 68.0
	rng.randomize()

func update(delta: float, look: Vector2, aiming: bool) -> void:
	var sensitivity: float = Profile.data.settings.sensitivity
	if aiming: sensitivity *= float(Profile.data.settings.aim_sensitivity)
	yaw -= look.x * sensitivity * 0.004
	pitch = clampf(pitch - look.y * sensitivity * 0.0035, -0.85, 0.65)
	recoil = move_toward(recoil, 0, delta * 0.2)
	shake = move_toward(shake, 0, delta * 0.6)
	rotation = Vector3(pitch + recoil, yaw, 0)
	var anchor := player.global_position + Vector3(0, 1.6, 0)
	global_position = global_position.lerp(anchor, minf(1, delta * 16))
	distance = lerpf(distance, 2.3 if aiming else float(Catalog.player.camera_distance), minf(1, delta * 9))
	var offset := Vector3(0.68 if aiming else 0.82, 0.22, distance)
	var desired := global_transform * offset
	var ray := PhysicsRayQueryParameters3D.create(global_position, desired, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var destination: Vector3 = hit.position + hit.normal * 0.2 if not hit.is_empty() else desired
	camera.global_position = destination + Vector3(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake), 0)
	camera.rotation = Vector3.ZERO
	camera.fov = lerpf(camera.fov, 48.0 if aiming else 68.0, minf(delta * 8, 1))

func kick(amount: float) -> void:
	recoil = minf(0.14, recoil + amount)
	shake = minf(0.08, shake + amount * 0.4)

func ray_target(range_value: float) -> Vector3:
	var origin := camera.global_position
	var target := origin - camera.global_basis.z * range_value
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 4 | 8, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else target
