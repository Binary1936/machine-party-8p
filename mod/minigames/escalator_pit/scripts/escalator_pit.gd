extends Minigame

class_name EscalatorPitMinigame

const player_scene = preload("res://minigames/escalator_pit/components/player/escalator_pit_player.tscn")

@export var player_spawn_positions: Array[Node3D]
@export var camera_rotation_start: float = -45.0
@export var camera_rotation_end: float = 45.0
@export var camera_pan_curve: Curve
@export var resistance_speeds: Array[float] = [0.2, 0.5, 0.8]
@export var offset_every_other_playername: bool
@export var sequence_character_parent: Node3D
@export var correct_input_increment: float = 0.01

var sequence_label_letters: Array[Label3D]

@export_category("Components")
@export var countdown_state: State
@export var stair_handler: EscalatorPitStairHandler
@export var post_processing_vignette: Control

@export_category("Ambience")
@export var ambience_speakers: Array[AudioStreamPlayer]
@export var ambience_speaker_controllers: Array[SpeakerController]

@onready var players_node_parent: Node3D = $Players

@onready var camera_target: Node3D = $CameraTarget
@onready var camera_3d: Camera3D = $CameraTarget / Camera3D

@onready var kill_area: Area3D = $Interactive / KillArea
@onready var finish_area: Area3D = $Interactive / FinishArea

var current_resistance_speed_index = 0
var player_characters: Dictionary[int, EscalatorPitPlayer]
var active_players: Array[EscalatorPitPlayer]
var finished_players: Array[EscalatorPitPlayer]
var player_scores: Dictionary[int, int]

var camera_progress: float = PI + (PI * 0.5)

var collective_speed: float = 0.0

# --- 8P MOD ------------------------------------------------------------------
# Vanilla ships four escalator troughs. spawn_expand.py gave the scene eight
# markers, but it displaces a clone along the marker's own local X - and three
# of the four markers here carry the basis (0,-1,0, 1,0,0, 0,0,1), whose first
# column is world +Y. So players 6-8 were placed 1.2 units *underneath* players
# 2-4 at identical x/z, which is why they read as doubled up and their input
# arrows (a Sprite3D on each player) printed on top of one another. Player 5,
# from the one identity-basis marker, went sideways instead and produced the
# visible side-by-side pair. Compare pitfall 14: spawn variety here comes from
# neither position nor rotation alone but from which trough you land in.
#
# The fix splits each trough into two narrower parallel stair strips, giving
# eight sets of stairs without touching the art. That is only possible because
# the stairs are procedural: stair_handler.gd iterates paths_parent's children
# with no hardcoded count, every lane shares one Curve3D, and all four
# MultiMeshInstance3D nodes already share a single MultiMesh - a lane differs
# from its neighbours purely by its Path3D transform. Cloning one is therefore
# a Path3D duplicate at a new x.
#
# What could NOT be done from script: the four escalator housings and the pit
# floor are baked together into `base platform` (ArrayMesh_go7oh, a single
# surface), so eight *full-width* lanes at the shipped 6.4 pitch would hang off
# the platform. Both strips stay inside an existing trough for that reason.
#
# The handrails are a separate node (`Plane_003`) and ARE removable - that was
# established by testing, after an earlier assumption that they lived inside
# `base platform` proved wrong. See MOD_HIDDEN_ART.
const MOD_VANILLA_LANES: int = 4
const MOD_MAX_LANES: int = 8
# Half the spacing between the two strips sharing a trough. Troughs sit 6.4
# apart, so +/-1.6 leaves 1.6 of clearance to the trough wall on each side.
const MOD_STRIP_OFFSET: float = 1.6
# The step mesh measures 2.44 x 0.66 x 1.08 (confirmed at runtime via the
# [LANES8] lane trace), NOT the ~6 needed to fill a 6.4-wide trough - the steps
# always sat as a narrow band inside a much wider baked housing. So no
# narrowing is required: two 2.44-wide steps at the 3.2 strip pitch still leave
# 0.76 of clearance. An earlier 0.48 here shrank them to 1.17 and made the
# stairs look like slivers sunk into the floor. Tunable, but 1.0 keeps the step
# art at its authored proportions.
const MOD_STRIP_SCALE: float = 1.0
# Vertical offsets applied on top of the shipped layout. Both are 0.0, i.e.
# stairs and players sit exactly where vanilla puts them - only their *count*
# and lateral spacing are modded. They were briefly 0.95 / 0.65 to lift the
# steps out of what looked like the trough floor, but that appearance came from
# the handrail assembly (Plane_003) crowding the lanes; with it hidden the
# shipped heights read correctly again.
#
# If you re-tune these, keep them equal unless you specifically want the
# players riding higher or lower relative to the steps, and re-check
# MOD_INDICATOR_NUDGE in escalator_pit_player.gd - a player lift pushes the
# input arrow up into the CRT housing.
const MOD_STEP_LIFT: float = 0.0
const MOD_PLAYER_LIFT: float = 0.0
# The three dividers between the shipped troughs (Cylinder/Cylinder2/Cylinder3,
# one shared mesh, sitting on the trough boundaries at x = -6.41, 0.01, 6.42).
# With eight strips a player stands ~1.6 from a divider and clips it, so they
# are hidden while expanded. NOTE: only these three are separable nodes - any
# remaining rail is baked into `base platform` and cannot be removed here.
const MOD_RAIL_NAME_HINT: String = "cylinder"
# Nodes hidden by name while expanded.
#
# `Plane_003` is the long diagonal handrail assembly - **confirmed by testing**,
# not by reading the scene. It is rotated 90 degrees about Z, so its 22.9-unit
# local extent runs across the lanes rather than along them; that is why its
# position (-9.6, 6.4, -11.4) reads as a single left-hand prop when it actually
# spans the whole escalator run at mid-height. Hiding it is what removes the
# rails that players clip at the eight-strip spacing.
#
# `base platform` (the pit floor and the four troughs) was hidden during that
# investigation and is deliberately NOT listed now: an earlier note claiming
# the rails were baked into it was wrong, and hiding it is unnecessary once
# Plane_003 is gone. Re-add the string to drop the floor again.
const MOD_HIDDEN_ART: Array[String] = [
	"Plane_003",
]
# How far the pit floor sits below its shipped height (y = -0.81), so the
# stairs read as resting on it rather than sunk into it.
#
# Deliberately a plain offset and NOT derived from geometry. An attempt to
# compute it - align `base platform`'s AABB top to the lowest point of the lane
# curve - put the floor at y = -23 for two reasons worth remembering:
#   * the lane curve is a closed loop, so its minimum is the return run passing
#     ~21 units *under* the escalator, not the visible bottom step;
#   * `base platform` is a 15.5-tall structure, so its AABB top (y = 11.3) is
#     the top of the housing, not a walking surface.
# Neither quantity corresponds to "the bottom of the stairs", so there is
# nothing sound to derive from. Eyeball it.
const MOD_FLOOR_NAME: String = "base platform"
const MOD_FLOOR_DROP: float = 0.75
# The CRT screens are the only per-lane art that is separable - the troughs and
# pit floor are baked into one mesh. They hold no exported node references
# (their `blinker` child only ever calls get_parent()), so duplicate() is safe.
# Matched by name rather than a hardcoded path, which returns null silently.
const MOD_CRT_NAME_HINT: String = "crt1_"
# All four shipped markers sit at y = -2; the expander pushed three to -3.2.
const MOD_SPAWN_Y: float = -2.0

func _enter_tree() -> void :
	# Deliberately _enter_tree and not _ready: StairHandler._ready() caches
	# paths_parent's children, and _ready fires bottom-up, so by the time this
	# node is ready the handler has already committed to four lanes.
	#
	# No RPC needed. Every peer instantiates the minigame scene and
	# PlayerManager.player_presences is replicated, so all peers build the same
	# lanes independently - same reasoning as the intermission score screen.
	if PlayerManager.player_presences.size() > MOD_VANILLA_LANES:
		_mod_build_eight_lanes()

func _mod_build_eight_lanes() -> void :

	if stair_handler == null or stair_handler.paths_parent == null:
		push_warning("[LANES8] stair_handler/paths_parent missing; lanes unchanged")
		return

	var parent: Node3D = stair_handler.paths_parent
	var originals: Array[Path3D] = []
	for child in parent.get_children():
		if child is Path3D:
			originals.append(child)

	if originals.size() != MOD_VANILLA_LANES:
		push_warning("[LANES8] expected %d stair paths, found %d; lanes unchanged"
			% [MOD_VANILLA_LANES, originals.size()])
		return

	var clones: Array[Path3D] = []
	for i in originals.size():
		var src: Path3D = originals[i]
		var centre_x: float = src.position.x

		var clone: Path3D = src.duplicate()
		clone.name = "%s_MOD%d" % [src.name, MOD_VANILLA_LANES + i + 1]
		parent.add_child(clone)

		src.position.x = centre_x - MOD_STRIP_OFFSET
		clone.position.x = centre_x + MOD_STRIP_OFFSET
		clones.append(clone)

		# After the duplicate, so each strip is lifted exactly once.
		_mod_shape_strip(src)
		_mod_shape_strip(clone)

	_mod_place_spawns(originals, clones)
	var crt_count: int = _mod_split_crts()
	var rail_count: int = _mod_hide_rails()
	var art_hidden: int = _mod_hide_art()
	_mod_lower_floor()
	if Array(OS.get_cmdline_args()).has("-localtest"):
		_mod_report_baked_art()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		var lane_x: Array[float] = []
		for p in originals + clones:
			lane_x.append(p.position.x)
		lane_x.sort()
		var xs: Array[String] = []
		for v in lane_x:
			xs.append("%.2f" % v)
		print("[LANES8] is_server=", multiplayer.is_server(),
			" players=", PlayerManager.player_presences.size(),
			" lanes=", originals.size() + clones.size(),
			" screens=", crt_count, " rails_hidden=", rail_count,
			" art_hidden=", art_hidden,
			" step_lift=%.2f" % MOD_STEP_LIFT,
			" player_lift=%.2f" % MOD_PLAYER_LIFT,
			" scale=%.2f" % MOD_STRIP_SCALE, " x=[", ", ".join(xs), "]")

		# Did the narrowing actually land, and how wide is a step to begin
		# with? If the step mesh is narrow, the wide lane surface on screen is
		# the baked housing and scaling the steps changes almost nothing.
		for p in originals + clones:
			for child in p.get_children():
				if child is MultiMeshInstance3D:
					var mmi: MultiMeshInstance3D = child
					var aabb_txt: String = "<no mesh>"
					if mmi.multimesh != null and mmi.multimesh.mesh != null:
						var ab: AABB = mmi.multimesh.mesh.get_aabb()
						aabb_txt = "step_size=(%.2f, %.2f, %.2f)" % [
							ab.size.x, ab.size.y, ab.size.z]
					print("[LANES8] lane x=%.2f mmi_scale=(%.2f, %.2f, %.2f) %s"
						% [p.position.x, mmi.scale.x, mmi.scale.y, mmi.scale.z,
						aabb_txt])
					break

func _mod_collect_named(node: Node, hint: String, out: Array[Node3D]) -> void :
	# Matched by name rather than a hardcoded relative path, which would return
	# null silently and make the whole feature a no-op (see UPDATING.md).
	for child in node.get_children():
		if child is Node3D and hint in String(child.name).to_lower():
			out.append(child)
		else:
			_mod_collect_named(child, hint, out)

func _mod_hide_art() -> int:
	var hidden: int = 0
	for wanted in MOD_HIDDEN_ART:
		var found: Array[Node3D] = []
		_mod_collect_named(self, wanted.to_lower(), found)
		if found.is_empty():
			push_warning("[LANES8] no '%s' node found; left visible" % wanted)
			continue
		for n in found:
			n.visible = false
			hidden += 1
		if Array(OS.get_cmdline_args()).has("-localtest"):
			print("[LANES8] hid art '", wanted, "' x", found.size())

	return hidden

func _mod_dump_all_meshes(node: Node) -> void :
	# Find the handrails by measurement rather than by guessing at names: they
	# run the length of a lane, so they are long in Z and thin in X. Prints the
	# world-space AABB of every mesh in the scene.
	#
	# find_children with owned=false is used rather than hand-rolled recursion
	# so that runtime-added nodes (the cloned lanes and screens) are included.
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	print("[ART] found ", meshes.size(), " MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m
		if mi.mesh == null:
			continue
		# NOT get_transformed_aabb(): it returns null in the release template,
		# and assigning that to a typed AABB aborts the calling function with
		# no error printed. mesh.get_aabb() is local space, so pair it with the
		# node's world scale.
		var ab: AABB = mi.mesh.get_aabb()
		var sc: Vector3 = mi.global_transform.basis.get_scale()
		var world: Vector3 = Vector3(ab.size.x * sc.x, ab.size.y * sc.y, ab.size.z * sc.z)
		print("[ART] ", mi.name, " vis=", mi.visible,
			" pos=", mi.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			" size=", world.snapped(Vector3(0.1, 0.1, 0.1)))

func _mod_lower_floor() -> int:
	if is_zero_approx(MOD_FLOOR_DROP):
		return 0

	var found: Array[Node3D] = []
	_mod_collect_named(self, MOD_FLOOR_NAME, found)
	if found.is_empty():
		push_warning("[LANES8] no '%s' node found; floor height unchanged"
			% MOD_FLOOR_NAME)
		return 0

	for n in found:
		n.position.y -= MOD_FLOOR_DROP

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[LANES8] floor dropped ", MOD_FLOOR_DROP,
			" below shipped -> y=", snappedf(found[0].position.y, 0.01))

	return found.size()

func _mod_report_baked_art() -> void :
	# The long diagonal handrails are not separate nodes. If they are their own
	# *surface* inside `base platform` they could still be hidden without the
	# GLB, so report the surface breakdown rather than assuming.
	var found: Array[Node3D] = []
	_mod_collect_named(self, "base platform", found)
	for n in found:
		if not n is MeshInstance3D:
			continue
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		print("[LANES8] baked '", n.name, "' surfaces=", mi.mesh.get_surface_count())
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			var mname: String = "<none>"
			if mat != null and mat.resource_name != "":
				mname = mat.resource_name
			elif mat != null:
				mname = mat.get_class()
			print("[LANES8]   surface ", s, " material=", mname)

func _mod_hide_rails() -> int:
	var rails: Array[Node3D] = []
	_mod_collect_named(self, MOD_RAIL_NAME_HINT, rails)

	if rails.is_empty():
		push_warning("[LANES8] no divider rails matched '%s'; rails unchanged"
			% MOD_RAIL_NAME_HINT)
		return 0

	for r in rails:
		r.visible = false

	if Array(OS.get_cmdline_args()).has("-localtest"):
		for r in rails:
			var extent: String = ""
			if r is MeshInstance3D and (r as MeshInstance3D).mesh != null:
				var ab: AABB = (r as MeshInstance3D).mesh.get_aabb()
				extent = " size=(%.2f, %.2f, %.2f)" % [ab.size.x, ab.size.y, ab.size.z]
			print("[LANES8] rail hidden name=", r.name,
				" x=%.2f" % r.position.x, extent)

	return rails.size()

func _mod_split_crts() -> int:

	var crts: Array[Node3D] = []
	_mod_collect_named(self, MOD_CRT_NAME_HINT, crts)

	if crts.size() != MOD_VANILLA_LANES:
		push_warning("[LANES8] expected %d CRT screens, found %d; screens unchanged"
			% [MOD_VANILLA_LANES, crts.size()])
		return crts.size()

	var parent: Node = crts[0].get_parent()
	for c in crts:
		if c.get_parent() != parent:
			push_warning("[LANES8] CRT screens do not share a parent; screens unchanged")
			return crts.size()

	# Their shared parent has a unit-scale basis whose first column is world X,
	# so shifting in local X moves them the same distance as the stair strips.
	crts.sort_custom(func(a, b): return a.position.x < b.position.x)

	for i in crts.size():
		var src: Node3D = crts[i]
		var clone: Node3D = src.duplicate()
		clone.name = "%s_MOD%d" % [src.name, MOD_VANILLA_LANES + i + 1]
		parent.add_child(clone)
		# Same inward/outward split as the lanes, so whatever offset the artist
		# gave a screen relative to its trough is carried to both copies.
		src.position.x -= MOD_STRIP_OFFSET
		clone.position.x += MOD_STRIP_OFFSET

	return MOD_MAX_LANES

func _mod_shape_strip(path: Path3D) -> void :
	for child in path.get_children():
		if child is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = child
			# Node scale and node offset, never the per-instance transforms:
			# stair_handler rewrites every instance each frame as
			# Transform3D(Basis(), position), so anything written there is
			# erased on the next tick.
			mmi.scale.x = MOD_STRIP_SCALE
			mmi.position.y += MOD_STEP_LIFT

func _mod_place_spawns(originals: Array[Path3D], clones: Array[Path3D]) -> void :

	if player_spawn_positions.size() < MOD_MAX_LANES:
		push_warning("[LANES8] only %d spawn markers; expected %d"
			% [player_spawn_positions.size(), MOD_MAX_LANES])
		return

	# Only the position is set - spawn_players() teleports by global_position
	# and never reads a marker's basis, which is what made the expander's
	# local-X displacement silently wrong here in the first place.
	for i in MOD_VANILLA_LANES:
		var inner: Node3D = player_spawn_positions[i]
		var outer: Node3D = player_spawn_positions[i + MOD_VANILLA_LANES]
		# Both strips take the *shipped* marker's z, so the layout does not
		# depend on what spawn_expand.py left in the added markers - it has
		# already been wrong here once, and the fixed tool now emits a
		# different z than the build this was verified against.
		var lane_z: float = inner.position.z
		var y: float = MOD_SPAWN_Y + MOD_PLAYER_LIFT
		inner.position = Vector3(originals[i].position.x, y, lane_z)
		outer.position = Vector3(clones[i].position.x, y, lane_z)

func _ready() -> void :
	super._ready()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		# Synchronous: the node is already in the tree here, so global
		# transforms are valid without waiting a frame.
		print("[ART] --- begin mesh dump ---")
		_mod_dump_all_meshes(self)
		print("[ART] --- end mesh dump ---")

	camera_3d.set_multiplayer_authority(1)

	if multiplayer.is_server():

		kill_area.area_entered.connect(_on_kill_area_entered)
		finish_area.area_entered.connect(_on_finish_area_entered)

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func initialize_debug_specifics():
	super.initialize_debug_specifics()

	post_processing_vignette.visible = false
	debug_player_specifics_initialized.emit(camera_3d.global_transform)

func _process(delta: float) -> void :

	if not multiplayer.is_server():
		return

	var highest_speed: float = 0.0
	for p in player_characters.values():
		if p.speed > highest_speed:
			highest_speed = p.speed
	highest_speed = min(highest_speed, 1.0)

	stair_handler.speed = move_toward(
		stair_handler.speed, highest_speed * 0.1, 8.0 * delta
	)

	for p in player_characters.values():
		p.set_escalator_speed_rpc.rpc(highest_speed)

func _physics_process(_delta: float) -> void :

	if not multiplayer.is_server():
		return

	if not is_all_player_loaded or active_players.is_empty():
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

func spawn_players():

	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character: EscalatorPitPlayer = player_scene.instantiate()
		players_node_parent.add_child(player_character, true)

		player_character.set_player_presence_rpc.rpc(player_presence.network_id)
		player_character.set_manager_from_path_rpc.rpc(self.get_path())
		player_character.teleport_rpc.rpc(player_spawn_positions[counter].global_position)
		player_character.correct_input.connect(_on_correct_player_input)

		player_characters[player_presence.network_id] = player_character
		active_players.append(player_character)

		player_scores[player_presence.network_id] = 0

		counter += 1

func check_game_end():

	if active_players.size() > 1:
		return

	for ap in active_players:
		ap.show_win_indicator_rpc.rpc()


	for ap in active_players:
		player_scores[ap.player_presence.network_id] += 1
		break

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finish")
	set_effects_visibility_rpc.rpc(false)

func fade_in_ambience():

	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)

func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if player_characters.has(_network_id):

		var player_instance = player_characters[_network_id]

		active_players.erase(player_instance)
		finished_players.erase(player_instance)
		player_characters.erase(_network_id)

		player_instance.queue_free()

	if multiplayer.is_server():
		check_game_end()





func _on_all_brief_ready():

	await get_tree().create_timer(1.0).timeout

	state_machine.transition_to_rpc.rpc(&"Round", {"round": round_number, "total": total_rounds})

func _on_countdown_expired():
	super._on_countdown_expired()
	for player in player_characters.values():
		player.set_active_rpc.rpc(true)
	state_machine.transition_to_rpc.rpc(&"Play")

func _on_finish_area_entered(body):

	if body.owner is EscalatorPitPlayer:

		active_players.erase(body.owner)
		if finished_players.is_empty():
			player_scored.emit(body.owner.player_presence.network_id, 2)
		else:
			player_scored.emit(body.owner.player_presence.network_id, 1)

		finished_players.append(body.owner)

		body.owner.finish_rpc.rpc()

		check_game_end()

func _on_correct_player_input(player_total_speed: float):

	if player_total_speed > collective_speed:
		collective_speed = player_total_speed

func _on_kill_area_entered(body):

	if body.owner is EscalatorPitPlayer:

		active_players.erase(body.owner)
		body.owner.kill_rpc.rpc()

		for ap in active_players:
			player_scores[ap.player_presence.network_id] += 1

		check_game_end()
