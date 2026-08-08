class_name Intermission_ScoreScreen extends Node

# --- 8P MOD ------------------------------------------------------------------
# Vanilla ships four score rows and a four-entry rank_y_positions, so a roster
# of 5-8 silently displayed only the top four players: reset_user_containers()
# fills from a *sorted* list bounded by user_container_array.size(), so the
# lowest-placed players were dropped rather than crashing.
#
# rank_y_positions was a `const`. It is now a `var` recomputed per round, which
# is what lets the three readers outside this function follow along without
# edits - notably user_container_order_manager.switch_places(), which indexes it
# by `user_rank_value - 1` and would go out of bounds for ranks 5-8 mid-swap.
#
# MOD_VANILLA_RANK_Y holds the shipped values verbatim. At <= 4 players the
# array, the row scale and the container set are all restored to exactly those,
# so a 1-4 player game is unchanged (see UPDATING.md rule 3).
var rank_y_positions: Array[float] = [0.84, 0.325, -0.19, -0.705]

const MOD_VANILLA_RANK_Y: Array[float] = [0.84, 0.325, -0.19, -0.705]
const MOD_VANILLA_RANKS: int = 4
const MOD_MAX_RANKS: int = 8
# The eight rows are resampled across the span the four originals covered
# (0.84 .. -0.705) rather than extended downward, which would run off the
# screen panel. That halves the row pitch, so the rows are scaled by the same
# ratio (3/7) to preserve the shipped gap-to-row proportion. Tunable: raise it
# for larger text at the cost of tighter gaps.
const MOD_ROW_SCALE: float = 3.0 / 7.0
# Instantiated from the PackedScene rather than duplicate()'d: user_info.tscn
# wires label_rank / label_score / label_name / opacity_visuals through
# node_paths, and duplicate() copies those as references to the *template's*
# children, so a cloned row would write its name and score into row 4.
const MOD_USER_INFO: PackedScene = preload("res://minigames/intermission_new/components/user_info.tscn")

var mod_vanilla_containers: Array[Intermission_UserContainer] = []
var mod_extra_containers: Array[Intermission_UserContainer] = []

func _mod_build_extra_containers() -> void:
	if not mod_extra_containers.is_empty():
		return
	if user_container_array.is_empty():
		push_warning("[SCORE8] no shipped user containers; cannot expand")
		return

	# Captured before _mod_set_capacity() ever reassigns the export.
	mod_vanilla_containers.assign(user_container_array)

	var template: Intermission_UserContainer = mod_vanilla_containers[MOD_VANILLA_RANKS - 1]
	var parent: Node = template.get_parent()

	for i in range(MOD_VANILLA_RANKS, MOD_MAX_RANKS):
		var clone: Intermission_UserContainer = MOD_USER_INFO.instantiate()
		clone.name = "user info%d_MOD" % (i + 1)
		clone.visible = false
		clone.score_screen = self
		clone.container_order_swapper = template.container_order_swapper
		clone.container_id = i
		# Shipped rows ramp 2.0, 2.5, 3.0, 3.5; continue the same step.
		clone.lerp_duration_score = template.lerp_duration_score + 0.5 * (i - (MOD_VANILLA_RANKS - 1))
		parent.add_child(clone)
		clone.position = Vector3(0.0, MOD_VANILLA_RANK_Y[MOD_VANILLA_RANKS - 1], 0.0)
		# Rank -1 keeps a spare row from matching a real row's "upstairs"
		# lookup (rank 1 searches for rank 0, which a fresh clone would hold).
		clone.set_user_container_as_empty()
		mod_extra_containers.append(clone)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[SCORE8] built extras=", mod_extra_containers.size(),
			" parent=", parent.name)

func _mod_set_capacity(player_count: int) -> void:
	_mod_build_extra_containers()
	if mod_vanilla_containers.is_empty():
		return

	var expand: bool = (player_count > MOD_VANILLA_RANKS
		and mod_extra_containers.size() == MOD_MAX_RANKS - MOD_VANILLA_RANKS)

	var active: Array[Intermission_UserContainer] = []
	active.assign(mod_vanilla_containers)
	var ys: Array[float] = []

	if expand:
		active.append_array(mod_extra_containers)
		var top: float = MOD_VANILLA_RANK_Y[0]
		var bottom: float = MOD_VANILLA_RANK_Y[MOD_VANILLA_RANKS - 1]
		var step: float = (top - bottom) / float(MOD_MAX_RANKS - 1)
		for i in MOD_MAX_RANKS:
			ys.append(top - step * i)
	else:
		ys.assign(MOD_VANILLA_RANK_Y)
		for uc in mod_extra_containers:
			uc.visible = false
			uc.set_user_container_as_empty()

	rank_y_positions = ys
	user_container_array = active

	var row_scale: float = MOD_ROW_SCALE if expand else 1.0
	for uc in active:
		uc.scale = Vector3.ONE * row_scale
		# Each container builds this from get_parent().get_children() in its own
		# _ready(), which would now also sweep up the spare rows. Pin it to the
		# active set so check_to_switch_places_with_upstairs_container() only
		# ever considers rows that are actually on screen.
		uc.user_container_array.clear()
		uc.user_container_array.assign(active)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[SCORE8] is_server=", multiplayer.is_server(),
			" players=", player_count, " rows=", active.size(),
			" scale=%.3f" % row_scale, " expanded=", expand)

@export_category("components")
@export var intermission_manager: IntermissionManager
@export var user_container_array: Array[Intermission_UserContainer]

@export_category("visuals")
@export var total_round_score_label: Label3D
@export var animator_score: AnimationPlayer
@export var letter_delay_for_typers: float
@export var typers_start: Array[Typer]
@export var typers_late: Array[Typer]
@export var score_container_nodes: Array[Intermission_UserContainer]
@export var anim_no_score: AnimationPlayer

@export var speaker_score_screen_bootup: AudioStreamPlayer
@export var speaker_show_score_node: AudioStreamPlayer
@export var speaker_score_click: AudioStreamPlayer
@export var speaker_score_click_reverb: AudioStreamPlayer
@export var speaker_everyone_died: AudioStreamPlayer
@export var speaker_everyone_died_click: AudioStreamPlayer
@export var speaker_hide_score_screen: AudioStreamPlayer
@export var sc_click: SpeakerController

@export var binary_cells_parent: Node3D

var active_total_score_by_network_id: Dictionary[int, int]
var active_game_score_by_network_id: Dictionary[int, int]

var binary_cells: Array[Node3D]

var total_game_score = 0

var stopping_music = false

var playing_hide_ui_sound = true

var lerping_total_score = false
var lerp_total_score_elapsed = 0
var lerp_duration_total_score = 0

signal score_screen_finished()
signal score_screen_hidden()

func _ready() -> void :
	for typer in typers_start:
		typer.letter_delay = letter_delay_for_typers

	for child in binary_cells_parent.get_children():
		binary_cells.append(child)

func _physics_process(delta: float) -> void :

	lerp_total_score(delta)

func reset_user_containers(
	_total_score_by_network_id: Dictionary, 
	_game_score_by_network_id: Dictionary
):

	# setup() is already invoked on every peer by show_score_screen_rpc, and the
	# score dictionaries it carries are identical everywhere, so sizing the
	# board from them needs no RPC of its own and cannot desync.
	_mod_set_capacity(_total_score_by_network_id.size())

	for i in user_container_array.size():
		var user_container = user_container_array[i]
		user_container.set_user_container_as_empty()
		user_container.user_network_id = -2
		user_container.user_rank_value = -1
		user_container.position.y = rank_y_positions[i]
		user_container.container_active = false

	var player_by_score_array: Array
	for network_id in _total_score_by_network_id.keys():
		var subtract = _game_score_by_network_id.get(network_id, 0)
		player_by_score_array.append({
			"network_id": network_id, 
			"score": _total_score_by_network_id[network_id] - subtract
		})

	player_by_score_array.sort_custom( func(a, b):
		return a["score"] > b["score"]
	)

	for i in user_container_array.size():
		var user_container = user_container_array[i]
		user_container.position.y = rank_y_positions[i]
		if i < player_by_score_array.size():
			var user_score = player_by_score_array[i]["score"]
			var user_name = intermission_manager.get_user_name_from_network_id(player_by_score_array[i]["network_id"])
			user_container.set_user_container_data(user_score, user_name)
			user_container.user_score_value_for_sorting = user_score
			user_container.user_network_id = player_by_score_array[i]["network_id"]
			user_container.container_active = true
			user_container.set_user_rank_label(i + 1)

	score_container_nodes.clear()
	for i in user_container_array.size():
		score_container_nodes.append(user_container_array[i])


func check_to_show_score():
	if not multiplayer.is_server():
		return

	await get_tree().create_timer(0.5).timeout

	var total_scores = intermission_manager.game.total_score_by_network_id.duplicate(true)
	var game_scores = intermission_manager.game.game_score_by_network_id.duplicate(true)

	var no_score: bool = true
	for value in game_scores.values():
		if value > 0:
			no_score = false
			break

	var games_concluded = intermission_manager.game.session_minigame_played_list == intermission_manager.game.session_minigame_list

	intermission_manager.show_score_screen_rpc.rpc(
		total_scores, 
		game_scores, 
		no_score, 
		games_concluded, 
	)

func hide_score_screen(emit: bool = true):
	animator_score.play("hide")
	if stopping_music:
		stop_music_final()
		if multiplayer.is_server():
			setup_session_end()
		emit = false
	if playing_hide_ui_sound:
		speaker_hide_score_screen.play()
	if !playing_hide_ui_sound:
		playing_hide_ui_sound = true
	binary_sheet_visuals_hide()
	hide_typers()
	hide_score_nodes()
	lerp_total_score_elapsed = 0
	lerping_total_score = false

	if emit:
		score_screen_hidden.emit()

func setup_session_end():
	await get_tree().create_timer(1.8, false).timeout
	intermission_manager.screen_session_end.send_session_end_data_host()

func stop_music_final():
	await get_tree().create_timer(0.14, false).timeout
	MusicManager.stop_playing_music(0.3)

func setup(
	_total_score_by_network_id: Dictionary[int, int], 
	_game_score_by_network_id: Dictionary[int, int], 
	_no_score: bool = false, 
	_stopping_music: bool = false
):
	reset_user_containers(_total_score_by_network_id, _game_score_by_network_id)
	stopping_music = _stopping_music

	active_total_score_by_network_id = _total_score_by_network_id
	active_game_score_by_network_id = _game_score_by_network_id

	show_total_game_score()

	animator_score.play("setup")
	speaker_score_screen_bootup.play()
	await get_tree().create_timer(0.6, false).timeout
	show_score_nodes()
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.6, false).timeout
	binary_sheet_visuals()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.5, false).timeout

	if _no_score:
		show_no_score_dialog()
	else:
		distribute_points_between_players()

func show_total_game_score():
	total_game_score = 0
	for score in active_game_score_by_network_id.values():
		total_game_score += score
	total_round_score_label.text = "%04d" % total_game_score

func show_score_nodes():

	for node in score_container_nodes:
		node.visible = true
		speaker_show_score_node.play()
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.12, false).timeout

func hide_score_nodes():
	for node in score_container_nodes:
		node.visible = false
		node.reset_score_division_connector()
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.06, false).timeout

func sort_user_containers_by_score():

	var array_to_sort = []
	var counter = 0
	for uc in user_container_array:
		if counter < active_total_score_by_network_id.values().size():
			array_to_sort.append([0, 0])
			array_to_sort[counter][0] = uc.user_score_value
			array_to_sort[counter][1] = uc.user_network_id
			counter += 1

	array_to_sort.sort()
	array_to_sort.reverse()

	var rank_position_counter = 0
	for user_data in array_to_sort:
		var user_network_id = user_data[1]
		for uc in user_container_array:
			if user_network_id == uc.user_network_id:
				uc.position = Vector3(
					uc.position.x, 
					rank_y_positions[rank_position_counter], 
					uc.position.z
				)
				score_container_nodes[rank_position_counter] = uc
				uc.set_user_rank_label(rank_position_counter + 1)
		rank_position_counter += 1

func distribute_points_between_players():

	var connection_sound_played = false
	var longest_score_lerp_value = 0

	for i in user_container_array.size():
		var user_container = user_container_array[i]


		if not user_container.container_active:
			continue


		var game_score = active_game_score_by_network_id.get(user_container.user_network_id, 0)
		if game_score <= 0:
			user_container.lerp_score_end_value = user_container.user_score_value
			continue


		user_container.connect_for_score_division()
		if not connection_sound_played:
			user_container.speaker_connector.play()
			connection_sound_played = true


		user_container.add_score(game_score)


		if user_container.lerp_duration_score > longest_score_lerp_value:
			longest_score_lerp_value = user_container.lerp_duration_score

	for uc in user_container_array:
		uc.checking_upstairs = true

	lerp_duration_total_score = longest_score_lerp_value * 1.5
	drain_total_score()
	await get_tree().create_timer(lerp_duration_total_score * 1.5, false).timeout

	score_screen_finished.emit()

func play_no_score_sound():
	await get_tree().create_timer(0.25, false).timeout
	speaker_everyone_died.play()

func show_no_score_dialog():
	await get_tree().create_timer(1, false).timeout
	anim_no_score.play("show no score")
	play_no_score_sound()
	if not is_inside_tree():
		return
	await get_tree().create_timer(3.5, false).timeout

	score_screen_finished.emit()

func play_click_sound():
	speaker_everyone_died_click.play()

func sum(arr: Array):
	var result = 0
	for i in arr:
		result += i
	return result

func drain_total_score():
	await get_tree().create_timer(0.5, false).timeout

	new_text_to_check = ""
	previous_text_to_check = ""

	lerp_total_score_elapsed = 0
	lerping_total_score = true

	speaker_score_click.pitch_scale = 2
	sc_click.speaker.volume_linear = 0
	sc_click.fade_duration = lerp_duration_total_score
	sc_click.fade_in()

var new_text_to_check = ""
var previous_text_to_check = ""
func lerp_total_score(delta: float):

	if lerping_total_score:
		previous_text_to_check = total_round_score_label.text
		lerp_total_score_elapsed += delta
		var progress: float = lerp_total_score_elapsed / lerp_duration_total_score
		var c = clampf(progress, 0.0, 1.0)
		c = ease(c, 0.4)
		var pitch = speaker_score_click.pitch_scale
		pitch -= 0.005
		if pitch < 0.1: pitch = 0.1
		speaker_score_click.pitch_scale = pitch
		var new_total_score = lerpf(total_game_score, 0, c)
		var new_text = "%04d" % new_total_score

		if new_text == "0001":
			speaker_score_click.play()
			total_round_score_label.text = "0001"
			set_final_label(progress)
			lerping_total_score = false
			for user_container in user_container_array:
				user_container.update_score(progress)
			return

		total_round_score_label.text = new_text

		new_text_to_check = total_round_score_label.text

		if previous_text_to_check != new_text_to_check:
			speaker_score_click.play()

		for user_container in user_container_array:
			user_container.update_score(progress)

func set_final_label(_progress):
	await get_tree().create_timer(0.5, false).timeout
	total_round_score_label.text = "0000"

	new_text_to_check = total_round_score_label.text

	speaker_score_click_reverb.volume_db = speaker_score_click.volume_db
	# 8P MOD: `speaker_score_click.pitch_scale` is floored at 0.1 by
	# lerp_total_score(), so vanilla's `- 0.2` hands AudioStreamPlayer a negative
	# pitch and Godot rejects it with `Condition "p_pitch_scale <= 0.0" is true`.
	# Reaching that floor takes ~380 decrements of the score countdown, which
	# only happens once the totals are big enough - so this fired once per peer
	# at eight players and never at four. It is vanilla code, found by the 4-vs-8
	# error-class diff (pitfall 12), not by the mod breaking anything.
	# maxf() is identity at <=4, where the pitch never gets near 0.2.
	speaker_score_click_reverb.pitch_scale = maxf(speaker_score_click.pitch_scale - 0.2, 0.1)
	speaker_score_click_reverb.play()

	for user_container in user_container_array:
		user_container.update_score(1)

func binary_sheet_visuals():
	var random_cells_to_show: Array[Node3D]
	for i in 8:
		random_cells_to_show.append(binary_cells.pick_random())
	for cell: BinaryCellManager in random_cells_to_show:
		cell.visible = true
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.06, false).timeout
		cell.shuffle_binary()

func type_start():
	for typer in typers_start:
		typer.type_text()

func type_late():
	for typer in typers_late:
		typer.type_text()

func binary_sheet_visuals_hide():
	for cell in binary_cells_parent.get_children():
		cell.visible = false
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.01, false).timeout

func hide_typers():
	for typer in typers_start:
		typer.hide_text()
	for typer in typers_late:
		typer.hide_text()



@rpc("any_peer", "call_local", "reliable")
func hide_score_screen_rpc():

	hide_score_screen()
