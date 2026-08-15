extends Node3D

class_name BurnRecyclePlayer

const burn_recycle_item_scene = preload("uid://be31rc14r3lhd")

enum InputType{
	Burn, Recycle
}

@export var piston: Node3D
@export var lever_burn: Node3D
@export var lever_recycle: Node3D

@export var ik_left: SkeletonIK3D
@export var ik_right: SkeletonIK3D

@export_category("Variables")
@export var conveyor_move_time: float = 0.1
@export var penalty_timeout: float = 0.2

@export_category("Nodes")
@export var item_spawn_position: Node3D
@export var camera: Camera3D
@export var score_viewport: SubViewport
@export var score_parent: Node3D
@export var score_label: Label
@export var end_score_labels: Array[Label3D]
@export var active_item_index: int = 3
@export var penalty_node: Node3D
@export var lights: Node3D
@export var indicator: Node3D
@export var active_belt: MeshInstance3D
@export var active_press: BurnRecyclePress
@export var anim_character: AnimationPlayer
@export var shaker_camera: ShakerComponent3D
@export var anim_camera_movement: AnimationPlayer
@export var debug: Label3D

@export_category("Local Multiplayer")
@export var local_root_node: Node3D
@export var local_camera: Camera3D
@export var local_viewport: SubViewport

@export_category("Audio")
@export var speaker_pull_lever: AudioStreamPlayer3D
@export var speaker_invalid_item: AudioStreamPlayer3D
@export var speaker_tally_click: AudioStreamPlayer3D
@export var speaker_death: AudioStreamPlayer3D
@export var sounds_lever: Array[AudioStream]

@export_category("Other")
@export var items_parent: Node3D
@export var item_position_parent: Node3D
@export var player_model_node: Node3D

@export var customization_assigner: CustomizationAssigner

@export_category("Player Nametag")
@export var player_marker: Node3D
@export var player_name_label: PlayerNameLabel

const visual_parent_rotations: Array[float] = [180.0, 270.0, 0.0, 90.0]

var game_instance: BurnRecycleMinigame

var player_presence: PlayerPresence

var lever_tweening: bool = false
var active: bool = false

var conveyor_items: Array[BurnRecycleItem]
var item_in_piston_area: Array[BurnRecycleItem]

var random_item_types: Array

var items: Dictionary[int, BurnRecycleItem]
var item_positions: Array[Node3D]
var item_tweens: Dictionary[BurnRecycleItem, Tween]

var input_buffer_time: int = 1
var input_buffer: String = ""

var valid_burns: int = 0
var valid_recycles: int = 0
var penalty_timer: float = 0.0

var active_seat_index: int
var epic_cheat_enabled = false
var is_dead: bool = false



var ach_invalid_inputs: int = 0
var ach_active: bool = true

var tally_previous_text = ""
var playing_tally_sound = false

signal tweens_finished()
signal item_queue_cleared(network_id)
signal item_launched(rot, type)

func _ready() -> void :

	ik_left.start()
	ik_right.start()

	var counter: int = 0
	for c in item_position_parent.get_children():
		item_positions.append(c)
		items[counter] = null
		counter += 1

	end_score_labels[0].position = Vector3(0, -100, 0)

	await get_tree().create_timer(1, false).timeout
	playing_tally_sound = true

func offset_nametag(_amount: float):
	pass

func _process(delta: float) -> void :

	if penalty_timer > 0.0:
		penalty_timer = max(penalty_timer - delta, 0.0)
		if penalty_timer <= 0.0:
			set_penalty_lights_rpc.rpc(false)

	if GameManager.local_game:
		local_camera.global_transform = camera.global_transform
		local_camera.fov = camera.fov

	if not active:
		return

	if is_dead:
		return

	if not GameManager.game_focused:
		return

	if penalty_timer > 0.0:
		return

	if GameManager.local_game and player_presence and not player_presence.local_controller_connected:
		return

	if DynamicInput.is_action_just_pressed(player_presence.device_id, "action_1"):
		burn_rpc.rpc()

	elif DynamicInput.is_action_just_pressed(player_presence.device_id, "action_2"):
		recycle_rpc.rpc()

func _physics_process(_delta: float) -> void :
	play_tally_indicator_click()




















func play_tally_indicator_click():

	if end_score_labels[0].text != tally_previous_text:
		if playing_tally_sound:
			speaker_tally_click.play()
	tally_previous_text = end_score_labels[0].text

func setup_local_visuals():

	var wall_copy = game_instance.client_side_wall_mesh.duplicate()
	add_child(wall_copy)
	wall_copy.top_level = true
	wall_copy.global_position = Vector3.ZERO

	wall_copy.visible = true
	wall_copy.rotation_degrees = Vector3(
		0.0, 90.0 + (active_seat_index * 90.0), 0.0
	)
	for c in wall_copy.get_children():
		if c is MeshInstance3D:
			c.set_layer_mask_value(1, false)
			c.set_layer_mask_value(active_seat_index + 2, true)

	local_camera.set_cull_mask_value(active_seat_index + 2, true)

# --- 8P MOD -------------------------------------------------------------------
# Which room this player sits in. 0 for everyone at 1-4 players, so every path
# below collapses to vanilla there.
var mod_room: int = 0

# "any_peer", NOT "authority": set_player_presence() hands each player node's
# multiplayer authority to that player's own peer, so the HOST is not the
# authority for anybody else's node and an "authority" RPC from the host is
# rejected on all seven of them - `RPC 'zz_mod_set_room_rpc' is not allowed`,
# once per player per peer, with the offset silently never applied and all eight
# players left stacked two-per-station at the origin. Vanilla's setup_rpc and
# set_player_presence are "any_peer" for exactly this reason; match them.
#
# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build. Any future
# mod RPC needs the same prefix.
@rpc("any_peer", "call_local", "reliable")
func zz_mod_set_room_rpc(_room: int) -> void :
	mod_room = _room
	# setup_rpc() only ever sets rotation_degrees - vanilla has no need to move a
	# player, because there is only one room to be in. Room B is the same four
	# stations translated, so the player node translates with it and takes its
	# camera along.
	position = BurnRecycleMinigame.MOD_ROOM_OFFSET * float(_room)

func setup_clientside_visuals(_seat_counter: int):
	await get_tree().create_timer(1, false).timeout

	var seats: int = BurnRecycleMinigame.MOD_SEATS_PER_ROOM
	var seat_in_room: int = _seat_counter % seats

	# 8P MOD: `clientside visuals parent` holds the main wall, the incinerator
	# and all six OmniLights, and vanilla already spins it to face the local
	# player's seat. It is per-VIEWER, not per-room, so room B does not need a
	# copy of the lighting - the whole assembly just has to move to whichever
	# room this client is actually sitting in. This runs in the
	# `camera.current = true` branch, i.e. for the local player only, so there is
	# exactly one writer.
	game_instance.clientside_visuals_parent.position = (
		BurnRecycleMinigame.MOD_ROOM_OFFSET * float(mod_room))
	game_instance.clientside_visuals_parent.rotation_degrees = Vector3(
		0.0, visual_parent_rotations[seat_in_room], 0.0)

	# 8P MOD: this lights up the neighbour's tally indicator, and the shipped
	# wrap of -1 -> 3 means "the seat before me, wrapping round the room". With
	# two rooms it has to wrap inside THIS room: seat 4 must wrap to 7, not to
	# room A's seat 3.
	var mod_room_base: int = mod_room * seats
	var index_to_enable_indicator_on = mod_room_base + posmod(seat_in_room - 1, seats)
	for i in game_instance.player_parent_node.get_children():
		var pl: BurnRecyclePlayer = i
		if pl.active_seat_index == index_to_enable_indicator_on:
			pl.end_score_labels[0].position = Vector3(-2.332, 3.747, 5.227)
			for _indicator in game_instance.indicators:
				if _indicator.indicator_id == index_to_enable_indicator_on:
					_indicator.get_child(0).visible = true

func set_active_belt(_seat_counter: int):
	active_seat_index = _seat_counter
	debug.text = "seat: " + str(_seat_counter)
	active_belt = game_instance.belts[_seat_counter]

func set_active_press(_seat_counter: int):
	for i in game_instance.presses:
		if i.press_id == _seat_counter:
			active_press = i
			break

func play_lever_sound():
	speaker_pull_lever.stream = sounds_lever.pick_random()
	speaker_pull_lever.pitch_scale = randf_range(0.95, 1.05)
	speaker_pull_lever.play()

func play_invalid_item_sound():
	speaker_invalid_item.pitch_scale = randf_range(0.95, 1.05)
	speaker_invalid_item.play()

func play_death_sound():
	speaker_death.play()

# 8P MOD: the shipped version was a 4x4 lookup of press_id against target seat,
# which silently falls through to "center" for any seat above 3. Rewritten as the
# relationship that table encodes - the target is N seats round the room from me:
#
#     0 -> "self"    1 -> "right"    2 -> "center"    3 -> "left"
#
# Verified to reproduce the shipped table 16/16 at four seats. Because each room
# still holds exactly four players at the shipped angles, the four authored
# clips remain EXACT here - this is the compromise the 45-degree single-room
# attempt could not avoid and the two-room layout does.
#
# A target in the other room has no meaningful direction, so the camera holds
# still rather than swinging at a wall 200 units away.
const MOD_LOOK_CLIPS: Array[String] = ["self", "right", "center", "left"]

func look_at_seat(_seat_index: int):

	var seats: int = BurnRecycleMinigame.MOD_SEATS_PER_ROOM
	var my_seat: int = active_press.press_id if active_press else 0

	if (my_seat / seats) != (_seat_index / seats):
		return

	var rel: int = posmod(_seat_index - my_seat, seats)
	anim_camera_movement.play("look " + MOD_LOOK_CLIPS[rel])

func move_piston():

	var t = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(piston, "position", Vector3(0.747, 0, 0), 0.05)
	t.tween_property(piston, "position", Vector3(0, 0, 0), 0.2)

func move_items_data():

	for i in range(items.keys().size() - 1, -1, -1):

		var item = items[i]
		if not item:
			continue


		if i + 1 >= items.keys().size():
			erase_item_rpc.rpc(i)


		else:
			items[i + 1] = item
			items[i] = null

func move_items_visual():

	for i in items.keys().size() - 1:

		var item = items[i]
		if not item:
			continue

		var t = create_tween()
		item_tweens[item] = t

		t.tween_property(
			item, "global_position", 
			item_positions[i].global_position, conveyor_move_time
		)
		t.tween_callback( func():
			if item:
				item.global_position = item_positions[i].global_position
				item_tweens.erase(item)
		)

		var t2 = create_tween()
		var mat: StandardMaterial3D = active_belt.get_active_material(0)
		var prev_uv = mat.uv1_offset.x
		t2.tween_property(mat, "uv1_offset", Vector3(prev_uv - 0.028, mat.uv1_offset.y, mat.uv1_offset.z), conveyor_move_time / 1.5)


func update_score_screen():
	score_label.text = "%s" % [str(valid_recycles + valid_burns).pad_zeros(2)]

func apply_penalty():

	penalty_timer = penalty_timeout
	penalty_node.visible = true
	input_buffer = ""
	input_buffer_time = -1



@rpc("any_peer", "call_local", "reliable")
func set_penalty_lights_rpc(_visiblity):

	penalty_node.visible = false

@rpc("any_peer", "call_local", "reliable")
func add_item_rpc():

	if random_item_types.is_empty():
		return

	if multiplayer.get_unique_id() == get_multiplayer_authority():
		game_instance.play_item_move_sound()

	var item: BurnRecycleItem = burn_recycle_item_scene.instantiate()
	items_parent.add_child(item)
	item.set_type(random_item_types.pop_front())

	items[0] = item
	item.global_position = item_positions[0].global_position

	move_items_data()
	move_items_visual()

@rpc("any_peer", "call_local", "reliable")
func erase_item_rpc(_index: int):

	var item = items[_index]
	items[_index] = null
	if item:
		item.free()

@rpc("any_peer", "call_local", "reliable")
func burn_rpc():

	play_lever_sound()


	if not item_tweens.is_empty():

		for t in item_tweens.values():
			t.kill()
		item_tweens.clear()

		for i in items.keys().size() - 1:
			var item = items[i]
			if not item:
				continue
			item.global_position = item_positions[i].global_position

	if items[active_item_index]:
		var item: BurnRecycleItem = items[active_item_index]

		item_launched.emit(rotation, item.type)

		if item.burnable:
			valid_burns += 1
			update_score_screen()
		else:
			ach_invalid_inputs += 1
			apply_penalty()
			play_invalid_item_sound()

		items[active_item_index] = null
		item.free()

	lever_tweening = true
	var t = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(lever_burn, "rotation_degrees", Vector3(lever_burn.rotation_degrees.x, lever_burn.rotation_degrees.y, 27.5), 0.1)
	t.tween_property(lever_burn, "rotation_degrees", Vector3(lever_burn.rotation_degrees.x, lever_burn.rotation_degrees.y, 0), 0.2)
	t.tween_callback( func():
		lever_tweening = false
		tweens_finished.emit()
	)

	move_piston()
	add_item_rpc()

@rpc("any_peer", "call_local", "reliable")
func recycle_rpc():

	play_lever_sound()

	if not item_tweens.is_empty():

		for t in item_tweens.values():
			t.kill()
		item_tweens.clear()

		for i in items.keys().size() - 1:
			var item = items[i]
			if not item:
				continue
			item.global_position = item_positions[i].global_position

	if items[active_item_index]:
		var item: BurnRecycleItem = items[active_item_index]

		if not item.burnable:
			valid_recycles += 1
			update_score_screen()
		else:
			ach_invalid_inputs += 1
			apply_penalty()
			play_invalid_item_sound()

	lever_tweening = true
	var t = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(lever_recycle, "rotation_degrees", Vector3(lever_recycle.rotation_degrees.x, lever_recycle.rotation_degrees.y, 27.5), 0.1)
	t.tween_property(lever_recycle, "rotation_degrees", Vector3(lever_recycle.rotation_degrees.x, lever_recycle.rotation_degrees.y, 0), 0.2)
	t.tween_callback( func():
		lever_tweening = false
		tweens_finished.emit()
	)

	add_item_rpc()

func tween_final_score(value: int):

	for i in end_score_labels:
		i.text = "%s" % [str(value).pad_zeros(2)]



@rpc("any_peer", "call_local", "reliable")
func clear_item_queue_rpc():

	var has_items: bool = false
	for item in items.values():
		if item:
			has_items = true
			break

	game_instance.setup_camera_movement()
	game_instance.play_sound_remove_items()

	var counter: int = 0
	while has_items:

		move_items_data()
		move_items_visual()

		await get_tree().create_timer(conveyor_move_time).timeout

		has_items = false
		for item in items.values():
			if item:
				has_items = true
				break

		counter += 1
		if counter > 100:
			has_items = false

	if multiplayer.is_server():
		item_queue_cleared.emit(player_presence.network_id)

@rpc("any_peer", "call_local", "reliable")
func round_finished_rpc():

	ach_invalid_inputs = 0

	active = false
	input_buffer = ""
	input_buffer_time = -1

@rpc("any_peer", "call_local", "reliable")
func show_end_score_rpc():

	var final_score: int = valid_burns + valid_recycles
	for i in end_score_labels:
		i.text = str(0)
		i.visible = not is_dead
	game_instance.play_sound_buzzer_on()
	var t = create_tween()
	t.tween_method(tween_final_score, 0, final_score, 2.0)
	t.tween_callback( func():
		for i in end_score_labels:
			i.visible = false
		game_instance.play_sound_buzzer_off()
	).set_delay(2.0)

@rpc("any_peer", "call_local", "reliable")
func set_eliminated_rpc():

	play_death_sound()

	ik_left.stop()
	ik_right.stop()
	active_press.start_press()
	anim_character.play("thrown on control panel death1")
	hide_nametag()
	shake_camera()

	valid_burns = 0
	valid_recycles = 0
	score_label.text = "00"

	active = false
	is_dead = true

@rpc("any_peer", "call_local", "reliable")
func trigger_achievement_rpc():

	if GameManager.local_game or (multiplayer.get_unique_id() == player_presence.network_id):
		if ach_invalid_inputs <= 0:
			AchievementManager.set_achievement("ACH_15")

func shake_camera():
	await get_tree().create_timer(0.9, false).timeout
	for i in game_instance.player_parent_node.get_children():
		i.shaker_camera.force_stop_shake()
		i.shaker_camera.play_shake()

func hide_nametag():
	var t = create_tween()
	t.tween_property(player_name_label, "modulate", Color(1, 1, 1, 0), 0.5)
	t.tween_property(player_name_label, "outline_modulate", Color(0, 0, 0, 0), 0.5)

@rpc("any_peer", "call_local", "reliable")
func reset_scores_rpc():

	valid_burns = 0
	valid_recycles = 0
	score_label.text = "00"

@rpc("any_peer", "call_local", "reliable")
func set_active_rpc(_active: bool):
	active = _active

@rpc("any_peer", "call_local", "reliable")
func setup_rpc(_rotation_degrees: Vector3, _random_types_byte_array: PackedByteArray):

	rotation_degrees = _rotation_degrees

	for b in _random_types_byte_array:
		random_item_types.append(
			BurnRecycleMinigame.ItemTypes.values()[b]
		)

@rpc("any_peer", "call_local", "reliable")
func set_random_type_array_rpc(_random_types_byte_array: PackedByteArray):

	random_item_types.clear()
	for b in _random_types_byte_array:
		random_item_types.append(
			BurnRecycleMinigame.ItemTypes.values()[b]
		)

@rpc("any_peer", "call_local", "reliable")
func set_manager_from_path_rpc(node_path: String):
	game_instance = get_node(node_path)


@rpc("any_peer", "call_local", "reliable")
func set_player_presence(_network_id: int, seat_counter: int):

	player_presence = PlayerManager.player_presences[_network_id]
	set_multiplayer_authority(player_presence.network_id, true)

	player_name_label.text = player_presence.network_name

	var customization_data = player_presence.customization
	customization_assigner.assign_hat(customization_data[0])
	customization_assigner.assign_glasses(customization_data[1])
	customization_assigner.assign_suit_color(customization_data[2])

	set_active_belt(seat_counter)
	set_active_press(seat_counter)

	if GameManager.local_game:

		player_name_label.text = ""
		player_name_label.visible = false

		local_camera.current = true
		setup_local_visuals()
		return

	if player_presence.network_id == multiplayer.get_unique_id():

		player_name_label.text = ""
		camera.current = true


		score_parent.visible = true
		score_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		score_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

		setup_clientside_visuals(seat_counter)

	else:

		set_process(false)
		indicator.visible = false
