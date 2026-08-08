extends Node3D

class_name ExplodingCollarRaceBloodTrail

@export var parent_visuals: Node3D
@export var path: Path3D
@export var distance_threshold: float = 0.1
@export var active: bool = false

var lerp_elapsed: float = 0.0
var curve: Curve3D

func _ready() -> void :

	path.curve = Curve3D.new()
	curve = path.curve

func set_active(_active: bool) -> void :

	if _active:
		curve.clear_points()
		curve.add_point(
			parent_visuals.global_position - (Vector3.UP * 0.1), 
		)

	# 8-PLAYER MOD: guard an empty curve. set_active(false) without a preceding
	# set_active(true) indexes point_count - 1 == -1 on an empty Curve3D, which
	# Godot reports as "p_index = 4294967295 is out of bounds (points.size() =
	# 0)". A latent vanilla bug, but at eight players it fired several hundred
	# times in a single round, so it is worth silencing here.
	elif curve.point_count > 0:
		curve.set_point_position(
			curve.point_count - 1,
			curve.get_point_position(curve.point_count - 1) - (Vector3.UP * 0.1)
		)

	active = _active

func _physics_process(_delta: float) -> void :

	if active:

		# Same guard: the trail can go active with no points laid down yet.
		if curve.point_count == 0:
			return

		if curve.get_point_position(curve.point_count - 1).distance_to(parent_visuals.global_position) >= distance_threshold:
			curve.add_point(
				parent_visuals.global_position
			)
