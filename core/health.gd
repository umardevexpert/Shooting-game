class_name CombatHealth
extends RefCounted

signal changed
signal died
var maximum: float
var current: float
var armor: float
var dead: bool = false

func _init(hp: float = 100.0, protection: float = 0.0) -> void:
	maximum = hp
	current = hp
	armor = protection

func damage(amount: float, headshot: bool = false, multiplier: float = 1.0) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var total := amount * (multiplier if headshot else 1.0)
	var absorbed := minf(armor, total * 0.55)
	armor -= absorbed
	var dealt := minf(current, total - absorbed)
	current -= dealt
	changed.emit()
	if current <= 0.0:
		dead = true
		died.emit()
	return dealt

func heal(amount: float) -> void:
	if dead:
		return
	current = minf(maximum, current + maxf(0.0, amount))
	changed.emit()
