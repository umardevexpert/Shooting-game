class_name RescueNPC
extends CharacterBody3D

signal died
var following := false
var health := CombatHealth.new(100, 0)
var world: Node3D
var visual: ActorVisual
var route := PackedVector3Array()
var route_index := 0
var timer := 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)
	visual = ActorVisual.new()
	add_child(visual)
	visual.build(Color("75b5ac"), true)
	health.died.connect(func(): died.emit())

func _physics_process(delta: float) -> void:
	if health.dead: return
	var direction := Vector3.ZERO
	if following and global_position.distance_to(world.player.global_position) > 2.5:
		timer -= delta
		if timer <= 0:
			timer = 0.4
			route = world.navigation.path(global_position, world.player.global_position)
			route_index = mini(1, route.size())
		if route_index < route.size():
			direction = route[route_index] - global_position
			direction.y = 0
			if direction.length() < 0.45: route_index += 1
			else: direction = direction.normalized()
	velocity = Vector3(direction.x * 3.8, velocity.y - 20 * delta, direction.z * 3.8)
	if is_on_floor(): velocity.y = -0.5
	move_and_slide()
	if direction.length_squared() > 0.01: visual.rotation.y = atan2(-direction.x, -direction.z)
	visual.animate(delta, direction.length() * 3.8, false, false, false)

func take_damage(amount: float, _origin: Vector3, _headshot: bool = false, _multiplier: float = 1.0) -> void:
	health.damage(amount)
