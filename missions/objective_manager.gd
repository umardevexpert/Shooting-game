class_name ObjectiveManager
extends Node

signal changed
signal completed
signal failed(reason: String)
var world: Node3D
var steps: Array
var index := 0
var progress := 0.0
var finished := false
var marker: MeshInstance3D
var pillar: MeshInstance3D
var target: ObjectiveTarget
var engineer: RescueNPC
var wave_delay := 0.0

func setup(arena: Node3D, definitions: Array) -> void:
	world = arena
	steps = definitions
	marker = Geometry.ring(world, 2.3, Vector3(0, 0.04, 0), Color("e9b86a"))
	pillar = Geometry.box(world, Vector3(0.15, 3.0, 0.15), Vector3.ZERO, Color("e9b86a"))
	pillar.material_override = Geometry.material(Color("e9b86a"), true)
	for step in steps:
		if step.type == "destroy":
			target = ObjectiveTarget.new()
			target.position = _position(step)
			target.health = CombatHealth.new(float(step.health), 0)
			world.add_child(target)
		if step.type == "rescue":
			engineer = RescueNPC.new()
			engineer.world = world
			engineer.position = _position(step)
			world.add_child(engineer)
			engineer.died.connect(func(): failed.emit("The engineer was lost"))
	_update_marker()

func current() -> Dictionary:
	return steps[index] if index < steps.size() else {}

func _position(step: Dictionary) -> Vector3:
	var values: Array = step.get("position", [0, 0, 0])
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func distance() -> float:
	return world.player.global_position.distance_to(_position(current())) if current().has("position") else 0.0

func _physics_process(delta: float) -> void:
	if finished or world.player.health.dead: return
	var step := current()
	match step.type:
		"reach", "escape":
			if distance() < float(step.radius):
				if step.type == "escape" and is_instance_valid(engineer) and engineer.global_position.distance_to(world.player.global_position) > 5: return
				_advance()
		"eliminate":
			if world.spawner.remaining() == 0: _advance()
		"destroy":
			if target.health.dead: _advance()
		"boss":
			if world.spawner.boss_defeated: _advance()
		"defend":
			if distance() < float(step.radius): progress += delta
			if progress >= float(step.duration) and world.spawner.remaining() == 0: _advance()
		"waves":
			if world.spawner.remaining() == 0:
				wave_delay += delta
				if world.spawner.wave >= int(step.count): _advance()
				elif wave_delay > 2:
					wave_delay = 0
					world.spawner.start_wave()
					world.game.ui.toast("WAVE %d / %d" % [world.spawner.wave, step.count])
	if is_instance_valid(pillar): pillar.rotation.y += delta * 0.8

func interact() -> bool:
	if finished: return false
	var step := current()
	if step.type not in ["collect", "activate", "rescue"] or distance() > float(step.radius): return false
	if step.type == "rescue": engineer.following = true
	Audio.play("pickup")
	_advance()
	return true

func prompt() -> String:
	if finished: return ""
	var step := current()
	if step.type in ["collect", "activate", "rescue"] and distance() < float(step.radius): return "USE / E • " + str(step.text)
	if step.type == "escape" and is_instance_valid(engineer) and distance() < 3 and engineer.global_position.distance_to(world.player.global_position) > 5: return "Wait for the engineer"
	return ""

func description() -> String:
	if finished: return "Mission complete"
	var step := current()
	var suffix := ""
	match step.type:
		"eliminate": suffix = " • %d remaining" % world.spawner.remaining()
		"defend": suffix = " • %ds / %ds" % [int(progress), int(step.duration)]
		"waves": suffix = " • wave %d" % world.spawner.wave
		"destroy": suffix = " • %d%%" % int(target.health.current / target.health.maximum * 100)
		_: if step.has("position"): suffix = " • %dm" % int(distance())
	return str(step.text) + suffix

func _advance() -> void:
	index += 1
	progress = 0
	if index >= steps.size():
		finished = true
		marker.visible = false
		pillar.visible = false
		completed.emit()
		return
	_update_marker()
	changed.emit()
	Audio.play("pickup")

func _update_marker() -> void:
	var step := current()
	marker.visible = step.has("position")
	pillar.visible = marker.visible
	marker.global_position = _position(step) + Vector3.UP * 0.045
	pillar.global_position = _position(step) + Vector3.UP * 1.5
	if is_instance_valid(target): target.active = step.type == "destroy"
	if step.type == "defend": world.spawner.enqueue(["soldier", "rusher", "rusher"])
