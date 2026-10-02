class_name CombatArena
extends Node3D

var game: Node
var definition: Dictionary
var difficulty: Dictionary
var player: PlayerController
var effects: CombatEffects
var spawner: EnemySpawner
var objectives: ObjectiveManager
var navigation := ArenaNavigation.new()
var pickups: Array[Dictionary] = []
var elapsed := 0.0
var environment: WorldEnvironment
var sun: DirectionalLight3D
var pickup_clock := 0.0

func start(mission: Dictionary, controller: Node, controls: MobileInput) -> void:
	game = controller
	definition = mission
	difficulty = Catalog.difficulties[Profile.data.settings.difficulty]
	navigation.build(definition.layout)
	_build_level()
	effects = CombatEffects.new()
	effects.world = self
	add_child(effects)
	player = PlayerController.new()
	player.world = self
	player.controls = controls
	player.position = Vector3(0, 0.05, 15)
	add_child(player)
	spawner = EnemySpawner.new()
	spawner.world = self
	add_child(spawner)
	if int(definition.id) != 7: spawner.enqueue(definition.enemies)
	objectives = ObjectiveManager.new()
	add_child(objectives)
	objectives.setup(self, definition.objectives)
	objectives.completed.connect(game.mission_complete)
	objectives.failed.connect(game.mission_failed)
	player.died.connect(func(): game.mission_failed("Operative down"))
	spawn_pickup(Vector3(-3, 0, 10), "ammo")
	spawn_pickup(Vector3(3, 0, 5), "health")
	apply_graphics()

func _build_level() -> void:
	var color := Color(definition.color)
	environment = WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = color.darkened(0.25)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9beca")
	settings.ambient_light_energy = 0.65 if definition.theme != "night" else 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-54, -25, 0)
	sun.light_color = Color("ffe3b6") if definition.theme != "night" else Color("a7c6ef")
	sun.light_energy = 1.5 if definition.theme != "night" else 0.6
	sun.directional_shadow_max_distance = 55
	Geometry.box(self, Vector3(40, 0.4, 40), Vector3(0, -0.2, 0), color.lightened(0.17), true)
	for x in [-20, 20]: Geometry.box(self, Vector3(1, 5, 40), Vector3(x, 2.5, 0), color.lightened(0.07), true)
	for z in [-20, 20]: Geometry.box(self, Vector3(40, 5, 1), Vector3(0, 2.5, z), color.lightened(0.07), true)
	for z in range(-18, 20, 4):
		Geometry.box(self, Vector3(0.12, 0.01, 2), Vector3(0, 0.01, z), Color("b1a17d"))
		Geometry.box(self, Vector3(38, 0.01, 0.025), Vector3(0, 0.005, z), color.lightened(0.24))
	for block in definition.layout:
		var origin := Vector3(float(block[0]), float(block[4]) / 2, float(block[1]))
		var size_value := Vector3(float(block[2]), float(block[4]), float(block[3]))
		Geometry.box(self, size_value, origin, color.lightened(0.12), true)
		Geometry.box(self, Vector3(size_value.x + 0.08, 0.08, size_value.z + 0.08), origin + Vector3.UP * (size_value.y / 2), Color("8a9797"))
		Geometry.box(self, Vector3(0.16, size_value.y * 0.6, 0.025), origin + Vector3(0, 0, -size_value.z / 2 - 0.02), Color("d5aa64"))
	for x in [-16, 16]:
		for z in [-16, 14]:
			Geometry.box(self, Vector3(0.2, 6, 0.2), Vector3(x, 3, z), Color("75878c"))
			var light_mesh := Geometry.box(self, Vector3(1.3, 0.15, 0.4), Vector3(x, 5.9, z), Color("ecd5a6"))
			light_mesh.material_override = Geometry.material(Color("ecd5a6"), true)
			var light := OmniLight3D.new()
			add_child(light)
			light.position = Vector3(x, 5.7, z)
			light.light_color = Color("f4d8a4")
			light.omni_range = 14
			light.light_energy = 1.6 if definition.theme == "night" else 0.3
	var label := Label3D.new()
	label.text = "IRONFALL  /  SECTOR %02d" % (int(definition.id) + 1)
	label.font_size = 72
	label.pixel_size = 0.014
	label.position = Vector3(0, 3.6, -19.4)
	label.modulate = Color("c8d1cf")
	add_child(label)

func apply_graphics() -> void:
	sun.shadow_enabled = Profile.data.settings.graphics != "Low"
	get_viewport().msaa_3d = Viewport.MSAA_4X if Profile.data.settings.graphics == "High" else Viewport.MSAA_DISABLED
	Engine.max_fps = 30 if Profile.data.settings.graphics == "Low" else 60

func _physics_process(delta: float) -> void:
	elapsed += delta
	pickup_clock += delta
	if pickup_clock < 0.1 or not is_instance_valid(player): return
	pickup_clock = 0
	for i in range(pickups.size() - 1, -1, -1):
		var item := pickups[i]
		item.mesh.rotation.y += 0.12
		if player.global_position.distance_to(item.mesh.global_position) < 1.3:
			if item.kind == "health":
				if player.health.current >= player.health.maximum: continue
				player.health.heal(30 * float(difficulty.pickups))
			else:
				for weapon in player.weapons.weapons: weapon.add_ammo(int(45 * float(difficulty.pickups)))
			item.mesh.queue_free()
			pickups.remove_at(i)
			Audio.play("pickup")

func spawn_pickup(position_value: Vector3, kind: String) -> void:
	if pickups.size() >= 20: return
	var color := Color("75bfa8") if kind == "health" else Color("e0bd77")
	var mesh := Geometry.box(self, Vector3(0.45, 0.35, 0.45), Vector3(position_value.x, 0.3, position_value.z), color)
	Geometry.box(mesh, Vector3(0.36, 0.04, 0.08), Vector3(0, 0.2, 0), Color("eff5ea"))
	if kind == "health": Geometry.box(mesh, Vector3(0.08, 0.04, 0.36), Vector3(0, 0.2, 0), Color("eff5ea"))
	pickups.append({"mesh": mesh, "kind": kind})

func line_of_sight(from: Vector3, to: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

func area_damage(origin: Vector3, radius: float, damage: float, source: Node3D) -> void:
	var actors: Array = spawner.active.duplicate()
	actors.append(player)
	if is_instance_valid(objectives.target): actors.append(objectives.target)
	if is_instance_valid(objectives.engineer): actors.append(objectives.engineer)
	for actor in actors:
		if not is_instance_valid(actor) or actor == source and source != player: continue
		var position_value: Vector3 = actor.global_position + Vector3.UP
		var distance_value := origin.distance_to(position_value)
		if distance_value < radius and line_of_sight(origin + Vector3.UP * 0.15, position_value):
			actor.take_damage(damage * (1.0 - distance_value / radius) * (0.6 if actor == player else 1.0), origin)
