extends Minigame

class_name TrainRaceMinigame

const player_scene = preload("res://minigames/train_race/components/player/train_race_player.tscn")

@export_category("Gameplay")
@export var sections_to_spawn: int = 10
@export var shake_proximity_radius: float = 50.0

@export_category("Nodes")
@export var player_spawn_positions_node: Node3D
@export var players_node: Node
@export var camera_base: Node3D
@export var camera: Camera3D
@export var multiplayer_synchronizer: MultiplayerSynchronizer
@export var shake_proximity: Area3D
@export var safety_killbox: Area3D

@export_category("Components")
@export var game_handler: TrainRaceGameHandler
@export var camera_shaker: ShakerComponent3D
@export var nook_handler: TrainRaceNookHandler

@export_category("Signal States")
@export var countdown_state: State

@export_category("Train")
@export var train: Area3D

@export_category("Ambience")
@export var ambience_speaker_controllers: Array[SpeakerController]

var players: Dictionary[int, TrainRacePlayer]
var active_players: Dictionary[int, TrainRacePlayer]
var game_end: bool = false

var player_count: int = 0
var player_scores: Dictionary[int, int]
var dead_players: Array[int]

var trains_in_proximity: Array

# --- 8P MOD ------------------------------------------------------------------
# Diagnostic only, gated behind -localtest; no gameplay change at any roster
# size, so 1-4 player games stay vanilla.
#
# Tunnel Hazard needed no gameplay edit: the level already ships EIGHT nooks
# (Left/1-4 + Right/5-8) even though vanilla caps out at four players, and
# nook_handler.cycle() opens `max((player_count + 2) - rounds_passed, 1)` of
# them with no hardcoded count anywhere. At eight players that starts at 10,
# clamps naturally to the 8 that exist, and converges - the first three cycles
# eliminate nobody, then it tightens by one a cycle. Only the spawn markers
# were modded.
#
# spawn_expand.py places the four added markers 1.2u outboard of the shipped
# ones, so a clone can land inside geometry; physics then shoves the player
# clear and the tell is a player standing well away from every marker.
const MOD_AUDIT_DELAY: float = 6.0
const MOD_DISPLACED_DIST: float = 2.0
const MOD_FELL_THROUGH_Y: float = - 3.0

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[TRAIN8] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var markers: Array[Node] = []
	if player_spawn_positions_node != null:
		markers = player_spawn_positions_node.get_children()

	var nooks := 0
	if nook_handler != null:
		nooks = nook_handler.nooks.size()

	print(tag, " markers=", markers.size(), " nooks=", nooks,
		" spawned=", players_node.get_child_count())

	# A count of 0 anywhere above means a lookup failed silently.
	if markers.is_empty() or nooks == 0:
		push_warning("[TRAIN8] lookup failed: markers=%d nooks=%d"
			% [markers.size(), nooks])
		return

	for child in players_node.get_children():
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

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	multiplayer_synchronizer.set_multiplayer_authority(1)

	shake_proximity.area_entered.connect(_on_shake_proximity_entered)
	shake_proximity.area_exited.connect(_on_shake_proximity_exited)

	camera.current = true

	if multiplayer.is_server():

		train.body_entered.connect(_on_train_body_entered)
		game_handler.cycle_finished.connect(_on_cycle_finished)

		safety_killbox.body_entered.connect(_on_safety_killbox_body_entered)

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

	if GameManager.local_game:

		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

func fade_in_ambience():
	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

	game_handler.set_player_count(
		PlayerManager.player_presences.keys().size()
	)

	round_number = _round_number
	total_rounds = _total_rounds
	minigame_overlay.set_round_rpc.rpc(_round_number, _total_rounds)

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func spawn_players():

	var player_spawn_positions = player_spawn_positions_node.get_children()
	player_spawn_positions.shuffle()

	player_count = PlayerManager.player_presences.size()


	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		players_node.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.set_marker_camera_from_path_rpc.rpc(camera.get_path())
		player_character.teleport_rpc.rpc(
			player_spawn_positions[counter].global_position
		)
		players[player_presence.network_id] = player_character
		add_active_player_rpc.rpc(player_presence.network_id)
		player_character.event_died.connect(_on_player_died)

		player_scores[player_presence.network_id] = 0

		counter += 1

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())



@rpc("authority", "call_local", "reliable")
func add_active_player_rpc(_network_id: int):

	for p in players_node.get_children():
		if p.player_presence.network_id == _network_id:
			active_players[_network_id] = p
			break

@rpc("authority", "call_local", "reliable")
func remove_active_player_rpc(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)

func _physics_process(delta: float) -> void :

	process_camera_shake(delta)

func process_camera_shake(_delta: float) -> void :

	if trains_in_proximity.is_empty():
		return

	var magnitude: float = 0.0
	for t in trains_in_proximity:
		var distance = (t.global_position - camera_base.global_position).length()

		magnitude += (1.0 - (distance / shake_proximity_radius)) * 0.1

	camera_shaker.intensity = magnitude

func check_game_end():

	if game_end:
		return

	if active_players.size() > 1:
		return

	game_end = true

	for i in dead_players.size():
		var network_id = dead_players[i]
		player_scores[network_id] = i

	for network_id in players.keys():
		if dead_players.has(network_id):
			continue
		player_scores[network_id] = player_count



	if active_players.size() == 1:
		if nook_handler.nooks_occupied_count == 1 and nook_handler.nooks_opened == 1:
			for active_player in active_players.values():
				active_player.trigger_achievement_rpc.rpc()
				break

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:
		player_instance.cleanup_rpc.rpc()
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

func _on_countdown_tick(time_left: int):
	super._on_countdown_tick(time_left)

	if time_left == 1:
		game_handler.nook_handler.reset_cycle()

func _on_countdown_expired():
	super._on_countdown_expired()
	for player in players.values():
		player.set_active_rpc.rpc(true)

	state_machine.transition_to_rpc.rpc(&"Play")

func _on_cycle_finished():

	# 8P MOD: elimination pacing is the thing to watch at eight players - the
	# nook count is fixed at 8, so the first cycles open one for everybody and
	# kill nobody. Host-only, which is correct here: this is the host's game
	# logic, not a scene change.
	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[TRAIN8] cycle rounds_passed=", game_handler.rounds_passed,
			" nooks_opened=", nook_handler.nooks_opened,
			" active=", active_players.size(),
			" dead=", dead_players.size())

	if game_end:
		return

	if active_players.size() <= 1:
		check_game_end()
		return

	game_handler.set_player_count(active_players.size())
	game_handler.cycle()

func _on_player_died(_network_id: int):
	remove_active_player_rpc.rpc(_network_id)

	if not dead_players.has(_network_id):
		dead_players.append(_network_id)

	check_game_end()

func _on_train_body_entered(body):

	if body is not TrainRacePlayer:
		return

	EffectManager.spawn_rpc.rpc(
		&"bloodmist_01", 
		body.global_position + (Vector3.UP * 1.5), 
		body.basis.z, 
		Vector3.ONE
	)

	body.kill_rpc.rpc()
	body.loose_hat_rpc.rpc()

func _on_shake_proximity_entered(area):

	trains_in_proximity.append(area)

func _on_shake_proximity_exited(area):

	trains_in_proximity.erase(area)

	if trains_in_proximity.is_empty():
		camera_shaker.intensity = 0.0

func _on_safety_killbox_body_entered(body):

	if body is not TrainRacePlayer:
		return

	body.kill_rpc.rpc()
