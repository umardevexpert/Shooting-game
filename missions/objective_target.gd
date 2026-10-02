class_name ObjectiveTarget
extends StaticBody3D

signal destroyed
var health := CombatHealth.new(160, 0)
var active := false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.7, 1.3)
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)
	MissionEnvironment.place(self, "generator", Vector3.ZERO, shape.size)
	health.died.connect(func(): visible = false; collision_layer = 0; destroyed.emit())

func take_damage(amount: float, _origin: Vector3, _headshot: bool = false, _multiplier: float = 1.0) -> void:
	if active: health.damage(amount)
