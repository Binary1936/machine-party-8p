extends Node

class_name LocalGame

@export_category("Debug")
@export var debug_no_shuffle: bool = true

@export_category("Scoring Properties")
@export var score_multiplier: int

@export_category("Components")
@export var state_machine: StateMachine
@export var intermission_manager: IntermissionManager

@export_category("UI")
@export var session_start_screen: Control
@export var minigame_start_screen: Control
@export var minigame_playing_screen: Control
@export var minigame_end_screen: Control
@export var minigame_results_screen: Control
@export var session_end_screen: Control
@export var shared_screen: Control
@export var all_screens: Array[Control]

@export_category("Post Processing")
@export var effects_parent_node: Control

var effect_backbuffers: Array[BackBufferCopy] = []
var effect_rects: Array[ColorRect] = []

@export_category("Nodes")
@export var minigame_parent: Node


var session_minigame_list: Array[Globals.MinigameIdentifier]
var session_minigame_rounds: Dictionary[Globals.MinigameIdentifier, int]
var session_minigame_index: int = -1
var session_minigame_played_list: Array[Globals.MinigameIdentifier]
var session_last_minigame_identifier: Globals.MinigameIdentifier = Globals.MinigameIdentifier.EMPTY

var session_next_minigame_index: int
var session_next_minigame_identifier: int

var session_current_minigame_round: int = 0
var session_current_minigame_max_rounds: int = 0

var minigame

var total_score_by_network_id: Dictionary[int, int]
var round_score_by_network_id: Dictionary[int, int]
var game_score_by_network_id: Dictionary[int, int]

var games_played_count: int = 0
var total_games_count: int = 0

var capture_input: bool = false


var can_check_for_connect_requests = false

func _ready() -> void :

	GameManager.can_input_switch = false
	GameManager.local_game = true

	setup_scores()

	intermission_manager.game = self
	intermission_manager.screen_score.score_screen_hidden.connect(_on_score_screen_hidden)
	intermission_manager.screen_score.score_screen_finished.connect(_on_score_screen_finished)

	generate_session_playlist()

	register_effects()
	get_tree().get_root().connect("size_changed", _viewport_size_changed)
	_viewport_size_changed()

	PauseMenu.show_quit_to_menu = true
	PauseMenu.set_can_activate(true)

	GlobalOverlay.fade_overlay(Color(0.0, 0.0, 0.0, 0.0), 0.5)
	await GlobalOverlay.fade_finished


	await get_tree().create_timer(1.0).timeout

	state_machine.transition_to(&"SessionIntro")

func setup_scores():

	for key in PlayerManager.player_presences.keys():
		game_score_by_network_id[key] = 0
		total_score_by_network_id[key] = 0

func generate_session_playlist():

	var minigames_shuffled: Array[Globals.MinigameIdentifier]

	if GameManager.custom_game:


		if Globals.session_playlist.is_empty():
			for mlr in Globals.default_playlist:
				Globals.session_playlist.append(mlr)

		for game in Globals.session_playlist:
			if not Globals.CustomMinigamesWhitelist.has(game.game_identifier):
				continue
			minigames_shuffled.append(game.game_identifier)
			session_minigame_rounds[game.game_identifier] = max(game.total_rounds, 1)

	else:

		Globals.session_playlist.clear()
		for mlr in Globals.default_playlist:
			Globals.session_playlist.append(mlr)

		for game in Globals.session_playlist:
			minigames_shuffled.append(game.game_identifier)
			session_minigame_rounds[game.game_identifier] = max(game.total_rounds, 1)

	# 8-PLAYER MOD: the wheat-field cutscene (`CutsceneTest`) is removed from
	# the rotation at the user's request - it scores nothing and interrupts the
	# session's pace. Online sessions apply this filter in game.gd's
	# generate_session_playlist(), gated on every peer being modded, so lobbies
	# containing vanilla clients keep the exact vanilla rotation. A local
	# shared-screen session has no vanilla peers by definition, so here the
	# removal is unconditional. `default_playlist` itself stays byte-identical
	# to vanilla (see globals.gd) because the handshake and any vanilla peer
	# expect the vanilla list.
	minigames_shuffled.erase(Globals.MinigameIdentifier.CutsceneTest)
	session_minigame_rounds.erase(Globals.MinigameIdentifier.CutsceneTest)

	if not debug_no_shuffle:
		minigames_shuffled.shuffle()

	total_games_count = minigames_shuffled.size()

	for game in minigames_shuffled:
		print("Generating session playlist with: ", Globals.MinigameIdentifier.keys()[game])

	session_minigame_list = minigames_shuffled


	session_minigame_list = [
		Globals.MinigameIdentifier.TrainRace, 
		Globals.MinigameIdentifier.DvdRoomba, 
		Globals.MinigameIdentifier.ExplodingCollarRace, 
		Globals.MinigameIdentifier.EscalatorPit, 
		Globals.MinigameIdentifier.DiscoDodge, 

		Globals.MinigameIdentifier.SmokeBreak, 
		Globals.MinigameIdentifier.GreenPea, 
		Globals.MinigameIdentifier.ForkliftCertified, 

		Globals.MinigameIdentifier.ChiselGauntlet, 
		Globals.MinigameIdentifier.DuckHunt, 
	]

	for mgi in session_minigame_list:
		session_minigame_rounds[mgi] = 1



func hide_all_screens():

	for s in all_screens:
		s.visible = false

func register_effects() -> void :
	for c in effects_parent_node.get_children():
		effect_backbuffers.append(c)
		if c.get_child(0):
			var rect = c.get_child(0)
			effect_rects.append(rect)

func clear_game_scores():
	for key in game_score_by_network_id.keys():
		game_score_by_network_id[key] = 0

func show_score():
	intermission_manager.screen_score.check_to_show_score()

func load_minigame(minigame_identifier: Globals.MinigameIdentifier, _is_round: bool, _total_rounds: int = -1, ):

	Globals.current_minigame_identifier = minigame_identifier

	if multiplayer.is_server():

		if _total_rounds >= 0:
			session_current_minigame_round = 1
			session_current_minigame_max_rounds = _total_rounds

		DecalManager.clear_rpc.rpc()
		PropManager.clear_rpc.rpc()

	if minigame != null:

		minigame.minigame_loaded.disconnect(_on_minigame_loaded)
		minigame.minigame_ready.disconnect(_on_minigame_ready)

		minigame.cleanup_rpc()
		await get_tree().create_timer(1.0).timeout

	var minigame_scene: PackedScene = load(Globals.MinigamePaths[minigame_identifier])
	var minigame_instance = minigame_scene.instantiate()
	minigame = minigame_instance

	minigame.minigame_loaded.connect(_on_minigame_loaded)
	minigame.minigame_ready.connect(_on_minigame_ready)
	minigame.player_scored.connect(_on_minigame_player_scored)
	minigame.player_scores_finalized.connect(_on_minigame_player_score_finalized)

	GameManager.current_minigame_identifier = minigame_identifier
	minigame_parent.add_child(minigame_instance, true)

func update_scores(more_rounds: bool):

	for k in game_score_by_network_id.keys():
		game_score_by_network_id[k] += round_score_by_network_id[k]

	if not more_rounds:
		for k in game_score_by_network_id.keys():
			total_score_by_network_id[k] += game_score_by_network_id[k]

	if more_rounds:
		for k in game_score_by_network_id.keys():
			round_score_by_network_id[k] = 0

@rpc("authority", "call_local", "reliable")
func clear_minigame_rpc(was_cutscene_minigame: bool):

	MusicManager.filter_controller.begin_shift(MusicManager.filter_controller.effect_low_pass.cutoff_hz, 300, 0)

	if multiplayer.is_server():

		DecalManager.clear_rpc.rpc()
		PropManager.clear_rpc.rpc()

		if was_cutscene_minigame:
			MusicManager.start_playing_music_host(true, 3.0, false, 3.0)

	if minigame != null:

		minigame.minigame_loaded.disconnect(_on_minigame_loaded)
		minigame.minigame_ready.disconnect(_on_minigame_ready)
		minigame.cleanup_rpc.rpc()

	if was_cutscene_minigame:

		intermission_manager.set_intermission_viewport_screen(true)
		intermission_manager.picker.start_minigame_pick()

	else:

		show_score()



@rpc("any_peer", "call_local", "reliable")
func hide_score_screen_rpc():
	intermission_manager.screen_score.hide_score_screen()

@rpc("authority", "call_remote", "reliable")
func update_playlist_state_rpc(_minigame_list, next_minigame_index, next_minigame_identifier):

	session_minigame_list = _minigame_list

	session_next_minigame_index = next_minigame_index
	session_next_minigame_identifier = next_minigame_identifier
	intermission_manager.next_minigame_identifier = next_minigame_identifier

@rpc("authority", "call_local", "reliable")
func clear_game_scores_rpc():

	for key in game_score_by_network_id.keys():
		game_score_by_network_id[key] = 0
		round_score_by_network_id[key] = 0



func _on_minigame_pick_finished(minigame_index: int):

	if debug_no_shuffle:
		minigame_index = 0

	session_minigame_index = minigame_index

	var current_minigame_identifier = session_minigame_list[session_minigame_index]
	var default_total_rounds: int = session_minigame_rounds[session_minigame_list[session_minigame_index]]
	var total_rounds: int = default_total_rounds
	var player_count: int = PlayerManager.player_presences.size()

	if not GameManager.custom_game:
		if Globals.MinigameRoundsByPlayerCount.has(current_minigame_identifier):
			total_rounds = Globals.MinigameRoundsByPlayerCount[current_minigame_identifier].get(
				player_count, default_total_rounds
			)

	load_minigame(
		session_next_minigame_identifier, 
		false, 
		max(total_rounds, 1)
	)

func _on_minigame_loaded(_network_id: int):
	capture_input = false

func _on_minigame_ready(_network_id: int):


	state_machine.transition_to_rpc(&"MinigameStart")
	minigame.initialize(
		session_current_minigame_round, 
		session_current_minigame_max_rounds, 
		total_score_by_network_id
	)

func _on_minigame_player_scored(_network_id: int, _score: int):
	round_score_by_network_id[_network_id] += (_score * score_multiplier)

func _on_minigame_player_score_finalized(player_scores):

	for network_id in player_scores.keys():
		if round_score_by_network_id.has(network_id):
			round_score_by_network_id[network_id] += player_scores[network_id] * score_multiplier

func _on_score_screen_finished():

	var is_cutscene: bool = false
	if session_minigame_list.size() > 0:
		var next_minigame_identifier: Globals.MinigameIdentifier = session_minigame_list[0]
		if Globals.CutsceneMinigameIdentifiers.has(next_minigame_identifier):
			is_cutscene = true

	if is_cutscene:
		state_machine.transition_to_rpc(&"MinigameCutsceneTransition")
	else:
		hide_score_screen_rpc.rpc()

func _on_score_screen_hidden():

	state_machine.transition_to_rpc(&"MinigamePick")

func _viewport_size_changed():

	var vp_size = get_viewport().get_visible_rect().size

	for bb in effect_backbuffers:
		bb.rect.expand(vp_size)

	for cr in effect_rects:
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cr.set_deferred("size", vp_size)
