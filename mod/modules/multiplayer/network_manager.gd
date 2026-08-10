extends Node

const MAX_PLAYERS: int = 8
# Stock was 4 players + 1: the extra slot is the `-trailer` free-fly observer
# camera (see debug_player_handler.gd), which joins once the real seats are
# full. Kept as MAX_PLAYERS + 1 so that observer still fits at eight.
const MAX_DEBUG_PLAYERS: int = 9

enum NetworkBackendType{
	Enet, Steam
}

enum RefuseReason{
	None, VersionMismatch, SessionEnded, HostLeft
}

var active_backend: MultiplayerBackend
var active_backend_type: NetworkBackendType = NetworkBackendType.Enet

var game_scene: PackedScene

var players: Dictionary
var players_loaded: Array
var max_player_count: int = MAX_PLAYERS

signal backend_ready()
signal on_server_created()
signal on_client_created()

signal on_peer_connected(id)
signal on_peer_disconnected(id)
signal on_host_disconnected()

signal on_connected_to_server()

signal lobby_joined(lobby, permissions, locked, response)
signal lobbies_fetched(lobbies)
signal on_client_loaded(network_id)
signal all_players_loaded()
signal join_allowed(reconnect, game_in_progress, debug_only)
signal join_refused(network_id, refuse_reason)

signal player_added_to_join_queue(network_id)
signal player_removed_from_join_queue(network_id)

func _ready() -> void :

	var args = Array(OS.get_cmdline_args())
	if args.has("-trailer"):
		max_player_count = MAX_DEBUG_PLAYERS

	# 8-PLAYER MOD: `-localtest` keeps the ENet backend in a release build so
	# several copies on one machine can play together over 127.0.0.1. Parsed
	# here rather than read off Globals because this autoload runs before
	# bootstrap.gd. The backend itself is created by start_host/start_client,
	# which is exactly what the editor path does.
	if not args.has("-localtest") and not OS.has_feature("editor"):
		active_backend_type = NetworkBackendType.Steam
		create_backend()

# 8-PLAYER MOD: true when nobody in the lobby is running unmodded v1.5.0.
# Every peer's self_data reaches the host through the join handshake and is
# rebroadcast verbatim to everyone, so active_backend.connected_players holds
# the dicts as sent - including the host's own, which both backends insert
# locally before any client connects. A modded peer stamps "mod8p" into that
# dict; a vanilla peer has no such key. So "all modded" is just "every dict has
# the key", and no dict at all (no backend yet, or an empty roster in a solo or
# lobbyless context) counts as all-modded, which keeps the current single-player
# and pre-lobby behaviour exactly as it is.
#
# Used by generate_session_playlist() in game.gd to decide whether the wheat-
# field cutscene is filtered out: a session with a vanilla peer in it has to
# play the exact vanilla rotation, cutscene included.
func mod_all_peers_modded() -> bool:

	if not active_backend:
		return true

	for peer_data in active_backend.connected_players.values():
		if not peer_data.has("mod8p"):
			return false

	return true

func is_active() -> bool:

	if not multiplayer:
		return false

	if not multiplayer.has_multiplayer_peer():
		return false

	if not multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return false

	return true

func reset():

	if not active_backend:
		return

	active_backend.connected_players.clear()
	active_backend.disconnected_players.clear()

func _exit_tree() -> void :

	on_peer_disconnected.emit(multiplayer.get_unique_id())

func set_game_scene(_game_scene: PackedScene):

	game_scene = _game_scene

func create_backend():

	if active_backend:

		active_backend.free()
		active_backend = null

	GameManager.multiplayer_mode_enabled = true

	match active_backend_type:
		NetworkBackendType.Enet:

			set_active_backend(preload("res://modules/multiplayer/backends/enet_backend.gd"))

		NetworkBackendType.Steam:

			if not Steamworks.is_initialized:

				Steamworks.initialize_steam()
				await Steamworks.initialized

			set_active_backend(preload("res://modules/multiplayer/backends/steam_backend.gd"))

	active_backend.lobbies_fetched.connect(on_lobbies_fetched)
	active_backend.lobby_joined.connect(on_lobby_joined)

func set_active_backend(backend_script):

	var backend_node: Node = Node.new()
	backend_node.set_script(backend_script)
	add_child(backend_node, true)
	active_backend = backend_node

	active_backend.on_server_created.connect( func(): on_server_created.emit())
	active_backend.on_client_created.connect( func(): on_client_created.emit())

	active_backend.on_peer_connected.connect( func(network_id):
		on_peer_connected.emit(network_id)
	)
	active_backend.on_peer_disconnected.connect( func(network_id):
		on_peer_disconnected.emit(network_id)
	)
	active_backend.on_host_disconnected.connect( func():
		on_host_disconnected.emit()
	)

	active_backend.on_connected_to_server.connect( func(): on_connected_to_server.emit())

	active_backend.join_allowed.connect( func(reconnect, game_in_progress, debug_only):
		join_allowed.emit(reconnect, game_in_progress, debug_only)
	)
	active_backend.join_refused.connect( func(network_id, refuse_reason):
		join_refused.emit(network_id, refuse_reason)
	)

	await get_tree().create_timer(0.1).timeout

	backend_ready.emit()

func start_host(player_name: String) -> void :

	create_backend()
	await backend_ready

	GameManager.host_mode_enabled = true
	active_backend.add_client_to_join_queue.connect( func(_network_manager):
		player_added_to_join_queue.emit(_network_manager)
	)
	active_backend.join_host(player_name)

func start_client(player_name: String, lobby_id: int = -1) -> void :

	create_backend()
	await backend_ready

	GameManager.host_mode_enabled = false
	active_backend.join_client(player_name, lobby_id)

func remove_player(network_id: int):

	if not active_backend:
		return

	active_backend.connected_players.erase(network_id)
	players_loaded.erase(network_id)

func cancel(network_id: int):

	if active_backend:

		active_backend.cancel(network_id)
		active_backend.queue_free()

	active_backend = null

func get_lobbies():

	create_backend()
	await backend_ready

	if active_backend_type != NetworkBackendType.Steam:
		return []

	active_backend.get_lobbies()

func leave_lobby():

	if active_backend:
		active_backend.leave_lobby()

func set_lobby_joinable(_joinable: bool):

	if active_backend:
		active_backend.set_lobby_joinable(_joinable)


func on_lobby_joined(lobby, permissions, locked, response):

	players.clear()

	match active_backend_type:
		NetworkManager.NetworkBackendType.Steam:
			players = active_backend.connected_players.duplicate()

	lobby_joined.emit(lobby, permissions, locked, response)

func on_lobbies_fetched(lobbies: Array):

	lobbies_fetched.emit(lobbies)



@rpc("any_peer", "call_remote", "reliable")
func load_game_scene_rpc(is_reconnect: bool = false):
	GameManager.reconnect = is_reconnect
	get_tree().change_scene_to_packed(game_scene)

@rpc("any_peer", "call_remote", "reliable")
func add_player_to_join_queue_rpc(_network_id: int):

	if not multiplayer.is_server():
		return

	player_added_to_join_queue.emit(_network_id)

@rpc("any_peer", "call_remote", "reliable")
func remove_player_from_join_queue_rpc(_network_id: int):

	if not multiplayer.is_server():
		return

	player_removed_from_join_queue.emit(_network_id)

@rpc("authority", "reliable")
func host_loaded(skip_intro: bool):
	Globals.skipping_intro_cutscene = skip_intro
	if not multiplayer.is_server():
		get_tree().change_scene_to_packed(game_scene)

@rpc("any_peer", "reliable")
func client_loaded(network_id):

	if multiplayer.is_server():

		players_loaded.append(network_id)
		on_client_loaded.emit(network_id)

		var all_loaded = true

		if players_loaded.size() + 1 != active_backend.connected_players.size():
			all_loaded = false
		else:
			for i in players_loaded:
				if not active_backend.connected_players.has(i):
					all_loaded = false

		if all_loaded:
			all_players_loaded.emit()

@rpc("authority", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	players.erase(_network_id)
	players_loaded.erase(_network_id)

	if active_backend and active_backend.connected_players.has(_network_id):

		var player_info = active_backend.connected_players[_network_id]
		active_backend.disconnected_players[_network_id] = player_info
		active_backend.connected_players.erase(_network_id)
