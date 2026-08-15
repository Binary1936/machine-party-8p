extends Minigame

class_name KnifeAtTheOfficeMinigame

const player_scene = preload("res://minigames/knife_at_the_office/components/player/knife_at_the_office_player.tscn")
const searchable_scene = preload("res://minigames/knife_at_the_office/components/searchable/searchable.tscn")

@export_category("Networked Components")
@export var player_spawn_node: Node3D
@export var player_spawn_positions_node: Node3D

@export_category("Components")
@export var light_handler: KnifeAtTheOfficeLightHandler
@export var countdown_handler: KnifeAtTheOfficeCountdownHandler
@export var anim_projector_hide_hunt: AnimationPlayer

@export_category("Local Nodes")
@export var local_root_node: Node3D
@export var local_handler: KnifeAtTheOfficeLocalHandler
@export var fow_meshes: Array[MeshInstance3D]
@export var local_audio_listener: AudioListener3D

@export_category("Game Settings")
@export var items_to_spawn: int = 2

@export_category("States With Signals")
@export var countdown_state: State

@export_category("Audio")
@export var speaker_syringe_found: AudioStreamPlayer
@export var ambience_speaker_controllers: Array[SpeakerController]

var players: Dictionary[int, KnifeAtTheOfficePlayer]
var infected_players: Array[int]
var killed_players: Array[int]
var active_players: Dictionary[int, KnifeAtTheOfficePlayer]

var hunting_phase: bool = false
var searching_disabled: bool = false

var searchables: Array[KnifeAtTheOfficeSearchable]
var containers_searched: int = 0
var guaranteed_search_result: int = -1

var projector_started = false

var player_count: int = 0
var player_scores: Dictionary[int, int]
var dead_players: Array[int]

# --- 8P MOD ------------------------------------------------------------------
# `guaranteed_search_result` is the running total of container searches after
# which the syringe turns up. Vanilla scales it by `players / 4` off a
# hardcoded `searchable_count = 26`, but a container can only ever be searched
# once (`searchable.searched` is set true and never reset), so the level's
# actual container count is a hard ceiling on that total.
#
# The office holds 36 searchables (26 cabinet_single_dynamic + 3
# drawer_desk_dynamic x 2 + 4 placed directly). At six or more players the
# scaled target can exceed 36, and then the syringe is never found: the hunting
# phase never starts, no timer is ever armed, and the round simply never ends.
# There is no crash and no log line - the players just search an empty office.
#
# Clamped rather than rescaled, so the developers' intent (more players =>
# proportionally more searches, keeping the search phase the same length in
# wall-clock time) is preserved wherever it is actually satisfiable. The margin
# leaves a couple of containers spare so the find is not forced to be the very
# last one in the level.
#
# Counted at runtime rather than hardcoded: an art pass that adds or removes
# cabinets must not silently reintroduce the stall.
const MOD_SEARCH_MARGIN: int = 2

# spawn_expand.py places the four added markers 1.2u outboard of the shipped
# ones, which can put a clone inside a desk or a wall. Physics then shoves the
# player clear, so the tell is a player standing well away from every marker -
# not an error. Audited on every peer, because spawn_players() is host-only and
# a host print says nothing about what clients see.
const MOD_AUDIT_DELAY: float = 6.0
const MOD_DISPLACED_DIST: float = 2.0
const MOD_FELL_THROUGH_Y: float = - 3.0

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[KATO8] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var markers: Array[Node] = []
	if player_spawn_positions_node != null:
		markers = player_spawn_positions_node.get_children()

	print(tag, " markers=", markers.size(),
		" spawned=", player_spawn_node.get_child_count())

	if markers.is_empty():
		push_warning("[KATO8] no spawn markers found")
		return

	for child in player_spawn_node.get_children():
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

# Host-only, deliberately. `guaranteed_search_result` is read only inside
# `request_item_find_rpc`, which returns early on non-servers, so unlike a
# scene change this needs no RPC to be correct everywhere.
func _mod_collect_searchables(_node: Node, _out: Array[KnifeAtTheOfficeSearchable]) -> void :

	if _node is KnifeAtTheOfficeSearchable:
		_out.append(_node)

	for c in _node.get_children():
		_mod_collect_searchables(c, _out)

func _ready() -> void :
	super._ready()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	if multiplayer.is_server():

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		countdown_handler.expired.connect(_on_game_countdown_expired)

	if GameManager.local_game:

		await get_tree().create_timer(1.0).timeout
		local_root_node.visible = true
		local_handler.local_after_post_processing_canvas.visible = true
		local_handler.canvas_layer.visible = true
		minigame_ready.emit(1)

		local_audio_listener.make_current()

func _process(delta: float) -> void :

	if not GameManager.local_game:
		return

	if players.is_empty():
		return

	var positions: Array[Vector3]
	for p in players.values():
		positions.append(p.global_position)
	var position_count: int = positions.size()

	var sum: Vector3 = positions.pop_front()
	for p in positions:
		sum += p
	var avg_position: Vector3 = sum / position_count

	local_audio_listener.global_position = local_audio_listener.global_position.move_toward(
		avg_position, delta * 128.0
	)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func fade_in_ambience():

	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)

func spawn_players():

	var spawn_positions = player_spawn_positions_node.get_children()
	spawn_positions.shuffle()


	var searchable_count: int = 26
	var player_ratio: float = PlayerManager.player_presences.size() / float(4)
	var searchable_base: int = round(searchable_count * player_ratio)
	var random_removal: int = round((searchable_base * 0.5) * randf())
	guaranteed_search_result = searchable_base - random_removal

	# 8P MOD: clamp the target to a total that is actually reachable. No-op at
	# four players or fewer, where the target tops out at 26 against 36
	# containers.
	searchables.clear()
	_mod_collect_searchables(self, searchables)
	var mod_reachable: int = max(searchables.size() - MOD_SEARCH_MARGIN, 1)
	var mod_clamped: bool = guaranteed_search_result > mod_reachable
	if mod_clamped:
		guaranteed_search_result = mod_reachable

	# 8P MOD, test aid: nobody plays in a localtest run, so containers are never
	# searched and the hunting phase - the half of this minigame that holds the
	# alive-indicator bug - is unreachable. `-kato-target=N` shortens the search
	# phase so one driven window can trigger it. Gated behind -localtest, so it
	# is inert in a shipped build, same as `-minigame` and `-fullflow`.
	if Array(OS.get_cmdline_args()).has("-localtest"):
		for arg in OS.get_cmdline_args():
			if arg.begins_with("-kato-target="):
				guaranteed_search_result = maxi(int(arg.split("=")[1]), 1)
				mod_clamped = false
				print("[KATO8] target overridden to ", guaranteed_search_result)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[KATO8] search is_server=", multiplayer.is_server(),
			" roster=", PlayerManager.player_presences.size(),
			" markers=", spawn_positions.size(),
			" searchables=", searchables.size(),
			" base=", searchable_base,
			" target=", guaranteed_search_result,
			" clamped=", mod_clamped)

	var counter: int = 0
	for key in PlayerManager.player_presences.keys():
		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		player_spawn_node.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.set_game_reference_from_path.rpc(self.get_path())
		player_character.teleport_rpc.rpc(
			spawn_positions[counter].global_position, 
			spawn_positions[counter].global_rotation, 
		)

		players[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character

		player_character.item_found.connect(_on_item_found)
		player_character.infected.connect(_on_player_infected)
		player_character.dead.connect(_on_player_died)

		player_scores[player_presence.network_id] = 0

		counter += 1

	if GameManager.local_game:
		local_handler.set_players(players.values())

		for i in players.size():
			var network_id = players.keys()[i]
			var player = players[network_id]
			var starting_layer = 11 + (i * 2)
			player.set_local_values(starting_layer)
			for mesh in fow_meshes:
				mesh.set_layer_mask_value(starting_layer, true)

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())

func check_game_end():

	if active_players.size() <= 1:
		await get_tree().create_timer(1.0).timeout
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("MINIGAME_SFX"), 0.0)
		MusicManager.start_playing_music_host(true, 3, false, 3)
		end_game()
		return

	if infected_players.size() < active_players.size():
		return

	await get_tree().create_timer(3.0).timeout

	countdown_handler.anim_fade.play("fade out")
	MusicManager.start_playing_music_host(true, 3, false, 3)

	end_game()

func end_game():

	for p in players.values():
		p.set_active_rpc.rpc(false)

	await get_tree().create_timer(1.0).timeout

	for p in players.values():
		if infected_players.has(p.player_presence.network_id):
			continue
		player_scores[p.player_presence.network_id] += 1
	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(1.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)

func start_2nd_phase_music():
	MusicManager.stop_playing_music(3)
	MusicManager.play_kato_2nd_phase_music()
	speaker_syringe_found.play()

	for player: KnifeAtTheOfficePlayer in player_spawn_node.get_children():
		if !player.is_infected:
			player.camera_zoom_in()


func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	remove_player_rpc.rpc(_network_id)
	await get_tree().create_timer(1.0).timeout

	check_game_end()



@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:

		player_instance.cleanup_rpc.rpc()
		player_instance.queue_free()

		player_scores.erase(_network_id)
		players.erase(_network_id)
		active_players.erase(_network_id)


@rpc("any_peer", "call_local", "reliable")
func start_projector_hide_hunt_loop_rpc():
	for player: KnifeAtTheOfficePlayer in player_spawn_node.get_children():
		if player.is_infected:
			continue
		player.player_name_label.animation_player.play("hide name")
	anim_projector_hide_hunt.play("loop")
	start_2nd_phase_music()

@rpc("any_peer", "call_local", "reliable")
func set_searching_disabled_rpc(state: bool):
	searching_disabled = state

@rpc("any_peer", "call_local", "reliable")
func enable_player_fow_rpc():

	for p in players.values():
		p.set_fow_rpc.rpc(true)

@rpc("any_peer", "call_local", "reliable")
func request_item_find_rpc(_network_id: int):

	if not multiplayer.is_server():
		return

	containers_searched += 1

	if GameManager.local_game:

		if containers_searched == guaranteed_search_result:
			players[_network_id].search_result_rpc(true)
		else:
			players[_network_id].search_result_rpc(false)

		return

	if containers_searched == guaranteed_search_result:
		players[_network_id].search_result_rpc.rpc(true)
	else:
		players[_network_id].search_result_rpc.rpc(false)



@rpc("any_peer", "call_local", "reliable")
func _on_item_found(_network_id):

	if not infected_players.has(_network_id):
		infected_players.append(_network_id)

	if !projector_started:
		start_projector_hide_hunt_loop_rpc.rpc()
	projector_started = true
	await get_tree().create_timer(1.5).timeout

	if not hunting_phase:
		hunting_phase = true

		player_scores[_network_id] += 1
		set_searching_disabled_rpc.rpc(true)

		light_handler.transition_to_dark_rpc.rpc()
		await get_tree().create_timer(3.0).timeout
		countdown_handler.set_active_rpc.rpc(active_players.size() - 1)
		enable_player_fow_rpc.rpc()

# 8P MOD, test aid: `-kato-hunt=N` makes the host enter the hunting phase N
# seconds after the round starts, through the real entry point - the same
# `_on_item_found` the search signal calls - so `set_active_rpc` runs with the
# real `active_players.size() - 1` on every peer. Without it the whole second
# half of this minigame, and the alive-indicator cap that lived there, is
# unreachable in an unattended run. Host-only and gated behind -localtest.
func _mod_force_hunt(_delay: float) -> void :
	await get_tree().create_timer(_delay).timeout

	if active_players.is_empty():
		push_warning("[KATO8] forced hunt: nobody left to infect")
		return

	print("[KATO8] forcing hunting phase after ", _delay, "s (test aid)",
		" active=", active_players.size())
	_on_item_found(active_players.keys()[0])

func _on_player_infected(_network_id: int, _by_network_id: int):

	if not infected_players.has(_network_id):
		infected_players.append(_network_id)
		if GameManager.local_game:
			local_handler.player_infected(players[_network_id])

	if multiplayer.is_server():

		player_scores[_by_network_id] += 1
		countdown_handler.update_alive_indicator_rpc.rpc(active_players.size() - infected_players.size())

		await get_tree().create_timer(1.0).timeout

		check_game_end()

func _on_player_died(_network_id: int, _by_network_id):
	killed_players.append(_network_id)

	await get_tree().create_timer(3.0).timeout

	check_game_end()

func _on_game_countdown_expired():
	MusicManager.start_playing_music_host(true, 3, false, 3)
	end_game()

func _on_all_brief_ready():

	await get_tree().create_timer(1.0).timeout
	state_machine.transition_to_rpc.rpc(&"Round")

func _on_countdown_expired():
	super._on_countdown_expired()

	for player in players.values():
		player.set_active_rpc.rpc(true)

	if multiplayer.is_server() and Array(OS.get_cmdline_args()).has("-localtest"):
		for arg in OS.get_cmdline_args():
			if arg.begins_with("-kato-hunt="):
				_mod_force_hunt(maxf(float(arg.split("=")[1]), 0.0))

	state_machine.transition_to_rpc.rpc(&"Play")
