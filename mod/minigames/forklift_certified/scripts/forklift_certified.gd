extends Minigame

class_name ForkliftCertifiedMinigame

const player_scene = preload("uid://bsv3e0qog8k42")

@export_category("Variables")
@export var countdown_time: int = 30
@export var min_countdown_time: int = 10

@export_category("Nodes")
@export var players_node: Node3D

@export var delivery_area_parent: Node3D
@export var player_spawn_positions_node: Node3D
@export var round_timer: Timer
@export var timer_label: Label
@export var crate_manager: ForkliftCertifiedCrateManager
@export var blood_decals_environment_parent: Node3D
@export var speaker_round_end: AudioStreamPlayer
@export var speaker_death: AudioStreamPlayer
@export var ambience_speaker_controllers: Array[SpeakerController]

@export_category("States")
@export var countdown_state: State

var pre_check_player_count: int = 0
var extra_crates_to_remove: int = 0
var round_timer_value: int = 0

var delivery_areas: Array[ForkilftCertifiedDeliveryArea]

var players: Dictionary[int, Node3D]
var active_players: Dictionary[int, Node3D]
var player_scores: Dictionary[int, int]
var dead_players: Array[int]
var player_count: int = 0



var check_id_threshold: int = 0
var local_check_id_threshold: int = -2
var set_inactive_area_to: int = -2

var ach_crate_number: int = 4

# 8-PLAYER MOD ---------------------------------------------------------------
#
# The yard ships four DropAreas at its corners and spawn_players() indexes BOTH
# the spawn markers and delivery_areas[] with the same counter, so player 5 runs
# off the end of a 4-entry array, the host's spawn loop aborts before any state
# transition, and the minigame loads to a black screen with the ambience still
# looping. Four more zones and four more markers are therefore needed together,
# paired by index.
#
# globals.gd used to justify the 4-player cap with "the four zones tile the
# whole 32x32 yard ... There is no room". Measured off the scene, they cover 24%
# of a 53.6 x 58.6 floor - and the inverted `CSGBox3D main collider` is the ONLY
# static collider in the level, so every bit of that floor is drivable. The
# shelves and pipes are visual-only. That leaves a 16.7-wide channel between the
# zone columns and an 18.3-deep band between the rows, which is where the four
# added zones go: one at each mid-edge, making a 3x3 ring with a free centre.
#
# Everything below is gated on the roster exceeding four and built at runtime,
# so forklift_certified.tscn is untouched and a 1-4 player game never runs any
# of it.
const MOD_VANILLA_AREAS: int = 4

# duplicate() defaults to DUPLICATE_SIGNALS|GROUPS|SCRIPTS. Signals must be
# dropped: on the host the shipped zones already carry a crate_number_changed
# connection made in _ready() below, and each zone connects its own
# body_entered/body_exited in ITS _ready(), which runs again on the clone when
# it enters the tree. Copying those would double-count every crate.
const MOD_DUPLICATE_FLAGS: int = 6  # DUPLICATE_GROUPS | DUPLICATE_SCRIPTS

# A crate is 3x3 and is spawned with a random Y rotation, so its worst-case
# footprint radius is the half-diagonal. Crates must clear every zone edge by
# this much or one spawns already inside somebody's zone and scores for free.
const MOD_CRATE_CLEARANCE: float = 2.122

const MOD_AUDIT_DELAY: float = 6.0

# Decals already moved onto the floor, oldest first. Only read when the shipped
# pool of four runs dry, which needs a fifth elimination - see spawn_blood_rpc().
var _mod_placed_decals: Array[Node3D] = []

func _mod_trace() -> bool:
	return Array(OS.get_cmdline_args()).has("-localtest")

func _mod_sorted_grid(parent: Node) -> Array[Node3D]:
	"""The shipped four, ordered far-west, far-east, near-west, near-east.

	Both the zones and the spawn markers are laid out as the same 2x2 grid, and
	the shipped child order already pairs them index for index. Sorting into a
	known order lets the added ones be appended to both lists in one shared
	order, so index 4..7 keeps pairing marker to zone the way 0..3 does.
	"""
	var ordered: Array[Node3D] = []
	var out: Array[Node3D] = []
	for c in parent.get_children():
		if c is Node3D:
			out.append(c as Node3D)
	if out.size() != MOD_VANILLA_AREAS:
		return ordered

	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)

	var far_row: Array[Node3D] = []
	far_row.append(out[0])
	far_row.append(out[1])
	var near_row: Array[Node3D] = []
	near_row.append(out[2])
	near_row.append(out[3])
	far_row.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	near_row.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)

	ordered.append(far_row[0])
	ordered.append(far_row[1])
	ordered.append(near_row[0])
	ordered.append(near_row[1])
	return ordered

func _mod_mid_edge_slots(grid: Array[Node3D]) -> Array:
	"""[position, template index] for the four mid-edge slots, in a fixed order.

	Positions are the midpoints of the shipped grid rather than literals, so a
	level retune carries through. The template is the shipped node whose row the
	new one joins - it decides `flip_display` on a zone and the facing on a
	marker. The two mid-band slots (west, east) have no row of their own and
	take the far row's, which points them along the wall into the yard.
	"""
	return [
		[(grid[0].position + grid[1].position) * 0.5, 0],  # mid far
		[(grid[2].position + grid[3].position) * 0.5, 2],  # mid near
		[(grid[0].position + grid[2].position) * 0.5, 0],  # mid west
		[(grid[1].position + grid[3].position) * 0.5, 1],  # mid east
	]

func _mod_zone_rect(area: Node3D) -> Rect2:
	"""A zone's world XZ footprint, read off its collision box."""
	for c in area.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var box: BoxShape3D = (c as CollisionShape3D).shape as BoxShape3D
			var centre: Vector3 = (c as CollisionShape3D).global_position
			return Rect2(
				centre.x - box.size.x * 0.5,
				centre.z - box.size.z * 0.5,
				box.size.x,
				box.size.z
			)
	return Rect2()

# Every node the delivery-area script reaches through an @export. These are
# object REFERENCES, not paths - the scene resolves the NodePath once at load -
# so duplicate() copies the pointer and a clone ends up driving the TEMPLATE's
# border, counter, light and speaker. It is silent: the clone's own border keeps
# its shipped material, whose albedo is Color(0,0,0,1), so the added zones
# rendered as bare floor while the corner zone they were cloned from had its
# red/green indicator and its "00" counter written by two owners at once.
#
# Found by looking at the game, not by a trace. Nothing measurable was wrong -
# belongs_to_id, the zone count and the ownership count were all correct on
# every peer, because those live on the clone itself. Worth remembering as a
# category: an @export node reference survives duplicate() pointing at the
# original, so ANY runtime clone of a scripted node needs this rebind.
const MOD_ZONE_NODE_EXPORTS: Array[String] = [
	"border_mesh_instance",
	"display_background_mesh_instance",
	"counter_label",
	"area_light",
	"speaker_mechanism",
]

# A zone's border plate sits at local y -0.221 and its readout at -0.255, i.e.
# BELOW the plane the forklifts drive on. That works at the four shipped corners
# because each sits in a bay recessed into the floor art, and it is why the
# added zones rendered as bare floor: at the mid-edges the floor is flat, so both
# plates are buried in it and only show through the slots in the grating art.
# The recess is art only - the sole collider in the level is the flat CSG box -
# so nothing detected it. Lift the plates to just above the floor instead.
const MOD_ZONE_ART_CLEARANCE: float = 0.03

# The far row's readouts jut ~2.4u past their zones into the mid band, and an
# unshifted side zone's border plate reaches right into them - the red that was
# clipping through the top two score boxes. Push the side zones clear by this
# much more than touching.
const MOD_ZONE_ART_MARGIN: float = 0.3

# The grey grid plate inside each shipped bay is painted into the yard mesh
# (`main floor_001`), not a node under the zone, so there is nothing to clone and
# the added zones read as plain red slabs. Workarounds considered:
#
#   - the zone's own SpotLight3D `light_projector` - it is
#     knife_at_the_office/light_01.png, a generic cookie, not the bay art;
#   - cloning the bay from the floor - `main floor_001` has no per-bay child,
#     the four bays are baked into one mesh;
#   - a Decal projecting the art onto the floor - would blend better, but the
#     blood pool already spawns up to eight decals and the size/orientation
#     tuning is a second unknown;
#   - shipping a new texture in the mod - unnecessary, the art is already here.
#
# So: a plane sampling the sub-rect of the shipped atlas that holds the plate.
# The box was measured off the 512x512 source; it is the framed grid with its
# corner brackets and the "DESIGNATED LOAD AREA" legend. This is the one place
# the mod deviates from vanilla art placement, with the user's go-ahead - the
# faked plate sits ON the floor where the shipped ones are recessed into it.
const MOD_PLATE_TEXTURE: String = "res://minigames/forklift_certified/models/forklift certified visuals1/forklift certified visuals1_fc area indicator8 marked8.png"
const MOD_PLATE_UV_OFFSET: Vector2 = Vector2(34.0 / 512.0, 6.0 / 512.0)
const MOD_PLATE_UV_SCALE: Vector2 = Vector2(276.0 / 512.0, 260.0 / 512.0)

# How much of the red plate the grey plate covers, leaving the rest as the frame.
const MOD_PLATE_INSET: float = 0.86

# Requested 2026-08-04: the added zones' red plates read as oversized next to the
# shipped bays. Visual only - the Area3D that actually detects crates is left at
# the shipped size.
const MOD_BORDER_SHRINK: float = 0.9

# Only used if a shipped zone is missing a plate or readout to measure; the
# shipped value is 2.16.
const MOD_READOUT_GAP_FALLBACK: float = 2.16

func _mod_add_zone_plate(copy: Node3D, floor_y: float) -> bool:
	"""Fake the bay's grid plate with a plane sampling the shipped atlas."""
	var border: Node3D = copy.get("border_mesh_instance") as Node3D
	if border == null:
		return false

	var texture: Texture2D = load(MOD_PLATE_TEXTURE) as Texture2D
	if texture == null:
		push_warning("[FORK8] no plate texture at %s - added zones keep a plain red plate"
			% MOD_PLATE_TEXTURE)
		return false

	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = _mod_plane_size(border) * MOD_PLATE_INSET

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.uv1_offset = Vector3(MOD_PLATE_UV_OFFSET.x, MOD_PLATE_UV_OFFSET.y, 0.0)
	mat.uv1_scale = Vector3(MOD_PLATE_UV_SCALE.x, MOD_PLATE_UV_SCALE.y, 1.0)
	# Matches the shipped border material, which sets texture_filter = 2.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.texture_repeat = false

	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = "ModZonePlate"
	plate.mesh = mesh
	plate.material_override = mat
	copy.add_child(plate)
	plate.global_position = Vector3(
		border.global_position.x,
		floor_y + MOD_ZONE_ART_CLEARANCE * 2.0,
		border.global_position.z
	)
	return true

func _mod_floor_y() -> float:
	"""The plane the forklifts stand on, read off a shipped spawn marker."""
	var markers: Array[Node3D] = _mod_sorted_grid(player_spawn_positions_node)
	if markers.is_empty():
		return 0.0
	return markers[0].global_position.y

func _mod_plane_size(node: Node3D) -> Vector2:
	"""World XZ footprint of a PlaneMesh child.

	Built from `mesh.size` and the node's scale rather than
	`get_transformed_aabb()`, which returns **null** in the release template and
	aborts the calling function with nothing printed - pitfall 18.
	"""
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi == null or mi.mesh == null:
		return Vector2.ZERO
	var plane: PlaneMesh = mi.mesh as PlaneMesh
	if plane == null:
		return Vector2.ZERO
	var scale: Vector3 = mi.global_transform.basis.get_scale()
	return Vector2(plane.size.x * scale.x, plane.size.y * scale.z)

func _mod_readout_gap(template: Node3D) -> float:
	"""How far a shipped readout sits beyond its own zone's plate edge.

	Learned from the shipped zone rather than hardcoded, so the side zones keep
	the same spacing as the corners if the level is ever retuned.
	"""
	var plate: Node3D = template.get("border_mesh_instance") as Node3D
	var readout: Node3D = template.get("display_background_mesh_instance") as Node3D
	if plate == null or readout == null:
		return MOD_READOUT_GAP_FALLBACK
	return readout.position.z - (plate.position.z + _mod_plane_size(plate).y * 0.5)

func _mod_fit_added_zone(copy: Node3D, shipped: Array[Node3D], floor_y: float, is_side: bool) -> bool:
	"""Make an added zone's plates visible and clear of the shipped furniture."""
	var border: Node3D = copy.get("border_mesh_instance") as Node3D
	var display: Node3D = copy.get("display_background_mesh_instance") as Node3D

	if border != null:
		border.scale *= MOD_BORDER_SHRINK

	# The two mid-band zones are the only added ones with no row of their own,
	# so they are the only ones that can run into another zone's readout.
	if is_side and border != null:
		var border_half: float = _mod_plane_size(border).y * 0.5
		var border_far_edge: float = border.global_position.z - border_half
		var blocked: float = -INF
		for zone in shipped:
			var panel: Node3D = zone.get("display_background_mesh_instance") as Node3D
			if panel == null or panel.global_position.z >= copy.global_position.z:
				continue
			blocked = maxf(blocked, panel.global_position.z + _mod_plane_size(panel).y * 0.5)

		if not is_inf(blocked):
			var shift: float = blocked + MOD_ZONE_ART_MARGIN - border_far_edge
			if shift > 0.0:
				copy.position.z += shift
				if _mod_trace():
					print("[FORK8] fit ", copy.name, " shifted z by %.2f to clear a shipped readout at %.2f"
						% [shift, blocked])

		# A shipped readout sits just beyond its zone's outward edge along z.
		# Neither z direction is free for the side zones - the far row's readouts
		# are on one side and the near row's bays on the other - so theirs go
		# beyond the outward edge along X instead, into the margin against the
		# side wall. The quarter turn is required, not cosmetic: the housing is
		# 4.6 long and the margin left of the plate is only ~4.3 wide, so
		# unrotated it would bury itself in the wall. Turned, it needs 2.8.
		if display != null and not shipped.is_empty():
			var outward: float = signf(copy.global_position.x)
			var gap: float = _mod_readout_gap(shipped[0])
			display.position.x = border.position.x + outward * (_mod_plane_size(border).x * 0.5 + gap)
			display.position.z = border.position.z
			display.rotation_degrees.y += -90.0 * outward
			if _mod_trace():
				print("[FORK8] fit ", copy.name, " readout to (%.2f, %.2f) gap=%.2f half_width=%.2f"
					% [display.global_position.x, display.global_position.z,
						gap, _mod_plane_size(display).y * 0.5])

	if border != null:
		border.global_position.y = floor_y + MOD_ZONE_ART_CLEARANCE
	if display != null:
		display.global_position.y = floor_y + MOD_ZONE_ART_CLEARANCE

	return _mod_add_zone_plate(copy, floor_y)

func _mod_rebind_zone_exports(template: Node3D, copy: Node3D) -> int:
	"""Re-point a clone's exported node references at its own children.

	The path is learned from where the reference sits under the template rather
	than hardcoded, so a scene reshuffle carries through instead of silently
	resolving to null - the failure mode under "Never reach scene nodes by a
	hardcoded relative path".
	"""
	var rebound: int = 0
	for prop in MOD_ZONE_NODE_EXPORTS:
		var ref: Node = template.get(prop) as Node
		if ref == null:
			push_warning("[FORK8] %s has no %s to rebind" % [template.name, prop])
			continue
		var relative: NodePath = template.get_path_to(ref)
		var mine: Node = copy.get_node_or_null(relative)
		if mine == null:
			push_warning("[FORK8] %s has no node at %s for %s" % [copy.name, relative, prop])
			continue
		copy.set(prop, mine)
		rebound += 1
	return rebound

@rpc("authority", "call_local", "reliable")
func mod_add_delivery_areas_rpc() -> void:
	"""Build the four mid-edge zones on every peer.

	This CANNOT be a host-local clone. The zones sit outside any
	MultiplayerSpawner and the game drives them with set_owner_rpc /
	update_counter_rpc / set_indicator_light_rpc, which resolve by node path, so
	a zone that exists only on the host is an RPC into thin air on all seven
	clients. Reliable RPCs are ordered, so the set_owner_rpc calls that
	spawn_players() sends straight afterwards arrive with the nodes already
	built - the same guarantee mod_add_stations_rpc() relies on in Chisel.
	"""
	if delivery_area_parent.get_child_count() > MOD_VANILLA_AREAS:
		return

	var grid: Array[Node3D] = _mod_sorted_grid(delivery_area_parent)
	if grid.is_empty():
		push_warning("[FORK8] expected %d shipped zones, found %d - not expanding"
			% [MOD_VANILLA_AREAS, delivery_area_parent.get_child_count()])
		return

	var floor_y: float = _mod_floor_y()
	var slots: Array = _mod_mid_edge_slots(grid)
	var rebound: int = 0
	var plates: int = 0
	for i in slots.size():
		var template: Node3D = grid[slots[i][1]]
		var copy: Node3D = template.duplicate(MOD_DUPLICATE_FLAGS) as Node3D
		copy.name = "DropArea_MOD%d" % (MOD_VANILLA_AREAS + 1 + i)
		copy.position = slots[i][0]
		# Before add_child, because _ready() reads these the moment it enters
		# the tree and caches a material off border_mesh_instance.
		rebound += _mod_rebind_zone_exports(template, copy)
		delivery_area_parent.add_child(copy)
		# After add_child - the fit works in world space. Slots 2 and 3 are the
		# mid-band pair; see _mod_mid_edge_slots().
		if _mod_fit_added_zone(copy, grid, floor_y, i >= 2):
			plates += 1

	if _mod_trace():
		var line: PackedStringArray = []
		for c in delivery_area_parent.get_children():
			var r: Rect2 = _mod_zone_rect(c as Node3D)
			line.append("%s@(%.2f,%.2f)" % [c.name, r.get_center().x, r.get_center().y])
		print("[FORK8] zones is_server=", multiplayer.is_server(),
			" peer=", multiplayer.get_unique_id(),
			" zones=", delivery_area_parent.get_child_count(),
			" added=", slots.size(),
			" rebound=", rebound, "/", slots.size() * MOD_ZONE_NODE_EXPORTS.size(),
			" plates=", plates, "/", slots.size(),
			" at=", ", ".join(line))

func _mod_add_spawn_markers() -> void:
	"""Host-only: clients never see a marker, only the position it resolves to.

	setup_rpc() carries the world position and rotation, so keeping the markers
	on the host alone also keeps them out of the shuffled marker list that a 1-4
	game walks - the deviation documented under "Spawn markers are visible to
	1-4 player games too". Forklift sidesteps it entirely.
	"""
	if not multiplayer.is_server():
		return
	if player_spawn_positions_node.get_child_count() > MOD_VANILLA_AREAS:
		return

	var grid: Array[Node3D] = _mod_sorted_grid(player_spawn_positions_node)
	if grid.is_empty():
		push_warning("[FORK8] expected %d shipped spawn markers, found %d - not expanding"
			% [MOD_VANILLA_AREAS, player_spawn_positions_node.get_child_count()])
		return

	var slots: Array = _mod_mid_edge_slots(grid)
	for i in slots.size():
		var marker: Marker3D = Marker3D.new()
		marker.name = "Marker3D_MOD%d" % (MOD_VANILLA_AREAS + 1 + i)
		player_spawn_positions_node.add_child(marker)
		marker.position = slots[i][0]
		marker.rotation = grid[slots[i][1]].rotation

func _mod_set_crate_region() -> void:
	"""Hand the crate manager the free floor left inside the ring of zones.

	The shipped sampler asks PoissonDiscSampling for `roster * 2` points at a
	4.0 separation inside a fixed 12x12 box, looping `while points.size() <
	target_size` with no bound. That box tops out around 10 points: 8 (four
	players) lands about half the time, 10 (five) takes ~160 calls, and 12 or
	more NEVER succeeds - measured 0 in 100,000 runs of the shipped algorithm.
	At six players and up vanilla would spin in that while loop forever. It is
	invisible today only because spawn_players() aborts first, and it would have
	presented as a host freeze with no error line rather than a black screen.
	"""
	var zones: Array[Node] = delivery_area_parent.get_children()
	if zones.size() <= MOD_VANILLA_AREAS:
		return

	var mean: Vector2 = Vector2.ZERO
	var rects: Array[Rect2] = []
	for z in zones:
		var r: Rect2 = _mod_zone_rect(z as Node3D)
		if not r.has_area():
			push_warning("[FORK8] zone %s has no box collider - keeping the vanilla crate box" % z.name)
			return
		rects.append(r)
		mean += r.get_center()
	mean /= rects.size()

	# The ring is a 3x3 grid with a free centre cell. Its bounds are the inner
	# edges of the zones sitting either side of the middle; the mid-edge zones
	# straddle the centre on one axis and are skipped on that axis by the gap.
	var gap: float = rects[0].size.x * 0.25
	var x0: float = -INF
	var x1: float = INF
	var z0: float = -INF
	var z1: float = INF
	for r in rects:
		var c: Vector2 = r.get_center()
		if c.x < mean.x - gap:
			x0 = maxf(x0, r.end.x)
		elif c.x > mean.x + gap:
			x1 = minf(x1, r.position.x)
		if c.y < mean.y - gap:
			z0 = maxf(z0, r.end.y)
		elif c.y > mean.y + gap:
			z1 = minf(z1, r.position.y)

	if is_inf(x0) or is_inf(x1) or is_inf(z0) or is_inf(z1):
		push_warning("[FORK8] could not resolve a free centre cell - keeping the vanilla crate box")
		return

	var region: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0).grow(-MOD_CRATE_CLEARANCE)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		push_warning("[FORK8] centre cell %.2f x %.2f is smaller than a crate - keeping the vanilla crate box"
			% [x1 - x0, z1 - z0])
		return

	crate_manager.mod_set_spawn_region(region)

	if _mod_trace():
		print("[FORK8] crate_region x=[%.2f,%.2f] z=[%.2f,%.2f] size=%.2fx%.2f clearance=%.3f"
			% [region.position.x, region.end.x, region.position.y, region.end.y,
				region.size.x, region.size.y, MOD_CRATE_CLEARANCE])

func _mod_expand_yard() -> void:
	var roster: int = PlayerManager.player_presences.size()

	if roster <= MOD_VANILLA_AREAS:
		if _mod_trace():
			print("[FORK8] zones roster=", roster,
				" zones=", delivery_area_parent.get_child_count(),
				" markers=", player_spawn_positions_node.get_child_count(),
				" added=0 (vanilla)")
		return

	mod_add_delivery_areas_rpc.rpc()

	# _ready() built delivery_areas and wired crate_number_changed from the
	# children that existed then. The clones are neither, and _on_crate_numbers_changed
	# iterates this array - a zone missing from it never lights up and never
	# grants its achievement.
	if multiplayer.is_server():
		for c in delivery_area_parent.get_children():
			var area: ForkilftCertifiedDeliveryArea = c as ForkilftCertifiedDeliveryArea
			if area == null or delivery_areas.has(area):
				continue
			delivery_areas.append(area)
			if not area.crate_number_changed.is_connected(_on_crate_numbers_changed):
				area.crate_number_changed.connect(_on_crate_numbers_changed)

	_mod_add_spawn_markers()
	_mod_set_crate_region()

	if _mod_trace():
		print("[FORK8] expanded roster=", roster,
			" zones=", delivery_area_parent.get_child_count(),
			" tracked=", delivery_areas.size(),
			" markers=", player_spawn_positions_node.get_child_count())

func _mod_localtest_audit() -> void :
	"""Per-peer count of what actually exists, not what the host meant to build.

	Zones are cloned through an RPC and players through a MultiplayerSpawner, so
	the host succeeding says nothing about the other seven. This reports the
	spawned forklifts, the zone nodes, and how many of those zones actually got
	an owner - the last being the one that would catch a marker/zone pairing
	that drifted out of step without erroring.
	"""
	await get_tree().create_timer(MOD_AUDIT_DELAY).timeout

	var roster: int = PlayerManager.player_presences.size()
	var expected_zones: int = MOD_VANILLA_AREAS if roster <= MOD_VANILLA_AREAS else MOD_VANILLA_AREAS * 2

	var zone_names: PackedStringArray = []
	var owned: int = 0
	for c in delivery_area_parent.get_children():
		var area: ForkilftCertifiedDeliveryArea = c as ForkilftCertifiedDeliveryArea
		if area == null:
			continue
		zone_names.append("%s:%d" % [area.name, area.belongs_to_id])
		if area.belongs_to_id > 0:
			owned += 1

	var spawned: int = players_node.get_child_count()

	print("[FORK8] spawned is_server=", multiplayer.is_server(),
		" peer=", multiplayer.get_unique_id(),
		" roster=", roster,
		" players=", spawned,
		" zones=", delivery_area_parent.get_child_count(),
		" expected_zones=", expected_zones,
		" owned=", owned,
		" nodes=", ", ".join(zone_names))

	if spawned != roster or delivery_area_parent.get_child_count() != expected_zones or owned != roster:
		push_warning("[FORK8] roster %d should give %d forklifts, %d zones and %d owners, got %d / %d / %d"
			% [roster, roster, expected_zones, roster,
				spawned, delivery_area_parent.get_child_count(), owned])

# END 8-PLAYER MOD ------------------------------------------------------------

func _ready() -> void :
	super._ready()

	if _mod_trace():
		_mod_localtest_audit()

	if multiplayer.is_server():

		for c in delivery_area_parent.get_children():
			delivery_areas.append(c)
			c.crate_number_changed.connect(_on_crate_numbers_changed)

		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		round_timer.timeout.connect(_on_round_timer_timeout)

	if GameManager.local_game:

		check_id_threshold = local_check_id_threshold
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
	crate_manager.spawn_crates(PlayerManager.player_presences.keys().size() * 2)

	round_number = _round_number
	total_rounds = _total_rounds
	minigame_overlay.set_round_rpc.rpc(_round_number, _total_rounds)

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func spawn_players():

	# 8-PLAYER MOD: runs before anything reads the marker or zone lists, because
	# both are indexed by the same counter below. Host-only path, so the zones
	# go out as an RPC; see _mod_expand_yard().
	_mod_expand_yard()

	var shuffled_indicies: Array[int] = []
	for i in player_spawn_positions_node.get_child_count():
		shuffled_indicies.append(i)
	shuffled_indicies.shuffle()

	var spawn_positions = player_spawn_positions_node.get_children()
	var delivery_area_nodes = delivery_area_parent.get_children()
	player_count = PlayerManager.player_presences.size()

	var counter: int = 0
	for i in PlayerManager.player_presences.size():
		var network_id = PlayerManager.player_presences.keys()[i]

		var player_character = player_scene.instantiate()
		players_node.add_child(player_character, true)

		player_character.set_player_presence.rpc(network_id)
		player_character.setup_rpc.rpc(
			spawn_positions[shuffled_indicies[counter]].global_position, 
			spawn_positions[shuffled_indicies[counter]].global_rotation, 
			delivery_areas[shuffled_indicies[counter]].get_path()
		)

		delivery_area_nodes[shuffled_indicies[counter]].set_owner_rpc.rpc(network_id)

		# 8-PLAYER MOD: the marker and the zone are picked with the SAME index,
		# so a list that grew out of step pairs a player with someone else's
		# zone silently. This prints the pair that was actually used.
		if _mod_trace():
			var _slot: int = shuffled_indicies[counter]
			print("[FORK8] pairing slot=", _slot,
				" id=", network_id,
				" marker=", spawn_positions[_slot].name,
				" zone=", delivery_area_nodes[_slot].name,
				" at=(%.2f,%.2f)" % [
					spawn_positions[_slot].global_position.x,
					spawn_positions[_slot].global_position.z])

		players[network_id] = player_character
		active_players[network_id] = player_character
		player_scores[network_id] = 0

		counter += 1

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	disconnect_player_rpc.rpc(_network_id)
	await get_tree().create_timer(1.0).timeout

	check_game_end(true)

func check_game_end(from_disconnect: bool = false):

	if active_players.size() > 1:
		if from_disconnect:
			return
		else:
			start_new_round()
			return

	for network_id in active_players.keys():
		player_scores[network_id] = player_count


		break

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)

func disable_forklifts():

	for player in active_players.values():
		player.disable_at_round_end_rpc.rpc()

func round_finished():

	pre_check_player_count = active_players.keys().size()

	disable_forklifts()
	if multiplayer.is_server():
		play_round_end_sound.rpc()
	await get_tree().create_timer(1.0).timeout

	remove_zero_scoring_players()


	calculate_results()
	await get_tree().create_timer(0.5).timeout

	if active_players.keys().size() == pre_check_player_count:
		extra_crates_to_remove += 1
	else:
		pre_check_player_count = active_players.keys().size()
		extra_crates_to_remove = 0

	check_game_end()

func remove_zero_scoring_players():

	var zero_scoring_areas: Array[ForkilftCertifiedDeliveryArea]
	var zero_scoring_player_ids: Array[int]

	for delivery_area in delivery_area_parent.get_children():

		if delivery_area.belongs_to_id <= check_id_threshold:
			continue

		if delivery_area.crates_in_area.size() == 0:
			zero_scoring_areas.append(delivery_area)
			zero_scoring_player_ids.append(delivery_area.belongs_to_id)

	var players_removed: Array[int]
	for network_id in zero_scoring_player_ids:
		remove_active_player_rpc.rpc(network_id)
		player_scores[network_id] = dead_players.size()
		players_removed.append(network_id)

	for area in zero_scoring_areas:
		area.set_owner_rpc.rpc(set_inactive_area_to)

	for pid in players_removed:
		if not dead_players.has(pid):
			dead_players.append(pid)

func calculate_results():

	if active_players.keys().size() <= 1:
		return


	var all_delivery_areas = delivery_area_parent.get_children()
	var active_delivery_areas: Array[ForkilftCertifiedDeliveryArea] = []
	for delivery_area in all_delivery_areas:

		if delivery_area.belongs_to_id <= check_id_threshold:
			continue

		active_delivery_areas.append(delivery_area)

	var player_ids_by_score: Dictionary
	for delivery_area in active_delivery_areas:
		var score = delivery_area.crates_in_area.size()
		if not player_ids_by_score.has(score):
			player_ids_by_score[score] = []
		player_ids_by_score[score].append(delivery_area.belongs_to_id)

	var lowest_score: int = player_ids_by_score.keys().min()
	var heighest_score: int = player_ids_by_score.keys().max()

	var players_removed: Array[int]
	if lowest_score != heighest_score:

		for player_id in player_ids_by_score[lowest_score]:
			remove_active_player_rpc.rpc(player_id)
			player_scores[player_id] = dead_players.size()
			players_removed.append(player_id)
			for delivery_area in all_delivery_areas:
				if delivery_area.belongs_to_id == player_id:
					delivery_area.set_owner_rpc.rpc(set_inactive_area_to)

	for score in player_ids_by_score.keys():
		if score >= heighest_score:
			continue
		var player_ids = player_ids_by_score[score]
		for network_id in player_ids:
			if not players_removed.has(network_id):
				remove_active_player_rpc.rpc(network_id)
				player_scores[network_id] = dead_players.size()
				players_removed.append(network_id)
				for delivery_area in all_delivery_areas:
					if delivery_area.belongs_to_id == network_id:
						delivery_area.set_owner_rpc.rpc(set_inactive_area_to)

	for pid in players_removed:
		if not dead_players.has(pid):
			dead_players.append(pid)

func start_new_round():

	var active_player_count = active_players.values().size()
	var crate_count = crate_manager.instances.size()

	var crates_to_remove: int = 1
	if active_player_count < crate_count:
		crates_to_remove = 2
	if crate_count < 5:
		crates_to_remove = 1

	crate_manager.remove_crates(crates_to_remove)

	await get_tree().create_timer(7.0).timeout

	for player in active_players.values():
		player.set_active_rpc.rpc(true)

	countdown_time = max(countdown_time - 1, min_countdown_time)
	start_round_timer()

func start_round_timer():

	round_timer_value = countdown_time
	update_timers_rpc.rpc(round_timer_value)
	round_timer.start(1.0)



@rpc("authority", "call_local", "reliable")
func play_round_end_sound():
	speaker_round_end.play()

@rpc("authority", "call_local", "reliable")
func disconnect_player_rpc(_network_id: int):

	if not multiplayer.is_server():
		return

	if players.has(_network_id):
		players.erase(_network_id)

	if active_players.has(_network_id):
		active_players[_network_id].queue_free()
		active_players.erase(_network_id)

	var remove_delivery_area_index: int = -1
	for i in delivery_areas.size():
		var da = delivery_areas[i]
		if da.belongs_to_id == _network_id:
			remove_delivery_area_index = i
			da.set_owner_rpc.rpc(set_inactive_area_to)

	player_scores.erase(_network_id)
	if not dead_players.has(_network_id):
		dead_players.append(_network_id)

	if remove_delivery_area_index >= 0:
		delivery_areas.remove_at(remove_delivery_area_index)

@rpc("authority", "call_local", "reliable")
func remove_active_player_rpc(_network_id: int):

	speaker_death.play()
	if active_players.has(_network_id):
		active_players[_network_id].set_eliminated_rpc.rpc()

		if multiplayer.is_server():
			var blood_decal_position = Vector3(
				active_players[_network_id].global_position.x, 
				1.3, 
				active_players[_network_id].global_position.z, 
			)
			spawn_blood_rpc.rpc(blood_decal_position)
		active_players.erase(_network_id)

@rpc("authority", "call_local", "reliable")
func spawn_blood_rpc(_at_pos: Vector3):

	# 8-PLAYER MOD: the scene ships FOUR Decal nodes and every elimination takes
	# one out of that parent for good. Four players can only ever produce three
	# eliminations, so vanilla never empties the pool; eight produce seven, and
	# the fifth ran get_child(0) against an empty node. That returned null and
	# aborted the caller mid-loop, so remove_zero_scoring_players() never
	# finished and round_finished() never reached check_game_end() - the round
	# hung on every peer with one engine ERROR and nothing else, and one client
	# segfaulted outright. Vanilla bug; only a roster above five can reach it.
	#
	# Refilling from a decal already on the floor keeps all seven visible rather
	# than dropping the surplus. At four players or fewer the pool cannot empty,
	# so this branch never runs and the path is bit-identical to vanilla - the
	# same by-construction parity as _mod_play_to_fit() in Duck Hunt.
	if blood_decals_environment_parent.get_child_count() == 0:
		if _mod_placed_decals.is_empty():
			push_warning("[FORK8] blood decal pool empty with nothing to clone - skipping decal")
			return
		var spare: Node3D = _mod_placed_decals[0].duplicate() as Node3D
		blood_decals_environment_parent.add_child(spare)

	var decal: Node3D = blood_decals_environment_parent.get_child(0)
	decal.get_parent().remove_child(decal)
	add_child(decal)
	_mod_placed_decals.append(decal)
	decal.global_position = _at_pos
	decal.global_rotation = Vector3(decal.global_rotation.x, randf_range(0, 360), decal.global_rotation.z)

@rpc("any_peer", "call_local", "reliable")
func update_timers_rpc(_time_remaining: int):

	timer_label.text = "%s" % [str(_time_remaining).pad_zeros(2)]



func _on_crate_numbers_changed():

	var highest_score: int = 0
	for da in delivery_areas:
		var crate_numbers: int = da.crates_in_area.size()

		if crate_numbers >= ach_crate_number:
			if da.belongs_to_id > check_id_threshold:
				if active_players.has(da.belongs_to_id):
					active_players[da.belongs_to_id].trigger_achievement_rpc.rpc()

		if crate_numbers > highest_score:
			highest_score = da.crates_in_area.size()

	if highest_score == 0:
		for da in delivery_areas:
			if da.belongs_to_id <= check_id_threshold:
				continue

			da.set_indicator_light_rpc.rpc(false)
			active_players[da.belongs_to_id].set_indicator_light_rpc.rpc(false)
		return

	for da in delivery_areas:

		if da.belongs_to_id <= check_id_threshold:
			continue

		if da.crates_in_area.size() == highest_score:
			da.set_indicator_light_rpc.rpc(true)
			active_players[da.belongs_to_id].set_indicator_light_rpc.rpc(true)
		else:
			da.set_indicator_light_rpc.rpc(false)
			active_players[da.belongs_to_id].set_indicator_light_rpc.rpc(false)

func _on_round_timer_timeout():

	round_timer_value -= 1

	if round_timer_value > 0:
		round_timer.start(1.0)
	else:
		round_finished()

	update_timers_rpc.rpc(round_timer_value)

func _on_countdown_expired():
	super._on_countdown_expired()

	for p in players.values():
		p.set_active_rpc.rpc(true)

	start_round_timer()

func _on_player_died(_network_id: int):

	if active_players.has(_network_id):
		active_players.erase(_network_id)

	await get_tree().create_timer(1.0).timeout

	check_game_end()
