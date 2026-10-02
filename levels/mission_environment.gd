class_name MissionEnvironment
extends RefCounted

const MODELS := {
	"container": preload("res://assets/models/environment/container.glb"),
	"crate": preload("res://assets/models/environment/cargo_crate.glb"),
	"barrel": preload("res://assets/models/environment/barrel.glb"),
	"supply": preload("res://assets/models/environment/supply_case.glb"),
	"light": preload("res://assets/models/environment/floodlight.glb"),
	"generator": preload("res://assets/models/environment/generator.glb"),
	"wall": preload("res://assets/models/environment/wall_panel.glb"),
	"fence": preload("res://assets/models/environment/fence.glb")}
static var bounds_cache: Dictionary = {}

static func _bounds(node: Node3D, transform_value: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var first := true
	transform_value *= node.transform
	if node is MeshInstance3D:
		result = transform_value * node.get_aabb()
		first = false
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := _bounds(child, transform_value)
			if child_bounds.size.length_squared() > 0:
				result = child_bounds if first else result.merge(child_bounds)
				first = false
	return result

static func place(parent: Node3D, kind: String, base: Vector3, size_value: Vector3, yaw: float = 0) -> Node3D:
	var anchor := Node3D.new()
	parent.add_child(anchor)
	anchor.position = base
	anchor.rotation.y = yaw
	var model: Node3D = MODELS[kind].instantiate()
	anchor.add_child(model)
	if not bounds_cache.has(kind): bounds_cache[kind] = _bounds(model)
	var bounds: AABB = bounds_cache[kind]
	model.scale = size_value / bounds.size
	model.position = -(bounds.position + Vector3(bounds.size.x / 2, 0, bounds.size.z / 2)) * model.scale
	MaterialLibrary.apply(model)
	anchor.set_meta("asset_kind", kind)
	return anchor

static func collision(parent: Node3D, size_value: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = center
	body.collision_layer = 1
	var collider := CollisionShape3D.new()
	body.add_child(collider)
	var box := BoxShape3D.new()
	box.size = size_value
	collider.shape = box
	return body

static func build(parent: Node3D, definition: Dictionary) -> void:
	# Authored cover footprints also drive navigation and simple mobile collision.
	var ground := MeshInstance3D.new()
	parent.add_child(ground)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var floor_material := MaterialLibrary.get_material("floor_grate_wholes").duplicate()
	floor_material.uv1_scale = Vector3(12, 12, 1)
	ground.material_override = floor_material
	collision(parent, Vector3(40, 0.4, 40), Vector3(0, -0.2, 0))
	for axis in [0, 1]:
		for side in [-1, 1]:
			var boundary := Vector3(side * 20, 2.5, 0) if axis == 0 else Vector3(0, 2.5, side * 20)
			collision(parent, Vector3(1, 5, 40) if axis == 0 else Vector3(40, 5, 1), boundary)
			for section in range(4):
				var offset := -15.0 + section * 10.0
				var point := Vector3(side * 20, 0, offset) if axis == 0 else Vector3(offset, 0, side * 20)
				place(parent, "wall", point, Vector3(10, 5, 1), PI / 2 if axis == 0 else 0.0)
	for block in definition.layout:
		var center := Vector3(float(block[0]), float(block[4]) / 2, float(block[1]))
		var dimensions := Vector3(float(block[2]), float(block[4]), float(block[3]))
		collision(parent, dimensions, center)
		var tiers := 2 if dimensions.y >= 4 else 1
		var columns := maxi(1, int(dimensions.x / 2.6)) if dimensions.y < 2 else 1
		for tier in range(tiers):
			for column in range(columns):
				var module := Vector3(dimensions.x / columns, dimensions.y / tiers, dimensions.z)
				var base := Vector3(center.x - dimensions.x / 2 + module.x * (column + 0.5), tier * module.y, center.z)
				place(parent, "crate" if dimensions.y < 2 else "container", base, module)
	for x in [-18.9, 18.9]:
		for z in [-15, -3, 12]:
			place(parent, "barrel", Vector3(x, 0, z), Vector3(0.65, 1.1, 0.65))
			collision(parent, Vector3(0.65, 1.1, 0.65), Vector3(x, 0.55, z))
	for x in [-16, 16]:
		for z in [-16, 14]: place(parent, "light", Vector3(x, 0, z), Vector3(0.9, 5.9, 0.9))
	place(parent, "generator", Vector3(-17, 0, -18.6), Vector3(2.2, 2.4, 1.6))
	place(parent, "generator", Vector3(17, 0, -18.6), Vector3(2.2, 2.4, 1.6))
