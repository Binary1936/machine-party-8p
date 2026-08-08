extends Minigame

class_name GreenPeaMinigame

const player_scene = preload("uid://cyhptkj072mxh")

@export_category("States")
@export var countdown_state: State

@export_category("Components")
@export var coach_handler: GreenPeaCoachHandler

@export_category("Networked")
@export var player_spawn_parent: Node3D
@export var player_spawn_positions: Node3D

@export_category("Nodes")
@export var camera: Camera3D

@export var ambience_speaker_controllers: Array[SpeakerController]

var players: Array[GreenPeaPlayer]
var player_characters: Dictionary[int, GreenPeaPlayer]
var finished_players: Array[int]
var active_players: Array[int]

var halfway_done_players: Array[int]
var player_scores: Dictionary[int, int]

var finished: bool = false



var ach_timer: float = 0.0
var ach_duration: float = 20.0
var ach_active: bool = false

func _ready() -> void :
	super._ready()

	camera.current = true

	if multiplayer.is_server():

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

	if GameManager.local_game:

		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

func _process(_delta: float) -> void :

	if ach_active:
		ach_timer = max(ach_timer - _delta, 0.0)
		if ach_timer <= 0.0:
			ach_active = false

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

# 8-PLAYER MOD ---------------------------------------------------------------
# The scene is left exactly as shipped, and the eight-seat layout is applied at
# runtime only when the lobby actually exceeds four players. A 1-4 player game
# therefore looks pixel-identical to vanilla: same four chairs in their original
# places at full width, same camera.
const MOD_VANILLA_SEATS: int = 4
const MOD_CHAIR_NARROW: float = 0.6      # chairs are 1.2 apart instead of ~2.0
const MOD_CAMERA_PULLBACK: float = 2.5   # along the camera's own view axis
const MOD_CAMERA_FOV: float = 50.0

func _mod_chairs() -> Array:
	"""Find the dinner-set chairs.

	Anchored to the `camera` export and walked upward rather than reached by a
	hardcoded relative path: this script's depth in the scene is not obvious,
	and a path that silently resolves to null makes the whole layout a no-op
	with no error - which is exactly what happened.
	"""
	var walls: Node = null
	var node: Node = camera
	while node and walls == null:
		walls = node.get_node_or_null("pea dinner scene4/walls")
		node = node.get_parent()
	if walls == null:
		push_warning("[8P MOD] green_pea: chair parent not found; seats unchanged")
		return []
	var out := []
	for c in walls.get_children():
		if c.name.begins_with("chair player"):
			out.append(c)
	return out

@rpc("authority", "call_local", "reliable")
func mod_apply_eight_seat_layout_rpc() -> void:

	var _dbg := Array(OS.get_cmdline_args()).has("-localtest")
	var markers := player_spawn_positions.get_children()
	var chairs := _mod_chairs()
	if _dbg:
		print("[SEATS8] running, is_server=", multiplayer.is_server(),
			"  markers=", markers.size(), "  chairs=", chairs.size())
	if chairs.size() < markers.size():
		return

	# Learn the chair-to-marker offset per side from the shipped chairs rather
	# than hardcoding it, so this still tracks if the level is re-authored.
	var off := {}
	for c in chairs:
		if not c.visible:
			continue
		var near: Node3D = markers[0]
		for m in markers:
			if m.global_position.distance_to(c.global_position) < \
					near.global_position.distance_to(c.global_position):
				near = m
		var side := "l" if c.position.x < 0.0 else "r"
		if not off.has(side):
			off[side] = {"d": Vector3.ZERO, "n": 0, "basis": c.transform.basis,
				"y": c.position.y}
		off[side].d += c.position - near.position
		off[side].n += 1
	for k in off:
		off[k].d /= float(off[k].n)

	# Seat every marker, narrowing the chairs along the table only. A uniform
	# shrink would drop the seat height and leave characters floating.
	var by_side := {"l": [], "r": []}
	for m in markers:
		by_side["l" if m.position.x < 0.0 else "r"].append(m)

	for side in by_side:
		if not off.has(side):
			continue
		var seats: Array = by_side[side]
		seats.sort_custom(func(a, b): return a.position.z < b.position.z)
		var pool := []
		for c in chairs:
			if (c.position.x < 0.0) == (side == "l"):
				pool.append(c)
		pool.sort_custom(func(a, b): return a.position.z < b.position.z)

		var b: Basis = off[side].basis
		b.z *= MOD_CHAIR_NARROW
		for i in min(seats.size(), pool.size()):
			var chair: Node3D = pool[i]
			chair.transform.basis = b
			chair.position = Vector3(
				seats[i].position.x + off[side].d.x,
				off[side].y,
				seats[i].position.z + off[side].d.z)
			chair.visible = true

	# Widen the framing so the end seats are not clipped by the near plane.
	var rig := camera.get_parent().get_parent()
	rig.position += rig.transform.basis.z * MOD_CAMERA_PULLBACK
	camera.fov = MOD_CAMERA_FOV
	if _dbg:
		print("[SEATS8] layout applied, camera fov=", camera.fov)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	# initialize() runs on the host only, so this has to travel to every peer -
	# otherwise clients keep the vanilla four chairs and camera while the host
	# alone sees the eight-seat layout.
	if PlayerManager.player_presences.size() > MOD_VANILLA_SEATS:
		mod_apply_eight_seat_layout_rpc.rpc()

	spawn_players()
	coach_handler.start_reading_rpc.rpc()
	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func spawn_players():


	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		player_spawn_parent.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.set_marker_camera_from_path_rpc.rpc(camera.get_path())
		player_character.setup_rpc.rpc(
			player_spawn_positions.get_child(counter).global_position, 
			player_spawn_positions.get_child(counter).global_rotation, 
			counter
		)
		player_characters[player_presence.network_id] = player_character
		player_character.finished.connect(_on_player_finished)
		player_character.acted.connect(coach_handler._on_player_acted)
		player_character.died.connect(_on_player_died)
		player_character.halfway_done.connect(_on_player_halfway)

		active_players.append(player_presence.network_id)

		player_scores[player_presence.network_id] = 0

		counter += 1

	coach_handler.set_players(player_characters)


func initialize_debug_specifics():
	super.initialize_debug_specifics()


func check_game_end():

	if finished:
		return

	if active_players.size() > 0:
		return

	finished = true

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(3.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)



@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = player_characters.get(_network_id, null)

	if player_instance:
		players.erase(player_instance)
		player_characters[_network_id].queue_free()
		player_characters.erase(_network_id)

	active_players.erase(_network_id)



func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	remove_player_rpc.rpc(_network_id)

	await get_tree().create_timer(1.0).timeout

	if multiplayer.is_server():
		check_game_end()

func _on_player_finished(_network_id: int):

	if player_characters.has(_network_id):
		if ach_active:
			player_characters[_network_id].trigger_achievement_rpc.rpc()

	if active_players.has(_network_id):

		player_scores[_network_id] += 1
		active_players.erase(_network_id)

	if finished_players.is_empty():
		player_scores[_network_id] += 1

	if not finished_players.has(_network_id):
		finished_players.append(_network_id)

	check_game_end()

func _on_player_died(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)

	check_game_end()

func _on_player_halfway(_network_id: int):

	if not halfway_done_players.has(_network_id):
		halfway_done_players.append(_network_id)
		player_scores[_network_id] += 1

func _on_countdown_tick(time_left: int):
	super._on_countdown_tick(time_left)

	if time_left == 1:
		coach_handler.stop_reading_fakeout_rpc.rpc()

func _on_countdown_expired():
	super._on_countdown_expired()

	coach_handler.activate()

	for player in player_characters.values():
		player.set_active_rpc.rpc(true)

	ach_timer = ach_duration
	ach_active = true

	state_machine.transition_to_rpc.rpc(&"Play")
