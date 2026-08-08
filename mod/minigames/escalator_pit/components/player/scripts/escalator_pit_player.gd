extends Node3D

class_name EscalatorPitPlayer

@export var speed: float = 0.0
@export var maximum_speed: float = 1.5
@export var step_increment: float = 0.01
@export var escalator_speed: float = 0.0
@export var progress_ratio_increase_scale: float = 0.5
@export var penalty_handicap_duration: float = 5.0
@export var penalty_handicap_value: float = 0.3
@export var step_curve: Curve
@export var last_input_buffer: float = 0.3
@export var min_input_time_modifier: float = 0.5

@export_category("Animation")
@export var ik_left_hand: SkeletonIK3D
@export var ik_right_hand: SkeletonIK3D
@export var ik_torso: SkeletonIK3D
@export var anim_main: AnimationPlayer
@export var particles_blood: GPUParticles3D
@export var particles_blood2: GPUParticles3D
@export var skeleton: Skeleton3D
@export var speaker_footsteps: AudioStreamPlayer3D
@export var speaker_input: AudioStreamPlayer

@export_category("Visual Nodes")
@export var customization_assigner: CustomizationAssigner
@export var character_animator: AnimationPlayer
@export var character_animation_tree: AnimationTree
@export var input_indicator: Sprite3D
@export var win_indicator: Sprite3D
@export var lose_indicator: Sprite3D
@export var indicator_animation_player: AnimationPlayer

@export_category("Player Nametag")
@export var player_marker: Node3D
@export var player_name_label: PlayerNameLabel

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

@onready var path_follow_3d: PathFollow3D = $Path3D / PathFollow3D
@onready var visuals: Node3D = $PositionRemote / Visuals
@onready var interact_area: Area3D = $PositionRemote / InteractArea

var input_indicator_atlas: AtlasTexture
var game_instance: EscalatorPitMinigame

@export var sound_array_foostep_metal: Array[AudioStream]
var velocity = 0
var relative_speed: float = 0.0
var footstep_counter = 0

@export var total_speed: float = 0.0

enum InputDirection{
	None, 
	Left, Down, Right, Up, Action1, Action2, Action3, Action4
}

var player_presence: PlayerPresence
var active: bool = false

var expected_input_direction: EscalatorPitPlayer.InputDirection = EscalatorPitPlayer.InputDirection.Left

var text_tween: Tween

var elapsed: float = 0.0
var active_sequence_string = ""
var correct_input_sound_pitch_default = 0.5
var correct_input_sound_pitch = 0.5
var incorrect_sound_pitch = 0.13
var last_input_timer: float = 0.0
var max_input_time: float = 1.0
var last_input_buffer_timer: float = 0.0



var consecutive_correct_inputs: int = 0
var consecutive_correct_input_target: int = 50
var achievement_reached: bool = false

signal correct_input(player_total_speed)
signal incorrect_input()
signal top_reached()
signal bottom_reached()
signal dead(network_id)

# --- 8P MOD ------------------------------------------------------------------
# The input arrow is a Sprite3D at local (0, 16.74, -13.84) on the player - far
# up and back, so it renders near the CRT bank rather than over the player's
# head. The monitor housing (`Cube_009`) sits at world (-0.13, 16.52, -14.67),
# only fractionally behind it, so once the players were lifted for the
# eight-lane layout the arrow rose into the housing and was occluded entirely.
#
# That occlusion was a side effect of lifting the players, and the lift has
# since been reverted to 0.0 - so this is back to zero and the arrow sits
# exactly where vanilla puts it. Only the *number* of arrows is modded (one per
# player, eight of them), never the placement.
#
# Kept as a named constant rather than deleted: if MOD_PLAYER_LIFT in
# escalator_pit.gd is raised again the arrow rises into the housing with it,
# and this is the dial that clears it.
const MOD_VANILLA_LANES: int = 4
const MOD_INDICATOR_NUDGE: Vector3 = Vector3.ZERO

func _ready() -> void :
	start_ik()

	# Runs on every peer the player is spawned on, and player_presences is
	# replicated, so no RPC is needed and 1-4 player games are untouched.
	if (PlayerManager.player_presences.size() > MOD_VANILLA_LANES
			and input_indicator != null):
		input_indicator.position += MOD_INDICATOR_NUDGE

func start_ik():

	ik_left_hand.start()
	ik_right_hand.start()
	ik_torso.start()

func _process(delta: float) -> void :

	if not active:
		return

	if PauseMenu.active:
		return

	if not GameManager.game_focused:
		return

	last_input_buffer_timer = max(last_input_buffer_timer - delta, 0.0)
	if last_input_buffer_timer <= 0.0:
		last_input_timer = min(last_input_timer + delta, max_input_time)

	elapsed += delta

	var input_direction: EscalatorPitPlayer.InputDirection = EscalatorPitPlayer.InputDirection.None

	if GameManager.local_game:
		if player_presence and player_presence.local_controller_connected:

			if DynamicInput.is_action_just_pressed(player_presence.device_id, "left"):
				input_direction = EscalatorPitPlayer.InputDirection.Left
			elif DynamicInput.is_action_just_pressed(player_presence.device_id, "down"):
				input_direction = EscalatorPitPlayer.InputDirection.Down
			elif DynamicInput.is_action_just_pressed(player_presence.device_id, "right"):
				input_direction = EscalatorPitPlayer.InputDirection.Right
			elif DynamicInput.is_action_just_pressed(player_presence.device_id, "up"):
				input_direction = EscalatorPitPlayer.InputDirection.Up

	else:

		if DynamicInput.is_action_just_pressed(player_presence.device_id, "left"):
			input_direction = EscalatorPitPlayer.InputDirection.Left
		elif DynamicInput.is_action_just_pressed(player_presence.device_id, "down"):
			input_direction = EscalatorPitPlayer.InputDirection.Down
		elif DynamicInput.is_action_just_pressed(player_presence.device_id, "right"):
			input_direction = EscalatorPitPlayer.InputDirection.Right
		elif DynamicInput.is_action_just_pressed(player_presence.device_id, "up"):
			input_direction = EscalatorPitPlayer.InputDirection.Up










	if input_direction != EscalatorPitPlayer.InputDirection.None:
		if GameManager.local_game or (player_presence.network_id == multiplayer.get_unique_id()):
			if input_direction == expected_input_direction:

				correct_input_sound_pitch += 0.02
				speaker_input.pitch_scale = correct_input_sound_pitch
				speaker_input.play()

				consecutive_correct_inputs += 1
				if not achievement_reached and consecutive_correct_inputs >= consecutive_correct_input_target:
					AchievementManager.set_achievement("ACH_07")
					achievement_reached = true

				indicator_animation_player.play(&"correct")
				var curve_modifier = step_curve.sample(speed / 2.0)
				var time_modifier = clamp(max_input_time - last_input_timer, min_input_time_modifier, 1.0)
				speed = min(speed + ((step_increment * curve_modifier) * time_modifier), 2.0)
				set_expected_input()

			else:

				correct_input_sound_pitch = correct_input_sound_pitch_default
				speaker_input.pitch_scale = incorrect_sound_pitch
				speaker_input.play()

				consecutive_correct_inputs = 0

				var input_handicap_ratio = 1.0 - (
					min(elapsed, penalty_handicap_duration) / penalty_handicap_duration
				)

				indicator_animation_player.play(&"incorrect")
				incorrect_input.emit()
				speed *= 0.3 + (penalty_handicap_value * input_handicap_ratio)

			last_input_buffer_timer = last_input_buffer
			last_input_timer = 0.0

	speed = move_toward(speed, 0.0, delta * step_increment)

func set_expected_input():

	var last_expected = expected_input_direction
	var potential = [
		InputDirection.Left, 
		InputDirection.Down, 
		InputDirection.Right, 
		InputDirection.Up, 
	]
	potential.erase(last_expected)
	expected_input_direction = potential.pick_random()

	var region_position = (expected_input_direction - 1) * 32
	set_input_indicator_rpc.rpc(region_position)

func offset_nametag(amount: float):
	player_name_label.transform.origin = Vector3(
		player_name_label.transform.origin.x, 
		player_name_label.transform.origin.y + amount, 
		player_name_label.transform.origin.z, 
	)

func _physics_process(delta: float) -> void :


	play_footstep_sound(delta)

	if not active:
		return

	if not GameManager.local_game:
		if not (player_presence.network_id == multiplayer.get_unique_id()):
			return

	character_animation_tree.set("parameters/run_blend/blend_amount", clamp(0.0, 1.5, abs(escalator_speed + speed)))

	var calc_speed = speed
	path_follow_3d.progress_ratio = clamp(
		path_follow_3d.progress_ratio + (
			( - escalator_speed + calc_speed) * progress_ratio_increase_scale * delta
		), 0.0, 1.0
	)



func show_death_indicator():
	await get_tree().create_timer(1.2, false).timeout
	SoundManager.play_omni_rpc.rpc(
		"escalator_pit_fail_alert", 
		"SFX", 
		4, 
		randf_range(0.95, 1.05), 
	)
	input_indicator.visible = false
	win_indicator.visible = false
	lose_indicator.visible = true

func play_footstep_sound(delta):
	if speed > 0.01:
		footstep_counter += delta
	if footstep_counter > 0.38:
		play_footstep_sound_rpc.rpc()
		footstep_counter = 0



@rpc("any_peer", "call_remote", "reliable")
func correct_input_rpc():
	if not multiplayer.is_server():
		return

	correct_input.emit(total_speed)

@rpc("any_peer", "call_local", "reliable")
func play_footstep_sound_rpc():
	speaker_footsteps.stream = sound_array_foostep_metal.pick_random()
	speaker_footsteps.play()

@rpc("any_peer", "call_local", "reliable")
func show_win_indicator_rpc():
	await get_tree().create_timer(0.8, false).timeout
	input_indicator.visible = false
	lose_indicator.visible = false
	win_indicator.visible = true
	active = false

@rpc("any_peer", "call_local", "reliable")
func set_input_indicator_rpc(region_position):
	input_indicator.texture.region.position.x = region_position

@rpc("any_peer", "call_local", "reliable")
func set_escalator_speed_rpc(_escalator_speed: float):
	escalator_speed = _escalator_speed

@rpc("any_peer", "call_local", "reliable")
func finish_rpc():

	top_reached.emit()
	if is_multiplayer_authority():
		game_instance.sequence_character_parent.visible = false
	active = false

@rpc("any_peer", "call_local", "reliable")
func kill_rpc():

	if not active:
		return

	bottom_reached.emit()
	if is_multiplayer_authority():
		game_instance.sequence_character_parent.visible = false

	active = false
	player_name_label.visible = false

	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	var blend_time = 0.5
	tween.tween_property(ik_left_hand, "influence", 0, blend_time)
	tween.tween_property(ik_right_hand, "influence", 0, blend_time)
	tween.tween_property(ik_torso, "influence", 0, blend_time)
	tween.tween_property(character_animation_tree, "parameters/death_blend/blend_amount", 1, blend_time)

	SoundManager.play_positional_rpc.rpc(
		"escalator_pit_death", 
		global_position, 
		"SFX", 
		1, 
		randf_range(0.95, 1), 
	)

	show_death_indicator()

	dead.emit(multiplayer.get_unique_id())

	await get_tree().create_timer(0.5, false).timeout
	particles_blood.emitting = true
	particles_blood2.emitting = true

@rpc("any_peer", "call_local", "reliable")
func remove_rpc():

	multiplayer_synchronizer.public_visibility = false

	if multiplayer.get_unique_id() != get_multiplayer_authority():
		return

	queue_free()

@rpc("any_peer", "call_local", "reliable")
func set_active_rpc(_active: bool):
	active = _active

@rpc("any_peer", "call_local", "reliable")
func set_player_presence_rpc(network_id: int):

	player_presence = PlayerManager.player_presences[network_id]
	set_multiplayer_authority(player_presence.network_id, true)
	player_name_label.text = player_presence.network_name

	var customization_data = player_presence.customization

	customization_assigner.assign_hat(customization_data[0])
	customization_assigner.assign_glasses(customization_data[1])
	customization_assigner.assign_suit_color(customization_data[2])

	if GameManager.local_game:
		randomize()
		set_expected_input()
		return

	if player_presence.network_id != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		input_indicator.modulate.a = 0.2
	else:
		input_indicator_atlas = input_indicator.texture
		player_name_label.text = ""
		set_expected_input()


@rpc("any_peer", "call_local", "reliable")
func teleport_rpc(_position: Vector3):
	global_position = _position

@rpc("any_peer", "call_local", "reliable")
func set_manager_from_path_rpc(node_path: String):
	game_instance = get_node(node_path)
