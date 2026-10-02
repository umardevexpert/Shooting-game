class_name EffectMeshes
extends RefCounted

const SMOKE := preload("res://assets/vendor/kenney_blaster_kit/models/smoke.glb")

static func build() -> Dictionary:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var arrays := cylinder.surface_get_arrays(0)
	var turn := Basis(Vector3.RIGHT, PI / 2)
	for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
		var values: PackedVector3Array = arrays[field]
		for index in range(values.size()): values[index] = turn * values[index]
		arrays[field] = values
	var trail := ArrayMesh.new()
	trail.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var burst := SphereMesh.new()
	burst.radius = 0.5
	burst.height = 1
	burst.radial_segments = 12
	burst.rings = 6
	var smoke_scene := SMOKE.instantiate()
	var smoke: Mesh = smoke_scene.get_node("smoke").mesh
	smoke_scene.free()
	return {"tracer": trail, "decal": trail, "spark": burst,
		"flash": _flare(), "explosion": burst, "smoke": smoke}

static func _flare() -> ArrayMesh:
	# Two crossed, tapered flame volumes, reused by every pooled muzzle flash.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for turn in [0.0, PI / 2]:
		var basis := Basis(Vector3.FORWARD, turn)
		var points := [Vector3(0, 0, -0.8), Vector3(-0.5, 0, 0), Vector3(0, 0.13, 0.25), Vector3(0.5, 0, 0), Vector3(0, -0.13, 0.25)]
		for face in [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1], [1, 4, 2], [2, 4, 3]]:
			for index in face: surface.add_vertex(basis * points[index])
	surface.generate_normals()
	return surface.commit()
