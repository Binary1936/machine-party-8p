extends Minigame

class_name DvdRoombaMinigame

const roomba_scene = preload("uid://badl26ts540cw")
const player_scene = preload("uid://w6wpt3kvl74p")

@export_category("Variables")
@export var max_roomba_count: int = 5
@export var roomba_spawn_interval: float = 5.0

@export_category("Components")
@export var blood_handler: DvdRoombaFloorBloodHandler
@export var camera_shaker: ShakerComponent3D

@export_category("Nodes")
@export var player_parent_node: Node3D
@export var player_spawn_parent_node: Node3D

@export var roomba_parent_node: Node3D
@export var roomba_spawn_parent_node: Node3D
@export var roomba_spawn_timer: Timer

@export var ambience_speaker_controllers: Array[SpeakerController]

@export var camera: Camera3D

@export_category("States")
@export var countdown_state: State

var players: Dictionary[int, DvdRoombaPlayer]
var active_players: Dictionary[int, DvdRoombaPlayer]
var player_scores: Dictionary[int, int]
var dead_players: Array[int]

var finished: bool = false
var player_count: int = 0
var roomba_spawned_count: int = 0

# --- 8P MOD ------------------------------------------------------------------
# Diagnostic only, gated behind -localtest; no gameplay change at any roster
# size, so 1-4 player games stay vanilla.
#
# Lethal Rebound needed no gameplay edit: roombas are spawned on a timer up to
# `max_roomba_count` and bounce, with nothing indexed or enumerated per player,
# so the only cap was the four spawn markers. Note the hazard count does NOT
# scale with the roster: eight players share one arena with the same hazards,
# which makes the round longer rather than broken. `max_roomba_count` is an
# @export whose script default of 5 is overridden to 10 by the scene - read the
# `max_roombas=` field of the trace below, not this file, and leave it alone:
# raising it would change the 1-4 player game too.
#
# spawn_expand.py places the four added markers 1.2u outboard of the shipped
# ones - here that puts MOD6 at x=6.2 against a shipped extreme of 5.0 - so a
# clone landing inside a wall is the specific risk this audit is for.
const MOD_AUDIT_DELAY: float = 6.0
const MOD_DISPLACED_DIST: float = 2.0
const MOD_FELL_THROUGH_Y: float = - 3.0

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[ROOMBA8] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var markers: Array[Node] = []
	if player_spawn_parent_node != null:
		markers = player_spawn_parent_node.get_children()

	print(tag, " markers=", markers.size(),
		" spawned=", player_parent_node.get_child_count(),
		" roombas=", roomba_parent_node.get_child_count(),
		" max_roombas=", max_roomba_count)

	if markers.is_empty():
		push_warning("[ROOMBA8] no spawn markers found")
		return

	for child in player_parent_node.get_children():
		if not child is Node3D:
			continue
		var pos: Vector3 = (child as Node3D).global_position
		var best: float = - 1.0
		var best_name: String = "?"
		for m in markers:
			if not m is Node3D:
				continue
			var d: float = (m as Node3D).global_position.distance_to(pos)
			if best < 0.0 or d < best:
				best = d
				best_name = m.name
		# kill_rpc() hides the player on every peer, so an eliminated player is
		# reported as such rather than as a bogus DISPLACED - the 6s audit does
		# sometimes land after the first casualties.
		var verdict := " OK"
		if not (child as Node3D).visible:
			verdict = " DEAD_OR_HIDDEN"
		elif pos.y < MOD_FELL_THROUGH_Y:
			verdict = " FELL_THROUGH"
		elif best > MOD_DISPLACED_DIST:
			verdict = " DISPLACED"
		print(tag, " player=", child.name,
			" pos=(%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z],
			" marker=", best_name, " dist=%.2f" % best, verdict)

func _ready() -> void :
	super._ready()

	camera.current = true

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	if multiplayer.is_server():

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		roomba_spawn_timer.timeout.connect(_on_roomba_timer_timeout)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)



func fade_in_ambience():
	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func cleanup():

	if is_multiplayer_authority():

		queue_free()





func spawn_players():

	var player_spawn_positions = player_spawn_parent_node.get_children()
	player_spawn_positions.shuffle()

	player_count = PlayerManager.player_presences.size()
	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		player_parent_node.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.teleport_rpc.rpc(
			player_spawn_positions[counter].global_position
		)
		players[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character
		player_character.event_died.connect(_on_player_died)
		player_character.event_shoved_died.connect(_on_player_died_shoving)
		player_scores[player_presence.network_id] = 0

		counter += 1

func spawn_roomba():
	var spawn_positions = roomba_spawn_parent_node.get_children()
	var position = spawn_positions.pick_random()

	var roomba_instance = roomba_scene.instantiate()
	roomba_parent_node.add_child(roomba_instance, true)

	var random_angle = [45, 135, 225, 315].pick_random()
	var random_rotation = deg_to_rad(random_angle)
	var direction = Vector3(
		cos(random_rotation), 0.0, sin(random_rotation)
	)
	roomba_instance.direction_angle = random_angle

	roomba_spawned_count += 1

	roomba_instance.setup_rpc.rpc(position.global_position, direction, roomba_spawned_count)
	blood_handler.roombas.append(roomba_instance)

	roomba_spawn_timer.start(roomba_spawn_interval)

func check_game_end():

	if finished:
		return

	if active_players.size() > 1:
		return

	finished = true

	for i in dead_players.size():
		player_scores[dead_players[i]] = i

	for network_id in active_players.keys():
		player_scores[network_id] = player_count


		break

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)



@rpc("any_peer", "call_local", "reliable")
func shake_camera_rpc():
	camera_shaker.force_stop_shake()
	camera_shaker.play_shake()

@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:
		player_instance.queue_free()
		players.erase(_network_id)
		active_players.erase(_network_id)





func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	# 8P MOD: before the game has started there is nothing to end - the peer
	# was never spawned here and its presence is already pruned. Vanilla's end
	# check below would see zero players and finish an unstarted game
	# (pitfall 32; session log 2026-08-15).
	if not is_all_player_loaded:
		return

	remove_player_rpc.rpc(_network_id)
	await get_tree().create_timer(1.0).timeout

	check_game_end()

func _on_countdown_expired():
	super._on_countdown_expired()

	for player in players.values():
		player.set_active_rpc.rpc(true)

	state_machine.transition_to_rpc.rpc(&"Play")

	if get_tree() == null: return
	await get_tree().create_timer(0.5, false).timeout

	spawn_roomba()

func _on_player_died(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)
		shake_camera_rpc.rpc()
		if not finished:
			dead_players.append(_network_id)

	check_game_end()

func _on_player_died_shoving(shover_network_id: int):

	if players.has(shover_network_id):
		players[shover_network_id].increment_achievement_rpc.rpc()

func _on_roomba_timer_timeout():

	if roomba_parent_node.get_child_count() >= max_roomba_count:
		return

	spawn_roomba()
