extends Node

@export var development_scene: String = "res://scenes/debug_lobby/debug_lobby.tscn"
@export var release_scene: String = "res://scenes/main_menu/main_menu.tscn"

func _ready() -> void :

	await Steamworks.initialized

	var command_line_arguments = OS.get_cmdline_args()

	check_debug_tools_launch(command_line_arguments)
	var local_test: bool = check_local_test_launch(command_line_arguments)

	if check_game_invite_launch(command_line_arguments):
		GlobalOverlay.set_overlay_color(Color.BLACK)
		MusicManager.play_menu_music()
		MusicManager.filter_controller.effect_low_pass.cutoff_hz = 300
		Globals.splash_screen_viewed = true
		get_tree().change_scene_to_file("res://scenes/lobby/lobby_scene.tscn")
		return

	if (OS.has_feature("editor") and Globals.debug) or local_test:

		get_tree().call_deferred("change_scene_to_file", development_scene)
	else:
		get_tree().call_deferred("change_scene_to_file", release_scene)

# 8-PLAYER MOD: `-localtest` opens the developers' debug lobby in a release
# build. That lobby hosts and joins over ENet on 127.0.0.1:25565, so several
# copies of the game on one machine can fill an 8-player session without Steam,
# extra accounts or other people. NetworkManager does its own check for this
# flag (it is an autoload and runs before this scene) to stay on ENet.
func check_local_test_launch(command_line_arguments) -> bool:

	for arg in command_line_arguments:
		if arg == "-localtest":
			Globals.debug = true
			Globals.allow_singleplayer = true
			Globals.enable_debug_tools()

			# `-startgame` means "get me into a minigame", so skip the intro
			# cutscene, briefs and intermission. Set here rather than via
			# Globals.debug_instant_start: that is consumed in Globals._ready(),
			# which as an autoload has already run by the time this scene loads.
			#
			# `-fullflow` suppresses exactly those skips, so an 8-instance run
			# goes through the session the way a real player experiences it:
			# intro cutscene -> briefing -> minigame -> score screen ->
			# intermission picker -> next briefing. The autostart in
			# multiplayer_menu.gd still fires, so nobody has to press anything
			# to begin - and the briefing's Ready gate is answered by the
			# auto-ready in intermission_briefing_screen.gd, which is the only
			# point in the whole loop that waits on player input.
			if (command_line_arguments.has("-startgame")
					and not command_line_arguments.has("-fullflow")):
				Globals.debug_skip_brief = true
				Globals.debug_skip_intermission = true
				Globals.skipping_intro_cutscene = true
			return true
	return false

func check_debug_tools_launch(command_line_arguments):

	for arg in command_line_arguments:
		if arg == "-debug-tools":
			Globals.allow_singleplayer = true
			Globals.enable_debug_tools()

func check_game_invite_launch(command_line_arguments):
	var join_lobby = false
	var lobby_code = -1

	var counter: int = 0
	for arg in command_line_arguments:

		if arg == "+connect_lobby":
			if command_line_arguments.size() > counter + 1:
				var temp = command_line_arguments[counter + 1]
				if temp is String and temp.length() == 18:
					lobby_code = temp
					join_lobby = true

		counter += 1

	if join_lobby:

		GameManager.join_lobby_id = lobby_code
		GameManager.host_game = false
		GameManager.custom_game = false
		GameManager.arcade_game = false

	return join_lobby
