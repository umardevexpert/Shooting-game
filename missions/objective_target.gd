class_name ObjectiveTarget
extends StaticBody3D

signal destroyed
var health := CombatHealth.new(160, 0)
var active := false
var shell: MeshInstance3D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.7, 1.3)
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)
	shell = Geometry.box(self, shape.size, Vector3(0, 0.85, 0), Color("9a6b50"))
	Geometry.box(self, Vector3(0.9, 0.5, 1.32), Vector3(0, 1, 0), Color("e8ad57"))
	health.died.connect(func(): visible = false; collision_layer = 0; destroyed.emit())

func take_damage(amount: float, _origin: Vector3, _headshot: bool = false, _multiplier: float = 1.0) -> void:
	if active: health.damage(amount)
