extends Minigame

class_name ChiselGauntletMinigame

const player_scene = preload("res://minigames/chisel_gauntlet_multiplayer/components/player/chisel_gauntlet_player.tscn")
const cube_segment_count: int = 18

enum JumbotronScreen{
	None, 
	Memorize, 
	Cube, 
	Carve
}

@export_category("Shared Parameters")
# 8-PLAYER MOD: indexed as player_rotations[counter] in spawn_players(), so
# four entries meant player 5 hit an out-of-bounds read and the spawn loop
# aborted - the same failure that black-screened Forklift Certified.
#
# Every player is teleported to the SAME point (player_spawn_node) and told
# apart purely by this rotation, so simply repeating the four facings put two
# players back-to-back in one slot with their carve cubes intersecting - one
# player's cube fills the other's camera. Eight distinct facings, 45 degrees
# apart, give everyone their own slot. The four `collision shape desk` nodes
# are level geometry at the original 90-degree positions, so the four added
# slots sit between desks.
@export var player_rotations: Array[float] = [
	0.0, 180.0, 90.0, -90.0,
	45.0, -135.0, 135.0, -45.0
]

@export_category("Game Parameters")
@export var memorization_duration: float = 4.0
@export var segments_to_remove: int = 4
@export var max_segments_to_remove: int = 9
@export var carving_duration: int = 15

@export_category("Local Nodes")
@export var local_root_node: Node3D
@export var local_handler: ChiselGauntletLocalHandler

@export_category("Screens")
@export var screen_memorize: Node3D
@export var screen_cube: Node3D
@export var screen_carve: Node3D

@export_category("Components")
@export var cube_handler: ChiselGauntletCubeHandler
@export var shotgun_handler: ChiselGauntletShotgunHandler
@export var round_timer: Timer
@export var spectate_position_parent: Node3D
@export var dead_camera_pivot: Node3D
@export var dead_camera: Camera3D
@export var anim_viewblocker: AnimationPlayer
@export var label_spectate: Label

@export_category("Audio")
@export var speaker_tv_background_hum: AudioStreamPlayer3D
@export var speaker_tv_off: AudioStreamPlayer3D
@export var speaker_tv_on: AudioStreamPlayer3D
@export var speakers_switches: Array[AudioStreamPlayer3D]
@export var speaker_tv_carve: AudioStreamPlayer3D

@export_category("Ambience")
@export var ambience_speakers: Array[AudioStreamPlayer]
@export var ambience_speaker_controllers: Array[SpeakerController]

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var player_spawn_node: Node3D = $PlayerSpawnNode

@export var debug_spectator_light_parent_to_show: Node3D
@export var debug_spectator_vignette_to_hide: Control


@onready var round_finished_state: Node = $StateMachine / RoundFinished


var player_count: int
var local_player: ChiselGauntletPlayer
var players: Dictionary[int, ChiselGauntletPlayer]
var active_players: Dictionary[int, ChiselGauntletPlayer]
var finished_players: Dictionary[int, ChiselGauntletPlayer]
var eliminate_players: Dictionary[int, ChiselGauntletPlayer]
var players_by_position: Dictionary[int, int]
var player_scores: Dictionary[int, int]
var players_alive: Array[int]


var round_instructions: Array[int] = []
var submitted_solutions: Dictionary[int, Array]


# 8-PLAYER MOD: the shotgun only visits the positions listed here, so the four
# added slots were never checked and those players could not be eliminated.
# The stock order is a clockwise sweep by angle (0, 90, 180, 270) rather than by
# index; MOD_CHECK_ORDER_8 keeps that sweep across all eight facings:
#   idx 0=0  4=45  2=90  6=135  1=180  5=225  3=270  7=315
#
# Kept at the stock four unless the lobby needs more. round_eliminate.gd sets
# `sequential = false` for an unoccupied slot, which makes the *next* move slow
# and plays the slow-travel sound - so using the eight-slot order in a 4-player
# game would put an empty slot between every real one and make the gun crawl
# instead of snap. spawn_players() swaps it in when the roster warrants it.
const MOD_CHECK_ORDER_8: Array[int] = [0, 4, 2, 6, 1, 5, 3, 7]
var shotgun_check_order: Array[int] = [0, 2, 1, 3]

var first_round: bool = true
var round_time_remaining: int
var spectate_positions: Array[Vector3]
var can_submit: bool = false

func _ready() -> void :
	super._ready()

	if multiplayer.is_server():

		multiplayer_synchronizer.set_multiplayer_authority(1)

		shotgun_handler.eliminate_player_by_id.connect(_on_player_eliminated)
		round_timer.timeout.connect(_on_round_timer_tick)
		round_finished_state.submissions_validated.connect(_on_submissions_validated)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		local_root_node.visible = true
		local_handler.canvas_layer.visible = true
		minigame_ready.emit(1)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	for p in spectate_position_parent.get_children():
		spectate_positions.append(p.global_position)

	spawn_players()

	await get_tree().create_timer(1.0).timeout

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func initialize_debug_specifics():
	super.initialize_debug_specifics()

	debug_spectator_light_parent_to_show.visible = true
	debug_spectator_vignette_to_hide.visible = false
	debug_player_specifics_initialized.emit(Transform3D.IDENTITY)

func _process(delta: float) -> void :

	if not multiplayer.is_server():
		return

	if active_players.size() == players.size():
		return

	var input_sum = Vector2.ZERO
	var counter: int = 0
	for p in players.values():
		if p.dead_input.length() > Globals.Epsilon:
			input_sum += p.dead_input
			counter += 1

	if counter < 0:
		return

	input_sum /= float(players.size())

	dead_camera_pivot.rotate_y(input_sum.x * delta)
	dead_camera.rotate_object_local(Vector3.RIGHT, input_sum.y * delta)
	var rotation_x = dead_camera.rotation.x
	dead_camera.rotation.x = clamp(
		rotation_x, 
		- deg_to_rad(60.0), 
		0.0
	)

func _input(_event: InputEvent) -> void :

	if not multiplayer.is_server():
		return

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())

func player_disconnected(_network_id):
	super.player_disconnected(_network_id)

	remove_player_rpc.rpc(_network_id)

	await get_tree().create_timer(1.0).timeout

	if can_submit:
		check_all_submitted()


const MOD_VANILLA_STATIONS: int = 4

# Everything that makes up a station. All of it sits on the Y axis and differs
# only by a Y rotation, so a copy turned 45 degrees lands exactly between two
# existing stations. Nodes are cloned whole (children come with them).
const MOD_STATION_NODES: Array[String] = [
	"chisel gauntlet art2/walls/control panel alpha",
	"chisel gauntlet art2/walls/control panel bravo",
	"chisel gauntlet art2/walls/control panel charlie",
	"chisel gauntlet art2/walls/control panel delta",
	# Exactly the four desk collision bodies - Colliders' other two children
	# are the room's concave collision mesh (plus a WorldBoundary) and the
	# centre CSG pillar, and cloning either puts a phantom 45-degree-rotated
	# room collider in the level.
	"Colliders/StaticBody3D",
	"Colliders/StaticBody3D2",
	"Colliders/StaticBody3D3",
	"Colliders/StaticBody3D4",
	"chisel gauntlet art2/control panel hole mesh",
	"chisel gauntlet art2/control panel hole wires",
]

func _mod_clone_rotated(node: Node) -> void:
	if not node is Node3D:
		return
	var copy: Node3D = node.duplicate()
	copy.name = node.name + "_MOD"
	node.get_parent().add_child(copy)
	copy.rotate_y(deg_to_rad(45.0))

# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build. Any future
# mod RPC needs the same prefix.
@rpc("authority", "call_local", "reliable")
func zz_mod_add_stations_rpc() -> void:
	"""Give the four added slots a full station of their own.

	A station is not a placed object - it is one piece of geometry at the origin
	spun to face a direction, exactly like the players themselves. So four more
	are a duplicate-and-rotate at runtime; the .tscn is untouched and a 1-4
	player game never runs this.
	"""
	var _dbg := Array(OS.get_cmdline_args()).has("-localtest")
	var _made := 0
	if _dbg:
		print("[STATIONS] running, is_server=", multiplayer.is_server())

	for path in MOD_STATION_NODES:
		var node := get_node_or_null(path)
		if _dbg:
			print("[STATIONS] ", "found " if node else "MISSING ", path)
		if node:
			_mod_clone_rotated(node)
			_made += 1

	if _dbg:
		print("[STATIONS] cloned ", _made, " single nodes")

func spawn_players():


	player_count = PlayerManager.player_presences.size()
	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[STATIONS] spawn_players player_count=", player_count)
	if player_count > MOD_VANILLA_STATIONS:
		shotgun_check_order = MOD_CHECK_ORDER_8
		# spawn_players() runs on the host only, so the geometry has to be
		# built through an RPC or every client sees the stock four stations.
		zz_mod_add_stations_rpc.rpc()

	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]
		var player_character = player_scene.instantiate()
		player_spawn_node.add_child(player_character, true)

		player_character.set_manager_from_path_rpc.rpc(self.get_path())

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.solution_submitted.connect(_on_player_submitted_solution)
		player_character.teleport_rpc.rpc(
			player_spawn_node.global_position, 
			Vector3(0.0, player_rotations[counter], 0.0)
		)
		player_character.set_spectate_position_rpc.rpc(
			spectate_positions[counter]
		)
		players[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character
		players_by_position[counter] = player_presence.network_id

		player_scores[player_presence.network_id] = player_count
		players_alive.append(player_presence.network_id)

		counter += 1

	if GameManager.local_game:
		local_handler.set_players(players.values())

func generate_random_cube_instructions():

	var instructions: Array[int] = []
	for i in 19:
		instructions.append(i)

	for i in segments_to_remove:
		instructions.erase(instructions.pick_random())

	update_instructions_rpc.rpc(instructions)

func start_round_timer(_duration: float):

	round_time_remaining = carving_duration
	round_timer.wait_time = 1.0
	round_timer.start()

func check_all_submitted():

	if submitted_solutions.size() == active_players.size():
		for player in players.values():
			player.set_timer_label_text_rpc.rpc("--:--")

		round_timer.stop()
		await get_tree().create_timer(1.0).timeout
		state_machine.transition_to_rpc(&"RoundFinished")

func check_game_end():

	if active_players.size() > 1:
		segments_to_remove = min(segments_to_remove + 1, max_segments_to_remove)
		carving_duration = max(carving_duration - 1, 5)
		state_machine.transition_to_rpc(&"RoundInstruction")

		if segments_to_remove == max_segments_to_remove:
			for player in active_players.values():
				player.trigger_achievement_rpc.rpc()

	for network_id in eliminate_players.keys():
		player_scores[network_id] -= players_alive.size()

	for network_id in eliminate_players:
		players_alive.erase(network_id)







	if active_players.size() <= 1:

		player_scores_finalized.emit(player_scores)
		await get_tree().create_timer(1.0).timeout
		set_minigame_sfx_linear_volume_rpc.rpc(0.0)
		state_machine.transition_to_rpc.rpc(&"GameFinished")
		set_effects_visibility_rpc.rpc(false)

func fade_in_ambience():
	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)


@rpc("authority", "call_local", "reliable")
func shake_player_cameras():
	if !multiplayer.is_server(): return

	for ap: ChiselGauntletPlayer in active_players.values():
		if ap.alive:
			ap.anim_handler.shake_camera_rpc.rpc()



@rpc("authority", "call_local", "reliable")
func start_tv_hum_sound_rpc():
	speaker_tv_on.play()
	speaker_tv_background_hum.play()

@rpc("authority", "call_local", "reliable")
func stop_tv_hum_sound_rpc():
	speaker_tv_background_hum.stop()
	speaker_tv_off.play()

@rpc("authority", "call_local", "reliable")
func play_tv_switch_sound_rpc(index: int):
	speakers_switches[index].play()

@rpc("authority", "call_local", "reliable")
func play_tv_carve_sound_rpc():
	speaker_tv_carve.play()

@rpc("authority", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	if players.has(_network_id):

		var player_instance = players[_network_id]

		players.erase(_network_id)
		active_players.erase(_network_id)
		finished_players.erase(_network_id)
		eliminate_players.erase(_network_id)
		players_by_position.erase(_network_id)

		player_instance.queue_free()

@rpc("authority", "call_local", "reliable")
func update_round_timers_rpc(_round_time: int):

	for ap in active_players.values():
		ap.update_timer_rpc.rpc(_round_time)

@rpc("authority", "call_local", "reliable")
func reset_jumbotron_cube_rpc():
	cube_handler.reset_cube()

@rpc("authority", "call_local", "reliable")
func update_instructions_rpc(_instructions: Array):
	round_instructions = _instructions

@rpc("authority", "call_local", "reliable")
func update_jumbotron_cube_rpc():
	cube_handler.remove_segments(round_instructions)

@rpc("authority", "call_local", "reliable")
func show_jumbotron_screen_rpc(_screen: ChiselGauntletMinigame.JumbotronScreen):

	screen_memorize.visible = false
	screen_cube.visible = false
	screen_carve.visible = false

	match _screen:
		ChiselGauntletMinigame.JumbotronScreen.Memorize:
			screen_memorize.visible = true
		ChiselGauntletMinigame.JumbotronScreen.Cube:
			screen_cube.visible = true
		ChiselGauntletMinigame.JumbotronScreen.Carve:
			screen_carve.visible = true



func _on_all_brief_ready():

	await get_tree().create_timer(1.0).timeout

	state_machine.transition_to_rpc.rpc(&"Round", {"round": round_number, "total": total_rounds})

func _on_player_eliminated(network_id: int):

	if active_players.has(network_id):
		active_players[network_id].eliminate_rpc.rpc()

func _on_round_timer_tick():

	round_time_remaining -= 1

	if round_time_remaining > 0:

		round_timer.wait_time = 1.0
		round_timer.start()

	else:

		can_submit = false
		state_machine.transition_to_rpc(&"RoundFinished")

	update_round_timers_rpc.rpc(round_time_remaining)

func _on_player_submitted_solution(network_id, solution):

	if not can_submit:
		return

	submitted_solutions[network_id] = solution
	check_all_submitted()

func _on_submissions_validated(_correct_player_ids: Array[int], incorrect_player_ids: Array[int]):

	eliminate_players.clear()

	for k in active_players.keys():
		if incorrect_player_ids.has(k):
			eliminate_players[k] = active_players[k]

	state_machine.transition_to_rpc(&"RoundEliminate")
