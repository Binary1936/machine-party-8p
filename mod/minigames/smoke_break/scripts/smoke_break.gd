extends Minigame

class_name SmokeBreakMinigame

const player_scene = preload("res://minigames/smoke_break/components/player/smoke_break_player.tscn")

@export var camera: Camera3D
@export var player_spawn_positions: Array[Node3D]
@export var offset_every_other_playername: bool
@onready var players_node_parent: Node3D = $PlayerSpawner / Players


@export_category("Components")
@export var timer_label: Label3D
@export var countdown_state: State
@export var post_processing_vignette: Control

@export_category("Ambience")
@export var ambience_speakers: Array[AudioStreamPlayer]
@export var ambience_speaker_controllers: Array[SpeakerController]


@onready var round_play_state: Node = $StateMachine / RoundPlay
@onready var camera_offset_parent: Node3D = $CameraParent / OffsetParent

var player_characters: Dictionary[int, SmokeBreakPlayer]
var active_players: Array[SmokeBreakPlayer]
var finished_players: Array[SmokeBreakPlayer]
var player_scores: Dictionary[int, int]

# --- 8P MOD ------------------------------------------------------------------
# Eight players on a bench authored for four sat shoulder-to-shoulder and
# clipped: the shipped seats are ~2.0 apart, and squeezing four more between
# them dropped the tightest gap to 0.73.
#
# Seats 0-3 CANNOT move - they are what a 1-4 player game uses - so the only
# freedom is where the four added seats go. Packing all four into the internal
# gaps is what caused the clipping, so two now sit beyond the ends of the arc
# and two in the widest internal gaps, lifting the tightest gap to 1.00.
#
# The two end seats hang off the end of the shipped seating, so a crate is
# cloned under each (crate1_003, 1.53 x 1.11 x 1.53). Those clones live in the
# scene but ship `visible = false`; revealing them here - and only above four
# players - is what keeps a 1-4 player game pixel-identical, the same pattern
# green_pea uses for its extra chairs.
#
# The crate offset is LEARNED from the shipped prop rather than hardcoded:
# crate1_003 sits at seat3 + (0.846, -3.069, -0.387), and both shipped props
# share that same ~+0.84 x / -3.069 y relationship to their seat.
const MOD_VANILLA_SEATS: int = 4
const MOD_EXTRA_PROP_HINT: String = "crate1_003_mod"

func _mod_reveal_extra_seating() -> void :
	var shown: int = 0
	for n in find_children("*", "MeshInstance3D", true, false):
		if MOD_EXTRA_PROP_HINT in String(n.name).to_lower():
			(n as MeshInstance3D).visible = true
			shown += 1

	if shown == 0:
		push_warning("[SMOKE8] no '%s' props found; end seats have nothing to sit on"
			% MOD_EXTRA_PROP_HINT)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[SMOKE8] seating is_server=", multiplayer.is_server(),
			" players=", PlayerManager.player_presences.size(),
			" markers=", player_spawn_positions.size(),
			" extra_crates_shown=", shown)

func _ready() -> void :
	super._ready()

	# Runs on every peer (the scene loads everywhere) and player_presences is
	# replicated, so no RPC is needed - same reasoning as the escalator lanes.
	if PlayerManager.player_presences.size() > MOD_VANILLA_SEATS:
		_mod_reveal_extra_seating()

	round_play_state.timer_updated.connect(_on_timer_updated)

	if multiplayer.is_server():

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
	debug_player_specifics_initialized.emit(camera.global_transform)

func _process(_delta: float) -> void :
	pass

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
		var player_character: SmokeBreakPlayer = player_scene.instantiate()

		players_node_parent.add_child(player_character, true)

		player_character.set_player_presence_rpc.rpc(player_presence.network_id)
		player_character.setup_rpc.rpc(
			player_spawn_positions[counter].global_position, 
			player_spawn_positions[counter].global_rotation, 
			counter
		)
		player_character.register_camera_offset_rpc.rpc(
			camera_offset_parent.get_path()
		)
		player_character.cigarette_finished.connect(_on_player_finished)

		player_characters[player_presence.network_id] = player_character
		active_players.append(player_character)

		player_scores[player_presence.network_id] = 0

		counter += 1

func fade_in_ambience():
	for speaker_controller in ambience_speaker_controllers:
		speaker_controller.speaker.volume_linear = 0
		speaker_controller.fade_duration = 3
		speaker_controller.fade_in_custom(db_to_linear(speaker_controller.original_volume_db), true)



func _on_all_brief_ready():
	await get_tree().create_timer(1.0).timeout
	state_machine.transition_to_rpc.rpc(&"Round", {"round": round_number, "total": total_rounds})

func _on_countdown_expired():
	super._on_countdown_expired()
	for player in active_players:
		player.set_active_rpc.rpc(true)

	state_machine.transition_to_rpc.rpc(&"RoundPlay")

func _on_timer_updated(time_left: int):
	timer_label.text = "00:%s" % [str(time_left).pad_zeros(2)]

func _on_player_finished(network_id: int):

	var player_character = player_characters[network_id]

	active_players.erase(player_character)

	if finished_players.is_empty():
		player_scores[network_id] += 1

	finished_players.append(player_character)

func player_disconnected(_network_id: int):
	super.player_disconnected(_network_id)

	var player_instance = player_characters[_network_id]

	active_players.erase(player_instance)

	finished_players.erase(player_instance)

	player_instance.queue_free()
