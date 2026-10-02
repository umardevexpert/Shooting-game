class_name ActorVisual
extends Node3D

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var clock := 0.0
var hurt := 0.0
var shot := 0.0
var motion := "idle"
var weapon_mesh: MeshInstance3D

func build(color: Color, heavy: bool = false) -> void:
	var dark := Color("18232a")
	Geometry.box(self, Vector3(0.65, 0.65, 0.38), Vector3(0, 1.15, 0), color)
	Geometry.box(self, Vector3(0.48, 0.42, 0.13), Vector3(0, 1.18, -0.24), dark)
	Geometry.box(self, Vector3(0.42, 0.36, 0.38), Vector3(0, 1.69, 0), color.lightened(0.13))
	Geometry.box(self, Vector3(0.33, 0.12, 0.02), Vector3(0, 1.69, -0.2), Color("86c1c5"))
	left_leg = _limb(Vector3(-0.18, 0.82, 0), Vector3(0.24, 0.7, 0.28), color.darkened(0.25))
	right_leg = _limb(Vector3(0.18, 0.82, 0), Vector3(0.24, 0.7, 0.28), color.darkened(0.25))
	left_arm = _limb(Vector3(-0.4, 1.4, 0), Vector3(0.18, 0.58, 0.2), color)
	right_arm = _limb(Vector3(0.4, 1.4, 0), Vector3(0.18, 0.58, 0.2), color)
	weapon_mesh = Geometry.box(right_arm, Vector3(0.12, 0.14, 0.72), Vector3(0, -0.36, -0.4), dark)
	if heavy: scale *= 1.25

func _limb(origin: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = origin
	Geometry.box(pivot, size, Vector3(0, -size.y / 2, 0), color)
	return pivot

func animate(delta: float, speed: float, aiming: bool, reloading: bool, dead: bool) -> void:
	clock += delta * minf(speed * 2.5, 14.0)
	hurt = move_toward(hurt, 0, delta * 5)
	shot = move_toward(shot, 0, delta * 8)
	motion = "death" if dead else "reload" if reloading else "shoot" if shot > 0 else "hit" if hurt > 0 else "aim" if aiming else "run" if speed > 5 else "walk" if speed > 0.2 else "idle"
	if dead:
		rotation.z = lerpf(rotation.z, 1.45, minf(delta * 6, 1))
		position.y = lerpf(position.y, -0.45, minf(delta * 6, 1))
		return
	left_leg.rotation.x = sin(clock) * minf(speed / 8.0, 0.55)
	right_leg.rotation.x = -left_leg.rotation.x
	right_arm.rotation.x = -1.1 if aiming else -0.55
	left_arm.rotation.x = -1.15 if aiming else -0.4
	if reloading:
		left_arm.rotation.z = sin(clock * 2) * 0.4 + 0.6
	else: left_arm.rotation.z = 0.0
	weapon_mesh.position.z = -0.4 + shot * 0.12
	rotation.z = hurt * 0.12
