extends Minigame

class_name SpineBreakerMinigame

const player_scene = preload("uid://b774mjndcdeqg")

@export_category("Nodes")
@export var players_node: Node3D
@export var player_spawn_positions_node: Node3D
@export var device: SpineBreakerDevice
@export var camera: Camera3D
@export var speaker_beep: AudioStreamPlayer
@export var ambience_speaker_controllers: Array[SpeakerController]
@export_category("States")
@export var countdown_state: State

var players: Dictionary[int, SpineBreakerPlayer]
var active_players: Dictionary[int, SpineBreakerPlayer]

var player_scores: Dictionary[int, int]
var dead_players: Array[int]
var finished: bool = false
var player_count: int = 0

var playing: bool = false

# --- 8P MOD: spawn audit (diagnostic) -----------------------------------------
# Gated behind -localtest; no gameplay effect at any roster size.
#
# Spine Breaker needed no *capacity* fix: the device picks its victim with
# `active_players.values().pick_random()` and nothing enumerates or indexes a
# per-slot array, so the only cap was the four spawn markers. spawn_expand.py
# places the four added markers 1.2u outboard of the shipped ones, so a clone
# can land inside geometry; physics then shoves the player clear and the tell
# is a player standing well away from every marker.
const MOD_AUDIT_DELAY: float = 6.0
const MOD_DISPLACED_DIST: float = 2.0
const MOD_FELL_THROUGH_Y: float = - 3.0

# --- 8P MOD: kill pace scaled to roster size ----------------------------------
# This one DOES change gameplay above four players. At eight players a round ran
# ~168s against ~72s at four, because the per-kill cycle is a fixed
#
#     fuse (activation_duration) + kill animation (1.0s) + dead time (3.0s)
#
# and eight players need seven kills where four need three. Both terms scaled
# here are host-only, so no RPC is involved (see "Client safety" below).
#
# Two mechanics facts this design rests on, neither of them obvious:
#
# 1. THE FUSE IS NEVER RESTARTED BY A THROW. `try_throw_rpc` in
#    spine_breaker_device.gd does not touch `activation_timer`, and
#    attached_state.gd reads `timed_out = owner.activation_timer.is_stopped()`
#    on entry - so once the fuse burns out mid-chase the *next* attach kills
#    instantly. `activation_duration` is a hard cap on time-from-arming-to-
#    death, which is what makes the cycle predictable enough to scale.
# 2. TRAVEL HAPPENS INSIDE THE FUSE WINDOW. `choose_new_target()` transitions
#    the device to Follow and calls `start_timer()` on the same frame, so
#    raising the chase speed (`new_target_speed`, `default_speed`, the
#    `speed_increase_*` ramp) would NOT shorten a round - it would only mean
#    the device spends more of the fuse attached. Those knobs are left alone
#    deliberately; speeding up the spider is not a pacing lever.
#
# The factor is `MOD_VANILLA_KILLS / (roster - 1)`, clamped to 1.0. At four
# players that is exactly 3/3 = 1.0, so 1-4 player games are untouched BY
# CONSTRUCTION rather than by an `if` - and `20.0 * 1.0` / `3.0 * 1.0` are
# bit-identical to the shipped values. Below four it clamps.
#
#   roster  kills  factor   fuse    dead    round
#     1-4     3    1.000   20.000   3.000   ~72s  <- vanilla
#      5      4    0.750   15.000   2.250   ~73s
#      6      5    0.600   12.000   1.800   ~74s
#      7      6    0.500   10.000   1.500   ~75s
#      8      7    0.429    8.571   1.286   ~76s
#
# i.e. round length stays roughly flat instead of scaling with the lobby.
#
# NOT touched: the 1.0s kill sequence in spine_breaker_player.gd's
# `break_spine_rpc`. Its two `create_timer` waits run independently on every
# peer, so shortening it host-side would desync the corpse drop.
const MOD_VANILLA_KILLS: float = 3.0
const MOD_VANILLA_DEAD_TIME: float = 3.0

# The shipped fuse, learned at runtime rather than hardcoded. `activation_
# duration` is an @export whose script default (15.0) is overridden twice - to
# 10.0 in spine_breaker_device.tscn and to 20.0 by the Device instance in
# spine_breaker.tscn - so the only trustworthy source is the live value before
# anything mutates it. Learning it also means a developer retuning that scene
# value on a future update carries through automatically, and it is why
# `choose_new_target()` assigns `_mod_vanilla_fuse * factor` rather than
# multiplying the current value, which would compound on every kill.
var _mod_vanilla_fuse: float = -1.0

func _mod_pace_factor() -> float:
	return clampf(MOD_VANILLA_KILLS / float(maxi(player_count - 1, 1)), 0.0, 1.0)

func _mod_localtest_audit() -> void :
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var tag := "[SPINE8] is_server=%s peer=%d" % [
		multiplayer.is_server(), multiplayer.get_unique_id()]

	var markers: Array[Node] = []
	if player_spawn_positions_node != null:
		markers = player_spawn_positions_node.get_children()

	print(tag, " markers=", markers.size(),
		" spawned=", players_node.get_child_count(),
		" device=", device != null)

	if markers.is_empty():
		push_warning("[SPINE8] no spawn markers found")
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

	camera.current = true

	# 8P MOD: snapshot the shipped fuse before anything can scale it. Read on
	# every peer even though only the host uses it, so the value cannot depend
	# on which peer we are.
	if device != null:
		_mod_vanilla_fuse = device.activation_duration
	else:
		push_warning("[SPINE8] device is null in _ready - pace scaling disabled")

	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_localtest_audit()

	if multiplayer.is_server():

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		device.request_new_target.connect(_on_device_requested_target)

func _physics_process(_delta: float) -> void :

	if not playing:
		return

	for p in players_node.get_children():
		if not p.active:
			continue

		var query = PhysicsRayQueryParameters3D.create(
			camera.global_position, 
			p.global_position
		)

		var result = camera.get_world_3d().direct_space_state.intersect_ray(query)
		var show = false
		if result:
			if result.collider == p:
				show = true

		p.player_name_label.visible = show

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

	var spawn_positions = player_spawn_positions_node.get_children()
	spawn_positions.shuffle()

	player_count = PlayerManager.player_presences.size()

	for i in PlayerManager.player_presences.size():
		var network_id = PlayerManager.player_presences.keys()[i]

		var position: Vector3 = spawn_positions[i].global_position
		var rot: Vector3 = spawn_positions[i].rotation_degrees
		var player_character = player_scene.instantiate()
		players_node.add_child(player_character, true)

		player_character.set_player_presence.rpc(network_id)
		player_character.setup_rpc.rpc(position, device.get_path(), rot)
		player_character.set_manager_from_path_rpc.rpc(self.get_path())

		player_character.emit_died.connect(_on_player_died)

		players[network_id] = player_character
		active_players[network_id] = player_character

		player_scores[network_id] = 0

	device.set_players_node(players_node)

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
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

	set_playing_rpc.rpc(false)
	device.deactive_rpc.rpc()

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
func remove_player_rpc(_network_id: int):

	var player_instance = players.get(_network_id, null)
	if player_instance:

		if multiplayer.is_server():
			device.player_disconnected(player_instance)

		player_instance.queue_free()
		players.erase(_network_id)
		active_players.erase(_network_id)

@rpc("any_peer", "call_local", "reliable")
func set_playing_rpc(_playing: bool):
	playing = _playing



func _on_countdown_tick(time_left: int):
	super._on_countdown_tick(time_left)

func choose_new_target():

	if active_players.size() <= 1:
		return

	var random_player = active_players.values().pick_random()

	device.state_machine.transition_to(&"Follow", {
		"target": random_player, 
		"new_target": true
	})

	# 8P MOD: scale the fuse to the roster. Assign the MEMBER, not
	# `activation_timer.start(x)` - spine_breaker_device.gd's _process divides by
	# `activation_duration` to drive the warning light's blink ramp, so setting
	# the member keeps the light in step with the real fuse for free.
	# Host-only: this function is reached only from `_on_countdown_expired`
	# under an is_server() guard and from `_on_device_requested_target`, whose
	# signal is likewise connected on the host only.
	if _mod_vanilla_fuse > 0.0:
		var mod_factor := _mod_pace_factor()
		device.activation_duration = _mod_vanilla_fuse * mod_factor

		if Array(OS.get_cmdline_args()).has("-localtest"):
			print("[SPINE8] pace roster=", player_count,
				" active=", active_players.size(),
				" factor=%.3f" % mod_factor,
				" fuse=%.3f" % device.activation_duration,
				" dead=%.3f" % (MOD_VANILLA_DEAD_TIME * mod_factor),
				" vanilla_fuse=%.3f" % _mod_vanilla_fuse)

	device.start_timer()

func _on_countdown_expired():
	super._on_countdown_expired()

	for p in players.values():
		p.set_active_rpc.rpc(true)

	if multiplayer.is_server():
		choose_new_target()

	set_playing_rpc.rpc(true)

func _on_device_requested_target():

	if multiplayer.is_server():
		device.laugh_rpc.rpc()

	# 8P MOD: the dead time between victims, scaled by the same factor as the
	# fuse. Vanilla is the bare literal 3.0; at four players or fewer the factor
	# is exactly 1.0 and this is bit-identical to it.
	await get_tree().create_timer(
		MOD_VANILLA_DEAD_TIME * _mod_pace_factor()
	).timeout

	choose_new_target()

func _on_player_died(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)
		dead_players.append(_network_id)

	await get_tree().create_timer(1.0).timeout

	check_game_end()
