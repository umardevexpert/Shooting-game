extends Node

enum State { MENU, PLAYING, PAUSED, RESULT }
var state := State.MENU
var arena: CombatArena
var menu_stage: Node3D
var ui: GameUI
var selected_mission := 0
var last_rewards: Dictionary = {}
var failure_reason := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	if not Catalog.valid:
		ui.show_data_error("\n".join(Catalog.errors))
		return
	_build_menu_stage()
	ui.show_screen("splash")
	await get_tree().create_timer(0.6).timeout
	if state == State.MENU: ui.show_screen("main")

func _build_menu_stage() -> void:
	menu_stage = Node3D.new()
	add_child(menu_stage)
	menu_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	var environment := WorldEnvironment.new()
	menu_stage.add_child(environment)
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101c24")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b3c7d7")
	environment.environment.ambient_light_energy = 0.65
	var sun := DirectionalLight3D.new()
	menu_stage.add_child(sun)
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("ffd5a0")
	sun.light_energy = 1.5
	Geometry.box(menu_stage, Vector3(14, 0.2, 14), Vector3(0, -0.1, 0), Color("273a45"))
	for i in range(6): Geometry.box(menu_stage, Vector3(0.04, 0.02, 12), Vector3(i * 2 - 5, 0.02, 0), Color("51636b"))
	var actor := ActorVisual.new()
	menu_stage.add_child(actor)
	actor.build(Color("708c98"))
	actor.position = Vector3(1.5, 0, 0)
	actor.rotation.y = -0.35
	actor.scale *= 1.75
	actor.animate(0.01, 0, true, false, false)
	MissionEnvironment.place(menu_stage, "crate", Vector3(3.3, 0, -2), Vector3(1.8, 1, 1.5))
	MissionEnvironment.place(menu_stage, "container", Vector3(-1, 0, -3), Vector3(1.6, 1.4, 1.5))
	var camera := Camera3D.new()
	menu_stage.add_child(camera)
	camera.position = Vector3(0.0, 2.8, 6.3)
	camera.look_at(Vector3(0, 1.65, 0))
	camera.fov = 50
	camera.current = true

func start_mission(id: int) -> void:
	if not Profile.mission_unlocked(id) or id < 0 or id >= Catalog.missions.size(): return
	selected_mission = id
	get_tree().paused = false
	ui.controls.clear()
	_cleanup_world()
	state = State.PLAYING
	arena = CombatArena.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	arena.start(Catalog.missions[id], self, ui.controls)
	ui.show_game(arena)
	Audio.combat = true

func _cleanup_world() -> void:
	for node in [arena, menu_stage]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	arena = null
	menu_stage = null

func pause_game() -> void:
	if state != State.PLAYING: return
	state = State.PAUSED
	get_tree().paused = true
	ui.controls.clear()
	ui.controls.enabled = false
	ui.show_screen("pause")
	Profile.commit()

func resume_game() -> void:
	if state != State.PAUSED: return
	state = State.PLAYING
	ui.controls.clear()
	ui.show_game(arena, false)
	get_tree().paused = false

func main_menu() -> void:
	get_tree().paused = false
	ui.controls.clear()
	ui.controls.enabled = false
	state = State.MENU
	_cleanup_world()
	Audio.combat = false
	Engine.max_fps = 60
	_build_menu_stage()
	ui.show_screen("main")

func mission_complete() -> void:
	if state != State.PLAYING: return
	state = State.RESULT
	var stars := 1
	if arena.player.health.current >= arena.player.health.maximum * 0.5: stars += 1
	if arena.elapsed <= float(arena.definition.par): stars += 1
	last_rewards = Profile.complete(selected_mission, stars, arena.spawner.reward)
	Audio.play("win")
	_show_result.call_deferred(true)

func mission_failed(reason: String = "Operative down") -> void:
	if state != State.PLAYING: return
	state = State.RESULT
	failure_reason = reason
	Audio.play("fail")
	_show_result.call_deferred(false)

func _show_result(victory: bool) -> void:
	get_tree().paused = true
	ui.controls.clear()
	ui.show_screen("complete" if victory else "failed")
	Audio.combat = false

func _notification(what: int) -> void:
	if not is_instance_valid(ui): return
	if not Catalog.valid:
		if what in [NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_WM_CLOSE_REQUEST]: get_tree().quit()
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		pause_game()
		Profile.commit()
	elif what in [NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_WM_CLOSE_REQUEST]:
		if state == State.PLAYING: pause_game()
		elif state == State.PAUSED and ui.screen == "pause": resume_game()
		elif ui.screen != "main": ui.go_back()
		else:
			Profile.commit()
			get_tree().quit()
