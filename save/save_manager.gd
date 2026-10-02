extends Node

signal changed
const VERSION := 2
const SAVE_PATH := "user://profile.json"
var data: Dictionary
var persistence_available := true

func _ready() -> void:
	if Catalog.valid: load_profile()
	else: data = defaults()

func defaults() -> Dictionary:
	return {"version": VERSION, "xp": 0, "credits": 0, "ratings": {},
		"unlocked": ["pistol", "rifle"], "upgrades": {}, "loadout": ["rifle", "pistol"],
		"settings": {"difficulty": "Normal", "graphics": "Medium", "sensitivity": 1.0,
		"aim_sensitivity": 0.65, "aim_assist": true, "opacity": 0.72,
		"left_handed": false, "haptics": true, "master": 0.8, "music": 0.35,
		"sfx": 0.8, "ui": 0.6, "weapon": 0.85, "environment": 0.5}}

func load_profile() -> void:
	data = defaults()
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 131072:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			push_warning("Ignoring malformed save: " + path)
			continue
		var candidate: Variant = parser.data
		if candidate is Dictionary and (candidate.get("version") is int or candidate.get("version") is float) and int(candidate.version) >= 1 and int(candidate.version) <= VERSION:
			data = sanitize(candidate)
			break

func sanitize(raw: Dictionary) -> Dictionary:
	var clean := defaults()
	for field in ["xp", "credits"]:
		if raw.get(field) is float or raw.get(field) is int:
			clean[field] = clampi(int(raw[field]), 0, 10000000)
	if raw.get("ratings") is Dictionary:
		for key in raw.ratings:
			if str(key).is_valid_int() and int(key) >= 0 and int(key) < Catalog.missions.size():
				var rating: Variant = raw.ratings[key]
				if rating is float or rating is int:
					clean.ratings[str(key)] = clampi(int(rating), 0, 3)
	if raw.get("unlocked") is Array:
		for id in raw.unlocked:
			if id is String and Catalog.weapons.has(id) and id not in clean.unlocked:
				clean.unlocked.append(id)
	if raw.get("upgrades") is Dictionary:
		for id in raw.upgrades:
			if not Catalog.weapons.has(id) or not raw.upgrades[id] is Dictionary:
				continue
			clean.upgrades[id] = {}
			for stat in Catalog.player.upgrades:
				var rank: Variant = raw.upgrades[id].get(stat, 0)
				if rank is float or rank is int:
					clean.upgrades[id][stat] = clampi(int(rank), 0, 5)
	if raw.get("loadout") is Array and raw.loadout.size() == 2:
		for i in range(2):
			if raw.loadout[i] in clean.unlocked:
				clean.loadout[i] = raw.loadout[i]
	if clean.loadout[0] == clean.loadout[1]:
		clean.loadout = ["rifle", "pistol"]
	if raw.get("settings") is Dictionary:
		for key in clean.settings:
			var value: Variant = raw.settings.get(key)
			match typeof(clean.settings[key]):
				TYPE_BOOL:
					if value is bool: clean.settings[key] = value
				TYPE_FLOAT:
					if (value is float or value is int) and is_finite(float(value)):
						clean.settings[key] = clampf(float(value), 0.15 if "sensitivity" in key else 0.0, 2.5 if "sensitivity" in key else 1.0)
				TYPE_STRING:
					if key == "difficulty" and value in ["Easy", "Normal", "Hard"]: clean.settings[key] = value
					if key == "graphics" and value in ["Low", "Medium", "High"]: clean.settings[key] = value
	return clean

func commit() -> bool:
	if not Catalog.valid: return false
	data = sanitize(data)
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		persistence_available = false
		push_warning("Progress could not be saved: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	var result := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	persistence_available = result == OK
	changed.emit()
	return persistence_available

func level() -> int:
	return 1 + int(sqrt(float(data.xp) / 180.0))

func completed_count() -> int:
	var result := 0
	for rating in data.ratings.values():
		if int(rating) > 0: result += 1
	return result

func mission_unlocked(id: int) -> bool:
	return id == 0 or int(data.ratings.get(str(id - 1), 0)) > 0

func complete(id: int, stars: int, kill_bonus: int) -> Dictionary:
	var mission: Dictionary = Catalog.missions[id]
	var first := int(data.ratings.get(str(id), 0)) == 0
	var reward := int(mission.reward) if first else int(mission.reward * 0.35)
	var xp := int(mission.xp) if first else int(mission.xp * 0.4)
	data.credits += reward + kill_bonus
	data.xp += xp
	data.ratings[str(id)] = maxi(int(data.ratings.get(str(id), 0)), stars)
	commit()
	return {"credits": reward + kill_bonus, "xp": xp, "stars": stars, "first": first}

func unlock(id: String) -> bool:
	if not Catalog.weapons.has(id) or id in data.unlocked:
		return false
	var weapon: Dictionary = Catalog.weapons[id]
	if not mission_unlocked(int(weapon.unlock)) or data.credits < weapon.cost:
		return false
	data.credits -= int(weapon.cost)
	data.unlocked.append(id)
	commit()
	return true

func upgrade_cost(id: String, stat: String) -> int:
	return 90 + int(data.upgrades.get(id, {}).get(stat, 0)) * 85

func purchase_upgrade(id: String, stat: String) -> bool:
	if id not in data.unlocked or not Catalog.player.upgrades.has(stat):
		return false
	var rank := int(data.upgrades.get(id, {}).get(stat, 0))
	var cost := upgrade_cost(id, stat)
	if rank >= 5 or data.credits < cost:
		return false
	if not data.upgrades.has(id): data.upgrades[id] = {}
	data.upgrades[id][stat] = rank + 1
	data.credits -= cost
	commit()
	return true
