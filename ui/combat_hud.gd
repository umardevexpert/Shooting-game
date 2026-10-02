class_name CombatHUD
extends Control

var world: CombatArena
var hit_time := 0.0
var headshot := false
var damage_time := 0.0
var damage_origin := Vector3.ZERO
var shot_time := 0.0
var font: Font = preload("res://assets/InterimSans.ttf")
var bold: Font = preload("res://assets/InterimBold.ttf")
var notices: Array[Dictionary] = []
var gold := Color("edbd77")
var panel_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.065, 0.085, 0.88)
	panel_style.set_corner_radius_all(5)

func attach(arena: CombatArena) -> void:
	world = arena
	world.player.weapons.hit_confirmed.connect(func(head: bool): hit_time = 0.17; headshot = head)
	world.player.weapons.fired.connect(func(): shot_time = 0.12)
	world.player.damaged.connect(func(origin: Vector3): damage_time = 0.75; damage_origin = origin)

func _process(delta: float) -> void:
	if not visible: return
	hit_time = maxf(0, hit_time - delta)
	damage_time = maxf(0, damage_time - delta)
	shot_time = maxf(0, shot_time - delta)
	queue_redraw()

func _text(point: Vector2, value: String, font_size: int, color: Color = Color("e0e8e8"), heavy: bool = false) -> void:
	draw_string(bold if heavy else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player): return
	var player := world.player
	var weapon := player.weapons.current()
	var center := size / 2
	var dark := Color(0.035, 0.065, 0.085, 0.88)
	draw_style_box(_panel(dark), Rect2(22, 18, minf(size.x * 0.59, 640), 76))
	_text(Vector2(38, 42), "OP %02d  /  %s" % [int(world.definition.id) + 1, str(world.definition.name).to_upper()], 13, gold, true)
	_text(Vector2(38, 70), world.objectives.description(), 18)
	var steps := world.objectives.steps.size()
	for i in range(steps): draw_rect(Rect2(38 + i * 26, 82, 20, 3), gold if i <= world.objectives.index else Color("45545b"))
	_text(Vector2(size.x - 158, 41), "%02d:%02d" % [int(world.elapsed) / 60, int(world.elapsed) % 60], 15)
	var spread := 7.0 + shot_time * 50 + (0 if player.controls.aim else 4)
	var color := Color("eee8da")
	for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + offset * spread, center + offset * (spread + 7), color, 1.5, true)
	draw_circle(center, 1.5, gold)
	if hit_time > 0:
		for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(center + offset * 11, center + offset * 17, gold if headshot else Color.WHITE, 2, true)
	var bar_width := minf(340, size.x * 0.29)
	var left := center.x - bar_width / 2
	var bottom := size.y - 30
	draw_style_box(_panel(dark), Rect2(left - 16, bottom - 92, bar_width + 32, 109))
	_text(Vector2(left, bottom - 64), str(weapon.config.name).to_upper(), 16, gold, true)
	_text(Vector2(left + bar_width - 98, bottom - 64), "%02d / %03d" % [weapon.magazine, weapon.reserve], 18, Color.WHITE, true)
	_text(Vector2(left, bottom - 35), "HP %03d" % int(player.health.current), 13)
	draw_rect(Rect2(left + 63, bottom - 46, bar_width - 122, 6), Color("405159"))
	draw_rect(Rect2(left + 63, bottom - 46, (bar_width - 122) * player.health.current / player.health.maximum, 6), Color("80bba8") if player.health.current > 30 else Color("dc785f"))
	_text(Vector2(left + bar_width - 49, bottom - 35), "A %02d" % int(player.health.armor), 13, Color("8fb5c5"))
	_text(Vector2(left, bottom - 9), "GRENADES  %d" % player.grenades, 11, Color("a1b2b9"))
	if weapon.reload_remaining > 0:
		var fraction := 1.0 - weapon.reload_remaining / float(weapon.config.reload)
		draw_arc(center, 29, -PI / 2, -PI / 2 + TAU * fraction, 40, gold, 2, true)
		_text(center + Vector2(-44, 52), "RELOADING", 12, gold)
	elif weapon.magazine == 0:
		_text(center + Vector2(-59, 52), "OUT OF AMMO", 13, Color("df856c"))
	var prompt := world.objectives.prompt()
	if not prompt.is_empty():
		var width := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_style_box(_panel(dark), Rect2(center.x - width / 2 - 20, size.y - 186, width + 40, 38))
		_text(Vector2(center.x - width / 2, size.y - 162), prompt, 15, gold)
	if world.objectives.current().has("position"):
		var objective_position: Vector3 = world.objectives._position(world.objectives.current()) + Vector3.UP * 1.2
		var camera := player.camera_rig.camera
		if not camera.is_position_behind(objective_position):
			var point := camera.unproject_position(objective_position)
			point = point.clamp(Vector2(30, 120), size - Vector2(30, 210))
			draw_polyline(PackedVector2Array([point + Vector2(0, -9), point + Vector2(7, 0), point + Vector2(0, 9), point + Vector2(-7, 0), point + Vector2(0, -9)]), gold, 1.7, true)
	if damage_time > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.13, 0.06, damage_time * 0.1))
		var direction := damage_origin - player.global_position
		var angle := atan2(direction.x, -direction.z) + player.camera_rig.yaw
		var point := center + Vector2(sin(angle), -cos(angle)) * 110
		draw_circle(point, 5, Color(0.9, 0.44, 0.3, damage_time))
	for enemy in world.spawner.active:
		if enemy.kind != "boss": continue
		var width := minf(420, size.x * 0.35)
		draw_rect(Rect2(center.x - width / 2, 119, width, 9), Color("3d3a37"))
		draw_rect(Rect2(center.x - width / 2, 119, width * enemy.health.current / enemy.health.maximum, 9), Color("c79664"))
		_text(Vector2(center.x - width / 2, 112), "WARDEN  /  PHASE %d%s" % [enemy.boss_phase, "  •  EXPOSED" if enemy.weakness_remaining > 0 else ""], 13, gold, true)

func _panel(color: Color) -> StyleBoxFlat:
	panel_style.bg_color = color
	return panel_style
