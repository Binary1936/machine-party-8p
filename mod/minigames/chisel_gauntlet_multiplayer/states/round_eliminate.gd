extends State

func init() -> void :
	pass

func can_leave() -> bool:
	return true

func can_enter() -> bool:
	return true

func enter(_msg: Dictionary = {}) -> void :
	state_time = 0.0

	if not multiplayer.is_server():
		return

	var players_by_position = owner.players_by_position.duplicate()

	owner.shotgun_handler.deploy_rpc.rpc()
	await owner.shotgun_handler.deployment_finished

	var first_valid_position: int = -1
	var sequential: bool = true
	for i in owner.shotgun_check_order:
		if players_by_position.has(i) and owner.active_players.has(players_by_position[i]):

			var player = owner.active_players[players_by_position[i]]

			if first_valid_position < 0:
				first_valid_position = i
			# 8-PLAYER MOD: gated trace of the sweep. The gun only visits
			# positions listed in shotgun_check_order, and a missing slot looks
			# like "the gun ignores that player" with nothing in the logs.
			if Array(OS.get_cmdline_args()).has("-localtest"):
				print("[SHOTGUN] slot ", i, " -> ",
					wrapf(owner.player_rotations[i] + 360.0, 0.0, 360.0),
					" deg, peer ", players_by_position[i])

			owner.shotgun_handler.rotate_rpc.rpc(
				wrapf(owner.player_rotations[i] + 360.0, 0.0, 360.0), sequential
			)
			sequential = true

			await owner.shotgun_handler.rotation_finished
			owner.shotgun_handler.verifiy_player_rpc.rpc(
				owner.eliminate_players.keys().has(player.player_presence.network_id), 
				player.player_presence.network_id
			)

			await owner.shotgun_handler.player_verification_finished

		else:
			sequential = false

	owner.shotgun_handler.set_to_standby_rpc.rpc(
		wrapf(owner.player_rotations[first_valid_position] + 360.0 - 45.0, 0.0, 360.0)
	)
	await owner.shotgun_handler.verification_finished

	for k in owner.eliminate_players.keys():
		owner.active_players.erase(k)

	owner.check_game_end()

func exit(_msg: Dictionary = {}) -> void :
	pass

func update(_delta: float) -> void :
	pass

func update_physics(_delta: float) -> void :
	pass
