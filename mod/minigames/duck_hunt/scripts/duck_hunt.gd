extends Minigame

class_name DuckHuntMinigame

const duck_player_scene = preload("uid://cav2dhye17owt")
const hunter_player_scene = preload("uid://bg7h0g6d2m2xu")

@export_category("Nodes")
@export var duck_player_spawn_parent: Node3D
@export var duck_player_spawn_positions: Node3D

@export var hunter_player_spawn_parent: Node3D
@export var hunter_player_spawn_position: Node3D

@export var finish_area: Area3D

@export var role_canvas: CanvasLayer
@export var ui_overlay: ColorRect
@export var ui_role_label: Label

@export var backup_camera: Camera3D
@export var backup_spectate_position_node: Node3D

@export_category("Local Nodes")
@export var local_handler: DuckHuntLocalHandler

@export_category("Components")

@export var light_parent_ducks_only: Node3D
@export var ambience_speaker_controllers: Array[SpeakerController]
@export var speaker_spectate1: AudioStreamPlayer
@export var speaker_spectate2: AudioStreamPlayer

@export_category("States")
@export var countdown_state: State

# --- 8P MOD ------------------------------------------------------------------
# Duck Hunt is 1 hunter + (N-1) DUCKS, not the "3 duck slots + 1 hunter" this
# mod's notes claimed for months. The hunter is popped from a shuffled pool and
# every remaining player is a duck, so the duck count already scales on its own.
# The only hard blocker was the spawn markers: the scene ships exactly THREE
# under Networked/DuckPlayerSpawner/DuckPlayerSpawnPositions, and spawn_players()
# reads `spawn_positions[counter]`. At five players `counter` reaches 3, the read
# runs off the end, the host's spawn loop aborts before the hunter is created,
# and the scene hangs - the Forklift Certified black-screen failure.
#
# Markers are created HERE, at runtime, gated on roster > 4 - never in the
# .tscn. That matters more than usual: the marker list is shuffle()d, so baking
# extras into the scene would let a 4-player game seat ducks on modded
# positions, which is the pre-existing deviation UPDATING.md documents for the
# other fifteen scenes. Creating them only above four means 1-4 sees the shipped
# three and nothing else, and Duck Hunt sidesteps that deviation entirely.
#
# Host-only is sufficient: clients never see a marker, only the position it
# resolves to, via `teleport_rpc.rpc(spawn_positions[counter].global_position)`.
#
# Placement keeps the shipped three exactly (x = -5, 0, +5 at z = 104) and
# interleaves up to four more at HALF the shipped spacing, alternating outward:
# x = +/-2.5 then +/-7.5. All seven sit on the same z, so every duck runs the
# same distance - a staggered second row would hand the front row a real head
# start over the 134-unit course.
#
# The span stays inside the FinishArea's half-width. That box is 23.5 x 7 x 5.5
# (duck_hunt.tscn), so +/-11.75 is provably traversable - every duck has to pass
# through it. Do not extend past it; the outer markers would start outside the
# finish corridor. The trace prints each x and flags anything outside.
const MOD_VANILLA_MARKERS: int = 3
const MOD_FINISH_HALF_WIDTH: float = 11.75
const MOD_SPACING_FRACTION: float = 0.5

# The marker trace above is host-only and reports what was *built*. This reports
# what actually *exists*, on every peer - the count of spawned duck nodes plus
# the hunter. Without it Duck Hunt rested on "no errors appeared", which is the
# proxy this file warns against everywhere else; seven ducks had only ever been
# confirmed by eye.
const MOD_AUDIT_DELAY: float = 6.0

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var ducks: int = 0
	var names: Array[String] = []
	if duck_player_spawn_parent != null:
		ducks = duck_player_spawn_parent.get_child_count()
		for c in duck_player_spawn_parent.get_children():
			names.append(str(c.name))

	var hunters: int = 0
	if hunter_player_spawn_parent != null:
		hunters = hunter_player_spawn_parent.get_child_count()

	var roster: int = PlayerManager.player_presences.size()

	print("[DUCK8] spawned is_server=", multiplayer.is_server(),
		" peer=", multiplayer.get_unique_id(),
		" roster=", roster,
		" ducks=", ducks, " hunters=", hunters,
		" expected_ducks=", maxi(roster - 1, 0),
		" nodes=", ", ".join(names))

	if ducks != maxi(roster - 1, 0) or hunters != 1:
		push_warning("[DUCK8] roster %d should give %d ducks + 1 hunter, got %d + %d"
			% [roster, maxi(roster - 1, 0), ducks, hunters])

func _mod_expand_spawn_markers() -> void :

	var roster: int = PlayerManager.player_presences.size()
	var needed: int = maxi(roster - 1, 1)

	var existing: Array[Node] = duck_player_spawn_positions.get_children()
	var before: int = existing.size()

	var trace := Array(OS.get_cmdline_args()).has("-localtest")

	if before == 0:
		push_warning("[DUCK8] no shipped spawn markers found - cannot expand")
		return

	# Vanilla path. At four players or fewer the shipped three already cover the
	# most ducks that can exist, so nothing is created and the scene is stock.
	if needed <= before:
		if trace:
			print("[DUCK8] markers roster=", roster, " ducks_needed=", needed,
				" markers=", before, " added=0 (vanilla)")
		return

	# Learn the row's spacing and depth from the shipped markers rather than
	# hardcoding 5.0 and z=104, so a level retune carries through.
	var base_z: float = (existing[0] as Node3D).position.z
	var xs: Array[float] = []
	for m in existing:
		xs.append((m as Node3D).position.x)
	xs.sort()

	var spacing: float = 5.0
	if xs.size() >= 2:
		var total: float = 0.0
		for i in range(1, xs.size()):
			total += xs[i] - xs[i - 1]
		spacing = total / float(xs.size() - 1)

	var step: float = spacing * MOD_SPACING_FRACTION
	var added: int = 0
	var slot: int = 1

	# Alternate outward from centre in half-spacing steps, skipping any x that
	# already has a shipped marker, and never leaving the finish corridor.
	while before + added < needed and slot < 64:
		for sign in [-1.0, 1.0]:
			if before + added >= needed:
				break
			var x: float = sign * step * float(slot)
			if absf(x) > MOD_FINISH_HALF_WIDTH:
				continue
			var clash := false
			for existing_x in xs:
				if absf(existing_x - x) < 0.01:
					clash = true
					break
			if clash:
				continue
			var marker := Marker3D.new()
			marker.name = "Marker3D_MOD%d" % (before + added + 1)
			duck_player_spawn_positions.add_child(marker)
			marker.position = Vector3(x, 0.0, base_z)
			xs.append(x)
			added += 1
		slot += 1

	if before + added < needed:
		push_warning("[DUCK8] only %d markers for %d ducks - the finish corridor (+/-%.2f) is full"
			% [before + added, needed, MOD_FINISH_HALF_WIDTH])

	if trace:
		var report: Array[String] = []
		var outside := 0
		for m in duck_player_spawn_positions.get_children():
			var mx: float = (m as Node3D).position.x
			report.append("%s=%.2f" % [m.name, mx])
			if absf(mx) > MOD_FINISH_HALF_WIDTH:
				outside += 1
		print("[DUCK8] markers roster=", roster, " ducks_needed=", needed,
			" markers=", before + added, " added=", added,
			" spacing=%.2f" % spacing, " z=%.2f" % base_z,
			" outside_gate=", outside,
			" [", ", ".join(report), "]")

var first_round: bool = true
var possible_hunters: Array[int]

var players: Array
var players_acknowledged: Array[int]
var duck_player_count: int = 0
var duck_players: Dictionary[int, DuckHuntDuckPlayer]
var hunter_player: DuckHuntHunterPlayer

var spectate_duck_players: Array[DuckHuntDuckPlayer]
var spectator_index: int = 0
var spectate_player: DuckHuntDuckPlayer
var is_spectating: bool = false

var is_hunter: bool = false

var players_shot: Array[int]
var current_round = 0
var resetting: bool = false

var players_finished: Array[int]
var player_scores: Dictionary[int, int]
var player_count: int
var hunter_name: String = ""

var last_spectate_camera_transform: Transform3D

var local_game_players_order: Dictionary

func _ready() -> void :
	super._ready()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	is_spectating = false
	PauseMenu.unpaused.connect(_on_unpaused)

	player_count = PlayerManager.player_presences.size()
	for key in PlayerManager.player_presences.keys():
		player_scores[key] = 0

	if multiplayer.is_server():

		for network_id in PlayerManager.player_presences.keys():
			possible_hunters.append(network_id)

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		finish_area.body_entered.connect(_on_finish_area_entered)

	if GameManager.local_game:

		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

		role_canvas.visible = false
		local_handler.canvas_layer.visible = true

func _process(_delta: float) -> void :

	if not is_spectating:
		return

	if spectate_duck_players.is_empty():
		if last_spectate_camera_transform:
			backup_camera.global_transform = last_spectate_camera_transform
		else:
			backup_camera.global_transform = backup_spectate_position_node.global_transform
		return
	else:
		if spectate_player:
			backup_camera.global_transform = spectate_player.camera.global_transform
			last_spectate_camera_transform = spectate_player.camera.global_transform

	var direction = 0
	var speaker = null
	if Input.is_action_just_pressed("action_1"):
		direction += 1
		speaker = speaker_spectate1
	if Input.is_action_just_pressed("action_2"):
		speaker = speaker_spectate2
		direction -= 1

	if direction != 0:
		if not spectate_duck_players.is_empty():
			var new_index = wrap(spectator_index + direction, 0, spectate_duck_players.size())
			if new_index != spectator_index:
				if speaker:
					speaker.volume_linear = 2
					speaker.play()
			spectator_index = new_index
			spectate_player = spectate_duck_players[spectator_index]

func fade_in_ambience():
	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)



func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

func cleanup():

	if is_multiplayer_authority():

		queue_free()

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())



func spawn_players():

	await get_tree().create_timer(1, false).timeout

	players_acknowledged.clear()

	if PlayerManager.player_presences.size() <= 1:
		force_game_end()
		return

	local_game_players_order.clear()
	for player_presence in PlayerManager.player_presences.keys():
		local_game_players_order[player_presence] = null


	possible_hunters.shuffle()
	var hunter_network_id = possible_hunters.pop_front()

	set_hunter_name_rpc.rpc(PlayerManager.player_presences[hunter_network_id].network_name)

	var player_presence: PlayerPresence

	set_ducks_ambient_light_rpc.rpc(hunter_network_id)

	# 8P MOD: must run BEFORE the marker list is read below. Host-only, like the
	# rest of spawn_players(), and a no-op at four players or fewer.
	_mod_expand_spawn_markers()

	var spawn_positions = duck_player_spawn_positions.get_children()
	spawn_positions.shuffle()


	var counter: int = 0
	for network_id in PlayerManager.player_presences.keys():

		if network_id == hunter_network_id:
			continue

		player_presence = PlayerManager.player_presences[network_id]

		var player_character: DuckHuntDuckPlayer = duck_player_scene.instantiate()
		duck_player_spawn_parent.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.teleport_rpc.rpc(
			spawn_positions[counter].global_position
		)
		duck_players[player_presence.network_id] = player_character
		players.append(player_character)
		player_character.dead.connect(_on_player_died)
		player_character.finished.connect(_on_player_finished)

		local_game_players_order[player_presence.network_id] = player_character

		if GameManager.local_game:
			acknowledge_role_rpc(network_id)

		counter += 1

	duck_player_count = duck_players.size()
	set_hunter_rpc.rpc(hunter_network_id)


	player_presence = PlayerManager.player_presences[hunter_network_id]
	var hunter_player_character = hunter_player_scene.instantiate()
	hunter_player_spawn_parent.add_child(hunter_player_character, true)

	hunter_player_character.set_player_presence.rpc(player_presence.network_id)
	hunter_player_character.setup_rpc.rpc(
		hunter_player_spawn_position.global_position, 
		duck_player_count
	)

	var hunter_initialization_delay = 8
	if current_round != 0: hunter_initialization_delay = 5
	hunter_player_character.initialize_hunter_rpc.rpc(hunter_initialization_delay)

	local_game_players_order[player_presence.network_id] = hunter_player_character
	hunter_player = hunter_player_character
	players.append(hunter_player_character)

	for network_id in duck_players.keys():
		duck_player_added_rpc.rpc(network_id)

	local_handler.set_players(local_game_players_order.values())

	_mod_apply_skipped_reveal()

# --- 8P MOD: `-startgame` leaves Duck Hunt permanently unplayable -------------
# `shared/states/round_state.gd` short-circuits Round -> Countdown whenever
# Globals.debug_skip_brief is set, skipping the RoleReveal state. That state is
# NOT purely presentational, which is what made this so easy to misread:
# `role_reveal_state.gd` holds the ONLY online call to
# `hunter_player.set_can_aim_rpc(true)` and `can_aim` defaults to false. (The
# other set_can_aim_rpc(true), in hunter_player.reveal_role(), is reached only
# from reveal_local() - the local-couch path, which this mod does not use.)
#
# So on the fast path the hunter can never aim or fire; no duck ever dies;
# check_game_end() never gets past `if not duck_players.is_empty() and
# hunter_player: return`; and there is no turn timer to break the deadlock. The
# minigame hangs forever. Measured 2026-08-05: 240s at 8 players sitting in Play
# with zero further state transitions. Duck Hunt is 4th in the rotation, so this
# also hung every START=1 rotation run before it could reach the other nine.
#
# It went unnoticed for three days because every START=1 run was killed by
# localtest.sh's duration long before anything needed Duck Hunt to *finish* -
# the traces fired at scene load and the session died. See UPDATING.md,
# "START=1 HANGS Duck Hunt permanently".
#
# This re-does exactly what the skipped state would have done, and only while
# the skip is active. A real session never sets debug_skip_brief, so 1-4 vanilla
# behaviour is untouched (rule 3). Called from the end of spawn_players(), which
# reset_state.gd re-runs for EVERY hunter turn - so each new hunter gets its aim
# enabled, not just the first.
func _mod_apply_skipped_reveal() -> void :

	if not Globals.debug_skip_brief:
		return

	if hunter_player:
		hunter_player.set_can_aim_rpc.rpc(true)

	zz_mod_clear_role_overlay_rpc.rpc()

# The role overlay is a per-peer node and reset_state.gd re-shows it on every
# peer at the start of each turn, so clearing it has to be an RPC. A local call
# would clear the host's and leave the other seven staring at a black screen -
# which is the same host-only trap documented under "Runtime scene changes must
# be RPCs, not local calls".
#
# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build.
@rpc("authority", "call_local", "reliable")
func zz_mod_clear_role_overlay_rpc() -> void :

	if ui_role_label:
		ui_role_label.visible = false
	if ui_overlay:
		ui_overlay.modulate.a = 0.0
		ui_overlay.visible = false

	# Printed HERE rather than in the host-only caller: the whole point is that
	# every peer's overlay clears, and a host-only line proves nothing about the
	# other seven (rule 4). `alpha` is read back after the write so the line
	# reports what the node actually holds, not what was asked for.
	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[DUCK8] skip-reveal is_server=", multiplayer.is_server(),
			" peer=", multiplayer.get_unique_id(),
			" overlay_visible=", ui_overlay.visible if ui_overlay else "NONE",
			" alpha=%.2f" % (ui_overlay.modulate.a if ui_overlay else - 1.0),
			" can_aim_sent=", hunter_player != null)

func force_game_end():

	player_scores_finalized.emit(player_scores)
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)
	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)

func fade_camera(set_to_backup: bool = false):

	ui_overlay.modulate.a = 0.0
	ui_role_label.visible = false
	ui_overlay.visible = true

	var t: = create_tween()
	t.tween_property(ui_overlay, "modulate:a", 1.0, 1.0)
	await t.finished

func check_game_end():

	if resetting:
		return

	if not duck_players.is_empty() and hunter_player:
		return

	if not possible_hunters.is_empty():
		resetting = true
		await get_tree().create_timer(3.0).timeout
		state_machine.transition_to_rpc.rpc(&"Reset")
	else:
		player_scores_finalized.emit(player_scores)
		await get_tree().create_timer(3.0).timeout
		set_minigame_sfx_linear_volume_rpc.rpc(0.0)
		state_machine.transition_to_rpc.rpc(&"Finished")
		set_effects_visibility_rpc.rpc(false)



@rpc("authority", "call_local", "reliable")
func set_hunter_name_rpc(_hunter_name: String):
	hunter_name = _hunter_name

@rpc("authority", "call_local", "reliable")
func set_ducks_ambient_light_rpc(_hunter_id):
	if multiplayer.get_unique_id() == _hunter_id:
		light_parent_ducks_only.visible = false
	else:
		light_parent_ducks_only.visible = true

@rpc("authority", "call_local", "reliable")
func duck_player_added_rpc(_network_id):

	if _network_id == multiplayer.get_unique_id():
		for duck_player in duck_player_spawn_parent.get_children():
			if duck_player.player_presence.network_id == _network_id:
				duck_player.finished.connect(_on_duck_player_spectate)
				duck_player.dead.connect(_on_duck_player_spectate)
				break
		return

	for duck_player in duck_player_spawn_parent.get_children():
		if not spectate_duck_players.has(duck_player):
			spectate_duck_players.append(duck_player)

@rpc("any_peer", "call_local", "reliable")
func set_hunter_rpc(_network_id):

	is_hunter = multiplayer.get_unique_id() == _network_id
	if is_hunter:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	acknowledge_role_rpc.rpc(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func acknowledge_role_rpc(_network_id: int):
	if not multiplayer.is_server():
		return

	players_acknowledged.append(_network_id)

	if players_acknowledged.size() == PlayerManager.player_presences.keys().size():
		if first_round:
			first_round = false
			state_machine.transition_to_rpc.rpc(&"Round", {"round": round_number, "total": total_rounds})
		else:
			state_machine.transition_to_rpc.rpc(&"RoleReveal")

@rpc("any_peer", "call_local", "reliable")
func remove_spectate_player_rpc(_network_id: int) -> void :

	if is_hunter:
		return

	var player_to_remove = null
	for duck_player in spectate_duck_players:
		if duck_player.player_presence.network_id == _network_id:
			player_to_remove = duck_player
			break

	var cycle_spectator_index: bool = false
	if is_spectating:
		for i in spectate_duck_players.size():
			var duck_player = spectate_duck_players[i]
			if _network_id == duck_player.player_presence.network_id:
				if spectator_index == i:
					cycle_spectator_index = true

		if spectate_duck_players.size() - 1 <= 0:
			cycle_spectator_index = true

	if player_to_remove:
		spectate_duck_players.erase(player_to_remove)

	if cycle_spectator_index:
		if spectate_duck_players.is_empty():
			fade_camera()
		else:
			spectator_index = wrap(spectator_index + 1, 0, spectate_duck_players.size())
			spectate_player = spectate_duck_players[spectator_index]

@rpc("any_peer", "call_local", "reliable")
func remove_player_rpc(_network_id: int):

	var player_instance = null
	for p in players:
		if p.player_presence.network_id == _network_id:
			player_instance = p
			break

	if player_instance:
		if player_instance is DuckHuntDuckPlayer:
			remove_spectate_player_rpc.rpc(_network_id)
			duck_players.erase(_network_id)
		if player_instance is DuckHuntHunterPlayer:
			hunter_player = null
			# 8P MOD: vanilla decremented `duck_player_count` here, but the
			# player leaving is the HUNTER - it was never counted as a duck.
			# The decrement corrupted the count the hunter's magazine size is
			# derived from. Wrong at any roster size; left as a no-op rather
			# than replaced, since nothing else needs adjusting on this path.

		player_instance.queue_free()
		players.erase(player_instance)

	possible_hunters.erase(_network_id)
	players_acknowledged.erase(_network_id)



func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	remove_player_rpc.rpc(_network_id)

	if multiplayer.is_server():
		await get_tree().create_timer(1.0).timeout
		check_game_end()

func _on_duck_player_spectate(_network_id):

	await get_tree().create_timer(1, false).timeout

	ui_overlay.modulate.a = 0.0
	ui_role_label.visible = false
	ui_overlay.visible = true

	var t: = create_tween()
	t.tween_property(ui_overlay, "modulate:a", 1.0, 1.0)
	await t.finished

	if spectate_duck_players.is_empty():
		return

	if _network_id == multiplayer.get_unique_id():
		is_spectating = true
		spectator_index = wrap(spectator_index + 1, 0, spectate_duck_players.size())
		spectate_player = spectate_duck_players[spectator_index]
		backup_camera.current = true
		var counter = 0
		for dp in spectate_duck_players:
			if dp == null:
				continue
			if dp.player_presence.network_id == _network_id:
				spectator_index = counter
				break
			counter += 1

	t = create_tween()
	t.tween_property(ui_overlay, "modulate:a", 0.0, 1.0)

func _on_finish_area_entered(body):

	if body is not DuckHuntDuckPlayer:
		return

	body.set_finished_rpc.rpc()

func _on_player_finished(_network_id: int):

	if duck_players.has(_network_id):
		duck_players.erase(_network_id)
		remove_spectate_player_rpc.rpc(_network_id)
		if players_finished.is_empty():
			players_finished.append(_network_id)
			player_scores[_network_id] += 1

		player_scores[_network_id] += 1

	check_game_end()

func _on_player_died(_network_id: int):

	# 8P MOD: `hunter_player` is set to null by remove_player_rpc when the hunter
	# disconnects, and vanilla dereferenced `.player_presence` unguarded on both
	# lines below - so a duck dying after the hunter left threw. Awarding the
	# points is skipped rather than deferred: with no hunter there is nobody to
	# credit, and the round is about to end anyway via check_game_end().
	var mod_hunter_id: int = -1
	if hunter_player != null and hunter_player.player_presence != null:
		mod_hunter_id = hunter_player.player_presence.network_id

	if duck_players.has(_network_id):
		duck_players.erase(_network_id)
		remove_spectate_player_rpc.rpc(_network_id)
		if mod_hunter_id != -1:
			player_scores[mod_hunter_id] += 1

	players_shot.append(_network_id)

	if players_shot.size() == (player_count - 1):
		if mod_hunter_id != -1:
			player_scores[mod_hunter_id] += 1

	check_game_end()

func _on_countdown_expired():
	super._on_countdown_expired()

	state_machine.transition_to_rpc.rpc(&"Play")

func _on_unpaused():

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
