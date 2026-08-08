extends State

func enter(_msg: Dictionary = {}) -> void :
	state_time = 0.0

	if multiplayer.is_server():
		owner.minigame.minigame_finished.connect(_on_minigame_finished)

func exit(_msg: Dictionary = {}) -> void :
	pass

func update(_delta: float) -> void :
	pass

func update_physics(_delta: float) -> void :
	pass



func _on_minigame_finished(_network_id: int):

	owner.minigame.minigame_finished.disconnect(_on_minigame_finished)
	MusicManager.filter_controller.begin_shift(300, 20000, 12)

	if multiplayer.is_server():
		owner.session_current_minigame_round += 1

		var current_minigame_identifier = owner.session_minigame_list[owner.session_minigame_index]
		var default_total_rounds: int = owner.session_current_minigame_max_rounds
		var total_rounds: int = default_total_rounds
		var player_count: int = PlayerManager.player_presences.size()

		# 8-PLAYER MOD: **this** is the site that decides how many times a
		# minigame repeats - `more_rounds` below drives the replay - so the
		# roster-scaled round count has to be applied here, not only where
		# game.gd loads the next minigame.
		#
		# Vanilla gates the lookup on `not GameManager.custom_game`, so a custom
		# lobby never got it and an 8-player Duck Hunt ran 8 hunter turns twice.
		# Now applied to custom games too, but **only above four players**, so a
		# 1-4 custom lobby keeps exactly the round count its host configured in
		# the playlist UI rather than having it silently overridden.
		if not GameManager.custom_game or player_count > 4:
			if Globals.MinigameRoundsByPlayerCount.has(current_minigame_identifier):
				total_rounds = Globals.MinigameRoundsByPlayerCount[current_minigame_identifier].get(
					player_count, default_total_rounds
				)

		var more_rounds = owner.session_current_minigame_round <= total_rounds

		if Array(OS.get_cmdline_args()).has("-localtest"):
			print("[ROUNDS8] site=repeat minigame=",
				Globals.MinigameIdentifier.keys()[current_minigame_identifier],
				" players=", player_count,
				" custom=", GameManager.custom_game,
				" default=", default_total_rounds,
				" resolved=", total_rounds,
				" round=", owner.session_current_minigame_round,
				" more_rounds=", more_rounds)
		if PlayerManager.player_presences.size() < 2:
			more_rounds = false

		owner.update_scores(more_rounds)

		if more_rounds:

			owner.load_minigame(owner.session_minigame_list[owner.session_minigame_index], true)
			return

		owner.games_played_count += 1
		state_machine.transition_to_rpc.rpc(&"MinigameEnd")
