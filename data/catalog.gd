extends Node

var weapon_visuals: Dictionary
var weapons: Dictionary
var enemies: Dictionary
var difficulties: Dictionary
var missions: Array
var player: Dictionary
var valid := false
var errors: Array[String] = []

func _ready() -> void:
	weapons = _read("weapons", {})
	weapon_visuals = _read("weapon_visuals", {})
	enemies = _read("enemies", {})
	difficulties = _read("difficulty", {})
	missions = _read("missions", [])
	player = _read("player", {})
	errors.append_array(validate_data())
	valid = errors.is_empty()
	if not valid: push_error("Game catalog invalid: " + "; ".join(errors))

func _read(file: String, fallback: Variant) -> Variant:
	var path := "res://data/%s.json" % file
	if not FileAccess.file_exists(path):
		errors.append("Missing " + path)
		return fallback
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or typeof(parser.data) != typeof(fallback):
		errors.append("Malformed " + path)
		return fallback
	return parser.data

func validate_data() -> Array[String]:
	var problems: Array[String] = []
	if not weapons.has("pistol") or not weapons.has("rifle"): problems.append("Starting weapons missing")
	for id in weapons:
		if not weapon_visuals.get(id) is Dictionary or not ResourceLoader.exists(str(weapon_visuals.get(id, {}).get("model", ""))):
			problems.append("Weapon model missing: " + str(id))
		if not weapons[id] is Dictionary:
			problems.append("Invalid weapon " + str(id))
			continue
		for key in ["name", "category", "mode", "damage", "rate", "magazine", "reserve", "reload", "spread", "recoil", "range", "headshot", "pellets", "speed", "unlock", "cost"]:
			if not weapons[id].has(key): problems.append("Weapon %s missing %s" % [id, key])
	if enemies.is_empty() or difficulties.is_empty(): problems.append("Enemy or difficulty data missing")
	for id in enemies:
		if not enemies[id] is Dictionary:
			problems.append("Invalid enemy " + str(id))
			continue
		for key in ["name", "health", "armor", "speed", "damage", "range", "rate", "accuracy", "reaction", "color", "reward"]:
			if not enemies[id].has(key): problems.append("Enemy %s missing %s" % [id, key])
	for name in ["Easy", "Normal", "Hard"]:
		if not difficulties.get(name) is Dictionary: problems.append("Difficulty missing: " + name)
		else:
			for key in ["damage", "accuracy", "reaction", "aggression", "pickups"]:
				if not difficulties[name].has(key): problems.append("Difficulty %s missing %s" % [name, key])
	for key in ["health", "armor", "speed", "sprint", "aim_speed", "acceleration", "gravity", "grenades", "grenade_damage", "grenade_radius", "camera_distance", "upgrades"]:
		if not player.has(key): problems.append("Player stat missing: " + key)
	if missions.is_empty(): problems.append("Campaign is empty")
	for i in range(missions.size()):
		var mission: Variant = missions[i]
		if not mission is Dictionary:
			problems.append("Invalid mission " + str(i))
			continue
		for key in ["id", "name", "brief", "theme", "color", "enemies", "layout", "objectives", "reward", "xp", "par"]:
			if not mission.has(key): problems.append("Mission %d missing %s" % [i, key])
		if mission.get("id") != i: problems.append("Mission IDs must be ordered and contiguous")
		if not mission.get("objectives") is Array or mission.get("objectives", []).is_empty():
			problems.append("Mission %d has no objectives" % i)
	return problems

func weapon(id: String) -> Dictionary:
	var result: Dictionary = weapons.get(id, weapons.pistol).duplicate(true)
	var levels: Dictionary = Profile.data.upgrades.get(id, {})
	for stat in player.upgrades:
		var rank: int = int(levels.get(stat, 0))
		var bonus: float = float(player.upgrades[stat]) * rank
		match stat:
			"damage": result.damage *= 1.0 + bonus
			"magazine": result.magazine = int(result.magazine * (1.0 + bonus))
			"reload": result.reload *= 1.0 - bonus
			"accuracy": result.spread *= 1.0 - bonus
			"rate": result.rate *= 1.0 + bonus
			"stability": result.recoil *= 1.0 - bonus
	return result

func _exit_tree() -> void:
	Geometry.materials.clear()
