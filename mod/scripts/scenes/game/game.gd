class_name Game extends Node

const player_score_container_scene = preload("res://scripts/scenes/game/components/player_score_container/player_score_container.tscn")

@export_category("Debug")
@export var debug_no_shuffle: bool = true
@export var debug_player_handler: DebugPlayerHandler

@export_category("Scoring Properties")
@export var score_multiplier: int

@export_category("Post Processing")
@export var effects_parent_node: Control

@export_category("Intermission")
@export var intermission_manager: IntermissionManager

@export_category("Mid Session Connect")
@export var can_check_for_connect_requests: bool = false
@export var connect_request_check_interval: float = 1.0

var connect_request_check_timer: float = 0.0
var player_join_queue: Array[int]
var player_mid_join_queue: Array[int]
var player_reconnected_queue: Array[int]

@onready var minigame_parent: Node = $Minigame
@onready var host_overlay: HostOverlay = $HostOverlay
@onready var state_machine: StateMachine = $StateMachine

var network_players_loaded: Array[int]
var players_ready: Array[int]
var minigame_players_loaded: Array[int]
var player_score_containers: Array[PlayerScoreContainer]
var player_removal_queue: Array[int]

var minigame: Minigame = null

var player_labels: Array[Label]

var session_minigame_list: Array[Globals.MinigameIdentifier]
var session_minigame_rounds: Dictionary[Globals.MinigameIdentifier, int]
var session_minigame_index: int = -1
var session_minigame_played_list: Array[Globals.MinigameIdentifier]
var session_last_minigame_identifier: Globals.MinigameIdentifier = Globals.MinigameIdentifier.EMPTY

var session_next_minigame_index: int
var session_next_minigame_identifier: int

var session_current_minigame_round: int = 0
var session_current_minigame_max_rounds: int = 0

var capture_input: bool = false
var is_game_session_ended: bool = false

var total_score_by_network_id: Dictionary[int, int]
var round_score_by_network_id: Dictionary[int, int]
var game_score_by_network_id: Dictionary[int, int]

var disconnected_scores_by_id: Dictionary[int, int]

var effect_backbuffers: Array[BackBufferCopy] = []
var effect_rects: Array[ColorRect] = []

var playlist_state_received: bool = false
var score_state_received: bool = false
var game_ready_sent: bool = false

var is_viewing_final_credits = false

var total_games_count: int = 0
var games_played_count: int = 0


var players_game_ready: Array[int]
var debug_player: int = -1

var trailer_tools_enabled: bool = false
var trailer_ui_visible: bool = true

@warning_ignore("unused_signal")
signal player_minigame_loaded(network_id)
signal player_game_ready(network_id)
signal player_reconnected(network_id)
signal game_session_ended()

func _ready() -> void :

	Globals.all_minigames_finished = false
	GameManager.game_in_progress = true
	GameManager.in_game = true
	SoundManager.set_active(true)

	register_effects()
	get_tree().get_root().connect("size_changed", _viewport_size_changed)
	_viewport_size_changed()

	GameManager.can_set_cursor = false
	CursorManager.set_cursor(false, false)

	PauseMenu.in_game = true
	PauseMenu.show_quit_to_menu = true
	PauseMenu.set_can_activate(true)

	intermission_manager.game = self


	var args = Array(OS.get_cmdline_args())
	if args.has("-trailer"):
		trailer_tools_enabled = true

		if not InputMap.has_action("__debug_ui_toggle"):
			InputMap.add_action("__debug_ui_toggle")
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_KP_DIVIDE
			InputMap.action_add_event("__debug_ui_toggle", ev)
			ev = InputEventKey.new()
			ev.physical_keycode = KEY_INSERT
			InputMap.action_add_event("__debug_ui_toggle", ev)


	for p in NetworkManager.MAX_PLAYERS:
		var label: Label = Label.new()
		label.text = "N/A"
		player_labels.append(label)

	capture_input = true
	GlobalOverlay.fade_overlay(Color(0.0, 0.0, 0.0, 0.0), 1.0)

	if multiplayer.is_server():

		NetworkManager.on_peer_disconnected.connect(_on_peer_disconnected)
		NetworkManager.on_host_disconnected.connect(_on_host_disconnected)

		NetworkManager.player_added_to_join_queue.connect(_on_player_added_to_join_queue)
		NetworkManager.player_removed_from_join_queue.connect(_on_player_removed_from_join_queue)

		intermission_manager.screen_score.score_screen_hidden.connect(_on_score_screen_hidden)
		intermission_manager.screen_score.score_screen_finished.connect(_on_score_screen_finished)
		host_overlay.minigame_selected.connect(_on_host_overlay_minigame_selected)

		player_reconnected.connect(_on_player_reconnected)
		game_session_ended.connect(_on_game_session_ended)

		generate_session_playlist()

		var player_presence = PlayerManager.add_player(1, NetworkManager.active_backend.self_data["customization"])
		PlayerManager.propagate_player_rpc(1, player_presence.get_path())
		players_game_ready.append(1)
		total_score_by_network_id[1] = 0
		game_score_by_network_id[1] = 0
		NetworkManager.host_loaded.rpc(Globals.skipping_intro_cutscene)

		if Globals.allow_singleplayer and NetworkManager.active_backend.connected_players.size() == 1:
			await get_tree().create_timer(1.0).timeout
			state_machine.transition_to_rpc.rpc(&"SessionIntro")

	else:

		NetworkManager.on_host_disconnected.connect(_on_host_disconnected)

		for player_info in NetworkManager.active_backend.connected_players.values():
			if player_info["peer_id"] == multiplayer.get_unique_id():

				var is_debug_player: bool = player_info.get("debug", false)
				if not is_debug_player:
					NetworkManager.client_loaded.rpc_id(1, multiplayer.get_unique_id())
					request_playlist_state_rpc.rpc_id(1, multiplayer.get_unique_id())
					request_score_state_rpc.rpc_id(1, multiplayer.get_unique_id())
				else:
					player_ready_rpc.rpc_id(1, multiplayer.get_unique_id(), false)

	GameManager.online_game_loaded.emit(self)

func _process(delta: float) -> void :


	if trailer_tools_enabled:
		if Input.is_action_just_pressed("__debug_ui_toggle"):
			trailer_ui_visible = not trailer_ui_visible
			var ui_nodes = get_tree().get_nodes_in_group(Globals.GROUP_UI)
			for ui_node in ui_nodes:
				ui_node.visible = trailer_ui_visible


	if not NetworkManager.is_active():
		return

	if not multiplayer.is_server():
		return

	if is_game_session_ended:
		for joining_player_network_id in player_join_queue:
			NetworkManager.active_backend.refuse_client_rpc.rpc_id(
				joining_player_network_id, joining_player_network_id, NetworkManager.RefuseReason.SessionEnded
			)
		player_join_queue.clear()

	if can_check_for_connect_requests:
		connect_request_check_timer += delta
		if connect_request_check_timer > connect_request_check_interval:
			connect_request_check_timer = 0.0
			check_connection_requests()

func _exit_tree() -> void :

	GameManager.game_finished.emit()
	PauseMenu.set_can_activate(false)
	NetworkManager.cancel(multiplayer.get_unique_id())
	PlayerManager.reset()

func is_current_game_cutscene() -> bool:

	if Globals.CutsceneGlitchedPickerMinigameIdentifiers.has(Globals.current_minigame_identifier):
		return true

	if Globals.CutsceneMinigameIdentifiers.has(Globals.current_minigame_identifier):
		return true

	return false

func check_connection_requests():

	for joining_player_network_id in player_join_queue:

		NetworkManager.host_loaded.rpc_id(
			joining_player_network_id, 
			Globals.skipping_intro_cutscene
		)

		player_mid_join_queue.append(joining_player_network_id)

	player_join_queue.clear()

func register_effects() -> void :
	for c in effects_parent_node.get_children():
		effect_backbuffers.append(c)
		if c.get_child(0):
			var rect = c.get_child(0)
			effect_rects.append(rect)

func generate_session_playlist():

	var minigames_shuffled: Array[Globals.MinigameIdentifier]

	# 8-PLAYER MOD: minigames that cannot seat more than four players are held
	# back once the lobby outgrows them. The host builds this list and ships it
	# to everyone over update_playlist_state_rpc, so clients need no such check.
	# Demoted debug spectators sit in connected_players but never play, so the
	# count excludes them - otherwise a 9th connection (8 players plus a demoted
	# spectator, or a mixed lobby's 4 players plus demoted joiners) filtered
	# every minigame out and dead-ended the session on an empty playlist.
	var lobby_size: int = 1
	if NetworkManager.active_backend:
		var mod_seated: int = 0
		for player_info in NetworkManager.active_backend.connected_players.values():
			if not player_info.get("debug", false):
				mod_seated += 1
		lobby_size = max(mod_seated, 1)

	if GameManager.custom_game:


		if Globals.session_playlist.is_empty():
			for mlr in Globals.default_playlist:
				Globals.session_playlist.append(mlr)

		if GameManager.arcade_game:

			var arcade_games_count: int = 10

			# 8-PLAYER MOD: Arcade (added in v1.5.0) draws its ten straight from
			# CustomMinigamesWhitelist, so it is the one playlist path that never
			# consulted the caps. Filter it exactly as the other two branches are
			# filtered, or an 8-player Arcade session can roll ManufactureGun or
			# BurnRecycle, both capped at 4. At 1-4 players nothing is removed -
			# every cap is 4 - so Arcade stays vanilla there, per rule 3.
			var all_allowed_minigame_identifiers: Array[Globals.MinigameIdentifier] = []
			for mod_identifier in Globals.CustomMinigamesWhitelist:
				if not Globals.supports_player_count(mod_identifier, lobby_size):
					continue
				all_allowed_minigame_identifiers.append(mod_identifier)
			all_allowed_minigame_identifiers.shuffle()

			# Vanilla indexes [0, arcade_games_count) against a list it assumes is
			# at least 10 long. Once the list is filtered that is no longer
			# guaranteed, and an out-of-bounds read returns null SILENTLY in the
			# release template (pitfall 23) - which would append nulls to the
			# playlist rather than erroring. Clamp instead. mini() not min(),
			# so the result stays a typed int.
			arcade_games_count = mini(arcade_games_count,
				all_allowed_minigame_identifiers.size())

			for i in arcade_games_count:
				var identifier = all_allowed_minigame_identifiers[i]
				minigames_shuffled.append(identifier)
				session_minigame_rounds[identifier] = randi_range(1, 2)

		else:

			for game in Globals.session_playlist:
				if not Globals.CustomMinigamesWhitelist.has(game.game_identifier):
					continue
				if not Globals.supports_player_count(game.game_identifier, lobby_size):
					continue
				minigames_shuffled.append(game.game_identifier)
				session_minigame_rounds[game.game_identifier] = max(game.total_rounds, 1)

			if GameManager.custom_shuffled:
				minigames_shuffled.shuffle()

	else:

		Globals.session_playlist.clear()
		for mlr in Globals.default_playlist:
			Globals.session_playlist.append(mlr)

		for game in Globals.session_playlist:
			if not Globals.supports_player_count(game.game_identifier, lobby_size):
				continue
			minigames_shuffled.append(game.game_identifier)
			session_minigame_rounds[game.game_identifier] = max(game.total_rounds, 1)

	# A hand-picked custom playlist can filter down to nothing at 5+ players.
	# Fall back to whatever the default rotation still supports so the session
	# starts instead of dead-ending on an empty list.
	if minigames_shuffled.is_empty():
		for mlr in Globals.default_playlist:
			if not Globals.supports_player_count(mlr.game_identifier, lobby_size):
				continue
			minigames_shuffled.append(mlr.game_identifier)
			session_minigame_rounds[mlr.game_identifier] = max(mlr.total_rounds, 1)

	# 8-PLAYER MOD: the user-sanctioned removal of the wheat-field cutscene. It
	# used to be a static deletion from Globals.default_playlist; vanilla-compat
	# moved it here so it can be conditional. A lobby containing an unmodded peer
	# must play the exact vanilla rotation, cutscene and all, so the entry is
	# back in default_playlist and is dropped only when every peer is modded -
	# which is every session the user actually plays.
	#
	# Placed after all three branches (default, custom and the empty-list
	# fallback) have filled minigames_shuffled, so it closes every path the old
	# static deletion closed, including the fallback that skips the
	# CustomMinigamesWhitelist. Host-authoritative like the rest of this
	# function: clients never generate a playlist, they receive the finished
	# identifier array over update_playlist_state_rpc.
	if NetworkManager.mod_all_peers_modded():
		minigames_shuffled.erase(Globals.MinigameIdentifier.CutsceneTest)
		session_minigame_rounds.erase(Globals.MinigameIdentifier.CutsceneTest)

	# 8-PLAYER MOD (testing): `-minigame <Identifier>` pins the session to a
	# single minigame, e.g. `-minigame GreenPea`, so a specific one can be
	# playtested without reshuffling until it comes up. Host-authoritative like
	# the rest of this function. Inert unless the argument is passed.
	var mod_args := Array(OS.get_cmdline_args())
	var mod_i := mod_args.find("-minigame")
	if mod_i >= 0 and mod_i + 1 < mod_args.size():
		var wanted := str(mod_args[mod_i + 1]).to_lower()
		var keys := Globals.MinigameIdentifier.keys()
		var pinned: Array[Globals.MinigameIdentifier] = []
		for game in minigames_shuffled:
			if str(keys[game]).to_lower() == wanted:
				pinned.append(game)
		if pinned.is_empty():
			print("[MINIGAME] '", wanted, "' not in the playlist for this lobby size")
		else:
			minigames_shuffled = pinned
			print("[MINIGAME] pinned session to ", keys[pinned[0]])

	if not debug_no_shuffle:
		minigames_shuffled.shuffle()

	total_games_count = minigames_shuffled.size()

	for game in minigames_shuffled:
		print("Generating session playlist with: ", Globals.MinigameIdentifier.keys()[game])

	session_minigame_list = minigames_shuffled


func check_player_game_state():

	if not playlist_state_received:
		return
	if not score_state_received:
		return

	if not game_ready_sent:
		game_ready_sent = true
		player_ready_rpc.rpc_id(1, multiplayer.get_unique_id(), GameManager.reconnect)


@rpc("any_peer", "call_remote", "reliable")
func request_playlist_state_rpc(_requestor_network_id: int):

	update_playlist_state_rpc.rpc_id(
		_requestor_network_id, 
		session_minigame_list, 
		session_next_minigame_index, 
		session_next_minigame_identifier
	)


@rpc("authority", "call_remote", "reliable")
func update_playlist_state_rpc(_minigame_list, next_minigame_index, next_minigame_identifier):

	session_minigame_list = _minigame_list

	session_next_minigame_index = next_minigame_index
	session_next_minigame_identifier = next_minigame_identifier
	intermission_manager.next_minigame_identifier = next_minigame_identifier

	playlist_state_received = true
	check_player_game_state()


@rpc("any_peer", "call_remote", "reliable")
func request_score_state_rpc(_requestor_network_id: int):

	var send_to_all: bool = false

	if not total_score_by_network_id.has(_requestor_network_id):
		total_score_by_network_id[_requestor_network_id] = 0
		send_to_all = true

	if not game_score_by_network_id.has(_requestor_network_id):
		game_score_by_network_id[_requestor_network_id] = 0
		send_to_all = true

	if send_to_all:
		update_score_state_rpc.rpc(total_score_by_network_id, game_score_by_network_id)
	else:
		update_score_state_rpc.rpc_id(_requestor_network_id, total_score_by_network_id, game_score_by_network_id)


@rpc("authority", "call_remote", "reliable")
func update_score_state_rpc(_total_score_by_network_id, _game_score_by_network_id):

	total_score_by_network_id = _total_score_by_network_id
	game_score_by_network_id = _game_score_by_network_id

	score_state_received = true
	check_player_game_state()


@rpc("any_peer", "call_remote", "reliable")
func player_ready_rpc(_network_id: int, _reconnect: bool):

	var is_mid_session: bool = player_mid_join_queue.has(_network_id)
	var is_debug: bool = false


	if NetworkManager.active_backend.connected_players.has(_network_id):
		is_debug = NetworkManager.active_backend.connected_players[_network_id].get("debug", false)

	if is_debug:

		for player_network_id in PlayerManager.player_presences.keys():

			PlayerManager.propagate_player_rpc.rpc_id(
				_network_id, 
				player_network_id, 
				PlayerManager.player_presences[player_network_id].get_path()
			)

		debug_player_handler.set_player_rpc.rpc(_network_id)

		players_game_ready.append(_network_id)
		player_game_ready.emit(_network_id)

		if players_game_ready.size() == NetworkManager.active_backend.connected_players.size():
			state_machine.transition_to_rpc.rpc(&"SessionIntro")


		return


	var presence = PlayerManager.add_player(_network_id)

	PlayerManager.propagate_player_rpc.rpc(_network_id, presence.get_path())

	PlayerManager.propagate_player_rpc.rpc_id(_network_id, 1, PlayerManager.player_presences[1].get_path())


	intermission_manager.screen_briefing.set_ready_button_disabled(
		PlayerManager.player_presences.size() < 2
	)


	if is_mid_session or _reconnect:


		for player_network_id in PlayerManager.player_presences.keys():
			PlayerManager.propagate_player_rpc.rpc_id(
				_network_id, 
				player_network_id, 
				PlayerManager.player_presences[player_network_id].get_path()
			)

		player_reconnected.emit(_network_id)

	players_game_ready.append(_network_id)
	player_game_ready.emit(_network_id)

	if is_mid_session:

		state_machine.transition_to_rpc.rpc_id(_network_id, &"MinigameBrief", {
			"reconnect": true, 
			"games_played": games_played_count, 
			"total_games": total_games_count, 
			"music_index": MusicManager.current_active_track_index
		})
		intermission_manager.cutscene_intro.reset_nametags_rpc.rpc_id(_network_id, PlayerManager.player_presences.keys())
		intermission_manager.screen_briefing.update_briefing_screen()
		intermission_manager.screen_briefing.update_player_data_rpc.rpc(total_score_by_network_id)
		reset_managed_instances_rpc.rpc()

		return

	if players_game_ready.size() == NetworkManager.active_backend.connected_players.size():
		state_machine.transition_to_rpc.rpc(&"SessionIntro")

func load_minigame(minigame_identifier: Globals.MinigameIdentifier, _is_round: bool, _total_rounds: int = -1, ):

	Globals.current_minigame_identifier = minigame_identifier

	if multiplayer.is_server():

		if _total_rounds >= 0:
			session_current_minigame_round = 1
			session_current_minigame_max_rounds = _total_rounds

		# 8P MOD: every path that starts a minigame funnels through here - the
		# first load of a session, a replay, and the load of the next minigame -
		# so this is the one place that sees the round count actually in force.
		# The two resolution sites upstream only run *after* a minigame finishes,
		# which a minigame nobody plays never does.
		if Array(OS.get_cmdline_args()).has("-localtest"):
			print("[ROUNDS8] load minigame=",
				Globals.MinigameIdentifier.keys()[minigame_identifier],
				" players=", PlayerManager.player_presences.size(),
				" custom=", GameManager.custom_game,
				" passed=", _total_rounds,
				" max_rounds=", session_current_minigame_max_rounds,
				" round=", session_current_minigame_round)

		DecalManager.clear_rpc.rpc()
		PropManager.clear_rpc.rpc()

	if minigame != null:

		minigame.minigame_loaded.disconnect(_on_minigame_loaded)
		minigame.minigame_ready.disconnect(_on_minigame_ready)

		minigame.cleanup_rpc.rpc()
		await get_tree().create_timer(1.0).timeout

	var minigame_scene: PackedScene = load(Globals.MinigamePaths[minigame_identifier])
	var minigame_instance = minigame_scene.instantiate()
	minigame = minigame_instance

	minigame.host_loaded.connect(_on_host_minigame_loaded)
	minigame.minigame_loaded.connect(_on_minigame_loaded)
	minigame.minigame_ready.connect(_on_minigame_ready)

	if multiplayer.is_server():
		minigame.player_scored.connect(_on_minigame_player_scored)
		minigame.player_scores_finalized.connect(_on_minigame_player_score_finalized)


	if NetworkManager.active_backend.self_data.get("debug", false):
		minigame.debug_player_specifics_initialized.connect(
			_on_debug_specifics_initialized, CONNECT_ONE_SHOT
		)
		minigame.before_player_marker_show.connect( func():
			debug_player_handler.update_ui_visibility()
		)

	GameManager.minigame_loaded.emit(minigame_identifier)
	GameManager.current_minigame_identifier = minigame_identifier
	minigame_parent.add_child(minigame_instance, true)

func update_scores(more_rounds: bool):

	if is_current_game_cutscene():
		for key in game_score_by_network_id.keys():
			game_score_by_network_id[key] = 0
		for key in round_score_by_network_id.keys():
			round_score_by_network_id[key] = 0

	for k in game_score_by_network_id.keys():
		game_score_by_network_id[k] += round_score_by_network_id[k]

	if not more_rounds:
		for k in game_score_by_network_id.keys():
			total_score_by_network_id[k] += game_score_by_network_id[k]

	receive_scores_rpc.rpc(
		total_score_by_network_id, 
		game_score_by_network_id
	)

	if more_rounds:
		for k in game_score_by_network_id.keys():
			round_score_by_network_id[k] = 0

func clear_game_scores():
	for key in game_score_by_network_id.keys():
		game_score_by_network_id[key] = 0



@rpc("authority", "call_local", "reliable")
func clear_minigame_rpc(was_cutscene_minigame: bool):

	MusicManager.filter_controller.begin_shift(MusicManager.filter_controller.effect_low_pass.cutoff_hz, 300, 0)

	if multiplayer.is_server():

		DecalManager.clear_rpc.rpc()
		PropManager.clear_rpc.rpc()

		if was_cutscene_minigame:
			MusicManager.start_playing_music_host(true, 3.0, false, 3.0)

	if minigame != null:

		minigame.minigame_loaded.disconnect(_on_minigame_loaded)
		minigame.minigame_ready.disconnect(_on_minigame_ready)
		minigame.cleanup_rpc.rpc()

	if was_cutscene_minigame:

		intermission_manager.set_intermission_viewport_screen(true)
		intermission_manager.picker.start_minigame_pick()

	else:
		if multiplayer.is_server():
			intermission_manager.screen_score.check_to_show_score()

@rpc("authority", "call_local", "reliable")
func clear_game_scores_rpc():

	for key in game_score_by_network_id.keys():
		game_score_by_network_id[key] = 0
		round_score_by_network_id[key] = 0

@rpc("authority", "call_local", "reliable")
func receive_scores_rpc(_total_scores: Dictionary, _game_scores: Dictionary):

	total_score_by_network_id = _total_scores
	game_score_by_network_id = _game_scores

@rpc("any_peer", "call_remote", "reliable")
func _host_minigame_loaded_rpc(minigame_identifer: Globals.MinigameIdentifier):

	load_minigame(minigame_identifer, false)

@rpc("any_peer", "call_local", "reliable")
func _client_minigame_loaded_rpc(network_id: int):

	if multiplayer.is_server():

		minigame_players_loaded.append(network_id)
		minigame_players_loaded.sort()

		if minigame_players_loaded == network_players_loaded:

			minigame.all_players_loaded()

@rpc("any_peer", "call_local", "reliable")
func hide_score_screen_rpc():

	intermission_manager.screen_score.hide_score_screen()

@rpc("any_peer", "call_local", "reliable")
func reset_managed_instances_rpc():

	PropManager.reset()
	EffectManager.reset()
	DecalManager.reset()



func _on_debug_specifics_initialized(_minigame_transform: Transform3D):

	debug_player_handler.pivot.global_transform = _minigame_transform
	debug_player_handler.debug_player_camera.global_transform = _minigame_transform

func _on_host_disconnected():

	if is_viewing_final_credits:
		return

	if multiplayer:
		NetworkManager.cancel(multiplayer.get_unique_id())

	MusicManager.stop_playing_music(3.0)

	if not GameManager.is_using_controller():
		CursorManager.set_locked(false)
		CursorManager.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if get_viewport():
			get_viewport().gui_release_focus()

	GameManager.main_menu_dialog_message = tr("LOC_ROOM_HOST_LEFT")

	if not is_inside_tree():
		return

	if OS.has_feature("editor") and Globals.debug:
		get_tree().change_scene_to_file("res://scenes/debug_lobby/debug_lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_peer_disconnected(_network_id: int):

	if is_viewing_final_credits:
		return

	NetworkManager.remove_player_rpc.rpc(_network_id)
	PlayerManager.remove_player_rpc.rpc(_network_id)

	if player_join_queue.has(_network_id):
		player_join_queue.erase(_network_id)

	if player_reconnected_queue.has(_network_id):
		player_reconnected_queue.erase(_network_id)

	if multiplayer.is_server():

		disconnected_scores_by_id[_network_id] = total_score_by_network_id.get(_network_id, 0)

		total_score_by_network_id.erase(_network_id)
		round_score_by_network_id.erase(_network_id)
		game_score_by_network_id.erase(_network_id)

		player_removal_queue.append(_network_id)

		intermission_manager.screen_briefing.set_ready_button_disabled(
			PlayerManager.player_presences.size() < 2
		)
		intermission_manager.screen_briefing.update_player_data_rpc.rpc(total_score_by_network_id)

	# 8P MOD: a peer that drops while a minigame is LOADING must not leave the
	# load gate stuck. Minigame.player_loaded() calls all_players_loaded() only
	# when players_loaded.size() == player_presences.size(), and only when a
	# player_loaded arrives - so once the last live peer has reported in and a
	# dead peer's presence is then removed, nothing re-evaluates the gate and
	# initialize() never runs: MINIGAME_SFX stays at the 0.0 the previous
	# minigame set (no gunshot in Duck Hunt), and the Game state machine never
	# enters MinigamePlaying, so minigame_finished has no listener and every
	# peer black-screens at the minigame's end. Vanilla at any roster size,
	# likelier with more peers (issues #10, #12; session-log 2026-08-15).
	# Prune the dead peer from the loaded list and re-run the gate.
	if multiplayer.is_server() and is_instance_valid(minigame) and not minigame.is_all_player_loaded:
		minigame.players_loaded.erase(_network_id)
		if PlayerManager.player_presences.size() > 0 \
				and minigame.players_loaded.size() >= PlayerManager.player_presences.size():
			minigame.all_players_loaded()

	if minigame:
		minigame.player_disconnected(_network_id)

func _on_minigame_pick_finished(minigame_index: int):
	if debug_no_shuffle:
		minigame_index = 0

	session_minigame_index = minigame_index

	var current_minigame_identifier = session_minigame_list[session_minigame_index]
	var default_total_rounds: int = session_minigame_rounds[session_minigame_list[session_minigame_index]]
	var total_rounds: int = default_total_rounds
	var player_count: int = PlayerManager.player_presences.size()

	# 8-PLAYER MOD: same relaxation as minigame_playing_state.gd, which is the
	# site that actually gates the replay - both must agree or the displayed
	# round total and the real one diverge. Custom games included, but only
	# above four players; a 1-4 custom lobby keeps its configured count.
	if not GameManager.custom_game or player_count > 4:
		if Globals.MinigameRoundsByPlayerCount.has(current_minigame_identifier):
			total_rounds = Globals.MinigameRoundsByPlayerCount[current_minigame_identifier].get(
				player_count, default_total_rounds
			)

	load_minigame(
		session_next_minigame_identifier, 
		false, 
		max(total_rounds, 1)
	)

func _on_minigame_loaded(_network_id: int):

	capture_input = false

	if _network_id == 1:
		minigame_players_loaded.append(1)
		_host_minigame_loaded_rpc.rpc(GameManager.current_minigame_identifier)
	else:
		_client_minigame_loaded_rpc.rpc(_network_id)

func _on_minigame_ready(_network_id: int):

	if multiplayer.is_server():
		state_machine.transition_to_rpc.rpc(&"MinigameStart")
		minigame.initialize(
			session_current_minigame_round, 
			session_current_minigame_max_rounds, 
			total_score_by_network_id
		)

func _on_host_minigame_loaded():
	_host_minigame_loaded_rpc.rpc(GameManager.current_minigame_identifier)

func _on_player_added_to_join_queue(network_id: int):

	player_join_queue.append(network_id)

func _on_player_removed_from_join_queue(network_id: int):

	player_join_queue.erase(network_id)

func _on_host_overlay_minigame_selected(minigame_identifier: Globals.MinigameIdentifier):

	host_overlay.set_is_visible(false)
	minigame_players_loaded.clear()

	load_minigame(minigame_identifier, false, 1)

func _on_minigame_player_scored(_network_id: int, _score: int):

	round_score_by_network_id[_network_id] += (_score * score_multiplier)

func _on_minigame_player_score_finalized(player_scores):

	for network_id in player_scores.keys():
		if round_score_by_network_id.has(network_id):
			round_score_by_network_id[network_id] += player_scores[network_id] * score_multiplier

func _on_score_screen_finished():

	if not multiplayer.is_server():
		return

	var is_cutscene: bool = false
	if session_minigame_list.size() > 0:
		var next_minigame_identifier: Globals.MinigameIdentifier = session_minigame_list[0]
		if Globals.CutsceneMinigameIdentifiers.has(next_minigame_identifier):
			is_cutscene = true

	if is_cutscene:
		state_machine.transition_to_rpc.rpc(&"MinigameCutsceneTransition")
	else:
		hide_score_screen_rpc.rpc()

func _on_score_screen_hidden():

	if not multiplayer.is_server():
		return

	state_machine.transition_to_rpc.rpc(&"MinigamePick")

func _on_player_reconnected(_network_id):

	if NetworkManager.active_backend.connected_players.has(_network_id):
		var previous_id: int = NetworkManager.active_backend.connected_players[_network_id].get("reconnect_id", 0)
		if previous_id > 0:
			if disconnected_scores_by_id.has(previous_id):
				var previous_score = disconnected_scores_by_id.get(previous_id, 0)
				disconnected_scores_by_id.erase(previous_id)
				total_score_by_network_id[_network_id] = previous_score

	intermission_manager.screen_briefing.update_player_data_rpc.rpc(total_score_by_network_id)
	reset_managed_instances_rpc.rpc()

func _on_game_session_ended():
	is_game_session_ended = true

	for joining_player_network_id in player_join_queue:

		NetworkManager.active_backend.refuse_client_rpc.rpc_id(
			joining_player_network_id, joining_player_network_id, NetworkManager.RefuseReason.SessionEnded
		)

	player_join_queue.clear()

func _viewport_size_changed():

	var vp_size = get_viewport().get_visible_rect().size

	for bb in effect_backbuffers:
		bb.rect.expand(vp_size)

	for cr in effect_rects:
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cr.set_deferred("size", vp_size)
