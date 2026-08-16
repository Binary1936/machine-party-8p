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
@export var local_extra_carving_duration: int = 5

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

	# 8-PLAYER MOD: wire the jumbotron HUD overlay (see the block above
	# spawn_players()). It has to be done here rather than in spawn_players(),
	# which is host-only - on a client the players dict stays empty and the
	# player nodes arrive under player_spawn_node through the MultiplayerSpawner.
	player_spawn_node.child_entered_tree.connect(_mod_hud_on_player_spawned)

	if multiplayer.is_server():

		multiplayer_synchronizer.set_multiplayer_authority(1)

		shotgun_handler.eliminate_player_by_id.connect(_on_player_eliminated)
		round_timer.timeout.connect(_on_round_timer_tick)
		round_finished_state.submissions_validated.connect(_on_submissions_validated)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		carving_duration += local_extra_carving_duration
		local_root_node.visible = true
		local_handler.canvas_layer.visible = true
		local_handler.local_after_post_processing_canvas.visible = true
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

	if GameManager.local_game:
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

	# 8P MOD: before the game has started there is nothing to end - the peer
	# was never spawned here and its presence is already pruned. Vanilla's end
	# check below would see zero players and finish an unstarted game
	# (pitfall 32; session log 2026-08-15).
	if not is_all_player_loaded:
		return

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

# The 135-degree slot's character stands 0.44u from barrel_001 and 0.89u from
# the chest-height barrel_002 stacked on it - visual clipping at any roster
# that seats that slot. Hidden here rather than in the .tscn so 1-4 players
# keep the shipped dressing.
const MOD_HIDE_PROPS: Array[String] = [
	"chisel gauntlet art2/walls/barrel_001",
	"chisel gauntlet art2/walls/barrel_002",
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
	# The one place a 5-8 roster is known on EVERY peer (spawn_players() is
	# host-only), so the jumbotron HUD overlay latches off the same call.
	_mod_hud_overlay_enabled = true

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

	var _hid := 0
	for path in MOD_HIDE_PROPS:
		var node := get_node_or_null(path)
		if node:
			node.visible = false
			# The barrels carry their own StaticBody3D - hiding the mesh alone
			# would leave invisible collision in the slot.
			for body in node.find_children("*", "CollisionObject3D", true, false):
				body.process_mode = Node.PROCESS_MODE_DISABLED
			_hid += 1
		elif _dbg:
			print("[STATIONS] MISSING prop ", path)

	if _dbg:
		print("[STATIONS] cloned ", _made, " single nodes, hid ", _hid, " props")


# 8-PLAYER MOD: the jumbotron HUD overlay.
#
# The four added seats (player_rotations 45/-135/135/-45) sit between the
# shipped stations, so they face a CORNER of the jumbotron and read its four
# CRT screens edge-on - the memorise phase is the one part of the round where
# that matters, because the cube instructions are only on those screens.
#
# The scene already contains a head-on view: LocalMultiplayer/JumbotronViewport
# is a SubViewport whose Camera3D is parked at seat 1's "look at jumbotron"
# pose, rendering the shared 3D world (own_world_3d is false); couch mode feeds
# its jumbotron TextureRect from it, and leaves it DISABLED otherwise. We mirror
# that same viewport into a full-screen overlay for as long as the local
# player's camera is on the jumbotron. The maintainer chose to show it to ALL
# eight above four rather than only to the four new seats, so everyone reads the
# same picture.
#
# LIGHTING. Online the room is lit ONLY by each player's own `lights` node -
# chisel_gauntlet_player.gd reveals it for the local player alone, and the
# scene-root Lights ship hidden. So a seat-1 render lit from wherever the local
# player happens to sit came out different on every seat: head-on and bright at
# seat 1, grazing at the diagonals, and dark enough elsewhere that only the CRT
# face (an unshaded material) showed against a black casing. While the overlay
# is up we therefore light the room the way couch mode does - LocalMultiplayer's
# four OmniLight3D copies of the seat light at the cardinal positions - and hide
# the local player's own seat light, so every client renders the identical,
# uniformly lit picture regardless of where they sit.
#
# Those lights are in the SHARED World3D, so they light the main view too. That
# is why the hide path restores the lighting BEFORE the fade rather than after
# it: the overlay spends the fade showing a frozen last frame over an
# already-normal room instead of popping the lighting when it finally clears.
#
# LocalMultiplayer itself has to be made visible for its lights to render at all
# (a hidden ancestor zeroes is_visible_in_tree(), which is what gates a
# VisualInstance3D) - which is exactly why couch mode's _ready() sets it. Its
# only other children are the SubViewport, which visibility does not reach, and
# the CanvasLayer carrying couch mode's black backdrop, which is independently
# `visible = false` and stays that way. Both are put back on hide.
#
# Nothing here runs at 1-4: _mod_hud_overlay_enabled is only ever set by
# zz_mod_add_stations_rpc(), which the host calls exactly when the roster
# exceeds four, and the overlay nodes are not created until first shown. Couch
# mode is excluded too - there the viewport is already owned by the local
# handler, the lights are already on, and there is no single local player.
var _mod_hud_overlay_enabled: bool = false
var _mod_hud_layer: CanvasLayer
var _mod_hud_rect: TextureRect
var _mod_hud_tween: Tween
var _mod_hud_lights: Node3D
var _mod_hud_lights_missing: bool = false
var _mod_hud_camera_missing: bool = false
var _mod_hud_near_saved: float = -1.0

func _mod_hud_on_player_spawned(node: Node) -> void:
	if not node is ChiselGauntletPlayer:
		return
	var anim: AnimationPlayer = (node as ChiselGauntletPlayer).camera_animation_player
	if anim == null:
		return
	# A node can enter the tree more than once, and the signal is per-player, so
	# this only ever matches a connection made for this same player.
	if anim.animation_started.is_connected(_mod_hud_on_camera_animation.bind(node)):
		return
	anim.animation_started.connect(_mod_hud_on_camera_animation.bind(node))

func _mod_hud_on_camera_animation(anim_name: StringName, player: ChiselGauntletPlayer) -> void:
	if not _mod_hud_overlay_enabled:
		return
	if GameManager.local_game:
		return
	# Every camera pose arrives by look_at_rpc on every peer, so filter to the
	# one player whose view this window actually is - the same test vanilla uses.
	if player.player_presence == null:
		return
	if player.player_presence.network_id != multiplayer.get_unique_id():
		return

	# "look at jumbotron" and "look at jumbotron instant"; everything else
	# ("look at desk*", "RESET", "death first person") puts the view back.
	if String(anim_name).begins_with("look at jumbotron"):
		_mod_hud_show(player)
	else:
		_mod_hud_hide(player)

func _mod_hud_create() -> void:
	_mod_hud_layer = CanvasLayer.new()
	_mod_hud_layer.name = "ModJumbotronHud"
	# Below PostProcessingLayer (2) and LocalAfterPostProcessing (3) so the
	# grade still applies over it, and below MinigameOverlay (10) so the round
	# fader still covers it.
	_mod_hud_layer.layer = 1
	add_child(_mod_hud_layer)

	_mod_hud_rect = TextureRect.new()
	_mod_hud_rect.name = "Feed"
	# Anchored BEFORE entering the tree: with no parent rect to measure against
	# the offsets stay zero, so the rect resolves to the full window on add and
	# follows it afterwards.
	_mod_hud_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mod_hud_rect.texture = local_handler.jumbotron_viewport.get_texture()
	_mod_hud_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mod_hud_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_mod_hud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mod_hud_rect.visible = false
	_mod_hud_rect.modulate.a = 0.0
	_mod_hud_layer.add_child(_mod_hud_rect)

func _mod_hud_couch_lights() -> Node3D:
	if _mod_hud_lights == null and not _mod_hud_lights_missing:
		_mod_hud_lights = local_root_node.get_node_or_null(^"Lights") as Node3D
		if _mod_hud_lights == null:
			_mod_hud_lights_missing = true
			push_warning("[8P MOD] chisel_gauntlet: LocalMultiplayer/Lights not found; jumbotron overlay renders unlit")
	return _mod_hud_lights

# Both callers do this synchronously rather than from a tween callback, so
# whichever of show/hide ran last always owns the lighting state.
func _mod_hud_set_overlay_lighting(overlay_lit: bool, player: ChiselGauntletPlayer) -> void:
	local_root_node.visible = overlay_lit
	var lights := _mod_hud_couch_lights()
	if lights != null:
		lights.visible = overlay_lit
	if player != null and player.lights != null:
		player.lights.visible = not overlay_lit

# Seat 1's third-person rig stands 0.77u in front of this camera and is tall
# enough (hat top ~4.8u in rest pose) for its head to breach the bottom of the
# frame on every client except seat 1's own, which hides its own third-person
# visuals; couch mode dodges that with per-player cull layers, which online does
# not use. Nothing else in view is nearer than the jumbotron at ~5.7u, so a 2.0
# near plane clips the model out and costs nothing.
func _mod_hud_set_overlay_near(overlay_shown: bool) -> void:
	var camera := local_handler.jumbotron_viewport.get_camera_3d()
	if camera == null:
		if not _mod_hud_camera_missing:
			_mod_hud_camera_missing = true
			push_warning("[8P MOD] chisel_gauntlet: jumbotron viewport has no camera; overlay near plane unchanged")
		return
	if overlay_shown:
		if _mod_hud_near_saved < 0.0:
			_mod_hud_near_saved = camera.near
		camera.near = 2.0
	elif _mod_hud_near_saved >= 0.0:
		camera.near = _mod_hud_near_saved

func _mod_hud_show(player: ChiselGauntletPlayer) -> void:
	if _mod_hud_layer == null:
		_mod_hud_create()

	_mod_hud_set_overlay_lighting(true, player)
	_mod_hud_set_overlay_near(true)

	var jumbotron_viewport: SubViewport = local_handler.jumbotron_viewport
	# The couch default is 960x540; render at the real window size instead. The
	# camera's fov is vertical, so the framing does not change with the aspect.
	jumbotron_viewport.size = get_window().size
	jumbotron_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	jumbotron_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	# Poses can follow each other within a frame ("look at jumbotron instant" at
	# round start), so an in-flight fade is dropped rather than queued.
	if _mod_hud_tween != null:
		_mod_hud_tween.kill()
	_mod_hud_rect.visible = true
	_mod_hud_tween = create_tween()
	_mod_hud_tween.tween_property(_mod_hud_rect, "modulate:a", 1.0, 0.5)

func _mod_hud_hide(player: ChiselGauntletPlayer) -> void:
	if _mod_hud_rect == null:
		return

	# Freeze the feed and put the lighting back BEFORE the fade. Disabling the
	# update mode stops the viewport re-rendering but leaves the render target
	# holding its last frame, so the ViewportTexture keeps showing it while the
	# alpha runs out - and the main view behind it is already back to normal.
	local_handler.jumbotron_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mod_hud_set_overlay_lighting(false, player)
	_mod_hud_set_overlay_near(false)

	if _mod_hud_tween != null:
		_mod_hud_tween.kill()
	_mod_hud_tween = create_tween()
	_mod_hud_tween.tween_property(_mod_hud_rect, "modulate:a", 0.0, 0.5)
	_mod_hud_tween.tween_callback(_mod_hud_rest)

func _mod_hud_rest() -> void:
	_mod_hud_rect.visible = false
	# Back to the shipped resting state, so nothing renders the second view
	# while the overlay is down.
	local_handler.jumbotron_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

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

		if GameManager.local_game:
			player_character.setup_local_visuals(counter)

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

		var next_round_duration = carving_duration - 1
		carving_duration = max(next_round_duration, 5)
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

	if GameManager.local_game:
		if players.has(network_id):
			local_handler.hide_player_tag(players.get(network_id))

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
	print("_on_player_submitted_solution %s" % network_id)

	if GameManager.local_game:
		var player = players.get(network_id, null)
		if player and local_handler.keyboard_player:
			if local_handler.keyboard_player == player:
				local_handler.fake_cursor.visible = false

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
