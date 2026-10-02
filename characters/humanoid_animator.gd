class_name HumanoidAnimator
extends Node

var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var was_reloading := false
var was_dead := false
var previous_shot := 0.0
var previous_hit := 0.0
var movement := Vector2.ZERO

func setup(model: Node3D) -> void:
	skeleton = model.find_child("Skeleton3D", true, false)
	player = model.find_child("AnimationPlayer", true, false)
	player.play("aim_center")
	player.advance(0.01)
	skeleton.force_update_all_bone_transforms()
	var library := AnimationLibrary.new()
	for name in ["fire", "reload", "switch", "death"]:
		library.add_animation(name, _authored_clip(name))
	player.add_animation_library("combat", library)
	for name in ["idle", "combat_idle", "walk", "run", "aim_run", "aim_forward", "aim_backward", "aim_left", "aim_right"]:
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	player.stop()
	tree = AnimationTree.new()
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var graph := AnimationNodeBlendTree.new()
	tree.tree_root = graph
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0
	locomotion.max_space = 8
	locomotion.add_blend_point(_clip("idle"), 0)
	locomotion.add_blend_point(_clip("walk"), 3)
	locomotion.add_blend_point(_clip("run"), 7)
	graph.add_node("locomotion", locomotion)
	var strafe := AnimationNodeBlendSpace2D.new()
	for pair in [["combat_idle", Vector2.ZERO], ["aim_forward", Vector2(0, 1)], ["aim_backward", Vector2(0, -1)], ["aim_left", Vector2(-1, 0)], ["aim_right", Vector2(1, 0)]]:
		strafe.add_blend_point(_clip(pair[0]), pair[1])
	graph.add_node("strafe", strafe)
	graph.add_node("combat", AnimationNodeBlend2.new())
	graph.connect_node("combat", 0, "locomotion")
	graph.connect_node("combat", 1, "strafe")
	var pitch := AnimationNodeBlendSpace1D.new()
	pitch.min_space = -0.7
	pitch.max_space = 0.7
	pitch.add_blend_point(_clip("aim_down"), -0.7)
	pitch.add_blend_point(_clip("aim_center"), 0)
	pitch.add_blend_point(_clip("aim_up"), 0.7)
	graph.add_node("pitch", pitch)
	var aim := AnimationNodeBlend2.new()
	_filter_upper_body(aim)
	graph.add_node("aim", aim)
	graph.connect_node("aim", 0, "combat")
	graph.connect_node("aim", 1, "pitch")
	var previous := "aim"
	for name in ["fire", "reload", "switch", "hit"]:
		graph.add_node(name + "_clip", _clip("hit" if name == "hit" else "combat/" + name))
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.06
		shot.fadeout_time = 0.12
		_filter_upper_body(shot)
		graph.add_node(name, shot)
		graph.connect_node(name, 0, previous)
		graph.connect_node(name, 1, name + "_clip")
		previous = name
	graph.add_node("death_clip", _clip("combat/death"))
	graph.add_node("death", AnimationNodeBlend2.new())
	graph.connect_node("death", 0, previous)
	graph.connect_node("death", 1, "death_clip")
	graph.connect_node("output", 0, "death")
	tree.active = true

func _clip(name: String) -> AnimationNodeAnimation:
	var result := AnimationNodeAnimation.new()
	result.animation = name
	return result

func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	var chest := skeleton.find_bone("spine1")
	for index in range(skeleton.get_bone_count()):
		var parent := index
		while parent >= 0:
			if parent == chest:
				node.set_filter_path(NodePath(str(player.get_path_to(skeleton)).trim_prefix("../") + ":" + skeleton.get_bone_name(index)), true)
				break
			parent = skeleton.get_bone_parent(parent)

func _base_rotation(bone: String) -> Quaternion:
	var clip := player.get_animation("aim_center")
	for index in range(clip.get_track_count()):
		if clip.track_get_type(index) == Animation.TYPE_ROTATION_3D and str(clip.track_get_path(index)).ends_with(":" + bone):
			return clip.rotation_track_interpolate(index, 0)
	return skeleton.get_bone_rest(skeleton.find_bone(bone)).basis.get_rotation_quaternion()

func _authored_clip(name: String) -> Animation:
	var result := Animation.new()
	result.length = 1.6 if name == "reload" else 0.5 if name == "switch" else 1.1 if name == "death" else 0.18
	var bones: Array = ["upper_arm.R", "forearm.R"] if name == "fire" else ["upper_arm.L", "forearm.L", "hand.L", "upper_arm.R"] if name in ["reload", "switch"] else ["root", "hips", "thigh.L", "thigh.R", "upper_arm.L", "upper_arm.R"]
	for bone in bones:
		var track := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track, NodePath("Robot_Skeleton/Skeleton3D:" + bone))
		var base := _base_rotation(bone)
		var angle := 0.10 if name == "fire" else 0.7 if bone == "upper_arm.L" else -0.9 if bone == "forearm.L" else 0.28
		if name == "death": angle = 1.5 if bone == "root" else -0.45
		var axis := Vector3.FORWARD if bone == "root" else Vector3.RIGHT
		result.rotation_track_insert_key(track, 0, base)
		result.rotation_track_insert_key(track, result.length * 0.35, base * Quaternion(axis, angle))
		result.rotation_track_insert_key(track, result.length, base * Quaternion(axis, angle) if name == "death" else base)
	if name == "death":
		var root_index := skeleton.find_bone("root")
		var track := result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(track, NodePath("Robot_Skeleton/Skeleton3D:root"))
		result.position_track_insert_key(track, 0, skeleton.get_bone_rest(root_index).origin)
		result.position_track_insert_key(track, result.length * 0.7, Vector3(1.2, 0.38, 0))
		result.position_track_insert_key(track, result.length, Vector3(1.2, 0.38, 0))
	return result

func switch_weapon() -> void:
	tree.set("parameters/switch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func update(delta: float, speed: float, aiming: bool, pitch: float, reloading: bool, shot: float, hurt: float, dead: bool) -> void:
	tree.set("parameters/locomotion/blend_position", speed)
	tree.set("parameters/strafe/blend_position", movement.limit_length())
	tree.set("parameters/combat/blend_amount", 1.0 if aiming else 0.0)
	tree.set("parameters/pitch/blend_position", clampf(pitch, -0.7, 0.7))
	tree.set("parameters/aim/blend_amount", 1.0 if aiming else 0.0)
	if shot > previous_shot:
		tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if hurt > previous_hit:
		tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if reloading and not was_reloading:
		tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if dead and not was_dead: tree.set("parameters/death/blend_amount", 1.0)
	was_reloading = reloading
	was_dead = dead
	previous_shot = shot
	previous_hit = hurt
	tree.advance(delta)
