extends Minigame

class_name JunkPlatformMinigame

const player_scene = preload("uid://t7tv7x86oo7o")

@export_category("Nodes")
@export var players_node: Node3D
@export var player_spawn_position_node: Node3D
@export var junks_node: Node3D
@export var camera_base: Node3D
@export var visuals_base: Node3D
@export var camera_shaker: ShakerComponent3D
@export var camera: Camera3D
@export var platforms: Array[JunkPlatformPlatform]
@export var ambience_speaker_controllers: Array[SpeakerController]

@export_category("Components")
@export var junk_handler: JunkPlatformJunkHandler

@export_category("States")
@export var countdown_state: State

var players: Dictionary[int, JunkPlatformPlayer]
var active_players: Dictionary[int, JunkPlatformPlayer]

var dead_players: Array[int]
var player_scores: Dictionary[int, int]
var finished: bool = false

var player_count: int = 0

# --- 8P MOD ------------------------------------------------------------------
# Diagnostic only, gated behind -localtest; no gameplay effect at any roster
# size, so 1-4 player games stay vanilla.
#
# The platform deck is a CylinderShape3D of radius 6.0 centred on each Platform
# node, and the four shipped spawn markers sit exactly on those four centres.
# spawn_expand.py clones each marker 1.2u along its local X, so the added slots
# share a deck with an original - well inside the radius. This trace exists to
# prove that at runtime rather than on paper.
const MOD_PLATFORM_RADIUS: float = 6.0
# spawn_players() is host-only, so a host-side print says nothing about what
# clients see (UPDATING.md, "How to verify anything"). This audit runs on every
# peer and reads global_position, which setup_rpc replicates to all of them.
const MOD_AUDIT_DELAY: float = 6.0

func _mod_localtest_audit() -> void:
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[PLATFORM] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var centres: Array[Vector3] = []
	for p in platforms:
		if p != null:
			centres.append(p.global_position)

	var markers := 0
	if player_spawn_position_node != null:
		markers = player_spawn_position_node.get_child_count()

	print(tag, " markers=", markers, " platforms=", centres.size(),
		" spawned=", players_node.get_child_count())

	# A count of 0 anywhere above means a lookup failed silently.
	if centres.is_empty() or markers == 0:
		push_warning("[PLATFORM] lookup failed: markers=%d platforms=%d"
			% [markers, centres.size()])
		return

	for child in players_node.get_children():
		if not child is Node3D:
			continue
		var pos: Vector3 = (child as Node3D).global_position
		var best: float = -1.0
		var idx: int = -1
		for i in centres.size():
			var d := Vector2(pos.x - centres[i].x, pos.z - centres[i].z).length()
			if best < 0.0 or d < best:
				best = d
				idx = i
		print(tag, " player=", child.name,
			" pos=(%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z],
			" platform=", idx + 1, " dist=%.2f" % best,
			" ON_DECK" if best <= MOD_PLATFORM_RADIUS else " OFF_DECK")

func _ready() -> void :
	super._ready()

	camera.current = true

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	if multiplayer.is_server():

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

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

	round_number = _round_number
	total_rounds = _total_rounds
	minigame_overlay.set_round_rpc.rpc(_round_number, _total_rounds)

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func spawn_players():

	player_count = PlayerManager.player_presences.size()
	var spawn_positions: Array[Transform3D]
	for p in player_spawn_position_node.get_children():
		spawn_positions.append(p.global_transform)
	if GameManager.local_game:
		spawn_positions.shuffle()

	for i in PlayerManager.player_presences.size():
		var network_id = PlayerManager.player_presences.keys()[i]

		var camera_rotation: float = 0.0
		var position: Vector3 = spawn_positions[i].origin
		var player_character: JunkPlatformPlayer = player_scene.instantiate()
		players_node.add_child(player_character, true)

		junk_handler.add_spawn_point(
			network_id, 
			position + (Vector3.UP * 20.0)
		)

		player_character.network_id = network_id

		if position.z < 0:
			camera_rotation = 180.0

		if GameManager.local_game:
			camera_rotation = rad_to_deg(spawn_positions[i].basis.get_euler().y)

		if Array(OS.get_cmdline_args()).has("-localtest"):
			var spawn_marker: Node3D = player_spawn_position_node.get_child(i)
			print("[PLATFORM] assign slot=", i, " id=", network_id,
				" marker=", spawn_marker.name,
				" pos=(%.2f, %.2f, %.2f)" % [position.x, position.y, position.z],
				" camrot=", camera_rotation)

		player_character.set_player_presence.rpc(network_id)
		player_character.setup_rpc.rpc(
			position, camera_rotation
		)

		if not GameManager.local_game and camera_rotation > 0.0:

			if network_id == 1:
				camera_base.rotation_degrees.y = camera_rotation
				visuals_base.rotation_degrees.y = camera_rotation
				for j in platforms:
					j.damage_circle_parent = j.damage_circle_parent_flipped
					j.platform_visuals = j.platform_visuals_flipped
					j.assign_indicators()
					j.assign_flipped_compactor()
			else:
				rotate_camera_rpc.rpc_id(network_id, camera_rotation)

		player_character.emit_died.connect(_on_player_died)
		player_character.event_fallen.connect(_on_player_fallen)

		players[network_id] = player_character
		active_players[network_id] = player_character
		player_scores[network_id] = 0


func cleanup():

	if is_multiplayer_authority():
		queue_free()

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



@rpc("any_peer", "call_remote", "reliable")
func rotate_camera_rpc(_rotation: float):
	camera_base.rotation_degrees.y = _rotation
	visuals_base.rotation_degrees.y = _rotation
	for i in platforms:
		i.damage_circle_parent = i.damage_circle_parent_flipped
		i.platform_visuals = i.platform_visuals_flipped
		i.assign_indicators()
		i.assign_flipped_compactor()

@rpc("any_peer", "call_local", "reliable")
func shake_camera_rpc():
	camera_shaker.play_shake()

@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:
		player_instance.queue_free()
		players.erase(_network_id)
		active_players.erase(_network_id)

	if multiplayer.is_server():
		junk_handler.remove_spawn_point(_network_id)



func _on_countdown_expired():
	super._on_countdown_expired()

	for player in players.values():
		player.set_active_rpc.rpc(true)

	junk_handler.set_active(true)

	state_machine.transition_to_rpc.rpc(&"Play")

func _on_player_died(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)
		shake_camera_rpc.rpc()
		if not finished:
			dead_players.append(_network_id)

	junk_handler.remove_spawn_point(_network_id)

	check_game_end()

func _on_player_fallen(last_hit_by_network_id: int):

	if last_hit_by_network_id > 0:

		if GameManager.local_game:
			AchievementManager.set_achievement("ACH_03")
			return

		if players.has(last_hit_by_network_id):
			players[last_hit_by_network_id].trigger_achievement_rpc.rpc()

	pass
