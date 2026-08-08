extends Node

class_name ForkliftCertifiedCrateManager

const crate_scene = preload("uid://dswpehgm6ottr")

@export_category("Variables")
@export var spawn_radius: float = 6.0

@export_category("Nodes")
@export var magnet: MagnetManager
@export var item_spawn_position_node: Node3D
@export var item_parent_node: Node3D

var active: bool = false
var instances: Dictionary[int, ForkliftCertifiedCrate]
var remove_indicies_after_move: Array[int]

# 8-PLAYER MOD ---------------------------------------------------------------
#
# spawn_crates() is called with `roster * 2` and loops
#
#     while points.size() < target_size:
#         points = PoissonDiscSampling.generate_points_for_polygon(...)
#
# with no bound. The sampler draws into a fixed 12x12 box at a 4.0 separation
# (spawn_radius is 4.0 - the SCENE overrides the 6.0 in this script, so read it
# there, not here) and that box simply cannot hold many points. Reimplementing
# the shipped sampler exactly and running it 100,000 times per case:
#
#     4 players   8 crates   succeeds 49% of the time   ~2 calls
#     5 players  10 crates   succeeds  0.6%             ~160 calls, a visible hitch
#     6 players  12 crates   0 successes, max ever 11   NEVER TERMINATES
#     8 players  16 crates   0 successes                NEVER TERMINATES
#
# So above five players vanilla spins in that while loop forever - a host freeze
# with no error line, which is a far nastier failure than the black screen the
# spawn-marker overrun gives. It has never been seen because spawn_players()
# aborts before reaching this.
#
# Two changes, both no-ops at four players or fewer:
#
#  1. The polygon becomes the free centre cell of the expanded ring of zones,
#     handed in by forklift_certified.gd (it owns the zones; this node has no
#     reference to them). Bigger and correctly centred - the cell's middle is
#     ~3.5u off the ItemSpawnPosition the shipped box is built around.
#  2. target_size is clamped to the cap the loop below ALREADY enforces. The
#     `counter >= 10` return means a 16-crate request was never going to produce
#     more than 10 crates anyway - it only ever made the sampler chase a target
#     it could not reach. Ten crates in the widened cell lands in ~5 calls.
#
# MOD_MAX_SAMPLER_ATTEMPTS is the belt-and-braces: whatever a future update does
# to the geometry, this loop now exits. At four players it would take 0.51^200
# to trip, so 1-4 is untouched in behaviour as well as in numbers.
const MOD_CRATE_CAP: int = 10
const MOD_MAX_SAMPLER_ATTEMPTS: int = 200

var mod_spawn_region: Rect2 = Rect2()

func mod_set_spawn_region(region: Rect2) -> void:
	"""World-space XZ rectangle the crates may spawn in. Empty keeps vanilla."""
	mod_spawn_region = region

func _mod_trace() -> bool:
	return Array(OS.get_cmdline_args()).has("-localtest")

# END 8-PLAYER MOD ------------------------------------------------------------

func _physics_process(_delta: float) -> void :

	if not multiplayer.is_server():
		return

func spawn_crates(amount: int):

	var size: float = 6.0
	var polygon: PackedVector2Array = [
		Vector2( - size, - size), 
		Vector2(size, - size), 
		Vector2(size, size), 
		Vector2( - size, size), 
	]

	# 8-PLAYER MOD: the sampler is given the free centre cell of the expanded
	# yard when there is one, and a target it can actually hit. See the block at
	# the top of this file - the shipped loop does not terminate above five
	# players.
	var start_point: Vector2 = Vector2.ZERO
	if mod_spawn_region.has_area():
		var origin: Vector2 = Vector2(
			item_spawn_position_node.global_position.x,
			item_spawn_position_node.global_position.z
		)
		var lo: Vector2 = mod_spawn_region.position - origin
		var hi: Vector2 = mod_spawn_region.end - origin
		polygon = [
			Vector2(lo.x, lo.y),
			Vector2(hi.x, lo.y),
			Vector2(hi.x, hi.y),
			Vector2(lo.x, hi.y),
		]
		start_point = (lo + hi) * 0.5

	var target_size: int = mini(amount, MOD_CRATE_CAP)
	var points: PackedVector2Array
	var attempts: int = 0

	while points.size() < target_size:
		points = PoissonDiscSampling.generate_points_for_polygon(
			polygon, spawn_radius, 20, start_point
		)
		attempts += 1
		if attempts >= MOD_MAX_SAMPLER_ATTEMPTS:
			push_warning("[FORK8] crate sampler gave up after %d tries: wanted %d points in %s, best %d"
				% [attempts, target_size, str(polygon), points.size()])
			break

	target_size = mini(target_size, points.size())

	if _mod_trace():
		print("[FORK8] crates requested=", amount,
			" target=", target_size,
			" attempts=", attempts,
			" points=", points.size(),
			" radius=", spawn_radius,
			" region=", "centre_cell" if mod_spawn_region.has_area() else "vanilla")

	var counter: int = 0
	for i in target_size:
		spawn_crate(Vector3(points[i].x, 0.0, points[i].y))
		counter += 1
		if counter >= MOD_CRATE_CAP:
			return

func spawn_crate(_position: Vector3):

	if not multiplayer.is_server():
		return

	var instance = crate_scene.instantiate()
	item_parent_node.add_child(instance, true)

	var random_rot: float = TAU * randf()

	register_crate_rpc.rpc(
		instances.size(), 
		instance.get_path()
	)
	instance.setup_rpc.rpc(
		item_spawn_position_node.global_position + _position, 
		random_rot
	)

func remove_crates(amount_to_remove: int):

	if instances.size() <= 1:
		return

	if amount_to_remove == instances.size():
		amount_to_remove -= 1

	var current_instance_indexes: Array[int] = instances.keys()
	current_instance_indexes.shuffle()

	var to_remove_indicies: Array[int]
	for i in amount_to_remove:
		to_remove_indicies.append(current_instance_indexes[i])

	remove_crates_rpc.rpc(to_remove_indicies)



@rpc("any_peer", "call_local", "reliable")
func remove_crates_rpc(indices: Array[int]):
	for index in indices:
		remove_indicies_after_move.append(index)
		await magnet.pickup_crate(instances[index].global_position, instances[index])
	await get_tree().create_timer(1, false).timeout
	await magnet.move_home()
	await get_tree().create_timer(0.8, false).timeout
	magnet.is_already_holding_crate = false
	for index in remove_indicies_after_move:
		var instance = instances[index]
		if instance and is_instance_valid(instance):
			instance.queue_free()
		instances.erase(index)
	remove_indicies_after_move.clear()

	magnet.hide_fake_crates()

@rpc("any_peer", "call_local", "reliable")
func register_crate_rpc(index: int, _path: NodePath):

	instances[index] = get_node(_path)
