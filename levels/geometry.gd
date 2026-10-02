class_name Geometry
extends RefCounted

static var materials: Dictionary = {}

static func material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key := color.to_html() + str(emissive)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	materials[key] = mat
	return mat

static func box(parent: Node3D, size: Vector3, position: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = position
	if solid:
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.add_child(mesh)
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		collider.shape = collision
		collider.position = position
		body.add_child(collider)
		body.collision_layer = 1
		body.collision_mask = 0
	else: parent.add_child(mesh)
	return mesh

static func sphere(parent: Node3D, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = position
	parent.add_child(mesh)
	return mesh

static func ring(parent: Node3D, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.055
	torus.outer_radius = radius + 0.055
	torus.rings = 32
	torus.ring_segments = 6
	mesh.mesh = torus
	mesh.material_override = material(color, true)
	mesh.position = position
	parent.add_child(mesh)
	return mesh
