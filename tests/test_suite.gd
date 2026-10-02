extends Node

var failures: Array[String] = []
var checks := 0
var game: Node
var original_profile: Dictionary

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)
	else: print("PASS: " + label)

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func _run() -> void:
	await get_tree().process_frame
	original_profile = Profile.data.duplicate(true)
	Profile.data = Profile.defaults()
	_health_tests()
	_weapon_tests()
	_save_and_economy_tests()
	game = load("res://core/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().create_timer(0.7).timeout
	await frames(2)
	check(game.ui.screen == "main", "Launch reaches main menu")
	game.start_mission(0)
	await frames(180)
	check(game.arena.spawner.active.size() == 3, "Training mission spawns three enemies")
	check(game.arena.player.is_on_floor(), "Player collides with arena floor")
	await _touch_and_pause_tests()
	_asset_tests()
	await _combat_tests()
	await _campaign_tests()
	await _layout_tests()
	Profile.data = original_profile
	Profile.commit()
	get_tree().paused = false
	game.queue_free()
	await frames(3)
	print("TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _health_tests() -> void:
	var health := CombatHealth.new(100, 40)
	health.damage(40)
	check(is_equal_approx(health.current, 82) and is_equal_approx(health.armor, 18), "Armor absorbs 55% until exhausted")
	health.damage(10, true, 2)
	check(is_equal_approx(health.current, 73), "Headshot multiplier passes through armor correctly")
	health.heal(1000)
	check(health.current == 100, "Healing capped at maximum")
	health.damage(1000)
	health.heal(1000)
	check(health.dead and health.current == 0, "Death is terminal and cannot be healed")

func _weapon_tests() -> void:
	var pistol := WeaponState.new("pistol", Catalog.weapon("pistol"))
	check(pistol.trigger(true), "Semi-auto fires on trigger edge")
	pistol.tick(1)
	check(not pistol.trigger(true), "Holding semi-auto does not fire repeatedly")
	pistol.trigger(false)
	check(pistol.trigger(true), "Releasing permits next semi-auto shot")
	var before := pistol.reserve
	check(pistol.reload(), "Reload begins with partial magazine")
	check(not pistol.trigger(true), "Shooting blocked during reload")
	pistol.tick(5)
	check(pistol.magazine == 12 and pistol.reserve == before - 2, "Reload transfers exact ammunition")
	pistol.magazine = 0
	pistol.reserve = 0
	check(not pistol.trigger(true) and not pistol.reload(), "Empty reserve safely blocks firing and reload")
	var rifle := WeaponState.new("rifle", Catalog.weapon("rifle"))
	rifle.trigger(true)
	check(not rifle.trigger(true), "Fire rate prevents duplicate shot in same tick")
	rifle.tick(1)
	check(rifle.trigger(true), "Automatic weapon fires while held after cooldown")
	rifle.reload()
	rifle.cancel_reload()
	check(rifle.reload_remaining == 0, "Switching cancels reload without gaining ammunition")
	var burst := WeaponState.new("burst", Catalog.weapon("burst"))
	for i in range(3):
		check(burst.trigger(true), "Burst shot %d" % (i + 1))
		burst.tick(0.1)
	burst.tick(1)
	check(not burst.trigger(true) and burst.magazine == 21, "Burst stops after three rounds until release")

func _save_and_economy_tests() -> void:
	check(Catalog.valid and Catalog.validate_data().is_empty(), "All weapon, enemy, player and campaign data passes catalog validation")
	var saved_definition: Variant = Catalog.weapons.pistol
	Catalog.weapons.pistol = {}
	check(not Catalog.validate_data().is_empty(), "Missing catalog fields reported before gameplay initialization")
	Catalog.weapons.pistol = saved_definition
	var malformed := {"version": 1, "xp": -40, "credits": "broken", "ratings": {"0": 9, "999": 3}, "unlocked": ["fake", 12, "smg"], "upgrades": {"rifle": {"damage": 999, "bogus": 4}}, "settings": {"difficulty": "bad", "sensitivity": -9}, "loadout": ["fake", "smg"]}
	var clean := Profile.sanitize(malformed)
	check(clean.version == 2 and clean.xp == 0 and clean.credits == 0, "Save migration and malformed scalar recovery")
	check(clean.ratings.size() == 1 and clean.ratings["0"] == 3, "Save ratings bounded to real missions and three stars")
	check(clean.upgrades.rifle.damage == 5 and not clean.upgrades.rifle.has("bogus"), "Save upgrades sanitized")
	check(clean.settings.difficulty == "Normal" and clean.settings.sensitivity == 0.15, "Settings sanitized and bounded")
	check(not Profile.mission_unlocked(1), "Future mission locked before prerequisite")
	check(not Profile.unlock("sniper"), "Unlock denied without mission prerequisite and funds")
	check(not Profile.purchase_upgrade("rifle", "damage"), "Upgrade cannot overspend")
	Profile.complete(0, 2, 30)
	check(Profile.mission_unlocked(1) and Profile.data.credits == 210, "Completion unlocks next mission and credits")
	check(Profile.purchase_upgrade("rifle", "damage") and Profile.data.credits == 120, "Upgrade debits exact currency")
	check(Catalog.weapon("rifle").damage > Catalog.weapons.rifle.damage, "Purchased upgrade changes effective weapon stats")
	Profile.data.credits = 400
	check(Profile.unlock("smg") and Profile.data.credits == 160, "Unlocked prerequisite permits weapon purchase")
	Profile.data.settings.left_handed = true
	Profile.commit()
	var saved := Profile.data.duplicate(true)
	Profile.data = {}
	Profile.load_profile()
	check(Profile.data == saved, "Save/load roundtrip retains complete profile")
	var file := FileAccess.open(Profile.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{bad data")
	file.close()
	Profile.load_profile()
	check(not Profile.data.is_empty() and Profile.data.has("settings"), "Corrupted save recovers from backup")
	Profile.data = Profile.defaults()
	Profile.data.settings.difficulty = "Easy"

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	game.ui.controls._input(event)

func drag(index: int, point: Vector2, relative_value: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative_value
	game.ui.controls._input(event)

func _touch_and_pause_tests() -> void:
	var controls: MobileInput = game.ui.controls
	controls.regions = {"fire": Vector2(1210, 566), "aim": Vector2(1119, 609)}
	var before: Vector3 = game.arena.player.global_position
	touch(0, Vector2(100, 600), true)
	drag(0, Vector2(100, 548), Vector2(0, -52))
	touch(1, Vector2(900, 320), true)
	drag(1, Vector2(920, 315), Vector2(20, -5))
	touch(2, Vector2(1210, 566), true)
	check(controls.movement.y < -0.8 and controls.look_delta.x == 20 and controls.fire, "Three concurrent touch IDs move, look and fire independently")
	await frames(30)
	check(game.arena.player.global_position.distance_to(before) > 1, "Touch movement drives real player physics")
	touch(2, Vector2(1210, 566), false)
	check(not controls.fire and controls.move_touch == 0, "Releasing fire preserves movement touch")
	controls.clear()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	check(game.state == game.State.PAUSED and game.ui.screen == "pause", "Escape pauses once across handled and unhandled input callbacks")
	var elapsed: float = game.arena.elapsed
	await frames(30)
	check(game.arena.elapsed == elapsed and get_tree().paused, "Pause freezes combat and mission time")
	check(not controls.fire and controls.move_touch == -1, "Pause clears held touch state")
	get_viewport().push_input(escape)
	check(game.state == game.State.PLAYING, "Escape resumes from the pause menu")
	await frames(4)
	check(game.arena.elapsed > elapsed and game.state == game.State.PLAYING, "Resume restores simulation")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(get_tree().paused and game.ui.screen == "pause", "Android background notification pauses safely")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(get_tree().paused, "Returning foreground waits for explicit resume")
	game.resume_game()
	var original: String = game.arena.player.weapons.current().id
	game.arena.player.weapons.reload()
	game.arena.player.weapons.switch_weapon()
	check(game.arena.player.weapons.current().id != original, "Live weapon switching selects secondary")
	game.arena.player.weapons.switch_weapon()

func _asset_tests() -> void:
	var visual: ActorVisual = game.arena.player.visual
	check(visual.skeleton.get_bone_count() >= 49 and visual.skeleton.find_bone("hand.R") >= 0, "Imported humanoid retains weighted skeleton and hand attachment bone")
	var body: MeshInstance3D = visual.model.find_child("Swat_Body", true, false)
	check(body.mesh is ArrayMesh and body.skin != null, "Player renders an imported skinned mesh")
	check(visual.animator.tree.active and visual.animator.player.has_animation("combat/reload") and visual.animator.player.has_animation("combat/death"), "Animation blend graph includes retargeted reload and death clips")
	check(visual.animator.player.has_animation("reload_source") and visual.animator.player.has_animation("death_source"), "Human rig contains licensed retargeted combat clips")
	visual.equip_weapon("rifle")
	visual.animate(0.1, 0, true, false, false)
	var left := visual.skeleton.find_bone("hand.L")
	var hand_position: Vector3 = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(left).origin
	check(hand_position.distance_to(visual.weapon.support_grip.global_position) < 0.08, "Left-hand IK reaches the firearm support grip")
	var to_target: Vector3 = (visual.aim_target - visual.weapon.muzzle.global_position).normalized() if visual.aim_target != Vector3.INF else visual.global_basis * Vector3(0, sin(visual.aim_pitch), -cos(visual.aim_pitch))
	check(visual.weapon.global_basis.z.normalized().dot(to_target.normalized()) > 0.998, "Rendered firearm barrel aligns with the actual aim target")
	check(visual.weapon.get_parent() is BoneAttachment3D and visual.weapon.get_parent().bone_name == "hand.R", "Weapon remains attached to the animated hand bone")
	check(game.arena.player.weapons.muzzle_origin().distance_to(visual.weapon.muzzle.global_position) < 0.03, "Clear muzzle ray starts at actual model muzzle socket")
	check(MaterialLibrary.get_material("container2").normal_texture != null and MaterialLibrary.get_material("mid_cargo_box").albedo_texture != null, "Imported environment materials load albedo and normal maps")
	var thigh := visual.skeleton.find_bone("thigh.L")
	visual.local_movement = Vector3(0, 0, -3)
	visual.animate(0.1, 3, false, false, false)
	var first := visual.skeleton.get_bone_pose_rotation(thigh)
	visual.animate(0.2, 3, false, false, false)
	check(first.angle_to(visual.skeleton.get_bone_pose_rotation(thigh)) > 0.01, "Locomotion changes the skinned leg pose over time")

	var models: Array[String] = []
	for id in Catalog.weapons:
		visual.equip_weapon(id)
		models.append(visual.weapon.model.scene_file_path)
	var sizes_match := true
	for enemy in game.arena.spawner.active:
		sizes_match = sizes_match and is_equal_approx(enemy.visual.scale.y, enemy.get_meta("body_scale"))
	check(sizes_match, "Human enemy visuals and damage colliders use the same body scale")
	check(models.size() == 8 and not models.any(func(path: String) -> bool: return models.count(path) > 1), "Eight weapon categories instantiate distinct imported models")
	visual.equip_weapon("rifle")

func _combat_tests() -> void:
	var arena: CombatArena = game.arena
	var enemy: EnemyController = arena.spawner.active[0]
	# Put both actors in a clear shooting lane; the real physics ray must hit.
	arena.player.global_position = Vector3(0, 0.1, 10)
	enemy.global_position = Vector3(0, 0.1, 4)
	enemy.set_physics_process(false)
	arena.player.camera_rig.yaw = 0
	arena.player.camera_rig.pitch = 0
	arena.player.controls.aim = true
	await frames(30)
	var initial_health: float = enemy.health.current
	for i in range(90):
		if enemy.health.dead: break
		var camera: Camera3D = arena.player.camera_rig.camera
		var direction := enemy.global_position + Vector3.UP * 1.45 - camera.global_position
		arena.player.camera_rig.yaw = atan2(-direction.x, -direction.z)
		arena.player.camera_rig.pitch = asin(direction.normalized().y) - arena.player.camera_rig.recoil
		arena.player.controls.fire = true
		await get_tree().physics_frame
	arena.player.controls.fire = false
	check(enemy.health.current < initial_health and arena.player.weapons.hit_count > 0, "Real camera/muzzle hitscan damages physical enemy collider")
	if not enemy.health.dead: enemy.take_damage(1000, arena.player.global_position)
	check(enemy.health.dead and enemy not in arena.spawner.active, "Enemy death removes active encounter participant")
	check(arena.player.weapons.fired_count > 0, "Shooting invokes reusable weapon framework")
	var grenade_count := arena.player.grenades
	arena.player._action("grenade")
	check(arena.player.grenades == grenade_count - 1, "Grenade launches a pooled physics projectile")
	var explosion_hp := arena.player.health.current
	arena.area_damage(arena.player.global_position + Vector3.UP, 3.4, 20, arena.player)
	check(arena.player.health.current < explosion_hp, "Area damage reaches the player without a typed enemy-array error")
	var previous_hp := arena.player.health.current
	arena.player.take_damage(20, Vector3(0, 0, 1))
	check(arena.player.health.current < previous_hp, "Enemy damage reaches player health and HUD")
	arena.player.take_damage(10000, Vector3.ZERO)
	await frames(3)
	check(game.state == game.State.RESULT and game.ui.screen == "failed", "Player death produces mission failure screen")
	var death_hips := arena.player.visual.skeleton.find_bone("hips")
	var death_start := arena.player.visual.skeleton.get_bone_pose_rotation(death_hips)
	await frames(20)
	check(death_start.angle_to(arena.player.visual.skeleton.get_bone_pose_rotation(death_hips)) > 0.01, "Human death animation continues behind the failure overlay while gameplay stays paused")
	game.start_mission(0)
	await frames(5)
	check(game.arena.player.health.current == 100 and not get_tree().paused, "Restart replaces world and resets combat state")

func _campaign_tests() -> void:
	for mission in Catalog.missions:
		var id := int(mission.id)
		game.start_mission(id)
		await frames(4)
		var arena: CombatArena = game.arena
		var guard := 0
		# Integration driver supplies actual damage/interaction events to verify all
		# authored objective chains. This is not a balance or human playability test.
		while not arena.objectives.finished and guard < 600:
			guard += 1
			var step: Dictionary = arena.objectives.current()
			match step.type:
				"reach", "escape":
					arena.player.global_position = arena.objectives._position(step) + Vector3.UP * 0.1
					if is_instance_valid(arena.objectives.engineer): arena.objectives.engineer.global_position = arena.player.global_position + Vector3.RIGHT
				"collect", "activate", "rescue":
					arena.player.global_position = arena.objectives._position(step) + Vector3.UP * 0.1
					arena.objectives.interact()
				"eliminate", "waves", "boss":
					for active_enemy in arena.spawner.active.duplicate():
						if active_enemy.kind == "boss":
							active_enemy.take_damage(260, arena.player.global_position)
							active_enemy._boss_update(0.1)
						else: active_enemy.take_damage(5000, arena.player.global_position)
				"destroy": arena.objectives.target.take_damage(5000, arena.player.global_position)
				"defend":
					arena.player.global_position = arena.objectives._position(step) + Vector3.UP * 0.1
					arena.objectives.progress += 1
					for active_enemy in arena.spawner.active.duplicate(): active_enemy.take_damage(5000, arena.player.global_position)
			await frames(5)
		await frames(3)
		check(arena.objectives.finished and game.ui.screen == "complete", "Mission %02d complete objective chain and results" % (id + 1))
		check(Profile.data.ratings.has(str(id)), "Mission %02d rewards persist" % (id + 1))
		if id == 7: check(arena.spawner.wave == 3, "Survival mission completes all three configured waves")
		if id == 9: check(arena.spawner.boss_defeated, "Final mission requires boss death")
		if not arena.objectives.finished: break
	check(Profile.data.ratings.size() == 10, "All ten campaign missions can complete sequentially")
	var credits: int = Profile.data.credits
	game.mission_complete()
	check(Profile.data.credits == credits, "Results cannot award currency twice")
	game.main_menu()
	await frames(3)
	check(game.state == game.State.MENU and not get_tree().paused, "Return to base cleans world and resumes menus")

func _layout_tests() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		for name in ["main", "campaign", "loadout", "weapons", "upgrades", "settings", "about"]:
			game.ui.show_screen(name)
			await frames(2)
		check(game.ui.root.size.x > 0 and game.ui.root.size.y > 0, "UI mounts all menus at %dx%d" % [resolution.x, resolution.y])
