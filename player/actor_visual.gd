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
var local_movement := Vector3.ZERO

func build(color: Color, heavy: bool = false, civilian: bool = false) -> void:
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
	if heavy: scale *= 1.12
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
		ArmIK.reach(skeleton, "L", weapon.support_grip.global_position)
	hurt = move_toward(hurt, 0, delta * 5)
	shot = move_toward(shot, 0, delta * 8)
