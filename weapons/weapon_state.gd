class_name WeaponState
extends RefCounted

var id: String
var config: Dictionary
var magazine: int
var reserve: int
var cooldown := 0.0
var reload_remaining := 0.0
var trigger_down := false
var burst_remaining := 0

func _init(weapon_id: String, definition: Dictionary) -> void:
	id = weapon_id
	config = definition
	magazine = int(config.magazine)
	reserve = int(config.reserve)

func tick(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if reload_remaining > 0:
		reload_remaining = maxf(0, reload_remaining - delta)
		if reload_remaining == 0:
			var transfer := mini(int(config.magazine) - magazine, reserve)
			magazine += transfer
			reserve -= transfer

func reload() -> bool:
	if reload_remaining > 0 or reserve <= 0 or magazine == int(config.magazine): return false
	reload_remaining = float(config.reload)
	burst_remaining = 0
	return true

func cancel_reload() -> void:
	reload_remaining = 0
	burst_remaining = 0
	trigger_down = false

func trigger(held: bool) -> bool:
	var edge := held and not trigger_down
	trigger_down = held
	if config.mode == "burst" and edge and reload_remaining == 0 and magazine > 0 and cooldown == 0:
		burst_remaining = 3
	var requested := held if config.mode == "auto" else edge if config.mode == "semi" else burst_remaining > 0
	if not requested or cooldown > 0 or reload_remaining > 0 or magazine <= 0:
		return false
	magazine -= 1
	cooldown = 1.0 / float(config.rate)
	if config.mode == "burst":
		burst_remaining -= 1
		if burst_remaining == 0: cooldown += 0.18
	return true

func add_ammo(amount: int) -> void:
	reserve = mini(reserve + maxi(0, amount), int(config.reserve) * 2)
