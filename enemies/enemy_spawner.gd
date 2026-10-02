class_name EnemySpawner
extends Node

signal enemy_killed(kind: String)
const MAX_ACTIVE := 10
var active: Array[EnemyController] = []
var queue: Array[String] = []
var timer := 0.0
var world: Node3D
var wave := 0
var kill_count := 0
var reward := 0
var boss_defeated := false
var spawn_index := 0
var anchors := [Vector3(-4, 0.1, 1), Vector3(6, 0.1, -5), Vector3(-5, 0.1, -11), Vector3(4, 0.1, -13), Vector3(-15, 0.1, -3), Vector3(15, 0.1, 4), Vector3(0, 0.1, -16)]

func enqueue(composition: Array) -> void:
	for kind in composition: queue.append(str(kind))

func remaining() -> int:
	return active.size() + queue.size()

func _physics_process(delta: float) -> void:
	timer -= delta
	if queue.is_empty() or active.size() >= MAX_ACTIVE or timer > 0: return
	timer = 0.45
	var kind: String = queue.pop_front()
	spawn(kind)

func spawn(kind: String) -> EnemyController:
	var enemy := EnemyController.new()
	enemy.kind = kind if Catalog.enemies.has(kind) else "soldier"
	enemy.world = world
	var position_value: Vector3 = anchors[spawn_index % anchors.size()]
	spawn_index += 1
	var open: Vector2i = world.navigation.nearest_open(position_value)
	enemy.position = Vector3(open.x, 0.05, open.y)
	world.add_child(enemy)
	active.append(enemy)
	enemy.killed.connect(_killed)
	return enemy

func _killed(enemy: EnemyController) -> void:
	active.erase(enemy)
	kill_count += 1
	reward += int(enemy.config.reward)
	if enemy.kind == "boss": boss_defeated = true
	enemy_killed.emit(enemy.kind)
	if kill_count % 2 == 0: world.spawn_pickup(enemy.global_position, "ammo")
	if kill_count % 3 == 0: world.spawn_pickup(enemy.global_position + Vector3.RIGHT, "health")

func alert_nearby(origin: Vector3, player_position: Vector3) -> void:
	for enemy in active:
		if enemy.global_position.distance_to(origin) < 12:
			enemy.last_known = player_position
			enemy.alert_time = 7
			if enemy.state == EnemyController.State.PATROL: enemy.state = EnemyController.State.SUSPICIOUS

func start_wave() -> void:
	wave += 1
	enqueue(["soldier", "soldier", "rusher"] if wave == 1 else ["soldier", "heavy", "rusher", "rusher"] if wave == 2 else ["elite", "heavy", "shotgun", "rusher"])
