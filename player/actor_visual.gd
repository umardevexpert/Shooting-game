class_name ActorVisual
extends Node3D

const OPERATOR := preload("res://assets/models/swat_operator.glb")
const CIVILIAN := preload("res://assets/models/casual_operator.glb")
var model: Node3D
var skeleton: Skeleton3D
var animator: HumanoidAnimator
var weapon: WeaponVisual
var hurt := 0.0
var shot := 0.0
var motion := "idle"
var aim_pitch := 0.0
var aim_target := Vector3.INF
var local_movement := Vector3.ZERO

func build(color: Color, civilian: bool = false) -> void:
	model = (CIVILIAN if civilian else OPERATOR).instantiate()
	add_child(model)
	model.rotation.y = PI
	skeleton = model.find_child("Skeleton3D", true, false)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			for index in range(child.mesh.get_surface_count()):
				var original: StandardMaterial3D = child.mesh.surface_get_material(index)
				if original == null: continue
				var material: StandardMaterial3D = original.duplicate()
				if "Swat" in material.resource_name:
					material.albedo_color *= color.lightened(0.55)
				child.set_surface_override_material(index, material)
	animator = HumanoidAnimator.new()
	add_child(animator)
	animator.setup(model)
	var reference := skeleton.get_bone_global_pose(skeleton.find_bone("hand.R")).basis
	var socket := BoneAttachment3D.new()
	socket.name = "WeaponSocket"
	socket.bone_name = "hand.R"
	skeleton.add_child(socket)
	weapon = WeaponVisual.new()
	socket.add_child(weapon)
	weapon.basis = reference.inverse().orthonormalized()
	if civilian: weapon.hide()

func equip_weapon(id: String) -> void:
	weapon.equip(id)
	animator.switch_weapon()

func muzzle_origin() -> Vector3:
	return weapon.origin()

func animate(delta: float, speed: float, aiming: bool, reloading: bool, dead: bool) -> void:
	motion = "death" if dead else "reload" if reloading else "shoot" if shot > 0 else "hit" if hurt > 0 else "aim" if aiming else "run" if speed > 5 else "walk" if speed > 0.2 else "idle"
	animator.movement = Vector2(local_movement.x, -local_movement.z) / 3.0
	animator.update(delta, speed, aiming, aim_pitch, reloading, shot, hurt, dead)
	if shot > 0.9: weapon.kick()
	weapon.update(delta)
	if aiming and not reloading and not dead and hurt <= 0 and weapon.visible:
		_align_weapon()
		ArmIK.reach(skeleton, "L", weapon.support_grip.global_position)
	hurt = move_toward(hurt, 0, delta * 5)
	shot = move_toward(shot, 0, delta * 8)

func _align_weapon() -> void:
	if weapon.aim_grip != Vector3.INF:
		ArmIK.reach(skeleton, "R", global_transform * weapon.aim_grip)
	var hand := skeleton.find_bone("hand.R")
	var pose := skeleton.get_bone_global_pose(hand)
	var world_basis := skeleton.global_basis.orthonormalized()
	# Rotate the actual wrist and its attached model, keeping the grip in the hand.
	# Two iterations compensate for the barrel's offset above the grip.
	for iteration in range(2):
		var gun_transform := skeleton.global_transform * pose * weapon.transform
		var direction: Vector3 = global_basis * Vector3(0, sin(aim_pitch), -cos(aim_pitch))
		if aim_target != Vector3.INF:
			direction = aim_target - gun_transform * weapon.muzzle.position
		if direction.length_squared() < 0.001: return
		var correction := Basis(Quaternion(gun_transform.basis.z.normalized(), direction.normalized()))
		pose.basis = world_basis.inverse() * correction * world_basis * pose.basis
	skeleton.set_bone_global_pose(hand, pose)
	skeleton.force_update_all_bone_transforms()
	# BoneAttachment updates at frame end; rays and IK need this frame's pose now.
	weapon.get_parent().transform = pose
