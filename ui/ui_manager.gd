class_name GameUI
extends CanvasLayer

const GOLD := Color("e9b56d")
const TEXT := Color("e6ecee")
const MUTED := Color("97aab5")
var game: Node
var root: Control
var content: Control
var controls: MobileInput
var hud: CombatHUD
var screen := "main"
var selected_weapon := "rifle"
var toast_label: Label
var toast_timer := 0.0
var theme_data: Theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	theme_data = _create_theme()
	root.theme = theme_data
	hud = CombatHUD.new()
	root.add_child(hud)
	hud.visible = false
	controls = MobileInput.new()
	root.add_child(controls)
	content = Control.new()
	root.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label = Label.new()
	root.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -300
	toast_label.offset_right = 300
	toast_label.offset_top = 155
	toast_label.offset_bottom = 197
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", GOLD)
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.visible = false
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()

func _create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = preload("res://assets/InterimSans.ttf")
	result.default_font_size = 17
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", Color("52656f"))
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("1d303c") if state_name == "normal" else Color("2c4654") if state_name in ["hover", "pressed"] else Color("13232c")
		box.border_color = GOLD if state_name == "focus" else Color("3d5260")
		box.set_border_width_all(1)
		box.set_corner_radius_all(5)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		result.set_stylebox(state_name, "Button", box)
		result.set_stylebox(state_name, "OptionButton", box)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 16)
	result.set_constant("h_separation", "GridContainer", 14)
	result.set_constant("v_separation", "GridContainer", 14)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("162934")
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(18)
	result.set_stylebox("panel", "PanelContainer", panel)
	return result

func _safe_area() -> void:
	if not OS.has_feature("mobile"): return
	var physical := Vector2(DisplayServer.window_get_size())
	if physical.x <= 0 or physical.y <= 0: return
	var safe := DisplayServer.get_display_safe_area()
	var viewport_size := root.get_viewport_rect().size
	var scale_value := viewport_size / physical
	root.offset_left = safe.position.x * scale_value.x
	root.offset_top = safe.position.y * scale_value.y
	root.offset_right = -(physical.x - safe.end.x) * scale_value.x
	root.offset_bottom = -(physical.y - safe.end.y) * scale_value.y

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _label(parent: Node, text: String, font_size: int = 17, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, primary: bool = false, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.disabled = disabled
	if primary:
		var box := StyleBoxFlat.new()
		box.bg_color = GOLD
		box.set_corner_radius_all(5)
		box.set_content_margin_all(12)
		button.add_theme_stylebox_override("normal", box)
		button.add_theme_color_override("font_color", Color("17232b"))
	parent.add_child(button)
	button.pressed.connect(func(): Audio.play("ui", "UI"); callback.call())
	return button

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	return stack

func _background(alpha: float = 0.96) -> void:
	var background := ColorRect.new()
	background.color = Color(0.038, 0.072, 0.098, alpha)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(background)

func _page(title: String, subtitle: String) -> VBoxContainer:
	_background()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 38)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	content.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	_button(header, "‹  BACK", go_back)
	var title_label := _label(header, title, 29)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "LV %02d   /   %s CR" % [Profile.level(), str(Profile.data.credits)], 16, GOLD)
	_label(stack, subtitle, 15, MUTED)
	var divider := HSeparator.new()
	stack.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func show_screen(name: String) -> void:
	if OS.is_debug_build(): print("IRONFALL_SCREEN " + name)
	screen = name
	controls.enabled = false
	controls.queue_redraw()
	hud.visible = false
	content.visible = true
	_clear()
	match name:
		"splash":
			_background()
			var center := CenterContainer.new()
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			content.add_child(center)
			_label(center, "IRONFALL", 64, GOLD)
		"main": _main()
		"campaign": _campaign()
		"loadout": _loadout()
		"weapons", "upgrades": _armory(name == "upgrades")
		"settings": _settings()
		"pause": _pause()
		"complete": _results(true)
		"failed": _results(false)
		"about": _about()
	var tween := create_tween()
	content.modulate.a = 0
	tween.tween_property(content, "modulate:a", 1.0, 0.18)

func show_game(arena: CombatArena, attach_signals: bool = true) -> void:
	if OS.is_debug_build(): print("IRONFALL_SCREEN game")
	screen = "game"
	content.visible = false
	hud.visible = true
	controls.enabled = true
	controls.queue_redraw()
	if attach_signals: hud.attach(arena)

func _main() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.07, 0.84)
	shade.anchor_right = 0.48
	shade.anchor_bottom = 1
	content.add_child(shade)
	var margin := MarginContainer.new()
	margin.anchor_right = 0.43
	margin.anchor_bottom = 1
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	content.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_label(stack, "TACTICAL CAMPAIGN  /  OFFLINE", 13, GOLD)
	_label(stack, "IRONFALL", 52)
	_label(stack, "OPERATION BLACKOUT", 17, MUTED)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	_label(stack, "OPERATOR %02d   •   %d CR" % [Profile.level(), Profile.data.credits], 17, GOLD)
	_label(stack, "%d / %d MISSIONS CLEARED" % [Profile.completed_count(), Catalog.missions.size()], 13, MUTED)
	_button(stack, "PLAY CAMPAIGN   →", func(): show_screen("campaign"), true)
	var row := HBoxContainer.new()
	stack.add_child(row)
	for item in [["WEAPONS", "weapons"], ["UPGRADES", "upgrades"]]:
		var destination: String = item[1]
		var button := _button(row, item[0], func(): show_screen(destination))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row = HBoxContainer.new()
	stack.add_child(row)
	_button(row, "SETTINGS", func(): show_screen("settings")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "ABOUT", func(): show_screen("about")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(stack, "MOVE • AIM • OVERCOME", 11, MUTED)
	var info := Label.new()
	info.text = "TEN OPERATIONS\nONE LAST SIGNAL."
	info.add_theme_font_size_override("font_size", 21)
	info.add_theme_color_override("font_color", MUTED)
	content.add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.anchor_left = 0.59
	info.anchor_right = 0.97
	info.anchor_top = 0.78
	info.anchor_bottom = 0.96

func _campaign() -> void:
	var body := _page("OPERATIONS", "Complete each mission to unlock the next. Stars: clear / 50% health / target time.")
	var grid := GridContainer.new()
	grid.columns = 2
	body.add_child(grid)
	for mission in Catalog.missions:
		var id := int(mission.id)
		var unlocked := Profile.mission_unlocked(id)
		var stars := int(Profile.data.ratings.get(str(id), 0))
		var card := _card(grid)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(card, "%02d   /   %s" % [id + 1, str(mission.name).to_upper()], 19, TEXT if unlocked else MUTED)
		var description := _label(card, mission.brief, 14, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(270, 42)
		_label(card, "★".repeat(stars) + "☆".repeat(3 - stars) + "   •   %d CR / %d XP" % [mission.reward, mission.xp], 16, GOLD)
		_button(card, "PREPARE LOADOUT  →" if unlocked else "LOCKED • CLEAR OP %02d" % id, func(): game.selected_mission = id; show_screen("loadout"), false, not unlocked)

func _loadout() -> void:
	var mission: Dictionary = Catalog.missions[game.selected_mission]
	var body := _page("DEPLOYMENT  /  %02d" % (game.selected_mission + 1), str(mission.name).to_upper() + "  •  " + str(Profile.data.settings.difficulty).to_upper())
	var briefing := _card(body)
	_label(briefing, mission.brief, 17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(briefing, "\n".join(mission.objectives.map(func(step): return "• " + str(step.text))), 15, MUTED)
	var row := HBoxContainer.new()
	body.add_child(row)
	for slot in range(2):
		var card := _card(row)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(card, "PRIMARY" if slot == 0 else "SECONDARY", 13, GOLD)
		var picker := OptionButton.new()
		picker.custom_minimum_size.y = 48
		card.add_child(picker)
		var available: Array = Profile.data.unlocked
		for i in range(available.size()):
			picker.add_item(Catalog.weapons[available[i]].name)
			if available[i] == Profile.data.loadout[slot]: picker.select(i)
		picker.item_selected.connect(func(index: int):
			var other := 1 - slot
			var previous: String = Profile.data.loadout[slot]
			Profile.data.loadout[slot] = available[index]
			if Profile.data.loadout[other] == available[index]: Profile.data.loadout[other] = previous
			Profile.commit()
			show_screen("loadout"))
		var weapon: Dictionary = Catalog.weapon(Profile.data.loadout[slot])
		_label(card, "%s  •  %s\nDMG %d    RPM %d    MAG %d\nRELOAD %.1fs    ACC %d%%" % [weapon.category, weapon.mode.to_upper(), weapon.damage, weapon.rate * 60, weapon.magazine, weapon.reload, (1.0 - weapon.spread * 6) * 100], 15, MUTED)
	_label(body, "EQUIPMENT   /   3 FRAGMENTATION GRENADES   •   40 ARMOR", 14, GOLD)
	_button(body, "DEPLOY TO " + str(mission.name).to_upper() + "   →", func(): game.start_mission(game.selected_mission), true)
	_label(body, "Touch: left stick • drag right to look • FIRE • ADS • USE\nDesktop: WASD • hold right mouse to look • left mouse fire • C aim • R reload • Q switch • E use • G grenade • Space roll", 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _armory(upgrades: bool) -> void:
	var body := _page("WORKSHOP" if upgrades else "ARMORY", "Earn credits in the campaign. Purchases and upgrades are saved offline.")
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 48
	body.add_child(picker)
	var ids := Catalog.weapons.keys()
	for i in range(ids.size()):
		picker.add_item(Catalog.weapons[ids[i]].name + ("  /  LOCKED" if ids[i] not in Profile.data.unlocked else ""))
		if ids[i] == selected_weapon: picker.select(i)
	picker.item_selected.connect(func(index: int): selected_weapon = ids[index]; show_screen(screen))
	var weapon: Dictionary = Catalog.weapon(selected_weapon)
	var card := _card(body)
	_label(card, weapon.category + "  /  " + weapon.mode.to_upper(), 13, GOLD)
	_label(card, weapon.name, 34)
	_label(card, "DAMAGE %d   •   RPM %d   •   MAGAZINE %d   •   RELOAD %.2fs\nRANGE %dm   •   HEADSHOT ×%.1f   •   ACCURACY %d%%" % [weapon.damage, weapon.rate * 60, weapon.magazine, weapon.reload, weapon.range, weapon.headshot, (1 - weapon.spread * 6) * 100], 16, MUTED)
	if selected_weapon not in Profile.data.unlocked:
		var unlocked := Profile.mission_unlocked(int(weapon.unlock))
		_label(card, "Requires OP %02d unlocked  •  %d CR" % [int(weapon.unlock) + 1, weapon.cost], 16, GOLD)
		_button(card, "UNLOCK WEAPON", func():
			if Profile.unlock(selected_weapon): toast("Weapon unlocked")
			show_screen(screen), true, not unlocked or Profile.data.credits < weapon.cost)
		return
	if not upgrades:
		_button(card, "UPGRADE THIS WEAPON   →", func(): show_screen("upgrades"), true)
		_button(card, "EQUIP AS PRIMARY", func():
			var previous: String = Profile.data.loadout[0]
			Profile.data.loadout[0] = selected_weapon
			if Profile.data.loadout[1] == selected_weapon: Profile.data.loadout[1] = previous
			Profile.commit()
			toast("Primary weapon equipped"))
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		body.add_child(grid)
		for stat in Catalog.player.upgrades:
			var rank := int(Profile.data.upgrades.get(selected_weapon, {}).get(stat, 0))
			var cost := Profile.upgrade_cost(selected_weapon, stat)
			var item := _card(grid)
			item.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(item, str(stat).to_upper() + "  /  " + "■".repeat(rank) + "□".repeat(5 - rank), 17, GOLD)
			_button(item, "MAXED" if rank == 5 else "UPGRADE  •  %d CR" % cost, func():
				if Profile.purchase_upgrade(selected_weapon, stat): toast("Upgrade installed")
				show_screen("upgrades"), false, rank == 5 or Profile.data.credits < cost)

func _settings() -> void:
	var body := _page("SETTINGS", "Changes are saved automatically. Low graphics targets 30 FPS; Medium/High target 60.")
	for item in [["difficulty", ["Easy", "Normal", "Hard"]], ["graphics", ["Low", "Medium", "High"]]]:
		var key: String = item[0]
		var choices: Array = item[1]
		var row := HBoxContainer.new()
		body.add_child(row)
		_label(row, key.to_upper(), 16, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picker := OptionButton.new()
		row.add_child(picker)
		for choice in choices: picker.add_item(choice)
		picker.select(choices.find(Profile.data.settings[key]))
		picker.item_selected.connect(func(index: int):
			Profile.data.settings[key] = choices[index]
			Profile.commit()
			if is_instance_valid(game.arena) and key == "graphics": game.arena.apply_graphics())
	for key in ["sensitivity", "aim_sensitivity", "opacity", "master", "music", "sfx", "ui", "weapon", "environment"]:
		var row := HBoxContainer.new()
		body.add_child(row)
		_label(row, str(key).replace("_", " ").to_upper(), 15).custom_minimum_size.x = 230
		var slider := HSlider.new()
		row.add_child(slider)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 42
		slider.min_value = 0.15 if "sensitivity" in key else 0
		slider.max_value = 2.5 if "sensitivity" in key else 1.0
		slider.step = 0.05
		slider.value = Profile.data.settings[key]
		var readout := _label(row, "%.2f" % slider.value, 15, GOLD)
		readout.custom_minimum_size.x = 50
		slider.value_changed.connect(func(value: float):
			Profile.data.settings[key] = value
			readout.text = "%.2f" % value
			Audio.apply_settings())
		slider.drag_ended.connect(func(_changed: bool): Profile.commit())
	for key in ["aim_assist", "haptics", "left_handed"]:
		var toggle := CheckButton.new()
		body.add_child(toggle)
		toggle.text = str(key).replace("_", " ").to_upper()
		toggle.custom_minimum_size.y = 48
		toggle.button_pressed = Profile.data.settings[key]
		toggle.toggled.connect(func(value: bool): Profile.data.settings[key] = value; Profile.commit())
	_label(body, "Difficulty applies on the next deployment.\nTouch controls mirror when left-handed mode is enabled.", 13, MUTED)

func _pause() -> void:
	var body := _page("MISSION PAUSED", "Your operation is paused safely. Resume when ready.")
	_button(body, "RESUME OPERATION", game.resume_game, true)
	_button(body, "RESTART MISSION", func(): game.start_mission(game.selected_mission))
	_button(body, "SETTINGS", func(): show_screen("settings"))
	_button(body, "QUIT TO MAIN MENU", game.main_menu)

func _results(victory: bool) -> void:
	var body := _page("OPERATION COMPLETE" if victory else "OPERATION FAILED", str(Catalog.missions[game.selected_mission].name).to_upper())
	var card := _card(body)
	if victory:
		_label(card, "★".repeat(game.last_rewards.stars) + "☆".repeat(3 - game.last_rewards.stars), 54, GOLD)
		_label(card, "+%d CREDITS    +%d XP" % [game.last_rewards.credits, game.last_rewards.xp], 25)
		_label(card, "CLEAR  •  HEALTH %d%%  •  TIME %ds / %ds\n%d ELIMINATIONS  •  %s" % [int(game.arena.player.health.current), int(game.arena.elapsed), Catalog.missions[game.selected_mission].par, game.arena.spawner.kill_count, "PROGRESS SAVED" if Profile.persistence_available else "SAVE FAILED — storage unavailable"], 16, MUTED)
		if game.selected_mission < Catalog.missions.size() - 1:
			_button(body, "NEXT OPERATION   →", func(): game.main_menu(); game.selected_mission += 1; show_screen("loadout"), true)
		else: _label(body, "CAMPAIGN COMPLETE  /  SIGNAL RESTORED", 24, GOLD)
	else:
		_label(card, game.failure_reason, 32, GOLD)
		_label(card, "Use cover, aim for the head and watch your ammunition.", 17, MUTED)
	_button(body, "REPLAY MISSION", func(): game.start_mission(game.selected_mission))
	_button(body, "RETURN TO BASE", game.main_menu)

func _about() -> void:
	var body := _page("IRONFALL", "OPERATION BLACKOUT  /  DEVELOPMENT CAMPAIGN")
	_label(body, "IRONFALL / OPERATION BLACKOUT\n\n3D character, source animations, environment meshes and PBR textures:\n© 2018 Juan Linietsky and Fernando Miguel Calabró.\nGodot TPS Demo • Creative Commons Attribution 3.0.\nModified for Ironfall. github.com/godotengine/tps-demo\ncreativecommons.org/licenses/by/3.0/\n\nStarting weapon models / texture atlas: Kenney • CC0.\nAdditional combat animations, audio and icon: original Ironfall assets.\nFonts: DejaVu Sans (assets/FONT_LICENSE.txt).\nEngine: Godot 4.6.3 • MIT.\n\nOffline campaign • No account, ads or in-app purchases.\nSee assets/manifest.json for sources and modifications.", 16, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func go_back() -> void:
	if screen == "data_error":
		get_tree().quit()
		return
	Profile.commit()
	if screen in ["complete", "failed"]: game.main_menu()
	elif game.state == game.State.PAUSED:
		if screen == "pause": game.resume_game()
		else: show_screen("pause")
	elif screen == "loadout": show_screen("campaign")
	else: show_screen("main")

func toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_timer = 2.5

func show_data_error(detail: String) -> void:
	screen = "data_error"
	_clear()
	var body := _page("CONTENT UNAVAILABLE", "The game data could not be loaded. Your saved progress has not been changed.")
	_label(body, detail, 16, GOLD).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(body, "EXIT", func(): get_tree().quit())

func _process(delta: float) -> void:
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0: toast_label.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and screen != "game":
		go_back()
		get_viewport().set_input_as_handled()
