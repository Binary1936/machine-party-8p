class_name ExplodingCollarRace

extends Minigame

const player_scene = preload("res://minigames/exploding_collar_race/components/player/exploding_collar_race_player.tscn")
const mine_scene = preload("res://minigames/exploding_collar_race/components/mine/mine.tscn")

@onready var host_synchronizer: MultiplayerSynchronizer = $HostSynchronizer
@onready var players_node_parent: Node3D = $Players
@onready var mines_node_parent: Node3D = $Mines

@export var player_spawn_positions: Array[Node3D]
@export var offset_every_other_playername: bool

@export_category("Game Parameters")
@export var mine_distance: float = 3.5
@export var mine_detection_threshold: float = 5.0
@export var mine_explosion_threshold: float = 1.0
@export var harvester_start_delay: float = 5.0

@export_category("Components")
@export var countdown_state: State
@export var harvester: ExplodingCollarRaceHarvester
@export var camera_shaker: ShakerComponent3D
@export var shaker_proximity: Area3D

@export_category("Ambience")
@export var ambience_speakers: Array[AudioStreamPlayer]
@export var ambience_speaker_controllers: Array[SpeakerController]

@export_category("Nodes")
@export var camera_target: Node3D
@export var camera_3d: Camera3D

@export var kill_area: Area3D
@export var harvester_behind_explode_area: Area3D
@onready var finish_area: Area3D = $Interactive / FinishArea

@export var legs_instance: PackedScene
@export var legs_spawn_parent: Node3D

@export var halfway_area: Area3D

var player_characters: Dictionary[int, ExplodingCollarRacePlayer]
var active_players: Array[ExplodingCollarRacePlayer]
var finished_players: Array[ExplodingCollarRacePlayer]
var player_scores: Dictionary[int, int]

var halway_players: Array[int]

var shaker_intensity: float = 0.0
var in_shaker_proximity: Array
var camera_player: ExplodingCollarRacePlayer

func _ready() -> void :
	super._ready()

	camera_3d.set_multiplayer_authority(1)
	host_synchronizer.set_multiplayer_authority(1)

	shaker_proximity.area_entered.connect(_on_shaker_area_entered)
	shaker_proximity.area_exited.connect(_on_shaker_area_exited)

	if multiplayer.is_server():

		finish_area.body_entered.connect(_on_finish_area_entered)
		countdown_state.countdown_started.connect(_on_countdown_started)
		countdown_state.tick.connect(_on_countdown_tick)
		countdown_state.expired.connect(_on_countdown_expired)

		harvester_behind_explode_area.body_entered.connect(_on_behind_harvester_body_entered)

		halfway_area.body_entered.connect(_on_halfawy_area_entered)

	if GameManager.local_game:
		await get_tree().create_timer(1.0).timeout
		minigame_ready.emit(1)

func _physics_process(delta: float) -> void :

	update_camera_shaker(delta)

	if active_players.is_empty():
		return

	var player_z_avg: float = active_players[0].global_position.z
	if GameManager.local_game:

		var positions: Array[Vector3]
		for p in active_players:
			positions.append(p.global_position)

		var sum = positions.pop_front().z
		for p in positions:
			sum += p.z

		player_z_avg = sum / float(active_players.size())

	else:

		for p in active_players:
			player_z_avg = p.global_position.z
			if not GameManager.local_game:
				if p.player_presence.network_id == multiplayer.get_unique_id():
					break

	camera_target.global_position = camera_target.global_position.move_toward(
		Vector3(0.0, 0.0, player_z_avg), 
		delta * 64.0
	)

func update_camera_shaker(delta: float):

	camera_shaker.intensity = shaker_intensity * 0.75
	shaker_intensity = move_toward(shaker_intensity, 0.0, delta)

	if in_shaker_proximity.has(harvester):
		var distance = (
			harvester.global_position - camera_target.global_position
		).length()
		camera_shaker.intensity += (1.0 - (distance / 25.0)) * 0.25

func cleanup():

	if is_multiplayer_authority():
		queue_free()

func initialize(_round_number: int, _total_rounds: int, _scores: Dictionary = {}):
	super.initialize(_round_number, _total_rounds, _scores)

	spawn_players()
	spawn_mines()

	state_machine.transition_to_rpc.rpc(&"Round", {"round": _round_number, "total": _total_rounds})

func initialize_debug_specifics():
	super.initialize_debug_specifics()

	debug_player_specifics_initialized.emit(camera_3d.global_transform)

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

func spawn_players():

	var player_positions: Array[Node3D] = player_spawn_positions.duplicate()
	player_positions.shuffle()


	var counter: int = 0
	for key in PlayerManager.player_presences.keys():

		var player_presence: PlayerPresence = PlayerManager.player_presences[key]

		var player_character = player_scene.instantiate()
		players_node_parent.add_child(player_character, true)

		player_character.set_manager_from_path_rpc.rpc(self.get_path())

		player_character.set_player_presence.rpc(player_presence.network_id)
		player_character.teleport_rpc.rpc(
			player_positions[counter].global_position
		)
		player_characters[player_presence.network_id] = player_character
		player_character.exploded.connect(_on_player_exploded)
		add_active_player_rpc.rpc(player_presence.network_id)

		player_scores[player_presence.network_id] = 0

		counter += 1

func spawn_mines():
	randomize()

	var polygon: PackedVector2Array = [
		Vector2(0.0, 0.0), Vector2(16.0, 0.0), 
		Vector2(16.0, 80.0), Vector2(0.0, 80.0), 
	]

	var points = PoissonDiscSampling.generate_points_for_polygon(
		polygon, mine_distance, 32
	)

	for p in points:

		var mine_instance = mine_scene.instantiate()
		mine_instance.set_thresholds(mine_detection_threshold, mine_explosion_threshold)
		mine_instance.set_multiplayer_authority(1, true)
		mines_node_parent.add_child(mine_instance, true)
		mine_instance.global_position = Vector3(
			-8.0 + p.x, 0.0, -10.0 - p.y
		)
		mine_instance.set_active_rpc.rpc()
		mine_instance.exploded.connect(_on_mine_exploded)

func spawn_legs(global_position: Vector3, suit_color: String):

	var legs: Node3D = legs_instance.instantiate()
	legs_spawn_parent.add_child(legs)
	legs.global_position = global_position
	var legs_customization_assigner_left: CustomizationAssignerLegs = legs.get_child(0)
	legs_customization_assigner_left.assign_suit_color(suit_color)
	var legs_customization_assigner_right: CustomizationAssignerLegs = legs.get_child(1)
	legs_customization_assigner_right.assign_suit_color(suit_color)
	legs.rotation_degrees = (Vector3(0, randf_range(0, 360), 0))

func check_game_end():

	if not active_players.is_empty():
		return

	player_scores_finalized.emit(player_scores)

	await get_tree().create_timer(2.0).timeout
	set_minigame_sfx_linear_volume_rpc.rpc(0.0)

	state_machine.transition_to_rpc.rpc(&"Finished")
	set_effects_visibility_rpc.rpc(false)



@rpc("authority", "call_local", "reliable")
func add_active_player_rpc(_network_id: int):

	for p in players_node_parent.get_children():
		if not active_players.has(p):
			active_players.append(p)

@rpc("authority", "call_local", "reliable")
func remove_active_player_rpc(_network_id: int, remove_player_character: bool = false):
	var index: int = -1

	for i in active_players.size():
		if active_players[i].player_presence.network_id == _network_id:
			index = i
			break

	if index >= 0:
		active_players.remove_at(index)

	if remove_player_character and player_characters.has(_network_id):
		player_characters[_network_id].queue_free()
		player_characters.erase(_network_id)

	if multiplayer.is_server():
		check_game_end()



func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	if not multiplayer.is_server():
		return

	# 8P MOD: before the game has started there is nothing to end - the peer
	# was never spawned here and its presence is already pruned. Vanilla's end
	# check below would see zero players and finish an unstarted game
	# (pitfall 32; session log 2026-08-15).
	if not is_all_player_loaded:
		return

	remove_active_player_rpc.rpc(_network_id, true)

func _on_countdown_expired():
	super._on_countdown_expired()

	for player in player_characters.values():
		player.set_active_rpc.rpc()

	state_machine.transition_to_rpc.rpc(&"Play")

func _on_player_exploded(network_id):

	remove_active_player_rpc.rpc(network_id)

func _on_shaker_area_entered(area):

	if area.owner is ExplodingCollarRaceMine:
		area.owner.exploded.connect(_on_shaker_mine_exploded)
		in_shaker_proximity.append(area.owner)

	if area is ExplodingCollarRaceHarvester:
		in_shaker_proximity.append(area)

func _on_shaker_area_exited(area):

	if area.owner is ExplodingCollarRaceMine:
		in_shaker_proximity.erase(area.owner)
		area.owner.exploded.disconnect(_on_shaker_mine_exploded)

	if area is ExplodingCollarRaceHarvester:
		in_shaker_proximity.erase(area)

func _on_shaker_mine_exploded(_player_id, mine, _with_effect):

	if not _with_effect:
		return

	var distance: float = (
		camera_target.global_position - mine.global_position
	).length()
	shaker_intensity = min(shaker_intensity + (1.0 - (distance / 25.0)), 1.0)

func _on_behind_harvester_body_entered(body):

	if body is ExplodingCollarRacePlayer:

		if not body.active:
			return

		body.explode_rpc.rpc(999)

		EffectManager.spawn_rpc.rpc(
			&"mine_explosion", 
			body.global_position, body.basis.z, Vector3.ONE
		)

		DecalManager.spawn_rpc.rpc(
			&"explosion_mark", 
			body.global_position, 
			Vector3(0.0, lerp(-180.0, 180.0, randf()), 0.0)
		)

		SoundManager.play_positional_rpc.rpc(
			"bad_explosion", 
			body.global_position, 
			"MINIGAME_SFX"
		)

func _on_halfawy_area_entered(body):

	if body is not ExplodingCollarRacePlayer:
		return

	if halway_players.has(body.player_presence.network_id):
		return

	halway_players.append(body.player_presence.network_id)

	player_scores[body.player_presence.network_id] += 1

func _on_mine_exploded(players_in_explosion, _mine, _with_effect):

	for player_network_id in players_in_explosion:
		player_characters[player_network_id].explode_rpc.rpc()

func _on_finish_area_entered(body):

	if body is ExplodingCollarRacePlayer:
		var player: ExplodingCollarRacePlayer = body
		player.enter_van_anim.rpc()
		await get_tree().create_timer(2, false).timeout
		active_players.erase(body)

		var add_score = 1
		if finished_players.is_empty():
			add_score += 1
		if body.lives == body.max_lives:
			add_score += 1

		player_scores[body.player_presence.network_id] += add_score

		finished_players.append(body)
		body.finished_rpc.rpc()

		check_game_end()
