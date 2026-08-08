class_name Intermission_BriefingScreen extends Node

var CONTROL_PAGE_HEADER: String = "LOC_IM_CONTROLS"
const CONTROL_INPUT_LABEL = preload("uid://bwixccr50fbc2")

@export var intermission_manager: IntermissionManager
@export var env_intermission: WorldEnvironment
@export var user_data_container_parent: Control
@export var user_container_array: Array[Intermission_UserContainer_2D]
@export var score_container_nodes: Array[Intermission_UserContainer_2D]
@export var anim_brief_screen: AnimationPlayer

@export var color_rect_scalers_parent: Control
@export var color_rect_scalers: Array[ColorRectVisualScaler]

var active_total_score_by_network_id: Dictionary[int, int]

var rank_y_positions: Array[float] = [0, 19, 38, 57]

# --- 8P MOD ------------------------------------------------------------------
# Same four-row cap as the score screen (see intermission_score_screen.gd), but
# with more coupled state, all of which had to grow together:
#
#   * rank_y_positions        - 4 entries, read at 4 sites here.
#   * user_container_array    - 4 cards wired in intermission_new.tscn.
#   * score_container_nodes   - sort_user_containers_by_score() *assigns*
#                               score_container_nodes[i], so leaving it at 4
#                               while the card list grows is an out-of-bounds
#                               write, not a silent truncation.
#   * speakers_show_player_card - indexed per row in show_score_nodes() and
#                               update_players(); pitfall 13. Wrapped modulo,
#                               which is identity at <= 4 rows.
#   * invite_visual_button / invite_interact_button - each card dereferences
#                               these in its own _ready() via
#                               hide_invite_button(), so a clone without them
#                               crashes on entering the tree. Cloned per row.
#
# Rows cannot be extended downward: "ready button parent" sits at offset_top
# 149.5 in the same column, and the four shipped rows already reach ~144. So the
# eight rows are resampled across the shipped span and scaled, exactly as on the
# score screen, giving the same 3/7 ratio.
const MOD_VANILLA_RANKS: int = 4
const MOD_MAX_RANKS: int = 8
const MOD_VANILLA_RANK_Y: Array[float] = [0, 19, 38, 57]
const MOD_ROW_SCALE: float = 3.0 / 7.0
const MOD_USER_INFO_2D: PackedScene = preload("res://minigames/intermission_new/components/user_info_2d.tscn")

var mod_vanilla_containers: Array[Intermission_UserContainer_2D] = []
var mod_extra_containers: Array[Intermission_UserContainer_2D] = []
# The two invite buttons live in different coordinate spaces from the card (the
# interact button is in the un-scaled screen overlay). Rather than hardcode
# either, the card-y -> button-offset ratio is learned from the shipped four,
# the way green_pea_chairs.py learns its marker->chair offset.
var mod_vis_base: float = 0.0
var mod_vis_ratio: float = 1.0
var mod_act_base: float = 0.0
var mod_act_ratio: float = 1.0
var mod_act_height: float = 0.0
var mod_act_scale: Vector2 = Vector2.ONE

func _mod_learn_button_mapping() -> void:
	var first: Intermission_UserContainer_2D = mod_vanilla_containers[0]
	var last: Intermission_UserContainer_2D = mod_vanilla_containers[MOD_VANILLA_RANKS - 1]
	var span: float = MOD_VANILLA_RANK_Y[MOD_VANILLA_RANKS - 1] - MOD_VANILLA_RANK_Y[0]
	if span == 0.0:
		return
	if first.invite_visual_button != null and last.invite_visual_button != null:
		mod_vis_base = first.invite_visual_button.offset_top
		mod_vis_ratio = (last.invite_visual_button.offset_top - mod_vis_base) / span
	if first.invite_interact_button != null and last.invite_interact_button != null:
		mod_act_base = first.invite_interact_button.offset_top
		mod_act_ratio = (last.invite_interact_button.offset_top - mod_act_base) / span
		mod_act_height = (first.invite_interact_button.offset_bottom
			- first.invite_interact_button.offset_top)
		mod_act_scale = first.invite_interact_button.scale

func _mod_build_extras() -> void:
	if not mod_extra_containers.is_empty():
		return
	if user_container_array.size() < MOD_VANILLA_RANKS:
		push_warning("[BRIEF8] only %d shipped cards; cannot expand"
			% user_container_array.size())
		return

	mod_vanilla_containers.assign(user_container_array)
	_mod_learn_button_mapping()

	var template: Intermission_UserContainer_2D = mod_vanilla_containers[MOD_VANILLA_RANKS - 1]
	var card_parent: Node = template.get_parent()

	for i in range(MOD_VANILLA_RANKS, MOD_MAX_RANKS):
		var card: Intermission_UserContainer_2D = MOD_USER_INFO_2D.instantiate()
		card.name = "player data container%d_MOD" % i
		card.visible = false
		card.container_id = i

		# Wired BEFORE add_child: the card's _ready() calls hide_invite_button(),
		# which dereferences both without a null check.
		card.invite_visual_button = _mod_clone_button(
			template.invite_visual_button, "InviteButton%d_MOD" % i)
		card.invite_interact_button = _mod_clone_button(
			template.invite_interact_button, "InviteOverlayButton%d_MOD" % i)

		card_parent.add_child(card)
		mod_extra_containers.append(card)

		if card.invite_visual_button != null:
			invite_buttons_visuals.append(card.invite_visual_button)
		if card.invite_interact_button != null:
			invite_buttons_interacts.append(card.invite_interact_button)
			# setup_invite_buttons() already ran in _ready(), before these
			# existed, so the Steam overlay hook is connected here instead.
			if not GameManager.local_game:
				card.invite_interact_button.pressed.connect(func():
					Steam.activateGameOverlayInviteDialog(
						NetworkManager.active_backend.lobby_id
					)
				)

		if GameManager.local_game:
			if card.invite_visual_button != null:
				card.invite_visual_button.visible = false
			if card.invite_interact_button != null:
				card.invite_interact_button.visible = false

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[BRIEF8] built extras=", mod_extra_containers.size(),
			" vis_ratio=%.4f act_ratio=%.4f" % [mod_vis_ratio, mod_act_ratio])

func _mod_clone_button(source: Button, new_name: String) -> Button:
	if source == null:
		return null
	# Plain Buttons with no exported node references, so duplicate() is safe
	# here - unlike the cards, which resolve label paths at instantiation.
	var clone: Button = source.duplicate()
	clone.name = new_name
	clone.visible = false
	source.get_parent().add_child(clone)
	return clone

func _mod_apply_row(card: Intermission_UserContainer_2D, row_y: float,
		row_scale: float) -> void:
	card.position.y = row_y
	card.scale = Vector2.ONE * row_scale

	var vis: Button = card.invite_visual_button
	if vis != null:
		vis.offset_top = mod_vis_base + mod_vis_ratio * row_y
		vis.offset_bottom = vis.offset_top
		vis.scale = Vector2.ONE * row_scale

	var act: Button = card.invite_interact_button
	if act != null:
		act.offset_top = mod_act_base + mod_act_ratio * row_y
		act.offset_bottom = act.offset_top + mod_act_height * row_scale
		act.scale = mod_act_scale * row_scale

func _mod_row_count() -> int:
	# Both sources are replicated, so every peer sizes the board identically.
	return maxi(active_total_score_by_network_id.size(),
		PlayerManager.player_presences.size())

func _mod_set_capacity() -> void:
	_mod_build_extras()
	if mod_vanilla_containers.is_empty():
		return

	var player_count: int = _mod_row_count()
	var expand: bool = (player_count > MOD_VANILLA_RANKS
		and mod_extra_containers.size() == MOD_MAX_RANKS - MOD_VANILLA_RANKS)

	var active: Array[Intermission_UserContainer_2D] = []
	active.assign(mod_vanilla_containers)
	var ys: Array[float] = []

	if expand:
		active.append_array(mod_extra_containers)
		var top: float = MOD_VANILLA_RANK_Y[0]
		var bottom: float = MOD_VANILLA_RANK_Y[MOD_VANILLA_RANKS - 1]
		var step: float = (bottom - top) / float(MOD_MAX_RANKS - 1)
		for i in MOD_MAX_RANKS:
			ys.append(top + step * i)
	else:
		ys.assign(MOD_VANILLA_RANK_Y)
		for card in mod_extra_containers:
			card.visible = false
			card.hide_invite_button()

	rank_y_positions = ys
	user_container_array = active
	# sort_user_containers_by_score() assigns score_container_nodes[i] by index,
	# so this must track the card list exactly rather than merely being appended.
	score_container_nodes = active.duplicate()

	var row_scale: float = MOD_ROW_SCALE if expand else 1.0
	for i in active.size():
		_mod_apply_row(active[i], ys[i], row_scale)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[BRIEF8] is_server=", multiplayer.is_server(),
			" players=", player_count, " rows=", active.size(),
			" scale=%.3f" % row_scale, " expanded=", expand)

@export var anim_page_button_blinking: AnimationPlayer
@export var anim_pagination_highlight: AnimationPlayer

@export var button_ready: Button
@export var button_page_left: Button
@export var button_page_right: Button

@export var ready_button_parent: Control

@export var bc_ready: ButtonClass
@export var bc_page_left: ButtonClass
@export var bc_page_right: ButtonClass

@export var briefing_screen_buttons: Array[Button]

@export var label_page_number: Label
@export var label_brief_content: Label
@export var label_brief_header: Label
@export var label_ready_button: Label
@export var brief_controls_container: Control

@export var anim_console_transition_text: AnimationPlayer

@export var speaker_servo3: AudioStreamPlayer
@export var speaker_show_ready: AudioStreamPlayer
@export var speakers_show_player_card: Array[AudioStreamPlayer]
@export var speaker_viewfinder_typer: AudioStreamPlayer

@export var speaker_transition_out: AudioStreamPlayer
@export var sc_transition_out: SpeakerController
@export var input_icon_mapping: InputIconMapping

@export_category("Other")
@export var pagination_highlight_control: Control
@export var button_press_speaker: AudioStreamPlayer

@export_category("Progress")
@export var progress_indicator: Control
@export var progress_bar_tiles: Control

@export var progress_indicator_min: float = 257.0
@export var progress_indicator_max: float = 422.0

@export var progress_bar_tiles_min: float = 0.0
@export var progress_bar_tiles_max: float = 312.0

@export_category("Invite")
@export var invite_buttons_visuals: Array[Button]
@export var invite_buttons_interacts: Array[Button]

@export_category("Local")
@export var local_ready_button: Control

var all_ready: bool = false
var is_ready: bool = false
var active: bool = false
var players_ready: Dictionary[int, bool]

var active_pages_content: Array[String]
var active_pages_headers: Array[String]
var active_page_index: int
var active_num_of_total_pages: int

var ready_button_cooldown_time: float = 0.2
var ready_button_cooldown_counter: float = 0
var ready_button_press_allowed = false
var ready_button_on_cooldown = false
var ready_button_cooldown_counting = false

var pagination_highlight_shown = false

var games_played: int = 0
var total_games: int = 0
var pagination_triggered: bool = false

signal all_players_ready()

func _ready() -> void :

	if GameManager.local_game:
		ready_button_parent.visible = false
		button_ready.disabled = true
		bc_ready.active = false
		for invite in invite_buttons_visuals:
			invite.visible = false
		for invite in invite_buttons_interacts:
			invite.visible = false

	brief_controls_container.visible = false

	button_ready.pressed.connect(_on_ready_button_pressed)
	bc_ready.connect("is_pressed", _on_ready_button_pressed)
	bc_page_left.connect("is_pressed", page_left_pressed)
	bc_page_right.connect("is_pressed", page_right_pressed)
	button_page_right.pressed.connect(page_right_pressed)

	progress_indicator.position.x = progress_indicator_min
	progress_bar_tiles.size.x = progress_bar_tiles_min

	setup_invite_buttons()
	set_briefing_screen_button_disabled(true)

	GameManager.input_device_changed.connect(_on_input_device_changed)
	PauseMenu.unpaused.connect(_on_unpaused)

	Globals.locale_changed.connect(debug_update)

func debug_update():
	update_page_number_visuals()
	update_page_content()

func setup_invite_buttons():

	if GameManager.local_game:
		return

	for iib in invite_buttons_interacts:
		iib.pressed.connect( func():
			Steam.activateGameOverlayInviteDialog(
				NetworkManager.active_backend.lobby_id
			)
		)

@rpc("authority", "call_local", "reliable")
func reset_briefing_rpc(
	_player_scores: Dictionary[int, int], 
	_current_game_count: int, 
	_total_game_count: int, 
):

	games_played = _current_game_count
	total_games = _total_game_count

	active_total_score_by_network_id = _player_scores

	# Before the clear() below, so the loop that follows rebuilds
	# score_container_nodes over the full card list rather than doubling it.
	_mod_set_capacity()

	score_container_nodes.clear()


	for i in user_container_array.size():

		var user_container = user_container_array[i]
		user_container.position.y = rank_y_positions[i]

		score_container_nodes.append(user_container)


	set_user_container_info()

	sort_user_containers_by_score()

func update_progess_elements():

	await get_tree().create_timer(0.5).timeout

	var progressed_current = min(games_played + 1, total_games)

	var indicator_position: float = lerp(
		progress_indicator_min, progress_indicator_max, progressed_current / float(total_games)
	)
	var indicator_tween: Tween = create_tween()
	indicator_tween.tween_property(
		progress_indicator, "position:x", indicator_position, 1.0
	).set_trans(Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)

	var tiles_size: float = lerp(
		progress_bar_tiles_min, progress_bar_tiles_max, progressed_current / float(total_games)
	)
	var tiles_tween: Tween = create_tween()
	tiles_tween.tween_property(
		progress_bar_tiles, "size:x", tiles_size, 1.0
	).set_trans(Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)

func set_user_container_info():
	var counter = 0
	for uc in user_container_array:

		if counter < active_total_score_by_network_id.values().size():
			var user_score = active_total_score_by_network_id.values()[counter]
			var user_name = intermission_manager.get_user_name_from_network_id(active_total_score_by_network_id.keys()[counter])
			uc.set_user_data(user_score, user_name)
			uc.user_network_id = active_total_score_by_network_id.keys()[counter]
			uc.user_ready = false
			if multiplayer.is_server():
				players_ready[uc.user_network_id] = false
		else:
			if multiplayer.is_server():
				uc.set_invite()
			else:
				uc.set_empty()

		counter += 1

func _physics_process(_delta: float) -> void :

	if not GameManager.game_focused:
		return

	check_ready_button_cooldown()

	if not active:
		return

	process_local_input()
	process_online_input()

func process_local_input():

	if not GameManager.local_game:
		return

	if PauseMenu.active:
		return

	for player_id in PlayerManager.player_presences.keys():
		var player_presence = PlayerManager.player_presences[player_id]
		if not player_presence.local_controller_connected:
			continue
		var device_id = player_presence.device_id

		if MultiplayerInput.is_action_just_pressed(device_id, "left"):
			page_left_pressed()
		elif MultiplayerInput.is_action_just_pressed(device_id, "right"):
			page_right_pressed()

		if MultiplayerInput.is_action_just_pressed(device_id, "local_intermission_ready"):
			set_ready_rpc(player_id, not players_ready.get(player_id, false))

func process_online_input():

	if GameManager.local_game:
		return

	if PauseMenu.active:
		return

	if Input.is_action_just_pressed("left"):
		page_left_pressed()

	elif Input.is_action_just_pressed("right"):
		page_right_pressed()

func hide_invite_buttons():

	for ivb in invite_buttons_visuals:
		ivb.visible = false

	for iib in invite_buttons_interacts:
		iib.visible = false

func set_ready_button_disabled(_disabled: bool):

	if GameManager.local_game:
		return

	if button_ready.disabled == _disabled:
		return

	if Globals.allow_singleplayer:

		button_ready.disabled = false
		bc_ready.active = true
		bc_ready.custom_ui_target.visible = true
		return

	button_ready.disabled = _disabled
	bc_ready.active = not _disabled
	bc_ready.custom_ui_target.visible = not _disabled

func check_ready_button_cooldown():

	if ready_button_cooldown_counting:
		ready_button_cooldown_counter += get_process_delta_time()
		if ready_button_cooldown_counter > ready_button_cooldown_time:
			ready_button_on_cooldown = false
			ready_button_cooldown_counting = false
			bc_ready.active = true

func play_show_ready_button_sound():
	speaker_show_ready.play()

func setup(_active_total_score_by_network_id: Dictionary[int, int]):

	if multiplayer.is_server():
		intermission_manager.game.clear_game_scores()
		for k in intermission_manager.game.game_score_by_network_id.keys():
			intermission_manager.game.round_score_by_network_id[k] = 0

		active_total_score_by_network_id = _active_total_score_by_network_id

		set_custom_game_check_rpc.rpc(GameManager.custom_game)

# --- 8P MOD: -localtest -fullflow auto-ready --------------------------------
# The briefing's Ready button is the ONLY point in a normal session loop that
# waits on player input (session end and the intermission picker advance on
# timers, and the intro cutscene needs no press). An unattended -localtest run
# with the normal flow enabled would therefore stall here forever, so each
# instance readies itself up.
#
# Deliberately routed through set_ready_rpc rather than poking players_ready:
# that is the same call the button handler makes, so the ready sound, the
# nametag indicator and the host's check_all_ready() all behave exactly as they
# do for a real press. Diagnostic-only, and inert without both flags.
const MOD_AUTOREADY_DELAY: float = 3.0

func _mod_should_autoready() -> bool:
	var args := Array(OS.get_cmdline_args())
	return args.has("-localtest") and args.has("-fullflow")

func _mod_autoready() -> void:
	await get_tree().create_timer(MOD_AUTOREADY_DELAY, false).timeout

	# The host only learns a peer's id when it fills user_container_array, so a
	# ready sent too early is dropped; the delay covers that, and these guards
	# cover the screen being torn down in the meantime.
	if not is_inside_tree() or not active or is_ready:
		return

	is_ready = true
	ready_button_parent.modulate.a = 0.2
	set_ready_rpc.rpc(multiplayer.get_unique_id(), true)
	print("[FLOW] auto-ready peer=", multiplayer.get_unique_id(),
		" is_server=", multiplayer.is_server())

func show_briefing_screen():
	brief_controls_container.visible = false

	active = true
	players_ready = {}
	all_ready = false

	if _mod_should_autoready():
		_mod_autoready()

	intermission_manager.game.can_check_for_connect_requests = true

	setup(intermission_manager.game.total_score_by_network_id)
	set_briefing_screen_info(intermission_manager.next_minigame_identifier)
	show_user_info()
	sort_user_containers_by_score()

	anim_brief_screen.play("setup brief screen")

	for scaler in color_rect_scalers:
		scaler.lerp_scale()
	speaker_servo3.play()
	await get_tree().create_timer(1.45, false).timeout
	show_score_nodes()
	set_briefing_screen_button_disabled(false)
	if GameManager.local_game:
		show_local_ready()

	update_progess_elements()

	if multiplayer.is_server():
		set_ready_button_disabled(
			PlayerManager.player_presences.size() < 2
		)

	GameManager.can_set_cursor = true
	PauseMenu.game_target_can_set_cursor = true

	if GameManager.is_using_controller():

		get_viewport().gui_release_focus()

		if not PauseMenu.active:
			button_ready.grab_focus()

	else:

		PauseMenu.game_target_can_set_cursor = true
		PauseMenu.game_target_cursor_active = true
		PauseMenu.game_target_cursor_visible = true

		CursorManager.set_locked(false, false)
		CursorManager.set_active(true)
		CursorManager.set_cursor(true, false)
		CursorManager.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)

	ready_button_press_allowed = true
	anim_page_button_blinking.play("flicker page buttons")
	bc_ready.active = true
	button_ready.visible = true
	bc_page_left.active = true
	button_page_left.visible = true
	bc_page_right.active = true
	button_page_right.visible = true
	ready_button_parent.modulate.a = 1
	is_ready = false

	if not Globals.settings.get("original_finished", false) && not GameManager.pagination_highlight_shown:
		if GameManager.local_game:
			return
		GameManager.pagination_highlight_shown = true
		if not is_inside_tree():
			return
		await get_tree().create_timer(1.5, false).timeout
		anim_pagination_highlight.play("show")

func show_local_ready():
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.0).timeout
	local_ready_button.visible = true

func update_briefing_screen():

	if multiplayer.is_server():
		intermission_manager.game.clear_game_scores()
		for k in intermission_manager.game.game_score_by_network_id.keys():
			intermission_manager.game.round_score_by_network_id[k] = 0

	active_total_score_by_network_id = intermission_manager.game.total_score_by_network_id

func set_briefing_screen_button_disabled(_disabled: bool):

	if GameManager.local_game:
		return

	if _disabled:
		for button in briefing_screen_buttons:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		for button in briefing_screen_buttons:
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.disabled = false

func set_briefing_screen_info(minigame_identifier: Globals.MinigameIdentifier):

	var brief_page_contents: Array[String] = []
	var brief_header_contents: Array[String] = []
	var minigame_briefing_info: Intermission_IconResource = null

	for minigame in intermission_manager.minigame_icon_resource_array:
		if minigame.identifier == minigame_identifier:
			minigame_briefing_info = minigame
			if minigame.brief_instructions_content_pages != null:
				brief_page_contents = minigame.brief_instructions_content_pages.duplicate(true)
			if minigame.brief_instructions_header_pages != null:
				brief_header_contents = minigame.brief_instructions_header_pages.duplicate(true)
			break

	for c in brief_controls_container.get_children():
		c.free()

	await get_tree().physics_frame


	if minigame_briefing_info:
		brief_header_contents.insert(0, CONTROL_PAGE_HEADER)
		brief_page_contents.insert(0, CONTROL_PAGE_HEADER)

		for control_data in minigame_briefing_info.controls_data:
			var control_input_label: IntermissionControlInputLabel = CONTROL_INPUT_LABEL.instantiate()
			brief_controls_container.add_child(control_input_label, true)

			var keyboard_icons: Array[Texture2D]
			var controller_icons: Array[Texture2D]

			for action in control_data.keyboard_icons:
				keyboard_icons.append(input_icon_mapping.get_icon(action))

			for action in control_data.controller_icons:
				controller_icons.append(input_icon_mapping.get_icon(action))

			control_input_label.set_data(
				keyboard_icons, controller_icons, control_data.control_text, control_data.controller_text
			)

	active_pages_headers = brief_header_contents
	active_pages_content = brief_page_contents
	active_page_index = 0
	if active_pages_content.is_empty():
		active_page_index = -1
	active_num_of_total_pages = brief_page_contents.size()

	update_page_content()
	update_page_number_visuals()

func page_left_pressed():

	if active_page_index != 0:
		active_page_index -= 1

	button_press_speaker.play()

	update_page_number_visuals()
	update_page_content()

func page_right_pressed():

	if active_page_index != active_num_of_total_pages - 1:
		active_page_index += 1

	button_press_speaker.play()

	update_page_number_visuals()
	update_page_content()

func update_page_content():

	if active_pages_headers.is_empty():

		label_brief_header.text = "-------------"
		label_brief_content.text = "----"

		return

	var label_brief_header_text = active_pages_headers[active_page_index]
	if label_brief_header_text == CONTROL_PAGE_HEADER:

		label_brief_header.text = tr(label_brief_header_text)

		brief_controls_container.visible = true
		label_brief_content.visible = false

	else:

		if not active_pages_headers.is_empty():
			label_brief_header.text = active_pages_headers[active_page_index]

		if not active_pages_content.is_empty():
			label_brief_content.text = active_pages_content[active_page_index]

		brief_controls_container.visible = false
		label_brief_content.visible = true

func update_page_number_visuals():
	if active_pages_headers.is_empty():
		label_page_number.text = tr("LOC_IM_NO_CONTENT")
	else:
		label_page_number.text = tr("LOC_IM_PAGE") % [str(active_page_index + 1), str(active_num_of_total_pages)]

	intermission_manager.picker.active_page = active_page_index + 1
	intermission_manager.picker.check_if_locale_requires_vertical_adjustment()

func show_score_nodes():

	var counter_speaker = 0
	for node in score_container_nodes:
		node.show_container()
		# 8P MOD: four card-reveal speakers are shipped, one per row. Wrap
		# instead of extending the array - identity at <= 4 rows, and the added
		# rows reuse the same click rather than falling silent.
		speakers_show_player_card[counter_speaker % speakers_show_player_card.size()].play()
		counter_speaker += 1
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.12, false).timeout

func hide_score_nodes():
	for node in score_container_nodes:
		node.hide_container()
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.06, false).timeout

func show_user_info():

	var counter = 0
	for uc in user_container_array:
		var type = "normal"

		if counter < active_total_score_by_network_id.values().size():
			var user_score = active_total_score_by_network_id.values()[counter]
			var user_name = intermission_manager.get_user_name_from_network_id(active_total_score_by_network_id.keys()[counter])
			uc.set_user_data(user_score, user_name)
			uc.user_network_id = active_total_score_by_network_id.keys()[counter]
			uc.user_ready = false
			if multiplayer.is_server():
				players_ready[uc.user_network_id] = false
		else:

			if multiplayer.is_server():
				uc.set_invite()
				type = "invite"
			else:
				uc.set_empty()
				type = "empty"

		counter += 1

func sort_user_containers_by_score():

	_mod_set_capacity()

	for i in user_container_array.size():
		var user_container = user_container_array[i]
		if multiplayer.is_server():
			user_container.set_invite()
		else:
			user_container.set_empty()
		user_container.user_network_id = -2
		user_container.user_rank_value = -1
		user_container.position.y = rank_y_positions[i]

	var player_by_score_array: Array
	for network_id in active_total_score_by_network_id.keys():
		player_by_score_array.append({
			"network_id": network_id, 
			"score": active_total_score_by_network_id[network_id]
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
			user_container.set_user_data(user_score, user_name)
			user_container.set_user_rank_label(i + 1)
			user_container.user_network_id = player_by_score_array[i]["network_id"]

	for i in user_container_array.size():
		score_container_nodes[i] = user_container_array[i]
































func check_all_ready():

	if all_ready:
		return

	for player_ready in players_ready.values():
		if !player_ready:
			return

	all_ready = true
	all_players_ready.emit()

	bc_page_left.active = false
	bc_page_right.active = false
	bc_ready.active = false

	if multiplayer.is_server():
		intermission_manager.game.can_check_for_connect_requests = false

	hide_briefing_screen_rpc.rpc()

func update_players():

	reset_ready_players_rpc.rpc()

	if active:
		reset_player_positions()
		sort_user_containers_by_score()
		for i in user_container_array.size():
			var user_container = user_container_array[i]
			user_container.show_container()
			speakers_show_player_card[i % speakers_show_player_card.size()].play()
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.12, false).timeout

func reset_player_positions():

	_mod_set_capacity()

	for i in user_container_array.size():
		var uc = user_container_array[i]
		uc.position.y = rank_y_positions[i]



@rpc("authority", "call_local", "reliable")
func set_custom_game_check_rpc(_is_custom: bool):
	GameManager.custom_game = _is_custom

@rpc("any_peer", "call_local", "reliable")
func synchronize_scores_rpc(_active_total_score_by_network_id: Dictionary[int, int]):

	reset_player_positions()
	active_total_score_by_network_id = _active_total_score_by_network_id

@rpc("any_peer", "call_local", "reliable")
func update_player_data_rpc(player_scores: Dictionary):
	var player_presences = PlayerManager.player_presences.values()

	active_total_score_by_network_id = player_scores
	_mod_set_capacity()
	for i in user_container_array.size():
		var uc = user_container_array[i]
		uc.hide_container()
		if i < player_presences.size():
			uc.set_user_data(
				player_scores.get(player_presences[i].network_id, 0), 
				player_presences[i].network_name, 
			)
			uc.user_network_id = player_presences[i].network_id
		else:
			if multiplayer.is_server():
				uc.set_invite()
			else:
				uc.set_empty()

	update_players()

@rpc("any_peer", "call_local", "reliable")
func reset_ready_players_rpc():
	players_ready.clear()

	is_ready = false
	ready_button_parent.modulate.a = 1.0

	for uc in user_container_array:
		uc.user_ready = false
		if uc.user_network_id > 0:
			players_ready[uc.user_network_id] = false

@rpc("any_peer", "call_local", "reliable")
func set_ready_rpc(_network_id: int, _is_ready: bool):

	players_ready[_network_id] = _is_ready
	for i in user_container_array:
		if i.user_network_id == _network_id:
			i.user_ready = _is_ready
			if _is_ready:
				i.speaker_ready.pitch_scale = 2
				i.speaker_ready.play()
			else:
				i.speaker_ready.pitch_scale = 1.6
				i.speaker_ready.play()

	if multiplayer.is_server():
		check_all_ready()

@rpc("authority", "call_local", "reliable")
func hide_briefing_screen_rpc():

	if not intermission_manager.is_glitched_minigame():

		MusicManager.start_playing_music_host(true, 2, false, 2.8)
		MusicManager.intro_music_playing = false
		MusicManager.filter_controller.begin_shift(MusicManager.filter_controller.effect_low_pass.cutoff_hz, 200, 5, 1)

	active = false

	GameManager.can_set_cursor = false

	CursorManager.set_locked(false, false)
	CursorManager.set_active(true)
	CursorManager.set_cursor(false, false)
	CursorManager.set_locked(true, false)

	var tween_exposure = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	var tween_contrast = create_tween()
	var tween_saturation = create_tween()
	tween_exposure.tween_property(env_intermission.environment, "tonemap_exposure", 5, 3)
	tween_contrast.tween_property(env_intermission.environment, "adjustment_contrast", 3.04, 3)
	tween_saturation.tween_property(env_intermission.environment, "adjustment_saturation", 0.24, 3)

	button_page_left.visible = false
	button_page_right.visible = false
	button_ready.visible = false

	sc_transition_out.moving = false
	sc_transition_out.elapsed = 0
	speaker_transition_out.volume_linear = db_to_linear(sc_transition_out.original_volume_db)
	speaker_transition_out.play()
	await get_tree().create_timer(0.4, false).timeout
	if GameManager.local_game:
		local_ready_button.visible = false
	intermission_manager.picker.minigame_viewfinder_anim.play("hide")
	anim_brief_screen.play("hide brief screen")
	hide_score_nodes()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.4, false).timeout
	anim_console_transition_text.play("show text")
	intermission_manager.cutscene_intro.anim_env.play("set env to intermission screen instant")
	if not is_inside_tree():
		return
	await get_tree().create_timer(2, false).timeout
	speaker_transition_out.stop()
	intermission_manager.set_intermission_viewport_screen(false)
	MusicManager.filter_controller.begin_shift(MusicManager.filter_controller.effect_low_pass.cutoff_hz, 20000, 20)
	anim_console_transition_text.play("RESET")
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3, false).timeout
	brief_controls_container.visible = false

	if multiplayer.is_server():
		intermission_manager.game._on_minigame_pick_finished(intermission_manager.game.session_next_minigame_index)

	intermission_manager.reset_environment_rpc.rpc()
	intermission_manager.set_default_env()



func _on_input_device_changed(input_device: GameManager.InputDevice) -> void :

	if not active:
		return

	if PauseMenu.active:
		return

	match input_device:
		GameManager.InputDevice.Controller:

			if get_viewport():
				get_viewport().gui_release_focus()
				await get_tree().process_frame

			CursorManager.set_mouse_mode(Input.MouseMode.MOUSE_MODE_CAPTURED)
			CursorManager.set_active(false)

			PauseMenu.game_target_can_set_cursor = false
			PauseMenu.game_target_cursor_active = false
			PauseMenu.game_target_cursor_visible = false

			button_ready.grab_focus()

		GameManager.InputDevice.Keyboard:

			if get_viewport():
				get_viewport().gui_release_focus()

			PauseMenu.game_target_can_set_cursor = true
			PauseMenu.game_target_cursor_active = true
			PauseMenu.game_target_cursor_visible = true

			CursorManager.set_locked(false, false)
			CursorManager.set_active(true)
			CursorManager.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)
			CursorManager.set_cursor(true, true)

func _on_unpaused():

	if not active:
		return

	if GameManager.is_using_controller():
		button_ready.grab_focus()

		PauseMenu.game_target_can_set_cursor = false
		PauseMenu.game_target_cursor_active = false
		PauseMenu.game_target_cursor_visible = false

	else:

		if get_viewport():
			get_viewport().gui_release_focus()

		PauseMenu.game_target_can_set_cursor = true
		PauseMenu.game_target_cursor_active = true
		PauseMenu.game_target_cursor_visible = true

		CursorManager.set_locked(false)
		CursorManager.set_active(true)
		CursorManager.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)
		CursorManager.set_cursor(true, true)

func _on_ready_button_pressed():

	if ready_button_on_cooldown:
		return
	if !ready_button_press_allowed:
		return

	ready_button_cooldown_counter = 0
	ready_button_on_cooldown = true
	ready_button_cooldown_counting = true
	is_ready = !is_ready
	if is_ready:
		ready_button_parent.modulate.a = 0.2
	else:
		ready_button_parent.modulate.a = 1

	set_ready_rpc.rpc(multiplayer.get_unique_id(), is_ready)
