class_name SmokeBreakPlayer_Anim extends Node

@export var player: SmokeBreakPlayer
@export var ik_target_right: Node3D
@export var ik_right: SkeletonIK3D
@export var anim_player: AnimationPlayer
@export var anim_cig_light: AnimationPlayer
@export var cig_scale_parent: Node3D
@export var blood_decal_parent: Node3D

@export_group("ik target transforms")
@export var ik_R_pos_in: Vector3
@export var ik_R_rot_in: Vector3
@export var ik_R_pos_out: Vector3
@export var ik_R_rot_out: Vector3

var coughing_animations: Array[String] = [
	"coughing1", "coughing2", "coughing3"
]

var coughing_sounds: Dictionary[String, Array] = {
	"coughing1": [
		"anim1_cough1", "anim1_cough2", "anim1_cough3"
	], 
	"coughing2": [
		"anim2_cough1", "anim2_cough2", "anim2_cough3"
	], 
	"coughing3": [
		"anim3_cough1", "anim3_cough2", "anim3_cough3"
	]
}

var tween_ik_target: Tween
var tween_camera_fov: Tween

@export var tween_camera_fov_duration: float = 5
@export var tween_camera_fov_pan_back_duration: float = 0.8
@export var tween_camera_fov_decrease_end: float = 15
@export var tween_camera_fov_original: float = 22.5

var dur_ik_tween: float = 0.3
var ticking = false

func _ready() -> void :
	player.inhale_started.connect(start_inhaling_cigarette)
	player.exhale_started.connect(start_exhaling_cigarette)
	player.choke_started.connect(start_coughing)
	player.eliminated.connect(get_eliminated)
	player.eliminate_animation_finished.connect(eliminate_finished)

	anim_player.play("sitting_idle")
	ik_right.start()

	ik_target_right.transform.origin = ik_R_pos_out
	ik_target_right.rotation_degrees = ik_R_rot_out

	ticking = true
	tick()

func tick():
	while ticking:
		if !get_tree(): return

		if GameManager.local_game:
			update_cigarette_left_rpc.rpc(player.cigarette_left)
			await get_tree().physics_frame
			continue

		if player.player_presence != null:
			if player.player_presence.network_id != multiplayer.get_unique_id(): return
		await get_tree().create_timer(0.4, false).timeout
		update_cigarette_left_rpc.rpc(player.cigarette_left)

func pan_back_fov():
	if multiplayer.get_unique_id() != player.player_presence.network_id: return
	if tween_camera_fov != null: tween_camera_fov.kill()
	tween_camera_fov = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	tween_camera_fov.tween_property(player.manager.camera, "fov", tween_camera_fov_original, tween_camera_fov_pan_back_duration)

func pan_in_fov():
	if multiplayer.get_unique_id() != player.player_presence.network_id: return
	if tween_camera_fov != null: tween_camera_fov.kill()
	tween_camera_fov = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	tween_camera_fov.tween_property(player.manager.camera, "fov", tween_camera_fov_decrease_end, tween_camera_fov_duration)

func pan_trolley_animation_fov():
	if multiplayer.get_unique_id() != player.player_presence.network_id: return
	if tween_camera_fov != null: tween_camera_fov.kill()
	tween_camera_fov = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	tween_camera_fov.tween_property(player.manager.camera, "fov", 16, 1)

@rpc("any_peer", "call_local", "reliable")
func start_inhaling_cigarette():
	tween_ik_target = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	tween_ik_target.tween_property(ik_target_right, "position", ik_R_pos_in, dur_ik_tween)
	tween_ik_target.tween_property(ik_target_right, "rotation_degrees", ik_R_rot_in, dur_ik_tween)

	pan_in_fov()

@rpc("any_peer", "call_local", "reliable")
func start_exhaling_cigarette():
	if tween_camera_fov != null: tween_camera_fov.kill()
	tween_ik_target = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	tween_ik_target.tween_property(ik_target_right, "position", ik_R_pos_out, dur_ik_tween)
	tween_ik_target.tween_property(ik_target_right, "rotation_degrees", ik_R_rot_out, dur_ik_tween)

	pan_back_fov()

@rpc("any_peer", "call_local", "unreliable")
func update_cigarette_left_rpc(cigarette_left: float):
	cig_scale_parent.scale = Vector3(
		cig_scale_parent.scale.x, 
		cigarette_left, 
		cig_scale_parent.scale.z
	)

@rpc("any_peer", "call_local", "reliable")
func start_coughing():

	pan_back_fov()
	var cough_animation_pick = coughing_animations.pick_random()
	SoundManager.play_positional_rpc(
		coughing_sounds[cough_animation_pick].pick_random(), 
		player.global_position
	)
	ik_right.stop()
	anim_player.play(cough_animation_pick)
	await get_tree().create_timer(2, false).timeout
	ik_right.influence = 0
	ik_target_right.transform.origin = ik_R_pos_out
	ik_target_right.rotation_degrees = ik_R_rot_out
	ik_right.start()
	tween_ik_influence(1, 1)
	await get_tree().create_timer(1, false).timeout
	anim_player.play("sitting_idle")

@rpc("any_peer", "call_local", "reliable")
func cigarette_finished(on_seat_index: int):
	pan_back_fov()

	tween_ik_influence(0, 1)
	var finish_animation = ""
	match on_seat_index:
		0:
			finish_animation = "finish_look_left"
		1:
			finish_animation = "finish_look_right"
		2:
			finish_animation = "finish_look_right"
		3:
			finish_animation = "finish_look_left"
	anim_player.play(finish_animation)
	await get_tree().create_timer(2.8, false).timeout
	anim_player.play("finish_idle", 0.5)

func tween_ik_influence(to_value: float, dur: float):
	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ik_right, "influence", to_value, dur)

@rpc("any_peer", "call_local", "reliable")
func get_eliminated():
	# 8P MOD: only seats 0-3 were matched, so seats 4-7 left this as "" and
	# anim_player.play("") produced no death animation at all - the player was
	# eliminated but never fell. Cases added for the four seats the mod adds,
	# each following its spatial neighbour on the bench (the seats run
	# 2 -> 1 -> 0 -> 3 left to right, with MOD5/6 between 2 and 1, MOD7 between
	# 1 and 0, MOD8 between 0 and 3). The catch-all keeps a missing case from
	# ever silently meaning "no animation" again.
	var death_anim_active = "death_window"
	match player.active_player_seat_index:
		0:
			death_anim_active = "death_window"
		1:
			death_anim_active = "death_fan"
		2:
			death_anim_active = "death_fan"
		3:
			death_anim_active = "death_window"
		4:
			death_anim_active = "death_fan"
		5:
			death_anim_active = "death_fan"
		6:
			death_anim_active = "death_fan"
		7:
			death_anim_active = "death_window"
		_:
			death_anim_active = "death_window"
	ik_right.stop()
	anim_player.play(death_anim_active, 0.2)

func show_blood_on_player():
	blood_decal_parent.visible = true

func eliminate_finished():
	pass
