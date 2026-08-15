extends Minigame

class_name BurnRecycleMinigame

const player_scene = preload("uid://bpek5gf5j3uvq")
const burn_recycle_launched_item = preload("uid://rf7b70eld6jw")

enum ItemTypes{
	Burn0, Burn1, Burn2, Burn3, Recycle0, Recycle1, Recycle2, Recycle3
}

# --- 8P MOD: THE FILTER as TWO ROOMS (prototype) -----------------------------
# THE FILTER is built for exactly four players: four belts, four presses, four
# indicators, and players told apart only by `90.0 * counter` yaw, which wraps
# at eight. An earlier attempt cloned the stations into the SAME ring at 45
# degrees; it worked mechanically and looked wrong - the consoles interpenetrate,
# because the shipped art already fills the ring at four.
#
# So instead of eight stations in one room, this builds a SECOND ROOM offset in
# space and seats players 5-8 in it, at the shipped 90-degree spacing. Each room
# is geometrically vanilla.
#
# What that buys, beyond the clipping:
#   * the four authored camera clips ("look self/left/center/right") stay EXACT,
#     because within a room every other player is still 90 or 180 degrees away;
#   * there is still ONE script, ONE StateMachine, ONE MinigameOverlay and ONE
#     MultiplayerSpawner, so no new replication surface and no way for the two
#     rooms' rounds to drift apart.
#
# The lighting comes free: all six OmniLights, the incinerator and the main wall
# live under `clientside visuals parent`, which vanilla already ROTATES to face
# the local player's seat. It is per-viewer, not per-room, so it just needs to be
# moved to the room the local player is in as well as rotated - see
# `setup_clientside_visuals()` in burn_recycle_player.gd.
#
# Elimination is PER ROOM: each room eliminates its own player each round, so a
# room of four resolves in three rounds as vanilla does, rather than the seven a
# single pooled ladder of eight would take. Rooms are balanced (5 -> 3+2,
# 7 -> 4+3) so nobody is ever alone in a room and handed a free win.
#
# Scoring stays GLOBAL - a player's score is their place in the overall
# elimination order, not their place within their room - with same-round
# eliminations tied upward; see `mod_death_score`. Both room winners take the
# full `player_count`, which is a deliberate accepted asymmetry at odd rosters:
# at seven, room B's winner outlasts two players and room A's outlasts three,
# and both score seven.
const MOD_SEATS_PER_ROOM: int = 4
const MOD_MAX_ROOMS: int = 2
# Far enough that nothing of room A is in frame from room B. Nothing renders in
# between, so a generous gap costs nothing.
const MOD_ROOM_OFFSET: Vector3 = Vector3(0.0, 0.0, 200.0)
const MOD_DEATH_PRESS_SCENE: PackedScene = preload("res://minigames/burn_recycle/instances/burn_recycle_death_press.tscn")

# Whole sibling subtrees that make up one room. `clientside visuals parent` is
# NOT here on purpose (it follows the viewer) and neither is anything logical -
# StateMachine, Networked, MinigameOverlay, WorldEnvironment all stay single.
const MOD_ROOM_SUBTREES: Array[String] = [
	"burn recycle visuals final",
	"burn recycle visuals blockout",
	"belts",
	"indicators parent",
	"TimerVisuals",
]
# NOT duplicated, and the reason is worth keeping: `player spawn parent` holds
# four instances of burn_recycle_player.tscn - the PLAYER SCENE itself, as
# editor placeholders. It is never referenced by spawn_players(), so copying it
# was pure defensiveness, and it cost 256 errors a run: each copy starts its own
# SkeletonIK3D in _ready() ("Attempt to disconnect a nonexistent connection from
# 'Skeleton3D'") and runs the manager handoff `get_node(<absolute path>)` while
# detached ("Can't use get_node() with absolute paths from outside the active
# scene tree"), 128 of each at eight players.
#
# It was first written off as pre-existing teardown churn on the arithmetic
# 8 peers x 8 players x 2 IK nodes, and on a grep for `type="Skeleton3D"` in
# this scene returning zero. Both were wrong: the grep cannot see inside
# INSTANCED sub-scenes, and a matched set of controls - DiscoDodge@8,
# ExplodingCollarRace@8 and BurnRecycle@4 - produced 0/0 while BurnRecycle@8
# produced 128/128. The errors appear if and only if room B is built.

var mod_room_count: int = 1
var mod_rooms_built: bool = false
var mod_extra_timer_labels: Array[Label3D] = []

# 8P MOD: network_id -> the score that player is owed for being eliminated.
# Vanilla derives it from position in `dead_players`, which with two rooms gives
# two players knocked out at the SAME moment different scores - and always in
# room order, so room A was systematically a point worse off. Since one raw
# point is 85 session points, that was worth as much as an entire place.
#
# Everyone eliminated in the same round now takes the HIGHEST index of that
# round's batch, so simultaneous eliminations score identically and the tie
# resolves upward. Deliberately not a shuffle: a shuffle only makes the
# unfairness random, whereas this removes it, and it needs no RNG so a replay
# of the same round scores identically.
#
# With ONE room a batch always holds exactly one victim, so the recorded value
# is that victim's own index and 1-4 players score exactly as vanilla does -
# no roster check needed for rule 3, it falls out of the batching.
var mod_death_score: Dictionary[int, int] = {}

# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build. Any future
# mod RPC needs the same prefix.
@rpc("authority", "call_local", "reliable")
func zz_mod_build_rooms_rpc() -> void :
	"""Build room B on EVERY peer. spawn_players() is host-only, so doing this
	locally would give the host two rooms and everyone else one - the trap under
	'Runtime scene changes must be RPCs, not local calls'."""

	if mod_rooms_built:
		return
	if PlayerManager.player_presences.size() <= MOD_SEATS_PER_ROOM:
		return

	mod_rooms_built = true
	mod_room_count = MOD_MAX_ROOMS

	var room: Node3D = Node3D.new()
	room.name = "MOD_RoomB"
	room.position = MOD_ROOM_OFFSET
	add_child(room)

	var copies: Dictionary = {}
	for subtree_name in MOD_ROOM_SUBTREES:
		var src: Node = get_node_or_null(NodePath(subtree_name))
		if src == null:
			push_warning("[FILTER8] room subtree missing: %s" % subtree_name)
			continue
		var copy: Node = src.duplicate()
		copy.name = "%s_MOD" % subtree_name
		room.add_child(copy)
		copies[subtree_name] = copy

	# Belts and indicators are safe to duplicate: a belt is a plain
	# MeshInstance3D and an indicator's only export is an int. Matching by NAME
	# rather than child order keeps the seat ordering intact - the exported
	# arrays are NOT in scene-child order.
	var belts_copy: Node = copies.get("belts")
	var indicators_copy: Node = copies.get("indicators parent")
	var new_belts: Array[MeshInstance3D] = []
	var new_indicators: Array[BurnRecycleIndicator] = []
	new_belts.assign(belts)
	new_indicators.assign(indicators)

	if belts_copy != null:
		for b in belts:
			var c: Node = belts_copy.get_node_or_null(NodePath(b.name))
			if c != null:
				new_belts.append(c as MeshInstance3D)
	if indicators_copy != null:
		for ind in indicators:
			var c: Node = indicators_copy.get_node_or_null(NodePath(ind.name))
			if c != null:
				# Seat 4+N in room B owns the indicator that seat N owns in room A.
				(c as BurnRecycleIndicator).indicator_id = ind.indicator_id + MOD_SEATS_PER_ROOM
				new_indicators.append(c as BurnRecycleIndicator)

	# Death presses are NOT duplicated. They carry @export OBJECT references
	# (anim_press, decals) which `duplicate()` copies as pointers, leaving every
	# copy driving ROOM A's animation and decal pool - the Forklift Certified
	# trap, whose tell is that there is no tell. Instantiating the PackedScene
	# instead re-resolves its node_paths against the new instance (pitfall 20).
	var press_parent: Node3D = Node3D.new()
	press_parent.name = "death press parent_MOD"
	room.add_child(press_parent)

	var new_presses: Array[BurnRecyclePress] = []
	new_presses.assign(presses)
	for p in presses:
		var copy: Node3D = MOD_DEATH_PRESS_SCENE.instantiate()
		copy.name = "%s_MOD" % p.name
		copy.transform = (p as Node3D).transform
		press_parent.add_child(copy)
		(copy as BurnRecyclePress).press_id = p.press_id + MOD_SEATS_PER_ROOM
		new_presses.append(copy as BurnRecyclePress)

	belts = new_belts
	indicators = new_indicators
	presses = new_presses

	# Room B needs its own countdown readout; update_timers_rpc writes to both.
	var timer_copy: Node = copies.get("TimerVisuals")
	if timer_copy != null:
		var lbl: Node = timer_copy.get_node_or_null(NodePath("TimerLabel"))
		if lbl != null:
			mod_extra_timer_labels.append(lbl as Label3D)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[FILTER8] rooms is_server=", multiplayer.is_server(),
			" peer=", multiplayer.get_unique_id(),
			" rooms=", mod_room_count,
			" subtrees=", copies.size(), "/", MOD_ROOM_SUBTREES.size(),
			" belts=", belts.size(), " presses=", presses.size(),
			" indicators=", indicators.size(),
			" timer_labels=", 1 + mod_extra_timer_labels.size(),
			" offset=", MOD_ROOM_OFFSET)

@export_category("Variables")
@export var random_items_to_pregenerate: int = 3
@export var countdown_time: int = 15
@export var min_countdown_time: int = 10
@export var spark_min_ratio: float = 0.01

@export_category("Local Nodes")
@export var local_root_node: Node3D
@export var client_side_wall_mesh: Node3D
@export var local_handler: BurnRecycleLocalHandler
@export var local_spark_particles_size: Vector2 = Vector2(0.2, 0.4)

@export_category("Nodes")
@export var player_parent_node: Node3D
@export var item_parent_node: Node3D
@export var round_timer: Timer
@export var timer_label: Label3D
@export var clientside_visuals_parent: Node3D
@export var belts: Array[MeshInstance3D]
@export var presses: Array[BurnRecyclePress]
@export var indicators: Array[BurnRecycleIndicator]
@export var spark_particles: GPUParticles3D
@export var multiplayer_synchronizer: MultiplayerSynchronizer

@export var speaker_tally_counter_turn_on: AudioStreamPlayer
@export var speaker_tally_counter_turn_off: AudioStreamPlayer
@export var speaker_tally_counter_buzz: AudioStreamPlayer
@export var speaker_items_moving_start_of_round: AudioStreamPlayer
@export var sounds_items_moving_start_of_round: Array[AudioStream]
@export var speaker_items_moving_end_of_round: AudioStreamPlayer
@export var speaker_countdown_start: AudioStreamPlayer
@export var ambience_speaker_controllers: Array[SpeakerController]

@export_category("Countdown State")
@export var countdown_state: State

var players: Dictionary[int, BurnRecyclePlayer]
var active_players: Dictionary[int, BurnRecyclePlayer]

var random_item_types: Array[BurnRecycleMinigame.ItemTypes]

var countdown_counter: int = 0
var queues_cleared: Array[int]

var player_scores: Dictionary[int, int]
var dead_players: Array[int]
var finished: bool = false
var player_count: int = 0
var spark_ratio: float = 0.01

signal player_item_queues_cleared
signal elimination_finished

func _ready() -> void :
	super._ready()

	multiplayer_synchronizer.set_multiplayer_authority(1)

	if multiplayer.is_server():

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		round_timer.timeout.connect(_on_round_timer_timeout)
		player_item_queues_cleared.connect(_on_player_item_queues_cleared)
		elimination_finished.connect(_on_elimination_finished)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		local_root_node.visible = true
		local_handler.canvas_layer.visible = true
		local_handler.local_after_post_processing_canvas.visible = true
		minigame_ready.emit(1)

		var particle_mesh: Mesh = spark_particles.get_draw_pass_mesh(0)
		particle_mesh.size = local_spark_particles_size

func _physics_process(delta: float) -> void :

	if not multiplayer.is_server():
		return

	spark_ratio = max(spark_ratio - delta, spark_min_ratio)
	spark_particles.amount_ratio = spark_ratio



func play_sound_remove_items():
	speaker_items_moving_end_of_round.play()

@rpc("any_peer", "call_local", "reliable")
func play_sound_ring_rpc():
	speaker_countdown_start.play()

func play_sound_buzzer_on():
	speaker_tally_counter_buzz.play()
	speaker_tally_counter_turn_on.play()

func play_sound_buzzer_off():
	speaker_tally_counter_turn_off.play()
	speaker_tally_counter_buzz.stop()

var item_move_sound_index = 0
func play_item_move_sound():
	speaker_items_moving_start_of_round.stream = sounds_items_moving_start_of_round[item_move_sound_index]
	speaker_items_moving_start_of_round.pitch_scale = randf_range(0.95, 1.05)
	speaker_items_moving_start_of_round.play()
	item_move_sound_index += 1
	if item_move_sound_index == 3:
		item_move_sound_index = 0

func append_random_item_types(_amount: int):

	random_item_types.clear()

	for i in _amount:
		random_item_types.append(BurnRecycleMinigame.ItemTypes.values().pick_random())

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

	append_random_item_types(500)
	spawn_players()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func spawn_players():

	var random_type_byte_array: PackedByteArray
	for t in random_item_types:
		random_type_byte_array.append(t)

	player_count = PlayerManager.player_presences.size()

	# 8P MOD: build room B before any seat is handed out - the loop below
	# immediately indexes belts[] and matches press_id, and an eight-player
	# roster against four stations is a silent null (pitfall 23), not an error.
	#
	# Gated on the roster rather than sent every time: the body's own early
	# return already made this a no-op at 1-4, but for vanilla-compat the mod
	# RPC must not go over the wire at all when an unmodded peer could be
	# listening. `player_count` is PlayerManager.player_presences.size(), set
	# just above.
	if player_count > MOD_SEATS_PER_ROOM:
		zz_mod_build_rooms_rpc.rpc()

	# 8P MOD: BALANCED rooms. Filling room A to four before starting room B put a
	# LONE player in room B at five, and with per-room elimination a room of one
	# is already "finished" - that player would be handed a survivor's score
	# having played nothing. ceil/floor instead: 5 -> 3+2, 6 -> 3+3, 7 -> 4+3,
	# 8 -> 4+4. Never more than the four stations a room has, never fewer than
	# two. At 1-4 this is one room and the whole thing collapses to vanilla.
	var mod_first_room_size: int = player_count
	if player_count > MOD_SEATS_PER_ROOM:
		mod_first_room_size = int(ceil(float(player_count) / float(MOD_MAX_ROOMS)))

	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character: BurnRecyclePlayer = player_scene.instantiate()
		player_parent_node.add_child(player_character, true)

		player_character.set_manager_from_path_rpc.rpc(self.get_path())

		# 8P MOD: the player's ORDINAL and its STATION are different numbers as
		# soon as the rooms are uneven, and conflating them is silent. With a
		# 3+2 split the first room-B player is ordinal 3 but owns station 4;
		# passing the ordinal would hand it `belts[3]` and `press_id == 3` -
		# room A's belt and room A's press - with no error, no null and nothing
		# in the log, because belts[3] exists. Everything downstream
		# (set_active_belt, press_id, indicator_id, look_at_seat) is keyed on
		# the STATION, so that is what gets passed.
		var mod_room: int = 0
		var mod_seat_in_room: int = counter
		if counter >= mod_first_room_size:
			mod_room = 1
			mod_seat_in_room = counter - mod_first_room_size
		var mod_station: int = mod_room * MOD_SEATS_PER_ROOM + mod_seat_in_room

		# Yaw is per-room, so every player still sits at one of the four SHIPPED
		# angles - why nothing clips, and why the four authored camera clips
		# still land exactly. At 1-4 this is vanilla's `90.0 * counter`.
		player_character.set_player_presence.rpc(player_presence.network_id, mod_station)
		# Same vanilla-compat gate as the room build above: at 1-4 every
		# `mod_room` is 0, so the RPC would only assign `mod_room` its declared
		# default and set `position` to the zero vector the player scene already
		# has - skipping it leaves identical state and keeps a mod RPC off the
		# wire in front of a possible unmodded peer.
		if player_count > MOD_SEATS_PER_ROOM:
			player_character.zz_mod_set_room_rpc.rpc(mod_room)
		player_character.setup_rpc.rpc(
			Vector3(0.0, 90.0 * mod_seat_in_room, 0.0),
			random_type_byte_array
		)

		players[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character

		player_character.item_queue_cleared.connect(_on_player_queue_cleared)
		# 8P MOD: the signal carries only (rotation, type), so the room is bound
		# at connect time - the handler otherwise has no way to know which room
		# the thrower is in, and would launch every picture in room A.
		player_character.item_launched.connect(_on_item_launched.bind(mod_room))

		counter += 1

	if GameManager.local_game:
		for c in client_side_wall_mesh.get_children():
			if c is MeshInstance3D:
				c.layers = 0
		local_handler.set_players(players.values())
		local_handler.show_all_tags()

func start_round_timer():

	countdown_counter = countdown_time
	update_timers_rpc.rpc(countdown_counter)
	play_sound_ring_rpc.rpc()
	round_timer.start(1.0)

func round_finished():


	var highest_score: int = 0
	var highest_scoring_network_id: int = -1
	for player in active_players.values():
		var score: int = (player.valid_burns + player.valid_recycles)
		if score > highest_score:
			highest_score = score
			highest_scoring_network_id = player.player_presence.network_id

	if highest_score > 0:
		if active_players.has(highest_scoring_network_id):
			active_players[highest_scoring_network_id].trigger_achievement_rpc.rpc()

	for player in players.values():
		player.round_finished_rpc.rpc()
		player.show_end_score_rpc.rpc()

	await get_tree().create_timer(3.0).timeout

	for player in players.values():
		player.clear_item_queue_rpc.rpc()

func check_game_end(from_disconnect: bool = false):

	if finished:
		return

	# 8P MOD: vanilla asks "is more than one player still alive?", which with two
	# rooms would keep running until one of the EIGHT remained - the whole point
	# of splitting is that each room resolves its own winner. The game is over
	# once every room is down to one (or none); a room that got there first just
	# has nothing left to eliminate.
	if _mod_any_room_contested():
		if from_disconnect:
			return
		else:
			elimination_finished.emit()
			return

	finished = true


	# 8P MOD: `i` is the vanilla score - position in the elimination order. The
	# lookup replaces it with the batch top for anyone who died alongside someone
	# else. The `i` fallback is what a single-room game gets for every player, so
	# this line is vanilla at 1-4 whether or not the dictionary was ever written.
	for i in dead_players.size():
		player_scores[dead_players[i]] = mod_death_score.get(dead_players[i], i)

	# 8P MOD: the `break` that was here scored only the FIRST survivor. With one
	# room that is harmless - there is never a second - but with two rooms it
	# silently dropped a winner from `player_scores` entirely, and since
	# game.gd's merge is `+=` keyed on network id, that player would simply have
	# scored nothing for the minigame with no error anywhere. Both room winners
	# are survivors and both are scored.
	for network_id in active_players.keys():
		player_scores[network_id] = player_count

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)

# 8P MOD: a player's room is derived from its STATION, never stored twice - the
# station is already authoritative (it decides the belt, the press and the
# indicator), so a second copy could only ever disagree with it.
func _mod_room_of(player) -> int:
	return player.active_seat_index / MOD_SEATS_PER_ROOM

func _mod_active_in_room(room: int) -> Array:
	var out: Array = []
	for player in active_players.values():
		if _mod_room_of(player) == room:
			out.append(player)
	return out

func _mod_any_room_contested() -> bool:
	for room in mod_room_count:
		if _mod_active_in_room(room).size() > 1:
			return true
	return false

# 8P MOD: the shipped rule, unchanged, applied to ONE room's players. Returns the
# player to eliminate, or null. Kept as its own function so the two rooms cannot
# drift apart, and so the tie behaviour stays exactly vanilla's:
#   * lowest is 0        -> one of the zero-scorers at random dies;
#   * lowest is above 0  -> only dies if EXACTLY ONE player holds it. Two or more
#                           tied on a non-zero low means NOBODY dies this round.
# That last case is easy to lose when restructuring, and losing it would make the
# minigame harsher than vanilla while every log stayed clean.
func _mod_pick_elimination(room_players: Array):
	if room_players.size() <= 1:
		return null

	var players_by_score: Dictionary[int, Array]
	var lowest_score: int = 9999
	for player in room_players:
		var score: int = (player.valid_burns + player.valid_recycles)
		if not players_by_score.has(score):
			players_by_score[score] = []
		players_by_score[score].append(player)

		if score < lowest_score:
			lowest_score = score

	if lowest_score == 0:
		return players_by_score[lowest_score].pick_random()
	elif lowest_score > 0:
		if players_by_score[lowest_score].size() == 1:
			return players_by_score[lowest_score].pop_front()

	return null

func eliminate_players():

	# One victim per room per round, so both rooms progress at vanilla's pace -
	# three elimination rounds to resolve four players, rather than the seven a
	# single pooled ladder of eight would take.
	var mod_victims: Array = []
	for room in mod_room_count:
		var chosen = _mod_pick_elimination(_mod_active_in_room(room))
		if chosen != null:
			mod_victims.append(chosen)
			dead_players.append(chosen.player_presence.network_id)

	# Everyone in this batch died at the same instant, so they all take the
	# batch's highest index. Read AFTER the appends above, which is what makes it
	# the top of the batch rather than the bottom.
	var mod_batch_top: int = dead_players.size() - 1
	for victim in mod_victims:
		mod_death_score[victim.player_presence.network_id] = mod_batch_top

	if not mod_victims.is_empty():
		# Every camera is told first, then a single shared beat, then everyone
		# dies together. Awaiting per victim would double the pause whenever
		# both rooms lose someone in the same round. look_at_seat() ignores a
		# target in the other room, so each room only reacts to its own.
		for victim in mod_victims:
			start_camera_movement_rpc.rpc(victim.active_seat_index)

		await get_tree().create_timer(1.0).timeout

		for victim in mod_victims:
			var victim_id: int = victim.player_presence.network_id
			if GameManager.local_game:
				if players.has(victim_id):
					local_handler.hide_player_tag(players.get(victim_id))
			if active_players.has(victim_id):
				active_players[victim_id].set_eliminated_rpc.rpc()
				remove_active_player_rpc.rpc(victim_id)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		var mod_report: Array[String] = []
		for room in mod_room_count:
			mod_report.append("r%d=%d" % [room, _mod_active_in_room(room).size()])
		print("[FILTER8] eliminate victims=", mod_victims.size(),
			" alive_by_room=[", ", ".join(mod_report), "]",
			" dead_total=", dead_players.size(),
			" contested=", _mod_any_room_contested())

	await get_tree().create_timer(2.0).timeout

	check_game_end()

func setup_camera_movement():
	if !multiplayer.is_server(): return

	var lowest_scoring_player: BurnRecyclePlayer
	var lowest_score: int = 9999
	for player in active_players.values():
		var score: int = (player.valid_burns + player.valid_recycles)
		if score < lowest_score:
			lowest_score = score
			lowest_scoring_player = player
	var seat: int = lowest_scoring_player.active_seat_index



func start_new_round():

	countdown_time = max(countdown_time - 1, min_countdown_time)
	queues_cleared.clear()

	for player in active_players.values():
		player.reset_scores_rpc.rpc()

	for i in 3:

		for network_id in active_players.keys():
			var player = active_players[network_id]
			player.add_item_rpc.rpc()

		await get_tree().create_timer(1.0).timeout

	for player in active_players.values():
		player.set_active_rpc.rpc(true)

	start_round_timer()

func player_disconnected(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)

	if players.has(_network_id):
		players[_network_id].queue_free()
		players.erase(_network_id)

	await get_tree().create_timer(1.0).timeout

	check_game_end(true)



@rpc("authority", "call_local", "reliable")
func start_camera_movement_rpc(_seat: int):


	for i in player_parent_node.get_children():
		var player: BurnRecyclePlayer = i
		player.look_at_seat(_seat)

@rpc("authority", "call_local", "reliable")
func remove_active_player_rpc(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)

@rpc("any_peer", "call_local", "reliable")
func update_timers_rpc(_time_remaining: int):
	timer_label.text = "00:%s" % [str(_time_remaining).pad_zeros(2)]
	# 8P MOD: room B has its own readout. Empty at 1-4 players, so this loop is
	# a no-op there rather than a branch.
	for lbl in mod_extra_timer_labels:
		lbl.text = timer_label.text



# 8P MOD: `mod_room` is bound at connect time in spawn_players(); it is 0 for
# every player at 1-4, making this identical to vanilla there.
func _on_item_launched(_rotation: Vector3, _type: BurnRecycleMinigame.ItemTypes,
		mod_room: int = 0):

	var launch_item: BurnRecycleLaunchedItem
	for li in item_parent_node.get_children():

		if not li.active:
			launch_item = li

	if not launch_item:

		launch_item = burn_recycle_launched_item.instantiate()
		item_parent_node.add_child(launch_item, true)

	# 8P MOD: `launch_rpc` sets rotation and NEVER position - vanilla has no need
	# to, because every player throws from the middle of the only room there is.
	# `item_parent_node` is the ItemSpawner's spawn_path, so these cannot simply
	# be re-parented into room B without breaking replication; the item is moved
	# instead. Sent BEFORE launch_rpc and on the same reliable channel, so it
	# arrives first and the picture is already in the right room when it starts
	# its animation. Items are pooled and reused across both rooms, which is why
	# this is set on every launch rather than once.
	#
	# 8P MOD: at 1-4 the wire must stay silent - an unmodded peer must never
	# receive a mod RPC - so the dispatch is gated and the trailing branch below
	# runs vanilla's own tail instead. That tail lives inside
	# `zz_mod_place_item_rpc` for rosters over four, where it has to reach every
	# peer so each one ramps ITS room's incinerator; the two are the same lines.
	# `player_count` is a local of spawn_players(), hence the size call here.
	if PlayerManager.player_presences.size() > MOD_SEATS_PER_ROOM:
		zz_mod_place_item_rpc.rpc(launch_item.name, mod_room)

	launch_item.launch_rpc.rpc(
		_rotation,
		_type,
		randf() * 10.0
	)

	# 8P MOD: vanilla's tail, verbatim and in vanilla's position - after
	# `launch_rpc`, because the await would otherwise delay the launch itself.
	if PlayerManager.player_presences.size() <= MOD_SEATS_PER_ROOM:
		await get_tree().create_timer(0.2).timeout
		spark_ratio = min(spark_ratio + 0.3, 1.0)

# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build.
@rpc("authority", "call_local", "reliable")
func zz_mod_place_item_rpc(_item_name: StringName, _room: int) -> void :
	var it: Node = item_parent_node.get_node_or_null(NodePath(String(_item_name)))
	if it != null:
		(it as Node3D).position = MOD_ROOM_OFFSET * float(_room)

	await get_tree().create_timer(0.2).timeout
	spark_ratio = min(spark_ratio + 0.3, 1.0)

func _on_elimination_finished():
	start_new_round()

func _on_player_item_queues_cleared():
	eliminate_players()

func _on_player_queue_cleared(_network_id):

	if not queues_cleared.has(_network_id):
		queues_cleared.append(_network_id)

	if queues_cleared.size() == players.keys().size():

		append_random_item_types(500)
		var random_type_byte_array: PackedByteArray
		for t in random_item_types:
			random_type_byte_array.append(t)

		for player in active_players.values():
			player.set_random_type_array_rpc.rpc(random_type_byte_array)

		player_item_queues_cleared.emit()

func _on_round_timer_timeout():

	countdown_counter -= 1

	if countdown_counter > 0:
		round_timer.start(1.0)
	else:
		round_finished()

	update_timers_rpc.rpc(countdown_counter)

func _on_countdown_started():
	super._on_countdown_started()

	for network_id in players.keys():
		var player = players[network_id]
		player.add_item_rpc.rpc()

func _on_countdown_tick(_time_left: int):
	super._on_countdown_tick(_time_left)

	for network_id in players.keys():
		var player = players[network_id]
		player.add_item_rpc.rpc()

func _on_countdown_expired():
	super._on_countdown_expired()

	for player in players.values():
		player.set_active_rpc.rpc(true)

	start_round_timer()

	state_machine.transition_to_rpc.rpc(&"Play")
