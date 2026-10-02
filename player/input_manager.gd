class_name MobileInput
extends Control

signal action_requested(action: String)
var movement := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire := false
var aim := false
var sprint := false
var move_touch := -1
var look_touch := -1
var button_touches: Dictionary = {}
var stick_origin := Vector2.ZERO
var stick_position := Vector2.ZERO
var regions: Dictionary = {}
var enabled := false
var desktop_look := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func clear() -> void:
	movement = Vector2.ZERO
	look_delta = Vector2.ZERO
	fire = false
	sprint = false
	move_touch = -1
	look_touch = -1
	button_touches.clear()
	desktop_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not enabled or get_tree().paused: return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			stick_position = event.position
			movement = (stick_position - stick_origin).limit_length(60.0) / 60.0
		elif event.index == look_touch:
			look_delta += event.relative
	elif event is InputEventMouseMotion and desktop_look:
		look_delta += event.relative
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: fire = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT:
			desktop_look = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if desktop_look else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: action_requested.emit("reload")
			KEY_Q: action_requested.emit("switch")
			KEY_E: action_requested.emit("interact")
			KEY_G: action_requested.emit("grenade")
			KEY_C: aim = not aim
			KEY_SPACE: action_requested.emit("dodge")
			KEY_ESCAPE:
				action_requested.emit("pause")
				get_viewport().set_input_as_handled()
	queue_redraw()

func _handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		if index == move_touch:
			move_touch = -1
			movement = Vector2.ZERO
		if index == look_touch: look_touch = -1
		if button_touches.has(index):
			var action: String = button_touches[index]
			button_touches.erase(index)
			if action == "fire": fire = "fire" in button_touches.values()
			if action == "sprint": sprint = "sprint" in button_touches.values()
		queue_redraw()
		return
	# Larger invisible hit areas preserve a compact visual layout. When adjacent
	# hit areas overlap, the nearest button wins rather than dictionary order.
	var nearest_action := ""
	var nearest_distance := INF
	for action in regions:
		var distance_value := point.distance_to(regions[action])
		if distance_value < (50.0 if action == "fire" else 46.0) and distance_value < nearest_distance:
			nearest_distance = distance_value
			nearest_action = action
	if not nearest_action.is_empty():
		button_touches[index] = nearest_action
		match nearest_action:
			"fire": fire = true
			"aim": aim = not aim
			"sprint": sprint = true
			_: action_requested.emit(nearest_action)
		queue_redraw()
		return
	var left: bool = not Profile.data.settings.left_handed
	var move_side := point.x < size.x * 0.4 if left else point.x > size.x * 0.6
	if move_side and point.y > size.y * 0.35 and move_touch == -1:
		move_touch = index
		stick_origin = point
		stick_position = point
	elif look_touch == -1 and point.y > 80:
		look_touch = index
	queue_redraw()

func sample_movement() -> Vector2:
	if move_touch >= 0: return movement
	var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	sprint = Input.is_physical_key_pressed(KEY_SHIFT) or "sprint" in button_touches.values()
	return keys.limit_length()

func consume_look() -> Vector2:
	var result := look_delta
	look_delta = Vector2.ZERO
	return result

func _draw() -> void:
	if not enabled: return
	var left: bool = not Profile.data.settings.left_handed
	var x := size.x - 70.0 if left else 70.0
	var sign_x := -1.0 if left else 1.0
	regions = {"fire": Vector2(x, size.y - 154), "aim": Vector2(x + sign_x * 91, size.y - 111),
		"reload": Vector2(x + sign_x * 171, size.y - 80), "switch": Vector2(x, size.y - 63),
		"interact": Vector2(x + sign_x * 93, size.y - 205), "grenade": Vector2(x + sign_x * 178, size.y - 176),
		"dodge": Vector2(x + sign_x * 255, size.y - 80), "sprint": Vector2(170 if left else size.x - 170, size.y - 194),
		"pause": Vector2(size.x - 40, 34)}
	var opacity: float = Profile.data.settings.opacity
	var font := ThemeDB.fallback_font
	var labels := {"fire": "FIRE", "aim": "ADS", "reload": "R", "switch": "SW", "interact": "USE", "grenade": "G", "dodge": "ROLL", "sprint": "RUN", "pause": "II"}
	for action in regions:
		var radius := 39.0 if action == "fire" else 29.0
		var active: bool = action in button_touches.values() or (action == "aim" and aim)
		draw_circle(regions[action], radius, Color(0.09, 0.14, 0.18, opacity))
		draw_arc(regions[action], radius, 0, TAU, 32, Color(0.91, 0.72, 0.4, opacity) if active or action == "fire" else Color(0.65, 0.74, 0.77, opacity), 1.5, true)
		var text_size := font.get_string_size(labels[action], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(font, regions[action] + Vector2(-text_size.x / 2, 5), labels[action], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.94, 0.96, 0.96, opacity))
	var origin := stick_origin if move_touch >= 0 else Vector2(98 if left else size.x - 98, size.y - 95)
	draw_circle(origin, 58, Color(0.09, 0.14, 0.18, opacity * 0.6))
	draw_arc(origin, 58, 0, TAU, 48, Color(0.65, 0.74, 0.77, opacity * 0.5), 1, true)
	draw_circle(origin + movement * 42, 21, Color(0.72, 0.8, 0.81, opacity * 0.65))
