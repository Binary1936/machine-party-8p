extends Minigame

class_name DiscoDodgeMinigame

const player_scene = preload("res://minigames/disco_dodge/components/player/disco_dodge_player.tscn")
const tile_scene = preload("res://minigames/disco_dodge/components/tile/disco_dodge_tile.tscn")

const tile_colors: Array[Color] = [
	Color("#4deeea"), 
	Color("#74ee15"), 
	Color("#ffe700"), 
	Color("#f000ff"), 
	Color("#001eff"), 
]

enum symbols{
	CROSS, 
	SQUARE, 
	CIRCLE, 
}

const tile_symbols: Array[symbols] = [
	symbols.CROSS, 
	symbols.SQUARE, 
	symbols.CIRCLE, 
]

@export_category("Piston Mechanism")
@export var delay_between_tile_placement: float

@export_category("Gameplay")
@export var tile_size: float = 4.0
@export var tiles_to_remove: int = 6

@export_category("Signal States")
@export var countdown_state: State
@export var play_state: State

@export_category("Networked Nodes")
@export var players_node: Node3D
@export var tile_parent_node: Node3D
@export var player_spawn_positions_node: Node3D

@export_category("Components")
@export var multiplayer_synchronizer: MultiplayerSynchronizer
@export var bounds_area: Area3D
@export var bounds_collision_shape: CollisionShape3D

@export var tile_rows: int = 20
@export var tile_columns: int = 12

@export_category("Display")
@export var display1_symbols: Array[Node3D]
@export var display2_symbols: Array[Node3D]
@export var anim_display: AnimationPlayer
@export var anim_sparks: AnimationPlayer
@export var particle_sparks: GPUParticles3D

@export_category("Audio")
@export var speaker_show_symbol: AudioStreamPlayer
@export var speaker_show_symbol_last: AudioStreamPlayer
@export var speaker_tiles_fall: AudioStreamPlayer
@export var speaker_display_bootup: AudioStreamPlayer
@export var ambience_speaker_controllers: Array[SpeakerController]

var players: Dictionary[int, DiscoDodgePlayer]
var active_players: Dictionary[int, DiscoDodgePlayer]
var scoring_players: Array[int]
var dead_players: Array[int]
var player_scores: Dictionary[int, int]
var finished: bool = false
var player_count: int = 0

var tiles: Array[Array]
var tile_nodes: Array[DiscoDodgeTile]

var armed_tiles_index_array: Array[int]
var game_end: bool = false



var ach_tile_limit: int = 10

# --- 8P MOD ------------------------------------------------------------------
# Diagnostic only, gated behind -localtest; no gameplay change at any roster
# size, so 1-4 player games stay vanilla.
#
# Stable Footing's only mod change is `MultiplayerSpawner.spawn_limit` 4 -> 8 in
# disco_dodge.tscn. That bug is uniquely hard to see: Godot silently refuses
# spawns past the cap - no error, the node just never appears - and the only
# symptom is a downstream "Node not found" for some *other* peer's synchroniser,
# which is the same message replication churn produces harmlessly all the time.
#
# So "the run had no errors" is NOT evidence that eight players spawned, and for
# a long time that absence was the only evidence this minigame had. This trace
# counts the player nodes that actually exist, on every peer, so the claim rests
# on a positive number instead of a missing error. `spawned=8` on a client is
# the thing to look for; anything less means the cap is back.
const MOD_AUDIT_DELAY: float = 6.0

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[DISCO8] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var markers := 0
	if player_spawn_positions_node != null:
		markers = player_spawn_positions_node.get_child_count()

	var spawned := 0
	var names: Array[String] = []
	if players_node != null:
		spawned = players_node.get_child_count()
		for c in players_node.get_children():
			names.append(str(c.name))

	print(tag, " roster=", PlayerManager.player_presences.size(),
		" markers=", markers, " spawned=", spawned,
		" nodes=", ", ".join(names))

	if markers == 0 or spawned == 0:
		push_warning("[DISCO8] lookup failed: markers=%d spawned=%d"
			% [markers, spawned])

func _ready() -> void :
	super._ready()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	if multiplayer.is_server():

		multiplayer_synchronizer.set_multiplayer_authority(multiplayer.get_unique_id())

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

	if GameManager.local_game:

		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()
	spawn_tiles()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func cleanup():

	if is_multiplayer_authority():
		multiplayer_synchronizer.free()
		queue_free()

func fade_in_ambience():
	pass
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
		player_character.teleport_rpc.rpc(
			player_spawn_positions[counter].global_position
		)
		players[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character
		player_character.died.connect(_on_player_died)

		player_scores[player_presence.network_id] = 0

		counter += 1

func spawn_tiles():

	var start_columns: float = - (tile_columns * 0.5) * tile_size + (tile_size * 0.5)
	var start_rows: float = - (tile_rows * 0.5) * tile_size + (tile_size * 0.5)

	var counter: int = 0
	for y in tile_columns:
		tiles.append([])
		for x in tile_rows:

			var position = Vector3(
				start_rows + (x * tile_size), 
				0.0, 
				start_columns + (y * tile_size)
			)

			var tile: DiscoDodgeTile = tile_scene.instantiate()
			tile_parent_node.add_child(tile, true)
			tile.setup_rpc.rpc(counter, tile_size, position)
			tiles[y].append(tile)

			counter += 1

			await get_tree().physics_frame

	register_tile_nodes_rpc.rpc()

func start_pattern():
	if !multiplayer.is_server(): return
	var tile_symbols_temp = []
	var tiles_data: Array[int]

	for i in tile_symbols.size():
		tile_symbols_temp.append(i)

	for i in range(3, 0, -1):
		for y in tiles.size():
			for x in tiles[y].size():
				if tile_symbols_temp.is_empty():
					for j in tile_symbols.size():
						tile_symbols_temp.append(j)
					tile_symbols_temp.shuffle()

				tiles_data.append(tile_symbols_temp.pop_front())

		set_tile_symbols_rpc.rpc(tiles_data, true, 0.8)
		tiles_data.clear()

		var rand_symbol = randi() % tile_symbols.size()
		for z in display1_symbols:
			z.visible = false
		display1_symbols[rand_symbol].visible = true
		for z in display2_symbols:
			z.visible = false
		display2_symbols[rand_symbol].visible = true

		if get_tree() == null: return
		await get_tree().create_timer(1.0).timeout

	var safe_symbol_index = randi() % tile_symbols.size()

	for y in tiles.size():
		for x in tiles[y].size():
			if tile_symbols_temp.is_empty():
				for j in tile_symbols.size():
					tile_symbols_temp.append(j)
				tile_symbols_temp.shuffle()

			tiles_data.append(tile_symbols_temp.pop_front())

	set_tile_symbols_rpc.rpc(tiles_data, false, 0, safe_symbol_index)

	if get_tree() == null: return
	await get_tree().create_timer(3).timeout

	arm_tiles_by_symbol_index_rpc.rpc(safe_symbol_index)
	if get_tree() == null: return
	await get_tree().create_timer(3.0).timeout

	check_game_end_on_cycle()

func check_game_end_on_cycle():

	if game_end:
		return


	if active_players.size() <= 1:
		game_end = true


		await get_tree().create_timer(3.0).timeout

		calculate_score()

		finish_game()
		return

	armed_tiles_index_array.shuffle()
	var num_of_tiles_to_remove_from_play = min(armed_tiles_index_array.size(), tiles_to_remove)
	var tile_indexes_to_remove_from_play = []
	for i in num_of_tiles_to_remove_from_play:
		tile_indexes_to_remove_from_play.append(
			armed_tiles_index_array.pick_random()
		)

	place_tiles_back_rpc.rpc(armed_tiles_index_array, tile_indexes_to_remove_from_play)
	await get_tree().create_timer(7.0, false).timeout

	start_pattern()

func check_game_end_on_death():

	if game_end:
		return

	if active_players.size() != 1:
		return

	game_end = true


	await get_tree().create_timer(3.0).timeout

	calculate_score()

	finish_game()

func calculate_score():

	if finished:
		return

	finished = true

	for i in dead_players.size():
		player_scores[dead_players[i]] = i

	for network_id in active_players.keys():
		player_scores[network_id] = player_count


		break

	player_scores_finalized.emit(player_scores)

func finish_game():

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)
	state_machine.transition_to_rpc.rpc(&"Finish")
	set_effects_visibility_rpc.rpc(false)



@rpc("any_peer", "call_local", "reliable")
func register_tile_nodes_rpc():
	for c in tile_parent_node.get_children():
		tile_nodes.append(c)

@rpc("any_peer", "call_local", "reliable")
func set_tile_symbols_rpc(
	symbol_indices: Array[int], 
	_fade: bool, 
	_duration: float = 1.0, 
	_safe_symbol_index: int = -1, 
):

	if _safe_symbol_index != -1:
		speaker_show_symbol_last.play()
		anim_display.play("RESET")
		anim_sparks.play("RESET")

		anim_sparks.play("sparks")
		particle_sparks.emitting = false
		particle_sparks.restart()
		particle_sparks.emitting = true
	else:
		speaker_show_symbol.play()
		anim_display.play("RESET")
		anim_display.play("fade out")

		anim_sparks.play("RESET")
		anim_sparks.play("sparks")
		particle_sparks.emitting = false
		particle_sparks.restart()
		particle_sparks.emitting = true

	for i in symbol_indices.size():
		if tile_nodes[i].is_tile_removed_from_play:
			continue

		tile_nodes[i].set_symbol_by_index(symbol_indices[i], _fade, _duration)
		if _duration != 0:
			tile_nodes[i].play_anim_fade_out()
		else:
			tile_nodes[i].anim_tile_emission.play("RESET")

	var display_symbol = symbol_indices[0]
	if _safe_symbol_index != -1: display_symbol = _safe_symbol_index

	for i in display1_symbols:
		i.visible = false
	display1_symbols[display_symbol].visible = true
	for i in display2_symbols:
		i.visible = false
	display2_symbols[display_symbol].visible = true

@rpc("any_peer", "call_local", "reliable")
func arm_tiles_by_symbol_index_rpc(_safe_symbol_index: int):
	armed_tiles_index_array = []
	for tile in tile_nodes:
		if tile.symbol_index != _safe_symbol_index:
			if tile.is_tile_removed_from_play: continue
			tile.arm()
			armed_tiles_index_array.append(tile.tile_index)
	await get_tree().create_timer(0.08, false).timeout
	speaker_tiles_fall.play()

@rpc("authority", "call_local", "reliable")
func place_tiles_back_rpc(tile_index_array: Array[int], tile_indexes_removed_from_play):
	var is_first_tile = true
	var last_tile_index = tile_index_array[tile_index_array.size() - 2]
	for tile_index in tile_index_array:
		for tile in tile_nodes:
			if tile.tile_index == tile_index:

				if tile.tile_index in tile_indexes_removed_from_play:
					tile.is_tile_removed_from_play = true

				tile.bring_back_tile()
				if is_first_tile:
					await get_tree().create_timer(1, false).timeout
					is_first_tile = false
				else:
					if tile.tile_index == last_tile_index:
						await get_tree().create_timer(0.8, false).timeout
					else:
						await get_tree().create_timer(delay_between_tile_placement, false).timeout
				break

	if multiplayer.is_server():
		var counter: int = 0
		for tile in tile_nodes:
			if tile.is_tile_removed_from_play:
				continue
			counter += 1

		if counter <= ach_tile_limit:
			for player in active_players.values():
				player.trigger_achievement_rpc.rpc()


@rpc("authority", "call_local", "reliable")
func turn_on_displays_rpc():
	speaker_display_bootup.play()
	for i in display1_symbols:
		i.visible = false
	display1_symbols[0].visible = true
	for i in display2_symbols:
		i.visible = false
	display2_symbols[0].visible = true
	await get_tree().create_timer(0.04, false).timeout
	for i in display1_symbols:
		i.visible = false
	display1_symbols[0].visible = false
	for i in display2_symbols:
		i.visible = false
	display2_symbols[0].visible = false
	await get_tree().create_timer(0.04, false).timeout
	for i in display1_symbols:
		i.visible = false
	display1_symbols[0].visible = true
	for i in display2_symbols:
		i.visible = false
	display2_symbols[0].visible = true

@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:
		if multiplayer.is_server():
			players[_network_id].queue_free()
			players.erase(_network_id)
			active_players.erase(_network_id)
			scoring_players.erase(_network_id)



func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	remove_player_rpc.rpc(_network_id)

	if multiplayer.is_server():
		await get_tree().create_timer(1.0).timeout
		check_game_end_on_death()

func _on_player_died(_network_id: int):
	active_players.erase(_network_id)

	if not dead_players.has(_network_id):
		dead_players.append(_network_id)

	check_game_end_on_death()

func _on_all_brief_ready():

	await get_tree().create_timer(1.0).timeout
	state_machine.transition_to_rpc.rpc(&"Round")

func _on_countdown_expired():
	super._on_countdown_expired()
	for player in players.values():
		player.set_active_rpc.rpc(true)

	state_machine.transition_to_rpc.rpc(&"Play")

	if multiplayer.is_server():
		await get_tree().create_timer(1, false).timeout
		turn_on_displays_rpc.rpc()
		await get_tree().create_timer(1, false).timeout
		start_pattern()
