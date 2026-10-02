class_name CombatEffects
extends Node3D

const MAX_EFFECTS := 96
const MAX_PROJECTILES := 24
var effects: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var cursor := 0
var world: Node3D

func _ready() -> void:
	for i in range(MAX_EFFECTS):
		var mesh := Geometry.box(self, Vector3.ONE, Vector3.ZERO, Color("f9b865"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visible = false
		effects.append({"mesh": mesh, "life": 0.0, "total": 1.0, "kind": "", "base": Vector3.ONE})
	for i in range(MAX_PROJECTILES):
		var mesh := Geometry.sphere(self, 0.12, Vector3.ZERO, Color("f3be63"))
		mesh.visible = false
		projectiles.append({"mesh": mesh, "active": false, "velocity": Vector3.ZERO, "damage": 0.0, "owner": null, "life": 0.0, "gravity": 0.0})

func _effect(position_value: Vector3, scale_value: Vector3, duration: float, color: Color, kind: String) -> MeshInstance3D:
	var effect := effects[cursor]
	cursor = (cursor + 1) % (40 if Profile.data.settings.graphics == "Low" else MAX_EFFECTS)
	var mesh: MeshInstance3D = effect.mesh
	mesh.visible = true
	mesh.global_position = position_value
	mesh.rotation = Vector3.ZERO
	mesh.scale = scale_value
	mesh.material_override = Geometry.material(color, kind != "decal")
	effect.life = duration
	effect.total = duration
	effect.kind = kind
	effect.base = scale_value
	return mesh

func tracer(start: Vector3, end: Vector3, color: Color) -> void:
	if start.distance_to(end) < 0.02: return
	var mesh := _effect((start + end) * 0.5, Vector3(0.015, 0.015, start.distance_to(end)), 0.06, color, "tracer")
	mesh.look_at(end, Vector3.UP if absf((end - start).normalized().y) < 0.98 else Vector3.RIGHT)

func flash(position_value: Vector3) -> void:
	_effect(position_value, Vector3.ONE * 0.22, 0.055, Color("ffe4a3"), "flash")

func impact(position_value: Vector3, normal: Vector3) -> void:
	_effect(position_value + normal * 0.03, Vector3.ONE * 0.1, 0.15, Color("ebc993"), "spark")
	var decal := _effect(position_value + normal * 0.015, Vector3(0.09, 0.09, 0.005), 9.0, Color("292b29"), "decal")
	decal.look_at(decal.global_position + normal, Vector3.UP if absf(normal.y) < 0.98 else Vector3.RIGHT)

func explosion(position_value: Vector3, damage: float, source: Node3D) -> void:
	_effect(position_value, Vector3.ONE * 0.4, 0.4, Color("dc8c48"), "explosion")
	_effect(position_value + Vector3.UP * 0.4, Vector3.ONE * 0.8, 0.8, Color("535c5d"), "smoke")
	world.area_damage(position_value, float(Catalog.player.grenade_radius), damage, source)
	Audio.play("explosion")
	if is_instance_valid(world.player): world.player.camera_rig.shake = 0.12

func projectile(origin: Vector3, velocity: Vector3, damage: float, source: Node3D, gravity_value: float) -> bool:
	for item in projectiles:
		if item.active: continue
		item.active = true
		item.mesh.visible = true
		item.mesh.global_position = origin
		item.velocity = velocity
		item.damage = damage
		item.owner = source
		item.life = 3.0 if gravity_value > 0 else 4.0
		item.gravity = gravity_value
		return true
	return false

func _physics_process(delta: float) -> void:
	for item in effects:
		if item.life <= 0: continue
		item.life -= delta
		if item.life <= 0: item.mesh.visible = false
		elif item.kind in ["explosion", "smoke"]:
			item.mesh.scale = item.base * (1.0 + (1.0 - item.life / item.total) * 5)
			if item.kind == "smoke": item.mesh.position.y += delta * 0.6
	for item in projectiles:
		if not item.active: continue
		var old: Vector3 = item.mesh.global_position
		item.velocity.y -= item.gravity * delta
		var next: Vector3 = old + item.velocity * delta
		var exclude: Array[RID] = []
		if is_instance_valid(item.owner): exclude.append(item.owner.get_rid())
		var query := PhysicsRayQueryParameters3D.create(old, next, 1 | 2 | 4 | 8, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		item.mesh.global_position = hit.position if not hit.is_empty() else next
		item.life -= delta
		if not hit.is_empty() or item.life <= 0:
			item.active = false
			item.mesh.visible = false
			explosion(item.mesh.global_position, item.damage, item.owner)
