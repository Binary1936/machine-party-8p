extends Control

@export var game_scene: PackedScene

@export_category("Screen Handlers")
@export var lobby_handler: MultiplayerMenuLobbyHandler
@export var playlist_handler: PlaylistHandler
@export var reconnect_handler: ReconnectHandler
@export var sc_ambience: SpeakerController
@export var screen_handlers: Array[Node]

@export var loading_screen: Control
@export var loading_screen_label_container: Control
@export var screen_roots: Array[Control]

@export var main_buttons_containers: Array[Control]

@export var load_timeout_timer: Timer

# 8-PLAYER MOD: this was hardcoded to four seats. player_joined_lobby_rpc walks
# it looking for the first free one, so players 5-8 joined the lobby and were
# never assigned a slot - and lobby_handler indexes its preview characters by
# seat, so an unassigned seat is also an out-of-bounds read. Derived from
# MAX_PLAYERS now, and filled in _ready() so NetworkManager is definitely up.
var player_order_by_seat: Dictionary[int, int] = {}

func make_seat_map(host_network_id: int = -1) -> Dictionary[int, int]:

	var seats: Dictionary[int, int] = {}
	for i in NetworkManager.MAX_PLAYERS:
		seats[i] = host_network_id if i == 0 else -1
	return seats

var loading: bool = true

# 8-PLAYER MOD: text roster of who is in the lobby. Preloaded rather than
# referenced by class_name - see the note in that file.
const ModPlayerNameList = preload("res://modules/multiplayer_lobby/mod_player_name_list.gd")
var mod_name_list: Node

func _ready() -> void :

	player_order_by_seat = make_seat_map()

	# Parented to the handler's root so it shows and hides with the lobby UI
	# rather than floating over the loading and playlist screens.
	mod_name_list = ModPlayerNameList.attach(
		lobby_handler.root if lobby_handler else null, NetworkManager.MAX_PLAYERS)

	PropManager.reset()
	EffectManager.reset()
	DecalManager.reset()
	SoundManager.set_active(false)

	GameManager.local_game = false
	GameManager.in_lobby = true
	GameManager.custom_shuffled = Globals.settings.get("custom_shuffled", false)
	Globals.all_minigames_finished = false
	GameManager.game_in_progress = false

	MultiplayerInput.reload_defaults()
	DebugTools.register_actions()

	PauseMenu.show_quit_to_menu = false
	PauseMenu.set_can_activate(true)
	PauseMenu.unpaused.connect(_on_unpaused)

	GameManager.input_device_changed.connect(_on_input_device_changed)

	hide_scene_roots()
	loading_screen.visible = true

	for handler in screen_handlers:
		handler.set_active(false)

	setup_network_signals()
	setup_screen_signals()

	set_ambience(true)

	lobby_handler.playlist_button.visible = false

	load_timeout_timer.timeout.connect(_on_load_timeout)
	load_timeout_timer.start()

	if GameManager.host_game:
		start_host()
	else:
		start_client()

	GlobalOverlay.fade_overlay(Color(0.0, 0.0, 0.0, 0.0), 0.5)
	await GlobalOverlay.fade_finished

func _process(_delta: float) -> void :

	if Input.is_action_just_pressed("lobby_toggle_debug_player"):
		if multiplayer and not multiplayer.is_server():
			request_player_debug_rpc.rpc_id(1, multiplayer.get_unique_id())

func set_ambience(active: bool):
	if active:
		sc_ambience.speaker.volume_linear = 0
		sc_ambience.speaker.play()
		sc_ambience.fade_duration = 0.5
		sc_ambience.fade_in()
	else:
		sc_ambience.fade_duration = 0.5
		sc_ambience.fade_out()

func set_skip_intro_text(skipping_intro: bool):
	if skipping_intro:
		lobby_handler.skip_intro_button.text = "SKIP INTRO [X]"
	else:
		lobby_handler.skip_intro_button.text = "SKIP INTRO [ ]"

func setup_screen_signals():

	lobby_handler.playlist_pressed.connect( func():
		lobby_handler.set_active(false)
		playlist_handler.set_active(true)
	)

	playlist_handler.back_pressed.connect( func(_previous_handler):
		playlist_handler.set_active(false)
		lobby_handler.set_active(true)
		if GameManager.is_using_controller():
			get_viewport().gui_release_focus()
			lobby_handler.playlist_button.grab_focus()
	)

	lobby_handler.invite_pressed.connect( func():

		if NetworkManager.active_backend and NetworkManager.active_backend.lobby_id > 0:

			Steam.activateGameOverlayInviteDialog(
				NetworkManager.active_backend.lobby_id
			)
	)

	lobby_handler.back_pressed.connect( func():

		for container in main_buttons_containers:
			container.visible = false

		if multiplayer:

			if multiplayer.is_server():
				host_left_rpc.rpc()

			NetworkManager.leave_lobby()

		GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
		MusicManager.filter_controller.begin_shift(MusicManager.filter_controller.effect_low_pass.cutoff_hz, 20000, 8)
		set_ambience(false)
		await GlobalOverlay.fade_finished

		await get_tree().create_timer(1, false).timeout

		NetworkManager.cancel(multiplayer.get_unique_id())

		if not is_inside_tree():
			return
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	)

	lobby_handler.skip_intro_toggled.connect( func():
		Globals.skipping_intro_cutscene = !Globals.skipping_intro_cutscene
		set_skip_intro_text(Globals.skipping_intro_cutscene)
	)

	lobby_handler.start_pressed.connect( func():
		if multiplayer.is_server():
			start_game_rpc.rpc()
	)



	reconnect_handler.cancel_pressed.connect( func():

		NetworkManager.leave_lobby()
		NetworkManager.cancel(multiplayer.get_unique_id())

		GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
		set_ambience(false)

		await GlobalOverlay.fade_finished
		GameManager.main_menu_dialog_message = ""
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

	)

func start_host():

	hide_scene_roots()

	NetworkManager.on_server_created.connect( func():
		player_order_by_seat = make_seat_map(1)
		player_list_updated_rpc.rpc(player_order_by_seat)
		fade_loading_screen()
	)
	NetworkManager.active_backend_type = NetworkManager.NetworkBackendType.Steam
	NetworkManager.start_host("steam host")

func start_client():

	if GameManager.join_lobby_id < 0:
		GameManager.main_menu_message = tr("LOC_ROOM_UNKNOWN")
		GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
		set_ambience(false)
		await GlobalOverlay.fade_finished
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

	hide_scene_roots()
	loading_screen.visible = true
	NetworkManager.active_backend_type = NetworkManager.NetworkBackendType.Steam
	NetworkManager.start_client("client", GameManager.join_lobby_id)

func hide_scene_roots():

	for sc in screen_roots:
		sc.visible = false

func setup_network_signals():

	NetworkManager.set_game_scene(game_scene)

	NetworkManager.on_server_created.connect(_on_server_created)
	NetworkManager.on_client_created.connect(_on_client_created)

	NetworkManager.on_peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.on_host_disconnected.connect(_on_host_disconnected)

	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.join_allowed.connect(_on_join_allowed)
	NetworkManager.join_refused.connect(_on_join_refused)

func update_player_list():

	if not NetworkManager.active_backend:
		return

	lobby_handler.update_player_list(player_order_by_seat.values())

	if mod_name_list:
		mod_name_list.refresh(
			player_order_by_seat.values(),
			NetworkManager.active_backend.connected_players,
			multiplayer.get_unique_id() if multiplayer else -1)

func fade_loading_screen():

	load_timeout_timer.stop()
	loading = false

	var t = create_tween()
	t.tween_property(loading_screen_label_container, "modulate:a", 0.0, 1.0)
	t.tween_property(loading_screen, "modulate:a", 0.0, 1.0)
	t.tween_callback( func():
		loading_screen.visible = false
		loading_screen.modulate.a = 1.0
		if GameManager.is_using_controller():
			get_viewport().gui_release_focus()
			lobby_handler.back_button.grab_focus()
		else:
			CursorManager.set_cursor_image("point")
			CursorManager.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)
	)



@rpc("call_local", "reliable")
func start_game_rpc():

	set_ambience(false)

	GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
	MusicManager.fade_out_menu_music(1)
	await GlobalOverlay.fade_finished

	if multiplayer.is_server():
		get_tree().change_scene_to_packed(game_scene)

@rpc("any_peer", "call_remote", "reliable")
func host_left_rpc():

	GameManager.main_menu_dialog_message = tr("LOC_ROOM_DISBANDED")

	GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
	set_ambience(false)
	await GlobalOverlay.fade_finished

	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

@rpc("any_peer", "call_remote", "reliable")
func request_player_debug_rpc(_network_id: int):

	if multiplayer.is_server():

		for player_info in NetworkManager.active_backend.connected_players.values():
			if player_info["peer_id"] == _network_id:
				var debug_value = not player_info.get("debug", false)
				set_player_debug_rpc.rpc(_network_id, debug_value)

@rpc("any_peer", "call_local", "reliable")
func set_player_debug_rpc(_network_id: int, _debug: bool):

	if multiplayer.get_unique_id() == _network_id:
		if _debug:
			lobby_handler.send_lobby_message("SPECTATOR MODE ENABLED.")
		else:
			lobby_handler.send_lobby_message("SPECTATOR MODE DISABLED.")

		if multiplayer.get_unique_id() == _network_id:
			NetworkManager.active_backend.self_data["debug"] = _debug

	for player_info in NetworkManager.active_backend.connected_players.values():
		if player_info["peer_id"] == _network_id:
			NetworkManager.active_backend.connected_players[_network_id]["debug"] = _debug

@rpc("any_peer", "call_remote", "reliable")
func player_joined_lobby_rpc(_network_id: int):


	for key in player_order_by_seat.keys():
		if player_order_by_seat[key] < 0:
			player_order_by_seat[key] = _network_id
			break

	player_list_updated_rpc.rpc(player_order_by_seat)

@rpc("any_peer", "call_local", "reliable")
func player_list_updated_rpc(_player_order: Dictionary):

	player_order_by_seat = _player_order
	update_player_list()

	if not lobby_handler.active:
		lobby_handler.set_active(true)

	if not multiplayer.is_server():
		fade_loading_screen()



func _on_server_created():

	hide_scene_roots()
	update_player_list()
	lobby_handler.set_active(true)

	if GameManager.custom_game:

		Globals.load_playlist()
		lobby_handler.playlist_button.visible = true

		lobby_handler.skip_intro_button.visible = false
		Globals.skipping_intro_cutscene = true

		if GameManager.arcade_game:
			lobby_handler.playlist_button.visible = false

	else:

		Globals.skipping_intro_cutscene = false

		Globals.session_playlist.clear()
		for mlr in Globals.default_playlist:
			Globals.session_playlist.append(mlr)

	set_skip_intro_text(Globals.skipping_intro_cutscene)

func _on_client_created():

	fade_loading_screen()
	update_player_list()
	lobby_handler.set_active(true)

func _on_lobby_joined(_lobby_id, _permissions, _locked, _response):

	if _response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:

		hide_scene_roots()
		lobby_handler.set_active(true)

	else:
		var fail_reason: String = "None"
		match _response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				fail_reason = tr("LOC_ROOM_DISBANDED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
				fail_reason = tr("LOC_ROOM_NO_PERMS")
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL:
				fail_reason = tr("LOC_ROOM_FULL")
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR:
				fail_reason = tr("LOC_ROOM_UNKNOWN")
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				fail_reason = tr("LOC_ROOM_BANNED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
				fail_reason = tr("LOC_ROOM_LIMITED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED:
				fail_reason = tr("LOC_ROOM_DISABLED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN:
				fail_reason = tr("LOC_ROOM_LOCKED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
				fail_reason = tr("LOC_ROOM_BLOCKED")
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
				fail_reason = tr("LOC_ROOM_BLOCKED_SELF")

		GameManager.main_menu_dialog_message = fail_reason
		GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
		set_ambience(false)
		await GlobalOverlay.fade_finished

		if not is_inside_tree():
			return
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_join_allowed(reconnect: bool, game_in_progress: bool, _debug_only: bool):
	update_player_list()

	if not game_in_progress:

		lobby_handler.set_active(true)
		player_joined_lobby_rpc.rpc_id(1, multiplayer.get_unique_id())

	else:
		if reconnect:

			lobby_handler.set_active(false)
			fade_loading_screen()
			hide_scene_roots()

			reconnect_handler.set_active(true)

			NetworkManager.add_player_to_join_queue_rpc.rpc_id(
				1, multiplayer.get_unique_id()
			)

			if GameManager.is_using_controller():
				reconnect_handler.cancel_button.grab_focus()

func _on_join_refused(network_id: int, refuse_reason):

	NetworkManager.leave_lobby()
	NetworkManager.cancel(network_id)

	GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
	await GlobalOverlay.fade_finished

	var message = tr("LOC_ROOM_UNKNOWN")
	match refuse_reason:
		NetworkManager.RefuseReason.None:
			message = tr("LOC_ROOM_UNKNOWN")
		NetworkManager.RefuseReason.VersionMismatch:
			message = tr("LOC_TAG_VERSION_MISMATCH")
		NetworkManager.RefuseReason.SessionEnded:
			message = tr("LOC_ROOM_DISBANDED")
		NetworkManager.RefuseReason.HostLeft:
			message = tr("LOC_ROOM_DISBANDED")

	GameManager.main_menu_dialog_message = message
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_host_disconnected():

	if multiplayer:

		var network_id: int = -1
		if multiplayer.multiplayer_peer:
			network_id = multiplayer.get_unique_id()

		NetworkManager.leave_lobby()
		NetworkManager.cancel(network_id)

	set_ambience(false)

	GameManager.main_menu_dialog_message = tr("LOC_ROOM_DISBANDED")
	GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
	await GlobalOverlay.fade_finished

	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_peer_disconnected(_network_id: int):
	NetworkManager.remove_player(_network_id)

	if multiplayer and not multiplayer.is_server():
		return

	for key in player_order_by_seat.keys():
		if player_order_by_seat[key] == _network_id:
			player_order_by_seat[key] = -1
			break

	player_list_updated_rpc.rpc(player_order_by_seat)

func _on_load_timeout():

	if not loading:
		return

	if multiplayer:

		NetworkManager.leave_lobby()
		NetworkManager.cancel(multiplayer.get_unique_id())

	GlobalOverlay.fade_overlay(Color.BLACK, 0.5)
	set_ambience(false)
	await GlobalOverlay.fade_finished

	GameManager.main_menu_dialog_message = tr("LOC_TAG_CONNECTION_TIMEOUT")
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_unpaused():

	if playlist_handler.active:
		return

	get_viewport().gui_release_focus()
	if GameManager.is_using_controller():

		CursorManager.set_active(false)
		CursorManager.set_locked(true)

		if reconnect_handler.active:
			reconnect_handler.cancel_button.grab_focus()
		else:
			lobby_handler.back_button.grab_focus()

func _on_input_device_changed(_input_device: GameManager.InputDevice):

	if PauseMenu.active:
		return

	if playlist_handler.active:
		return

	if GameManager.is_using_controller():

		get_viewport().gui_release_focus()
		CursorManager.set_active(false)
		CursorManager.set_locked(true)

		if reconnect_handler.active:
			reconnect_handler.cancel_button.grab_focus()
		else:
			lobby_handler.back_button.grab_focus()

	else:

		get_viewport().gui_release_focus()

		CursorManager.set_locked(false)
		CursorManager.set_active(true)
		CursorManager.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
