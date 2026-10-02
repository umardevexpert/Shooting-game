class_name WeaponVisual
extends Node3D

static var scenes: Dictionary = {}
var model: Node3D
var muzzle := Marker3D.new()
var casing_socket := Marker3D.new()
var recoil := 0.0
var equipped := ""
var rest_position := Vector3.ZERO

func _ready() -> void:
	add_child(muzzle)
	muzzle.name = "Muzzle"
	add_child(casing_socket)
	casing_socket.name = "ShellEjection"
	equip("rifle")

func equip(id: String) -> void:
	if equipped == id: return
	equipped = id
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	var config: Dictionary = Catalog.weapon_visuals.get(id, Catalog.weapon_visuals.rifle)
	var path: String = config.model
	if not scenes.has(path): scenes[path] = load(path)
	model = scenes[path].instantiate()
	add_child(model)
	var size: float = config.scale
	model.scale = Vector3.ONE * size
	model.rotation.y = deg_to_rad(float(config.rotation))
	rest_position = _vector(config.offset) * size
	model.position = rest_position
	muzzle.position = _vector(config.muzzle) * size
	casing_socket.position = rest_position + Vector3(0.08, 0.08, 0) * size

func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func kick() -> void:
	recoil = 1

func update(delta: float) -> void:
	recoil = move_toward(recoil, 0, delta * 10)
	if is_instance_valid(model): model.position = rest_position - Vector3(0, 0, recoil * 0.055)

func origin() -> Vector3:
	return muzzle.global_position
