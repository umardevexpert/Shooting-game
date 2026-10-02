class_name MaterialLibrary
extends RefCounted

static var cache: Dictionary = {}

static func get_material(name: String) -> StandardMaterial3D:
	if cache.has(name): return cache[name]
	var result := StandardMaterial3D.new()
	var maps := {"container2": "container2", "mid_cargo_box": "mid_cargo_box", "floor_grate_wholes": "floor_grate_wholes", "tile_painted_gun_metal": "tile_painted_gun_metal", "tile_default_metal": "tile_default_metal"}
	var texture_name: String = maps.get(name, "tile_painted_gun_metal")
	result.albedo_texture = load("res://assets/textures/" + texture_name + "_albedo.png")
	result.normal_enabled = true
	result.normal_texture = load("res://assets/textures/" + texture_name + "_normal.png")
	var orm: Texture2D = load("res://assets/textures/" + texture_name + "_orm.png")
	result.roughness_texture = orm
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	result.metallic_texture = orm
	result.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	result.metallic = 1
	result.ao_enabled = true
	result.ao_texture = orm
	if "emitter" in name or "glow" in name:
		result.albedo_texture = null
		result.normal_enabled = false
		result.emission_enabled = true
		result.emission = Color("f3b768") if "orange" in name else Color("9ed2e6")
		result.albedo_color = result.emission
	cache[name] = result
	return result

static func apply(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(index)
			node.set_surface_override_material(index, get_material(material.resource_name if material else "tile_default_metal"))
	for child in node.get_children(): apply(child)
