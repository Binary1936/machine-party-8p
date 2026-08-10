# 8-PLAYER MOD: overlaid ONLY to make vanilla-compat mode work. Three changes,
# all in the join handshake, all mirrored in steam_backend.gd - the two files
# duplicate this logic and must never be allowed to drift apart:
#
#   1. self_data reports Globals.MOD_NETWORK_GAME_VERSION (vanilla's exact
#      "v1.5.0") instead of Globals.game_version, so an unmodded host's
#      exact-equality check accepts us and ours accepts it. The mod tag moved
#      into a separate "mod8p" capability key, which vanilla never looks at: it
#      reads self_data through .get()/known keys and rebroadcasts the dict
#      verbatim, so an unknown key rides through the whole handshake and the
#      roster broadcast harmlessly.
#   2. receive_client_data_rpc compares against MOD_NETWORK_GAME_VERSION, then
#      requires a matching "mod8p" from any client that carries one - so two
#      different mod builds still refuse each other, while a peer with no mod8p
#      key is simply a vanilla peer and is let in.
#   3. Over-capacity handling is ASYMMETRIC. A vanilla joiner that would push the
#      roster past vanilla's four is REFUSED outright in receive_client_data_rpc,
#      because an unmodded build cannot safely render or even spectate a 5-8
#      player session. A modded joiner still takes vanilla's own demote-to-debug-
#      spectator path in acknowledge_client_data_rpc, against a cap of four while
#      any vanilla peer is in the lobby and MAX_PLAYERS otherwise.
#
# STANDING CONSTRAINT: never add, remove, reorder or re-annotate an @rpc method
# in this file or in steam_backend.gd. The handshake has to stay wire-identical
# to vanilla v1.5.0 or unmodded peers cannot talk to us at all. Anything
# vanilla-compat needs travels inside the existing self_data Dictionary.
extends MultiplayerBackend

class_name EnetBackend

const SERVER_PORT = 25565
const SERVER_IP = "127.0.0.1"

var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var joinable: bool = false

func _ready() -> void :

	reconnect_check_property = "name"

	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_host_disconnected)


	multiplayer.connected_to_server.connect(_on_connected_to_server)

func get_connected_players() -> Dictionary:

	return connected_players

func save_player_info(player_name: String, is_host: bool = false):

	set_self_data({
		"id": multiplayer.get_unique_id(), 
		"peer_id": multiplayer.get_unique_id(), 
		"name": player_name, 
		"customization": [
			Globals.active_cosmetic_hat, 
			Globals.active_cosmetic_glasses, 
			Globals.active_cosmetic_suit_color
		], 
		"reconnect_id": 0,
		"game_version": Globals.MOD_NETWORK_GAME_VERSION,
		"mod8p": Globals.MOD_SUFFIX
	})

	if is_host:
		connected_players[1] = self_data
	else:
		connected_players[multiplayer.get_unique_id()] = self_data

func is_already_connected(network_id):

	return connected_players.has(network_id)

func cancel(network_id: int):

	if multiplayer and multiplayer_peer:

		disconnect_player.rpc(network_id)
		multiplayer_peer.close()

func join_host(player_name: String) -> void :

	multiplayer_peer.create_server(SERVER_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer

	if player_name.length() < 1:
		player_name = "Player 1"

	save_player_info(player_name, true)
	joinable = true
	on_server_created.emit()

func join_client(player_name: String, _lobby_id: int) -> void :

	multiplayer_peer.create_client(SERVER_IP, SERVER_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer

	if player_name.length() < 1:
		player_name = "Player " + str(multiplayer.get_unique_id())

	save_player_info(player_name)
	on_client_created.emit()

func leave_lobby():

	multiplayer_peer.close()

func set_lobby_joinable(_joinable: bool):

	if multiplayer and multiplayer.is_server():
		joinable = _joinable



func _on_connected_to_server():

	on_connected_to_server.emit()

func _on_player_connected(network_id):
	if not multiplayer.is_server():
		return

	send_client_data_rpc.rpc_id(network_id, multiplayer.get_unique_id())

func _on_player_disconnected(network_id):

	if connected_players.has(network_id):
		disconnected_players[network_id] = connected_players[network_id]

	on_peer_disconnected.emit(network_id)
	connected_players.erase(network_id)

func _on_host_disconnected():
	on_host_disconnected.emit()



@rpc("authority", "call_remote", "reliable")
func send_client_data_rpc(host_network_id: int):

	receive_client_data_rpc.rpc_id(
		host_network_id, multiplayer.get_unique_id(), self_data
	)

@rpc("any_peer", "call_remote", "reliable")
func receive_client_data_rpc(client_network_id: int, client_data: Dictionary):


	for key in disconnected_players.keys():
		var player_data = disconnected_players[key]
		if player_data[reconnect_check_property] == client_data[reconnect_check_property]:
			client_data["reconnect_id"] = key
			disconnected_players.erase(key)
			break

	var client_game_version = client_data.get("game_version", "error")
	if client_game_version != Globals.MOD_NETWORK_GAME_VERSION:
		refuse_client_rpc.rpc_id(client_network_id, client_network_id, NetworkManager.RefuseReason.VersionMismatch)
		return
	# 8-PLAYER MOD: mod-to-mod strictness, which used to be the game_version
	# comparison above. A peer with no "mod8p" key is vanilla and was already
	# accepted; a peer that HAS one but disagrees is a different 8-player build
	# and must not mix with this one. Mod v1.0 peers never reach this line - they
	# still report "v1.5.0-8P-v1.0" as their game_version and the check above
	# refuses them, which is correct, they are wire-incompatible with this build.
	if client_data.has("mod8p") and client_data["mod8p"] != Globals.MOD_SUFFIX:
		refuse_client_rpc.rpc_id(client_network_id, client_network_id, NetworkManager.RefuseReason.VersionMismatch)
		return
	# 8-PLAYER MOD: a vanilla joiner that does not fit inside vanilla's own
	# four-player roster is REFUSED here instead of being demoted to a spectator
	# in acknowledge_client_data_rpc. Demotion is only safe for a client that can
	# render the session, and an unmodded build cannot: the roster broadcast
	# ships every entry, so it would replicate five to eight players into scenes
	# and local handlers dimensioned for four - the silent out-of-bounds class,
	# not a clean error. VersionMismatch is the reason to send because it is the
	# one whose lobby message reads correctly to them: their version cannot play
	# in this lobby. The literal 4 is vanilla's MAX_PLAYERS; ours is 8.
	#
	# Counted with the same expression as vanilla's cap, connected_players.size()
	# + 1, which does include demoted spectators - a demoted client re-enters
	# through set_as_debug_rpc and IS stored in connected_players on that second
	# pass. That is the right count here anyway, since it is the roster the
	# joining client would have to replicate. The debug exemption mirrors
	# vanilla's own: a client already carrying "debug" is mid-round-trip through
	# set_as_debug_rpc and must not be re-gated on the way back in.
	if not client_data.has("mod8p") and not client_data.get("debug", false):
		if connected_players.size() + 1 > 4:
			refuse_client_rpc.rpc_id(client_network_id, client_network_id, NetworkManager.RefuseReason.VersionMismatch)
			return
	if not joinable:
		refuse_client_rpc.rpc_id(client_network_id, client_network_id, NetworkManager.RefuseReason.SessionEnded)
		return

	acknowledge_client_data_rpc.rpc(
		client_network_id, 
		client_data, 
	)

@rpc("authority", "call_local", "reliable")
func refuse_client_rpc(client_network_id, refuse_reason):

	join_refused.emit(client_network_id, refuse_reason)

@rpc("authority", "call_local", "reliable")
func acknowledge_client_data_rpc(network_id: int, client_data: Dictionary):

	if multiplayer.is_server():

		# 8-PLAYER MOD: a lobby may only grow past four when EVERY occupant runs
		# the mod, so the cap is computed per-join instead of being the constant.
		# The scan covers the joiner plus everything already in connected_players,
		# and that is the complete roster: join_host() -> save_player_info() puts
		# the host's own self_data at key 1 before any client connects, so the
		# local peer needs no special case here. The literal 4 is vanilla's
		# MAX_PLAYERS - our NetworkManager.MAX_PLAYERS is 8, so it cannot be used
		# for the mixed case.
		#
		# This governs MODDED joiners only. A modded client demoted to spectator
		# of a <=4 mixed session is safe: it behaves exactly as a vanilla client
		# would there. A vanilla joiner never reaches an over-capacity decision
		# here - receive_client_data_rpc already refused it, because demotion is
		# not safe for a build that cannot render a 5-8 player roster. Its cap
		# still resolves to 4 below, which is consistent and keeps this block
		# correct on its own terms.
		var mod_effective_max: int = NetworkManager.MAX_PLAYERS
		if not client_data.has("mod8p"):
			mod_effective_max = 4
		else:
			for mod_peer_data in connected_players.values():
				if not mod_peer_data.has("mod8p"):
					mod_effective_max = 4
					break

		var debug_only: bool = false
		if not client_data.get("debug", false):
			debug_only = connected_players.size() + 1 > mod_effective_max
			if debug_only:
				client_data["debug"] = true
				set_as_debug_rpc.rpc_id(network_id, true)
				return
		else:
			debug_only = client_data.get("debug", false)

		connected_players[network_id] = client_data
		send_connected_player_data_rpc.rpc(connected_players)
		on_peer_connected.emit(network_id)

		if GameManager.game_in_progress:
			add_client_to_join_queue.emit(network_id)

		allow_player_join_rpc.rpc_id(
			network_id, 
			client_data["reconnect_id"] > 0, 
			GameManager.game_in_progress, 
			debug_only
		)

@rpc("any_peer", "call_remote", "reliable")
func set_as_debug_rpc(debug: bool):
	self_data["debug"] = debug


	receive_client_data_rpc.rpc_id(
		1, 
		multiplayer.get_unique_id(), 
		self_data
	)

@rpc("authority", "call_remote", "reliable")
func send_connected_player_data_rpc(connected_players_data: Dictionary):

	for key in connected_players_data.keys():
		var connected_player_data: Dictionary = connected_players_data[key]
		if not connected_players.has(connected_player_data["peer_id"]):
			connected_players[key] = connected_player_data
			on_peer_connected.emit(key)

@rpc("authority", "call_remote", "reliable")
func allow_player_join_rpc(reconnect: bool, game_in_progress: bool, debug_only: bool):

	join_allowed.emit(reconnect, game_in_progress, debug_only)

@rpc("any_peer", "reliable")
func disconnect_player(network_id: int):

	if multiplayer.is_server():
		multiplayer_peer.disconnect_peer(network_id)

@rpc("reliable")
func connect_to_server(peer_info):

	for peer in peer_info:

		connected_players[peer] = peer_info[peer]
		on_peer_connected.emit(peer)

	receive_player_info.rpc(multiplayer.get_unique_id(), self_data)

@rpc("any_peer", "reliable")
func receive_player_info(network_id, info):

	if not is_already_connected(network_id):

		connected_players[network_id] = info
		on_peer_connected.emit(network_id)
