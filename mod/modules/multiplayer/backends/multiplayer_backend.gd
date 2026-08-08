extends Node

class_name MultiplayerBackend

var self_data: Dictionary = {
	"id": -1, 
	"device_id": -1, 
	"peer_id": -1, 
	"name": "player", 
	"customization": ["", "", ""], 
	"reconnect_id": 0, 
	"game_version": Globals.game_version
}

var reconnect_check_property: String = "name"
var lobby_id: int = -1
var connected_players: Dictionary[int, Dictionary]
var disconnected_players: Dictionary = {}
var exiting: bool = false

@warning_ignore_start("unused_signal")
signal on_server_created()
signal on_client_created()

signal on_connected_to_server()

signal on_peer_connected(id)
signal on_peer_disconnected(id)
signal on_host_disconnected()

signal lobby_joined(lobby, permissions, locked, response)
signal lobbies_fetched(lobbies)
signal join_refused(network_id, refuse_reason)
signal join_allowed(reconnect, game_in_progress, debug_only)
signal add_client_to_join_queue(network_id)

func join_host(_player_name: String) -> void :
	pass


func join_client(_player_name: String, _lobby_id: int) -> void :
	pass

func cancel(_network_id: int) -> void :
	pass

func remove_player(_id: int) -> void :
	pass

func leave_lobby():
	pass

func get_lobbies():

	lobbies_fetched.emit([])

func set_lobby_joinable(_joinable: bool):
	pass

func set_self_data(data: Dictionary):

	self_data = data

	# 8-PLAYER MOD: also title the window during -localtest, so eight instances
	# on one desktop are tellable apart (P1..P8).
	if Globals.debug and (OS.has_feature("editor")
			or Array(OS.get_cmdline_args()).has("-localtest")):
		DisplayServer.window_set_title(self_data["name"])
