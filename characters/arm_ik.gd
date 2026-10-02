class_name ArmIK
extends RefCounted

# The model adapter supplies a grip target; gameplay does not know rig names.
static func reach(skeleton: Skeleton3D, side: String, world_target: Vector3) -> void:
	var upper := skeleton.find_bone("upper_arm." + side)
	var lower := skeleton.find_bone("forearm." + side)
	var hand := skeleton.find_bone("hand." + side)
	if upper < 0 or lower < 0 or hand < 0: return
	skeleton.force_update_all_bone_transforms()
	var shoulder := skeleton.get_bone_global_pose(upper)
	var elbow := skeleton.get_bone_global_pose(lower)
	var wrist := skeleton.get_bone_global_pose(hand)
	var goal: Vector3 = skeleton.global_transform.affine_inverse() * world_target
	var upper_length := shoulder.origin.distance_to(elbow.origin)
	var lower_length := elbow.origin.distance_to(wrist.origin)
	var direction := goal - shoulder.origin
	var distance := clampf(direction.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	direction = direction.normalized()
	goal = shoulder.origin + direction * distance
	var bend := elbow.origin - shoulder.origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	if bend.length_squared() < 0.1: bend = direction.cross(Vector3.UP).normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance)
	var height := sqrt(maxf(0, upper_length * upper_length - along * along))
	var elbow_goal := shoulder.origin + direction * along + bend * height
	var rotation := Quaternion((elbow.origin - shoulder.origin).normalized(), (elbow_goal - shoulder.origin).normalized())
	shoulder.basis = Basis(rotation) * shoulder.basis
	skeleton.set_bone_global_pose(upper, shoulder)
	skeleton.force_update_all_bone_transforms()
	elbow = skeleton.get_bone_global_pose(lower)
	wrist = skeleton.get_bone_global_pose(hand)
	rotation = Quaternion((wrist.origin - elbow.origin).normalized(), (goal - elbow.origin).normalized())
	elbow.basis = Basis(rotation) * elbow.basis
	skeleton.set_bone_global_pose(lower, elbow)
	skeleton.force_update_all_bone_transforms()
