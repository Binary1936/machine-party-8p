class_name SmokeBreak_Trolley extends Node

@export var manager: SmokeBreakMinigame
@export var state_machine: StateMachine
@export var player_parent: Node3D

@export var rot_by_seat_index_array: Array[Vector3]
@export var blood_decals_by_seat_index_array: Array[Node3D]
@export var blood_decal_fan: Node3D
@export var particles_smoke: Array[GPUParticles3D]

@export var shaker_trolley: ShakerComponent3D

@export var anim_trolley: AnimationPlayer
@export var anim_revolver_firing: AnimationPlayer

@export var revolver_yaw_parent: Node3D

@export_category("Audio")
@export var setup_audio_player: AudioStreamPlayer3D
@export var fire_audio_player: AudioStreamPlayer3D

var smoke_particle_active_index = -1

# 8P MOD: cached once. shoot_player() runs up to eight times a round, and
# OS.get_cmdline_args() allocates a fresh array on every call.
@onready var mod_trace: bool = Array(OS.get_cmdline_args()).has("-localtest")

@rpc("any_peer", "call_local", "reliable")
func eliminate_players_routine_rpc(player_seats_to_eliminate):

	if mod_trace:
		print("[SMOKE8] eliminate is_server=", multiplayer.is_server(),
			" seats=", player_seats_to_eliminate,
			" decal_array=", blood_decals_by_seat_index_array.size(),
			" players=", manager.players_node_parent.get_child_count())

	for player: SmokeBreakPlayer in manager.players_node_parent.get_children():
		if !player.is_cigarette_finished:
			player.anim_handler.start_exhaling_cigarette()
			player.anim_handler.pan_trolley_animation_fov()
	await (setup_trolley())
	for seat in player_seats_to_eliminate:
		shoot_player(seat)
		await get_tree().create_timer(0.8).timeout
	await get_tree().create_timer(3, false).timeout
	state_machine.transition_to(&"Finish")

func setup_trolley():
	anim_trolley.play("setup trolley")
	setup_audio_player.stop()
	setup_audio_player.play(0.0)
	await get_tree().create_timer(1.6, false).timeout

func shoot_player(seat: int):

	smoke_particle_active_index += 1
	var tweener = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	var rot_destination = rot_by_seat_index_array[seat]
	var rot_duration = 0.3
	tweener.tween_property(revolver_yaw_parent, "rotation_degrees", rot_destination, rot_duration)
	await get_tree().create_timer(rot_duration + 0.2, false).timeout
	anim_revolver_firing.play("fire")
	fire_audio_player.stop()
	fire_audio_player.play(0.0)
	# 8P MOD: one smoke puff is consumed per shot and only four exist, so an
	# eight-player round overruns this. Wrapping is identity for the first four.
	particles_smoke[smoke_particle_active_index % particles_smoke.size()].emitting = true
	shaker_trolley.force_stop_shake()
	shaker_trolley.play_shake()

	var player_to_shoot: SmokeBreakPlayer
	var counter = 0
	for player: SmokeBreakPlayer in player_parent.get_children():
		if counter == seat:
			player_to_shoot = player
			break
		else:
			counter += 1

	# One compact line per shot: the seat, the angle the gun was told to take,
	# and whether the seat is inside the four-entry decal/particle arrays. The
	# fuller calibration dump (target in the yaw pivot's parent space) lived
	# here while the eight aim angles were being derived; it is gone now that
	# they are settled, and `git diff` of this file recovers it if ever needed.
	if mod_trace:
		var shipped: String = "n/a"
		if seat < rot_by_seat_index_array.size():
			shipped = "%.2f" % rot_by_seat_index_array[seat].x
		print("[SMOKE8] shot seat=", seat, " aim=", shipped,
			" decal=", seat < blood_decals_by_seat_index_array.size())

	player_to_shoot.anim_handler.get_eliminated()
	player_to_shoot.anim_handler.show_blood_on_player()
	# 8P MOD: four decal nodes exist, one per shipped seat, each positioned on
	# its own bit of scenery - so there is nothing correct to show for seats
	# 4-7. Skipping is deliberate: wrapping would paint blood on the wrong
	# seat, which reads as a bug rather than a missing detail. Cosmetic only.
	var seat_index: int = player_to_shoot.active_player_seat_index
	if seat_index < blood_decals_by_seat_index_array.size():
		blood_decals_by_seat_index_array[seat_index].visible = true
	if seat_index in [1, 2]:
		blood_decal_fan.visible = true
