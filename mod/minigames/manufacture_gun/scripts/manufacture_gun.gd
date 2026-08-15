extends Minigame

class_name ManufactureGun

const player_scene = preload("res://minigames/manufacture_gun/components/player/manufacture_gun_player.tscn")
const workstation_scene = preload("res://minigames/manufacture_gun/components/workstation/manufacture_gun_workstation.tscn")
const item_scene = preload("res://minigames/manufacture_gun/components/item/manufacture_gun_item.tscn")

@export_category("Gameplay")
@export var recipe_material: ShaderMaterial
@export var recipe_current_color: Color
@export var recipe_wrong_color: Color
@export var recipe_inactive_color: Color
@export var recipe_fresnel_color: Color

@export_category("Components")
@export var camera: Camera3D
@export var countdown_state: State
@export var offset_every_other_playername: bool
@export var empty_desk_array: Array[Node3D]
@export var recipe_indicator_ligths: Array[Node3D]

@onready var players_node_parent: Node3D = $Players
@onready var workstations_node_parent: Node3D = $Workstations
@onready var items_node_parent: Node3D = $ItemSpawner / Items

@onready var host_synchronizer: MultiplayerSynchronizer = $HostSynchronizer
@export var item_sequence_preview_node_parent: Node3D

@export var speaker_recipe_indicator: AudioStreamPlayer
@export var sound_wrong_item_inserted: AudioStream
@export var sound_correct_item_inserted: AudioStream

@export var debug_visual_instance_parent: Node3D
@export var post_processing_vignette: Control

@export_category("Ambience")
@export var ambience_speakers: Array[AudioStreamPlayer]
@export var ambience_speaker_controllers: Array[SpeakerController]

var player_characters: Dictionary[int, ManufactureGunPlayer]
var active_players: Dictionary[int, ManufactureGunPlayer]
var finished_players: Array[ManufactureGunPlayer]
var player_scores: Dictionary[int, int]

var workstation: ManufactureGunWorkstation
var workstations: Array[ManufactureGunWorkstation]
var items: Array[ManufactureGunItem]

var sequence_preview_nodes: Array[Node3D]
var sequence_preview_node_meshes: Array[Array]

var item_sequence: Array
var local_item_sequence: Dictionary



var ach_players_with_gun: Array[int]

func _ready() -> void :
	super._ready()

	for c in item_sequence_preview_node_parent.get_children():
		sequence_preview_nodes.append(c)

	for i in sequence_preview_nodes.size():
		var sequent_preview_item_node = sequence_preview_nodes[i]
		sequence_preview_node_meshes.append(
			sequent_preview_item_node.get_children() as Array[MeshInstance3D]
		)

	for preview_meshes in sequence_preview_node_meshes:
		for preview_mesh in preview_meshes:
			if preview_mesh is MeshInstance3D:
				preview_mesh.material_override = recipe_material
				preview_mesh.set_instance_shader_parameter(
					"core_colour", recipe_current_color
				)
				preview_mesh.set_instance_shader_parameter(
					"fresnel_colour", recipe_fresnel_color
				)

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

# --- 8P MOD: FIREARM FACTORY uncapped from 4 to 8 -----------------------------
# The last capped minigame. Its cap was real: FOUR blockers, in the order they
# fire, of which only the first is ever observed because it masks the rest.
#
#  1. `$SpawnPositions` ships 4 markers. `spawn_positions[counter].global_position`
#     past index 3 is a null read (pitfall 23 - silent), so `teleport_rpc` gets
#     Nil and ABORTS the host's spawn loop. Measured at 8: the minigame never
#     reaches `Round` at all.
#  2. `$WorkstationSpawns` ships 4, same shape in spawn_workstations().
#  3. `empty_desk_array` holds 4 and is used as `empty_desk_array[i].queue_free()`
#     - a METHOD CALL past the end, which per pitfall 23 is a SIGSEGV, not a
#     silent no-op. Never seen, because (1) aborts first.
#  4. `spawn_limit = 4` on the three MultiplayerSpawners (pitfall 11).
#
# Unlike THE FILTER, the arena has room: the shipped workstations sit 15.1u apart
# on an 18.6 x 16.5 rectangle, so eight around the perimeter lands at ~8.7u and
# eight spawns at ~5.9u - both far above the ~1.6u a character occupies. So this
# expands in place rather than splitting into rooms, which would also have halved
# the opponent pool in what is a PvP arena (you score by killing people).
#
# Markers are built at RUNTIME, host-only, gated on roster > 4 - the duck_hunt /
# forklift_certified pattern. That keeps a 1-4 game seating on the shipped four
# ONLY, and keeps manufacture_gun.tscn out of the overlay entirely; the
# spawn_limit raise is done as a property write for the same reason.
const MOD_VANILLA_SLOTS: int = 4

# Two of the four added desks land against a wall with their APPROACH side
# pointing into it, and have to be turned to sit along the wall instead.
#
# Which two is decided by the interact box, not by proximity: it is
# `BoxShape3D(2, 5, 3.6)`, so the side a player approaches from runs along the
# desk's LOCAL Z - the 3.6-deep axis. At the shipped yaw of ~0 that is world Z,
# so the desks needing a turn are the ones whose offset from the arena centre is
# **Z-dominated**, i.e. the pair against the +Z / -Z walls.
#
# An earlier version tested X-dominance instead, reasoning only about which wall
# was nearest and never about which way the box actually runs. It selected the
# exact complement - turning the two desks that were already correct, and leaving
# the two broken ones alone. Proximity to a wall says nothing on its own; what
# matters is the approach axis relative to it.
const MOD_WALL_DESK_TURN_DEG: float = - 90.0

# Once turned, each desk slides ALONG its wall rather than sitting at the exact
# midpoint, and stays flush with the wall line the shipped corner desks occupy.
# The two slide in opposite directions (+X on the -Z wall, -X on the +Z wall),
# which preserves the 180-degree rotational symmetry the rest of the level has.
const MOD_WALL_DESK_SLIDE: float = 3.8

# ...and then push OUT, perpendicular to that wall. Sliding alone left each turned
# desk on the line the shipped corner desks occupy - i.e. 2.80u (MOD5) and 2.71u
# (MOD7) of bare floor between it and the wall behind it - which reads as a desk
# marooned in the room rather than one installed against the wall.
#
# The number is measured, not chosen. Re-derive it if the level is re-authored:
#
#  * the +/-Z wall inner faces sit at |z| = 11.99 (wall thickness 1.0 out to
#    12.99). Recover them by pulling `ConcavePolygonShape3D_70a5h` out of
#    manufacture_gun.tscn, offsetting by its CollisionShape3D transform
#    (10.6282, 2.34833, 0), and keeping the triangles whose normal is Z-dominated
#    at waist height - they span the full x range at |z| = 11.99 exactly.
#  * a turned desk's solid collider is `BoxShape3D(2.4, 2, 3.8)`; rotated to its
#    final yaw its footprint reaches 1.315u along z from its centre on MOD5
#    (+93.54 deg) and 1.333u on MOD7 (-94.10 deg). The two differ because each
#    inherits its yaw from its own nearest shipped marker, and the shipped four sit
#    at +3.54 to +5.08 deg rather than at 0 - so do NOT expect the pair to be
#    symmetric, and re-derive both rather than assuming one figure covers them.
#  * so MOD5's centre at z = -9.93 leaves a 0.75u gap, and MOD7's at +10.00 leaves
#    0.66u - against the 0.73u the shipped `Marker3D2` desk leaves at the -X wall.
#    That is the target: not touching the wall, but as close as vanilla ever puts
#    a desk.
#
# 2.05 is the largest push that keeps clearance on the +Z side, where the desk is
# boxed in on three sides: 0.66u to the wall, 0.72u to the rotated crate collider
# (`BoxShape3D_ulsii` at (-6.82, 3.36, 12.71)) and 0.73u to the `desk trolley`
# art. Pushing 2.4 takes the crate gap down to 0.49u.
#
# It cannot affect a 1-4 game: _mod_expand_for_roster() returns before any of this
# runs at four players or fewer, so no shipped marker is ever touched (rule 3).
const MOD_WALL_DESK_PUSH: float = 2.05

# How far an extra ingredient is nudged from the marker it shares.
#
# 0.45 was too small and the copies visibly intersected each other: measured off
# manufacture_gun_item.tscn, the five variations' footprints are 1.614 (the flat
# disc), 1.283, 1.079, 0.755 and 0.629 wide, so 0.45 puts two of them inside one
# another however they are drawn. Two copies stop touching at (w1 + w2) / 2, which
# is 1.07 for the average pair.
#
# 1.10 is that figure, checked against the surfaces the markers actually sit on.
# Of the 26 markers, 11 are on the floor (unbounded), 2 are on the +Z trolley, and
# 13 are on desks; of those 13, ten have >= 1.10u of desk left toward -X. The three
# that do not are `part_011` (0.39), `part_012` (0.75) and `part_004` (0.93), where
# the copy overhangs its desk edge a little - on surfaces where the SHIPPED single
# item already overhangs, since a 1.614-wide disc centred on `part_011` hangs 0.42u
# past the edge in vanilla too. Two flat discs is still the worst case and they
# still touch at 1.10; separating those needs 1.61, which overhangs four markers.
#
# The offset stays in WORLD space. Using the marker's own local X - the
# spawn_expand.py approach - is wrong here: 25 of the 26 markers are rotated and
# `part_001`'s basis has its Y column on world -Z, i.e. it is laid on its side, so
# a local-X nudge would bury a copy under the table (pitfall 17). `spawn_items()`
# discards marker rotation anyway and spawns every item axis-aligned.
const MOD_ITEM_SPREAD: float = 1.10

# The ingredient projection - the five-slot recipe hologram that reads as a bar
# along the bottom of the screen - is a single node in the LEVEL, not a per-player
# HUD, and `MOD8`'s added desk lands on top of it: the desk occupies x[-8.60,-5.97]
# z[-2.00,1.94] to y 2.14, the projection sits at x[-7.56,-6.34] z[-4.63,5.12] and
# y 0.62..2.50, so the desk buries the middle three of the five slots and the item
# holograms show through it.
#
# Moving the desk was ruled out - it would change the balance of the arena - so the
# projection goes up instead, by exactly its own height, measured at runtime rather
# than baked in. Roster-gated, so a 1-4 game (where nothing covers it, because MOD8
# does not exist) is untouched.
func _mod_subtree_mesh_y_extent(root: Node3D) -> Vector2:
	"""World-space y span of every mesh under `root`, as (low, high).

	Uses `mesh.get_aabb()`, which is LOCAL space, rather than
	`get_transformed_aabb()`: that returns null in the release template, and
	assigning null to a typed AABB aborts the calling function with no error line
	at all - pitfall 18, which cost half of an _ready() once."""
	var lo: float = INF
	var hi: float = - INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var ab: AABB = mi.mesh.get_aabb()
		for i in 8:
			var wy: float = (mi.global_transform * ab.get_endpoint(i)).y
			lo = minf(lo, wy)
			hi = maxf(hi, wy)
	return Vector2(lo, hi)

func _mod_raise_item_preview() -> void :
	"""Host-only measurement; the move itself is an RPC, because this alters the
	shipped scene and `initialize()` runs on the host alone - see 'Runtime scene
	changes must be RPCs' in UPDATING.md."""
	if PlayerManager.player_presences.size() <= MOD_VANILLA_SLOTS:
		return

	var preview: Node3D = item_sequence_preview_node_parent
	if preview == null:
		push_warning("[GUN8] no item_sequence_preview_node_parent to raise")
		return

	var span: Vector2 = _mod_subtree_mesh_y_extent(preview)
	var height: float = span.y - span.x
	if not is_finite(height) or height <= 0.0:
		push_warning("[GUN8] could not measure the item preview height")
		return

	zz_mod_raise_item_preview_rpc.rpc(height)

func _mod_preview_mover() -> Node3D:
	"""The node that actually moves is the PARENT of the exported one. Each of the
	five `recipe item parentN` children carries an `anim_spin recipe item`
	AnimationPlayer whose tracks are `.:position` and `.:rotation` on itself, so
	anything at or below `Visual` gets fought over every frame. Nothing animates
	`ItemSequencePreview`."""
	if item_sequence_preview_node_parent == null:
		return null
	return item_sequence_preview_node_parent.get_parent() as Node3D

# The `zz_` prefix is load-bearing: Godot assigns RPC wire ids by sorting each
# script chain's @rpc names alphabetically, so every mod RPC must sort AFTER the
# vanilla ones to leave vanilla's ids identical to an unmodded build. Any future
# mod RPC needs the same prefix.
@rpc("authority", "call_local", "reliable")
func zz_mod_raise_item_preview_rpc(amount: float) -> void :
	var mover: Node3D = _mod_preview_mover()
	if mover == null:
		push_warning("[GUN8] item preview has no Node3D parent to raise")
		return

	mover.position.y += amount

	# Deliberately inside the RPC: a host-only line would prove nothing about the
	# other seven peers, and this is a scene change, which is exactly the class of
	# fix that has silently applied on one machine before.
	if Array(OS.get_cmdline_args()).has("-localtest"):
		var span: Vector2 = _mod_subtree_mesh_y_extent(
			item_sequence_preview_node_parent)
		print("[GUN8] preview raised by %.4f" % amount,
			" is_server=", multiplayer.is_server(),
			" now y=%.3f..%.3f" % [span.x, span.y])

func _mod_nearest_shipped(shipped: Array, pos: Vector3) -> Node3D:
	"""Rotation for a new marker is taken from the nearest SHIPPED one rather
	than invented. The spawn markers face +90 on the left of the arena and -90 on
	the right, and the workstations all sit at roughly 0 - copying the nearest
	neighbour reproduces both conventions without either being written down."""
	var best: Node3D = shipped[0]
	var best_d: float = INF
	for m in shipped:
		var d: float = (m as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = m
	return best

func _mod_expand_container(container: Node3D, tag: String) -> int:
	"""Insert a marker at the midpoint of each pair of angularly-adjacent shipped
	markers - the Forklift Certified mid-edge pattern. The shipped four are the
	corners of a rectangle, so this yields eight evenly spread round its
	perimeter, and it is derived from wherever the corners actually are rather
	than from hardcoded coordinates."""
	if container == null:
		push_warning("[GUN8] missing container for %s" % tag)
		return 0

	var shipped: Array = container.get_children()
	if shipped.size() < MOD_VANILLA_SLOTS:
		push_warning("[GUN8] %s has only %d markers" % [tag, shipped.size()])
		return 0

	var centre: Vector3 = Vector3.ZERO
	for m in shipped:
		centre += (m as Node3D).global_position
	centre /= float(shipped.size())

	var ordered: Array = shipped.duplicate()
	ordered.sort_custom(func(a, b):
		var pa: Vector3 = (a as Node3D).global_position - centre
		var pb: Vector3 = (b as Node3D).global_position - centre
		return atan2(pa.z, pa.x) < atan2(pb.z, pb.x))

	var added: int = 0
	for i in ordered.size():
		var a: Node3D = ordered[i]
		var b: Node3D = ordered[(i + 1) % ordered.size()]
		var mid: Vector3 = (a.global_position + b.global_position) * 0.5

		var marker: Marker3D = Marker3D.new()
		marker.name = "%s_MOD%d" % [tag, MOD_VANILLA_SLOTS + added + 1]
		container.add_child(marker)
		marker.global_position = mid
		marker.global_rotation = _mod_nearest_shipped(shipped, mid).global_rotation

		# Z-dominated desks only: turn them so the approach runs along the wall,
		# slide them off the wall's midpoint, then push them out against the wall.
		# Applied to workstations rather than to player spawns, because a spawn is
		# a point with no footprint and wants to stay out in the open.
		var off: Vector3 = mid - centre
		if tag == "WorkstationSpawns" and absf(off.z) > absf(off.x):
			var wall_sign: float = signf(off.z)
			marker.rotate_y(deg_to_rad(MOD_WALL_DESK_TURN_DEG * wall_sign))
			marker.global_position = mid + Vector3(
				- wall_sign * MOD_WALL_DESK_SLIDE,
				0.0,
				wall_sign * MOD_WALL_DESK_PUSH)

		added += 1

	return added

func _mod_expand_for_roster() -> void :
	"""Host-only: spawn_players() and spawn_workstations() are the only readers of
	these containers and both run on the host, so the markers never need to exist
	on a client."""
	var roster: int = PlayerManager.player_presences.size()
	if roster <= MOD_VANILLA_SLOTS:
		return
	if $SpawnPositions.get_child_count() > MOD_VANILLA_SLOTS:
		return

	var spawns: int = _mod_expand_container($SpawnPositions, "SpawnPositions")
	var desks: int = _mod_expand_container($WorkstationSpawns, "WorkstationSpawns")

	# spawn_limit caps how many nodes a MultiplayerSpawner will replicate. Raised
	# as a property write so manufacture_gun.tscn stays out of the overlay - one
	# fewer file to re-derive on every game update. Pitfall 11 records that the
	# equivalent raise on disco_dodge measured as INERT, so this is
	# defence-in-depth, not the fix.
	for spawner_name in ["PlayerSpawner", "WorkstationSpawner", "ItemSpawner"]:
		var sp: Node = get_node_or_null(NodePath(spawner_name))
		if sp != null and sp.spawn_limit > 0 and sp.spawn_limit < roster:
			sp.spawn_limit = roster

	if Array(OS.get_cmdline_args()).has("-localtest"):
		var closest: float = INF
		var all: Array = $SpawnPositions.get_children()
		for i in all.size():
			for j in range(i + 1, all.size()):
				closest = minf(closest,
					(all[i] as Node3D).global_position.distance_to(
						(all[j] as Node3D).global_position))
		# The added desks' own placement is otherwise invisible: it is host-side and
		# no existing line reports where they landed, so a wrong MOD_WALL_DESK_PUSH
		# (or a re-authored level that moved the walls) could only be found by eye.
		var added_desks: Array[String] = []
		for d in $WorkstationSpawns.get_children():
			if not String(d.name).contains("_MOD"):
				continue
			var dp: Vector3 = (d as Node3D).global_position
			added_desks.append("%s@(%.2f,%.2f)/%.0fdeg" % [d.name, dp.x, dp.z,
				rad_to_deg((d as Node3D).global_rotation.y)])

		print("[GUN8] expand roster=", roster,
			" spawns=", $SpawnPositions.get_child_count(), " (+", spawns, ")",
			" desks=", $WorkstationSpawns.get_child_count(), " (+", desks, ")",
			" closest_spawn_pair=%.2f" % closest,
			" empty_desks=", empty_desk_array.size(),
			" added=", ", ".join(added_desks))

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	# 8P MOD: before spawn_players(), which reads $SpawnPositions immediately.
	_mod_expand_for_roster()

	spawn_players()
	spawn_workstations()
	spawn_items()

	# 8P MOD: after the spawn RPCs above, which are the ones already proven to
	# reach clients from inside initialize().
	_mod_raise_item_preview()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func initialize_debug_specifics():
	super.initialize_debug_specifics()

	post_processing_vignette.visible = false
	debug_player_specifics_initialized.emit(camera.global_transform)

func _physics_process(_delta: float) -> void :

	if not multiplayer.is_server():
		return

	if not is_all_player_loaded or active_players.is_empty():
		return

	if Input.is_action_just_pressed("action_4"):
		check_game_end()

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func all_players_loaded():
	super.all_players_loaded()

	if not multiplayer.is_server():
		return

	is_all_player_loaded = true
	minigame_ready.emit(multiplayer.get_unique_id())

	set_tutorial_variables.rpc(Globals.current_minigame_identifier, GameManager.custom_game, Globals.current_minigame_round)

func spawn_players():

	var spawn_positions: Array[Node3D]
	for c in $SpawnPositions.get_children():
		spawn_positions.append(c)


	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		players_node_parent.add_child(player_character, true)

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.set_manager_from_path_rpc.rpc(self.get_path())
		player_character.teleport_rpc.rpc(
			spawn_positions[counter].global_position, 
			spawn_positions[counter].global_rotation, 
		)

		player_characters[player_presence.network_id] = player_character
		active_players[player_presence.network_id] = player_character
		player_character.dead.connect(_on_player_dead)

		player_scores[player_presence.network_id] = 0

		counter += 1

func spawn_workstations():

	var spawn_positions: Array[Vector3]
	var spawn_rotations: Array[Vector3]
	for c in $WorkstationSpawns.get_children():
		spawn_positions.append(c.global_position)
		spawn_rotations.append(c.rotation_degrees)

	var counter: int = 0
	for player in active_players.values():

		var player_presence: PlayerPresence = player.player_presence

		var workstation_instance = workstation_scene.instantiate()
		workstations_node_parent.add_child(workstation_instance, true)

		workstation_instance.set_manager_from_path_rpc.rpc(self.get_path())
		workstation_instance.set_player_presence.rpc(player_presence.network_id)
		workstation_instance.teleport_rpc.rpc(spawn_positions[counter])
		workstation_instance.teleport_rpc_with_rot.rpc(spawn_positions[counter], spawn_rotations[counter])
		workstation_instance.item_assembled.connect(_on_item_assembled)

		remove_empty_workstation_rpc.rpc(counter)
		workstations.append(workstation_instance)

		if GameManager.local_game:
			local_setup_workstation(player_presence.network_id)
		else:
			spawned_workstation_rpc.rpc_id(player_presence.network_id)

		counter += 1

func local_setup_workstation(network_id: int):


	var sequence: Array = ManufactureGunItem.Variation.values()
	sequence.erase(0)
	sequence.shuffle()
	if sequence[0] == ManufactureGunItem.Variation.Three:
		sequence.pop_front()
		sequence.insert(randi_range(1, sequence.size()), ManufactureGunItem.Variation.Three)

	local_item_sequence[network_id] = sequence

	for w in workstations:
		if w.player_presence.network_id == network_id:
			w.local_set_item_sequence(sequence)
			break

func spawn_items():

	var spawn_positions: Array[Vector3]
	for c in $ItemSpawner / ItemSpawns.get_children():
		spawn_positions.append(c.global_position)
	spawn_positions.shuffle()

	var variations = ManufactureGunItem.Variation.values().duplicate()
	variations.pop_front()
	variations.shuffle()

	# 8P MOD: these are the ingredients the guns are built from, and vanilla spawns
	# exactly one per shipped marker - a fixed 26 however many players there are.
	# Eight players competing over a four-player supply would halve everyone's
	# share, so the count scales with the roster: 1 item per marker at 1-4, 2 at
	# 5-8, keeping ingredients-per-player roughly constant.
	#
	# The extra ones are nudged sideways rather than stacked. A ManufactureGunItem
	# is a plain Node3D with no physics, so two at an identical position would
	# simply intersect and never settle apart.
	var mod_per_marker: int = int(ceil(
		float(PlayerManager.player_presences.size()) / float(MOD_VANILLA_SLOTS)))
	mod_per_marker = maxi(mod_per_marker, 1)
	var mod_spawned: int = 0

	for spawn_position in spawn_positions:
		for mod_copy in mod_per_marker:

			var item_instance: ManufactureGunItem = item_scene.instantiate()
			items_node_parent.add_child(item_instance, true)

			# Copy 0 sits exactly where vanilla puts it, so 1-4 is unchanged.
			var mod_offset: Vector3 = Vector3.ZERO
			if mod_copy > 0:
				var ang: float = TAU * (float(mod_copy) / float(mod_per_marker))
				mod_offset = Vector3(cos(ang), 0.0, sin(ang)) * MOD_ITEM_SPREAD

			item_instance.teleport_rpc.rpc(spawn_position + mod_offset, Vector3.ZERO)
			item_instance.set_variation_rpc.rpc(variations.pop_front(), true)
			items.append(item_instance)
			mod_spawned += 1

			if variations.is_empty():
				variations = ManufactureGunItem.Variation.values().duplicate()
				variations.pop_front()
				variations.shuffle()

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[GUN8] items roster=", PlayerManager.player_presences.size(),
			" markers=", spawn_positions.size(),
			" per_marker=", mod_per_marker, " total=", mod_spawned)

func update_sequence(_item_sequence):
	item_sequence = _item_sequence

func check_game_end():

	if active_players.size() > 1:
		return


	if not active_players.is_empty():
		for network_id in active_players.keys():
			var player = active_players[network_id]
			player_scores[network_id] += 1
			player.finished_rpc.rpc()
			break

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finish")
	set_effects_visibility_rpc.rpc(false)


@rpc("authority", "call_local", "reliable")
func set_tutorial_variables(current_minigame_identifier, custom_game, minigame_round):
	Globals.current_minigame_identifier = current_minigame_identifier
	GameManager.custom_game = custom_game
	Globals.current_minigame_round = minigame_round

@rpc("any_peer", "call_local", "reliable")
func spawned_workstation_rpc():

	for w in workstations_node_parent.get_children():
		if w.player_presence.network_id == multiplayer.get_unique_id():
			workstation = w
			workstation.set_sequence_preview_node(item_sequence_preview_node_parent)
			request_item_sequence_rpc.rpc_id(1, multiplayer.get_unique_id())
			return


@rpc("any_peer", "call_local", "reliable")
func request_item_sequence_rpc(network_id: int):
	if multiplayer.is_server():

		var sequence: Array = ManufactureGunItem.Variation.values()
		sequence.erase(0)
		sequence.shuffle()
		if sequence[0] == ManufactureGunItem.Variation.Three:
			sequence.pop_front()
			sequence.insert(randi_range(1, sequence.size()), ManufactureGunItem.Variation.Three)

		if network_id == 1:
			update_sequence(sequence)
		else:
			receive_item_sequence_rpc.rpc_id(network_id, sequence)

		for w in workstations:
			if w.player_presence.network_id == network_id:
				w.set_item_sequence_rpc.rpc_id(network_id, sequence)


@rpc("any_peer", "call_remote", "reliable")
func receive_item_sequence_rpc(sequence: Array):
	update_sequence(sequence)



@rpc("any_peer", "call_local", "reliable")
func remove_empty_workstation_rpc(index: int):
	# 8P MOD: `empty_desk_array` holds exactly four placeholder desks, one per
	# shipped workstation slot, freed as the real workstation takes its place.
	# Players 5-8 spawn at mid-edge positions where no placeholder was ever
	# authored, so there is simply nothing to remove for them.
	#
	# This guard is NOT cosmetic. Indexing past the end and calling a method on
	# the result - `empty_desk_array[4].queue_free()` - is the one case in
	# pitfall 23 that CRASHES the process (SIGSEGV) rather than failing quietly.
	# It was never observed only because the spawn loop aborted earlier.
	if index < 0 or index >= empty_desk_array.size():
		return
	empty_desk_array[index].queue_free()



func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	# 8P MOD: before the game has started there is nothing to end - the peer
	# was never spawned here and its presence is already pruned. Vanilla's end
	# check below would see zero players and finish an unstarted game
	# (pitfall 32; session log 2026-08-15).
	if not is_all_player_loaded:
		return

	# 8P MOD: a peer that dropped during the load was never spawned here even
	# though the game has since started. Vanilla indexes unguarded; the release
	# build swallows the miss as null (pitfall 34), a debug build errors.
	var player_instance = active_players.get(_network_id, null)

	active_players.erase(_network_id)

	if player_instance:
		player_instance.queue_free()
		active_players.erase(_network_id)

	if player_characters.has(_network_id):
		player_characters.erase(_network_id)

	check_game_end()

func _on_item_assembled(network_id: int):

	player_scores[network_id] += 1
	ach_players_with_gun.append(network_id)

func _on_all_brief_ready():

	await get_tree().create_timer(1.0).timeout
	state_machine.transition_to_rpc.rpc(&"Round", {"round": round_number, "total": total_rounds})

func _on_countdown_expired():

	super._on_countdown_expired()
	for player in player_characters.values():
		player.set_active_rpc.rpc()
	state_machine.transition_to_rpc.rpc(&"Play")

func _on_player_dead(network_id, killer_network_id):

	if ach_players_with_gun.has(network_id):
		if active_players.has(killer_network_id):
			active_players[killer_network_id].trigger_achievement_rpc.rpc()

	player_scores[killer_network_id] += 1
	active_players.erase(network_id)

	check_game_end()
