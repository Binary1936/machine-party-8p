extends Control

@export var game_scene: PackedScene

@export_category("Screen Handlers")
@export var debug_lobby_handler: DebugLobbyHandler
@export var lobby_handler: MultiplayerMenuLobbyHandler
@export var reconnect_handler: ReconnectHandler
@export var playlist_handler: PlaylistHandler
@export var screen_handlers: Array[Node]
@export var loading_overlay: Control

@export var lobby_message_label: Label
@export var lobby_message_animator: AnimationPlayer

var player_order_by_seat: Dictionary[int, int] = {
	0: -1, 
	1: -1, 
	2: -1, 
	3: -1
}

# 8-PLAYER MOD (test harness): with `-startgame`, the host starts the session by
# itself once the lobby has filled - so a multi-instance -localtest run reaches
# an actual minigame with no clicking. Seats, roster and start path are stock.
var mod_autostart_pending: bool = false
var mod_autostart_target: int = 0

func _ready() -> void :

	lobby_handler.skip_intro_button.visible = false

	PropManager.reset()
	EffectManager.reset()
	DecalManager.reset()

	MultiplayerInput.reload_defaults()
	DebugTools.register_actions()

	toggle_skip_intro_visuals()

	Globals.all_minigames_finished = false
	GameManager.local_game = false
	GameManager.custom_game = true
	if not GameManager.is_using_controller():
		GameManager.current_input_device = GameManager.InputDevice.Keyboard

	CursorManager.set_cursor(true, false)
	CursorManager.set_cursor_image("point")

	PauseMenu.show_quit_to_menu = false
	PauseMenu.set_can_activate(true)
	PauseMenu.unpaused.connect(_on_unpaused)

	NetworkManager.set_game_scene(game_scene)
	NetworkManager.active_backend_type = NetworkManager.NetworkBackendType.Enet

	NetworkManager.on_server_created.connect(_on_server_created)

	NetworkManager.on_peer_connected.connect(_on_peer_connected)
	NetworkManager.on_peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.on_host_disconnected.connect(_on_host_disconnected)

	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.join_allowed.connect(_on_join_allowed)
	NetworkManager.join_refused.connect(_on_join_refused)

	GameManager.input_device_changed.connect(_on_input_device_changed)

	for handler in screen_handlers:
		handler.set_active(false)

	debug_lobby_handler.host_button.pressed.connect(_on_host_button_pressed)
	debug_lobby_handler.join_button.pressed.connect(_on_join_button_pressed)

	debug_lobby_handler.steam_host_button.pressed.connect(_on_steam_host_button_pressed)
	debug_lobby_handler.steam_join_button.pressed.connect(_on_steam_join_lobby_button_pressed)


	lobby_handler.message_sent.connect(_on_subscreen_message_sent)
	lobby_handler.back_pressed.connect(_on_lobby_back_button_pressed)
	lobby_handler.invite_pressed.connect(_on_lobby_invite_button_pressed)
	lobby_handler.start_pressed.connect(_on_lobby_start_button_pressed)
	lobby_handler.playlist_pressed.connect(_on_lobby_playlist_pressed)
	lobby_handler.skip_intro_toggled.connect( func():
		Globals.skipping_intro_cutscene = !Globals.skipping_intro_cutscene
		toggle_skip_intro_visuals()
	)


	playlist_handler.back_pressed.connect(_on_playlist_back_pressed)
	playlist_handler.accept_pressed.connect(_on_playlist_accept_pressed)


	reconnect_handler.cancel_pressed.connect(_on_reconnect_cancel_pressed)

	debug_lobby_handler.button_customization.pressed.connect(_on_customization_button_pressed)

	setup_lobby_view()

	var arguments = Array(OS.get_cmdline_args())
	var m_size = DisplayServer.screen_get_usable_rect()

	# 8-PLAYER MOD (test harness): the token after -startgame is how many
	# players to wait for, so a run with fewer instances than the lobby holds
	# still starts. Defaults to the stock MAX_PLAYERS.
	mod_autostart_pending = arguments.has("-startgame")
	mod_autostart_target = NetworkManager.MAX_PLAYERS
	var mod_startgame_index := arguments.find("-startgame")
	if (mod_startgame_index >= 0 and mod_startgame_index + 1 < arguments.size()
			and str(arguments[mod_startgame_index + 1]).is_valid_int()):
		mod_autostart_target = int(arguments[mod_startgame_index + 1])

	if arguments.has("1"):
		debug_lobby_handler.name_entry.text = "P1"
		get_window().size = Vector2(m_size.size.x * 0.5, m_size.size.y * 0.5)
		get_window().position = Vector2(m_size.position.x + (m_size.size.x * 0.5), 0.0)

	elif arguments.has("2"):
		debug_lobby_handler.name_entry.text = "P2"
		get_window().size = Vector2(m_size.size.x * 0.5, m_size.size.y * 0.5)
		get_window().position = Vector2(m_size.position.x, 0.0)

	elif arguments.has("3"):
		debug_lobby_handler.name_entry.text = "P3"
		get_window().size = Vector2(m_size.size.x * 0.5, m_size.size.y * 0.5)
		get_window().position = Vector2(m_size.position.x + (m_size.size.x * 0.5), m_size.size.y * 0.5)

	elif arguments.has("4"):
		debug_lobby_handler.name_entry.text = "P4"
		get_window().size = Vector2(m_size.size.x * 0.5, m_size.size.y * 0.5)
		get_window().position = Vector2(m_size.position.x, m_size.size.y * 0.5)

	if arguments.has("host"):
		_on_host_button_pressed()

	elif arguments.has("join"):
		if arguments.has("1"):
			await get_tree().create_timer(0.2, false).timeout
			AudioServer.set_bus_mute(0, true)
		if arguments.has("2"):
			await get_tree().create_timer(0.6, false).timeout
		if arguments.has("3"):
			await get_tree().create_timer(0.8, false).timeout
			AudioServer.set_bus_mute(0, true)
		if arguments.has("4"):
			await get_tree().create_timer(1, false).timeout
			AudioServer.set_bus_mute(0, true)

		_on_join_button_pressed()

	lobby_handler.root.visible = false
	hide_screens()
	debug_lobby_handler.set_active(true)

func hide_screens():

	for screen in screen_handlers:
		screen.set_active(false)

func setup_lobby_view():
	if !OS.has_feature("editor"):
		pass

func update_player_list():

	if not NetworkManager.active_backend:
		return

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[SEATS] ", player_order_by_seat, "  connected=",
			NetworkManager.active_backend.connected_players.size())

	lobby_handler.update_player_list(player_order_by_seat.values())

	if mod_autostart_pending and multiplayer and multiplayer.is_server() \
			and (NetworkManager.active_backend.connected_players.size()
				>= mod_autostart_target):
		mod_autostart_pending = false
		print("[AUTOSTART] reached ", mod_autostart_target, " players, starting session")
		await get_tree().create_timer(3.0, false).timeout
		_on_lobby_start_button_pressed()

func show_message(_message: String):

	lobby_message_label.text = _message
	lobby_message_animator.play("RESET")
	lobby_message_animator.play("show message")



func _on_playlist_back_pressed(_handler):
	if _handler:
		_handler.set_active(true)

func _on_playlist_accept_pressed(_handler):
	screen_handlers[1].set_active(false)
	if _handler:
		_handler.set_active(true)

func _on_lobby_playlist_pressed():
	playlist_handler.set_active(true, lobby_handler)

func _on_customization_button_pressed():

	get_tree().change_scene_to_file("res://scenes/character_customization.tscn")

func _on_host_button_pressed():
	NetworkManager.start_host(debug_lobby_handler.name_entry.text)

	player_order_by_seat = {0: 1, 1: -1, 2: -1, 3: -1}
	player_list_updated_rpc.rpc(player_order_by_seat)

func _on_steam_host_button_pressed():
	NetworkManager.active_backend_type = NetworkManager.NetworkBackendType.Steam
	NetworkManager.start_host(debug_lobby_handler.name_entry.text)

func _on_join_button_pressed():
	NetworkManager.start_client(debug_lobby_handler.name_entry.text)

	update_player_list()
	hide_screens()
	loading_overlay.visible = true

func _on_steam_join_lobby_button_pressed():

	var clipboard = DisplayServer.clipboard_get()
	if clipboard.length() != 18:
		GameManager.join_lobby_id = clipboard
		show_message(tr("LOC_TAG_NO_ROOM_ID"))
	else:
		if NetworkManager.active_backend:
			NetworkManager.cancel(0)
			NetworkManager.active_backend_type = NetworkManager.NetworkBackendType.Steam

		NetworkManager.start_client(debug_lobby_handler.name_entry.text, int(clipboard))

func _on_lobbies_back_button_pressed():

	NetworkManager.cancel(multiplayer.get_unique_id())

func _on_lobby_back_button_pressed():

	hide_screens()
	lobby_handler.root.visible = false

	if NetworkManager.is_active():

		if multiplayer.is_server():

			host_left_rpc.rpc()
			await get_tree().create_timer(1.0).timeout
			NetworkManager.cancel(multiplayer.get_unique_id())

		else:

			NetworkManager.leave_lobby()
			NetworkManager.cancel(multiplayer.get_unique_id())

	debug_lobby_handler.set_active(true)

func _on_reconnect_cancel_pressed():

	hide_screens()

	if multiplayer:

		NetworkManager.leave_lobby()
		NetworkManager.cancel(multiplayer.get_unique_id())

	debug_lobby_handler.set_active(true)

func _on_lobby_invite_button_pressed():

	if NetworkManager.active_backend and NetworkManager.active_backend.lobby_id:
		Steam.activateGameOverlayInviteDialog(
			NetworkManager.active_backend.lobby_id
		)

func _on_lobby_start_button_pressed():

	if multiplayer.is_server():
		start_game.rpc()

func _on_server_created():

	update_player_list()
	debug_lobby_handler.set_active(false)
	lobby_handler.set_active(true)
	lobby_handler.root.visible = true
	if multiplayer.is_server():
		lobby_handler.skip_intro_button.visible = true

func _on_lobby_joined(_lobby_id, _permissions, _locked, _response):
	if _response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:

		hide_screens()
		loading_overlay.visible = true
		lobby_handler.root.visible = true

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

		print("Failed to join with fail reason: ", fail_reason)

func _on_peer_connected(_network_id: int):
	pass

func _on_peer_disconnected(_network_id: int):

	NetworkManager.remove_player(_network_id)

	if not multiplayer:
		return

	if not multiplayer.is_server():
		return

	for key in player_order_by_seat.keys():
		if player_order_by_seat[key] == _network_id:
			player_order_by_seat[key] = -1
			break

	player_list_updated_rpc.rpc(player_order_by_seat)

func _on_subscreen_message_sent(_message: String):
	show_message(_message)

func _on_join_allowed(reconnect: bool, game_in_progress: bool, _debug_only: bool):

	if not game_in_progress:

		lobby_handler.root.visible = true
		lobby_handler.set_active(true)
		debug_lobby_handler.set_active(false)

		player_joined_lobby_rpc.rpc_id(1, multiplayer.get_unique_id())
	else:

		if reconnect:

			hide_screens()
			reconnect_handler.set_active(true)
			loading_overlay.visible = false
			SoundManager.set_active(false)

			NetworkManager.add_player_to_join_queue_rpc.rpc_id(
				1, multiplayer.get_unique_id()
			)

			if GameManager.is_using_controller():
				reconnect_handler.cancel_button.grab_focus()

func _on_join_refused(network_id: int, _refuse_reason):
	print("_on_join_refused with reason: ", _refuse_reason)

	NetworkManager.leave_lobby()
	NetworkManager.cancel(network_id)

	loading_overlay.visible = false
	lobby_handler.set_active(false)
	debug_lobby_handler.set_active(true)

func _process(_delta: float) -> void :

	if Input.is_action_just_pressed("lobby_toggle_debug_player"):
		if multiplayer:
			request_player_debug_rpc.rpc_id(1, multiplayer.get_unique_id())

func toggle_skip_intro_visuals():

	if Globals.skipping_intro_cutscene:
		lobby_handler.skip_intro_button.text = "SKIP INTRO [X]"
	else:
		lobby_handler.skip_intro_button.text = "SKIP INTRO [ ]"



func _on_host_disconnected():

	_on_lobby_back_button_pressed()
	loading_overlay.visible = false

func _on_unpaused():

	if playlist_handler.active:
		return

	if get_viewport():
		get_viewport().gui_release_focus()

	if GameManager.is_using_controller():

		CursorManager.set_active(false)
		CursorManager.set_locked(true)

		if reconnect_handler.active:
			reconnect_handler.cancel_button.grab_focus()
		else:
			lobby_handler.back_button.grab_focus()

func _on_input_device_changed(input_device: GameManager.InputDevice):

	if PauseMenu.active:
		return

	if playlist_handler.active:
		return

	if input_device == GameManager.InputDevice.Controller:

		if get_viewport():
			get_viewport().gui_release_focus()

		if reconnect_handler.active:
			reconnect_handler.cancel_button.grab_focus()
		else:
			lobby_handler.back_button.grab_focus()

	else:

		CursorManager.set_locked(false)
		CursorManager.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if get_viewport():
			get_viewport().gui_release_focus()



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

	loading_overlay.visible = false

@rpc("any_peer", "call_remote", "reliable")
func request_player_debug_rpc(_network_id: int):

	if multiplayer.is_server():
		if NetworkManager.active_backend.connected_players.has(_network_id):
			var toggle_player_data = NetworkManager.active_backend.connected_players[_network_id]
			var debug_value = not toggle_player_data.get("debug", false)
			set_player_debug_rpc.rpc(_network_id, debug_value)

@rpc("any_peer", "call_local", "reliable")
func set_player_debug_rpc(_network_id: int, _debug: bool):

	if multiplayer.get_unique_id() == _network_id:
		if _debug:
			lobby_handler.send_lobby_message("SPECTATOR MODE ENABLED.")
		else:
			lobby_handler.send_lobby_message("SPECTATOR MODE DISABLED.")
	if NetworkManager.active_backend.connected_players.has(_network_id):
		NetworkManager.active_backend.connected_players[_network_id]["debug"] = _debug

@rpc("any_peer", "call_remote", "reliable")
func host_left_rpc():
	_on_lobby_back_button_pressed()

@rpc("call_local", "reliable")
func start_game():
	if multiplayer.is_server():
		get_tree().change_scene_to_packed(game_scene)
