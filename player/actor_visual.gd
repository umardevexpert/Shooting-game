class_name ActorVisual
extends Node3D

const OPERATOR := preload("res://assets/models/operator.glb")
const ALBEDO := preload("res://assets/textures/player_robot_albedo.png")
const NORMAL := preload("res://assets/textures/player_robot_normal.png")
const ORM := preload("res://assets/textures/player_robot_orm.png")
var model: Node3D
var skeleton: Skeleton3D
var animator: HumanoidAnimator
var weapon: WeaponVisual
var hurt := 0.0
var shot := 0.0
var motion := "idle"
var aim_pitch := 0.0
var local_movement := Vector3.ZERO

func build(color: Color, heavy: bool = false) -> void:
	model = OPERATOR.instantiate()
	add_child(model)
	model.rotation.y = PI
	model.scale = Vector3.ONE * 1.15
	skeleton = model.find_child("Skeleton3D", true, false)
	var body := StandardMaterial3D.new()
	body.albedo_texture = ALBEDO
	body.albedo_color = color.lightened(0.3)
	body.normal_enabled = true
	body.normal_texture = NORMAL
	body.roughness_texture = ORM
	body.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	body.metallic_texture = ORM
	body.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	body.metallic = 1
	body.ao_enabled = true
	body.ao_texture = ORM
	var emission := StandardMaterial3D.new()
	emission.albedo_color = color.lightened(0.5)
	emission.emission_enabled = true
	emission.emission = Color("82c3d3")
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			for index in range(child.mesh.get_surface_count()):
				var original: Material = child.mesh.surface_get_material(index)
				child.set_surface_override_material(index, emission if original.resource_name == "robotemitter" else body)
			if "Cannons" in child.name: child.visible = false
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
	if heavy: scale *= 1.25

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
	hurt = move_toward(hurt, 0, delta * 5)
	shot = move_toward(shot, 0, delta * 8)
