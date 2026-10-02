class_name ArenaNavigation
extends RefCounted

var grid: AStarGrid2D
var covers: Array[Vector3] = []

func build(layout: Array) -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-20, -20, 41, 41)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for obstacle in layout:
		var x := float(obstacle[0])
		var z := float(obstacle[1])
		var width := float(obstacle[2]) / 2 + 0.45
		var depth := float(obstacle[3]) / 2 + 0.45
		for gx in range(int(floor(x - width)), int(ceil(x + width)) + 1):
			for gz in range(int(floor(z - depth)), int(ceil(z + depth)) + 1):
				if grid.is_in_boundsv(Vector2i(gx, gz)): grid.set_point_solid(Vector2i(gx, gz))
		for offset in [Vector3(width + 1.2, 0, 0), Vector3(-width - 1.2, 0, 0), Vector3(0, 0, depth + 1.2), Vector3(0, 0, -depth - 1.2)]:
			covers.append(Vector3(x, 0, z) + offset)

func nearest_open(position_value: Vector3) -> Vector2i:
	var point := Vector2i(clampi(roundi(position_value.x), -18, 18), clampi(roundi(position_value.z), -18, 18))
	if not grid.is_point_solid(point): return point
	for radius in range(1, 8):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := point + Vector2i(x, z)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	return Vector2i.ZERO

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in grid.get_id_path(nearest_open(from), nearest_open(to)):
		result.append(Vector3(point.x, 0, point.y))
	return result
