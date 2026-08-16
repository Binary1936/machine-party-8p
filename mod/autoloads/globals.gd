extends Node

const Epsilon: float = 0.001

# 8-PLAYER MOD: the DISPLAY version. It shows up on the main menu (main_menu.gd
# points version_label at this) and the installer tells you to read it back off
# that label to confirm the overlay took, so it keeps the mod suffix.
#
# It is deliberately NOT the version put on the wire any more. Vanilla-compat
# mode splits the two: the handshake reports MOD_NETWORK_GAME_VERSION, which is
# vanilla's string verbatim, so an unmodded peer's exact-equality check
# in receive_client_data_rpc passes and modded and vanilla players can share an
# ordinary <=4-player lobby. Mod-to-mod strictness did not disappear, it moved:
# the backends also put MOD_SUFFIX on the wire under the "mod8p" key, refuse a
# peer whose mod8p disagrees, and treat a peer with no mod8p key at all as
# vanilla (accepted, and counted against the vanilla 4-player cap). See
# mod/modules/multiplayer/backends/{steam,enet}_backend.gd.
#
# On every game or mod version bump, re-derive ALL THREE of these together:
# MOD_NETWORK_GAME_VERSION must become the new vanilla string EXACTLY (a stale
# value here silently refuses every vanilla peer), MOD_SUFFIX the new mod tag,
# and game_version their concatenation. That extends the existing three-places
# rule for the version label - globals.gd, installer/install.py and
# installer/README.txt still all have to agree on game_version.
var game_version: String = "v2.1.2-8P-v1.5"
const MOD_NETWORK_GAME_VERSION := "v2.1.2"
const MOD_SUFFIX := "8P-v1.5"


const GROUP_UI: StringName = "GROUP_UI"

var debug: bool = false
var debug_local: bool = false
var debug_instant_start = false
var debug_capture_mouse_enabled = false
var debug_skip_brief = false





var debug_skip_intermission = false

var debug_tools_enabled = false
var splash_screen_viewed = false
var skipping_intro_cutscene = false
var all_minigames_finished = false
var allow_singleplayer: bool = false

var showing_post_original_menu = false


const audio_channel_multipliers: Dictionary[StringName, float] = {
	"MUSIC": 0.25
}

const Languages: Dictionary[StringName, StringName] = {
	"EN": "LOC_ENGLISH", 
	"EE": "LOC_ESTONIA", 
	"FI": "LOC_FINLAND", 
	"SV": "LOC_SWEDEN", 
	"JA": "LOC_JAPANESE", 
	"ZHS": "LOC_CHINESE_SIMPLIFIED", 
	"ZHT": "LOC_CHINESE_TRADITIONAL", 
	"FR": "LOC_FRENCH", 
	"DE": "LOC_GERMAN", 
	"ES": "LOC_SPANISH", 
	"ES_ES": "LOC_SPANISH_LATIN_AMERICA", 
	"BR": "LOC_PORTUGUESE_BRAZIL", 
	"KO": "LOC_KOREAN", 
	"PL": "LOC_POLISH", 
	"RU": "LOC_RUSSIAN", 
	"UA": "LOC_UKRANIAN", 
	"TR": "LOC_TURKISH", 
}

var Quotes: Array[String] = [
	tr("LOC_IM_GO")
]

var default_playlist: Array = [
	MinigameListResource.create(MinigameIdentifier.ExplodingCollarRace, 3), 
	MinigameListResource.create(MinigameIdentifier.ChiselGauntlet, 2), 
	MinigameListResource.create(MinigameIdentifier.ManufactureGun, 3), 
	MinigameListResource.create(MinigameIdentifier.EscalatorPit, 2), 
	MinigameListResource.create(MinigameIdentifier.DuckHunt, 2), 
	MinigameListResource.create(MinigameIdentifier.DiscoDodge, 3), 
	MinigameListResource.create(MinigameIdentifier.GreenPea, 2), 
	# 8-PLAYER MOD: the wheat-field cutscene (`CutsceneTest`) is PRESENT here, in
	# its vanilla position and with its vanilla round count, even though the user
	# asked for it gone. It has to be: this list is what a session containing an
	# unmodded peer plays, and that session must get the exact vanilla rotation,
	# cutscene included, or the two sides disagree about the playlist.
	#
	# The user-sanctioned removal did not go away, it MOVED and became dynamic.
	# generate_session_playlist() in game.gd drops CutsceneTest from the shuffled
	# list when NetworkManager.mod_all_peers_modded() is true - i.e. only when
	# every peer is running the mod, which is every session the user actually
	# plays. It is applied after all three branches (default, custom and the
	# empty-list fallback) have filled the list, so it closes every path the old
	# static deletion closed, including the fallback that skips the
	# CustomMinigamesWhitelist. Do NOT delete this line again to "restore" the
	# removal - that would break vanilla-compat and change nothing else.
	MinigameListResource.create(MinigameIdentifier.CutsceneTest, 1), 
	MinigameListResource.create(MinigameIdentifier.TrainRace, 3), 
	MinigameListResource.create(MinigameIdentifier.KnifeAtTheOffice, 3), 
	MinigameListResource.create(MinigameIdentifier.SmokeBreak, 2), 
	MinigameListResource.create(MinigameIdentifier.JunkPlatform, 3), 
	MinigameListResource.create(MinigameIdentifier.SpineBreaker, 3), 
	MinigameListResource.create(MinigameIdentifier.DvdRoomba, 3), 
	MinigameListResource.create(MinigameIdentifier.ForkliftCertified, 3), 
	MinigameListResource.create(MinigameIdentifier.BurnRecycle, 2), 
]

var session_playlist: Array[MinigameListResource]

enum MinigameIdentifier{
	ChiselGauntlet, 
	ExplodingCollarRace, 
	EscalatorPit, 
	ManufactureGun, 
	SmokeBreak, 
	DiscoDodge, 
	ShapeCutter, 
	KnifeAtTheOffice, 
	ScavangerChairs, 
	TrainRace, 
	DuckHunt, 
	GreenPea, 
	DvdRoomba, 
	JunkPlatform, 
	SpineBreaker, 
	MemorizePath, 
	ForkliftCertified, 
	BurnRecycle, 
	CutsceneTest, 
	CutsceneGame02, 
	EMPTY, 
}

const CustomMinigamesWhitelist: Array[MinigameIdentifier] = [
	MinigameIdentifier.ChiselGauntlet, 
	MinigameIdentifier.ExplodingCollarRace, 
	MinigameIdentifier.EscalatorPit, 
	MinigameIdentifier.ManufactureGun, 
	MinigameIdentifier.SmokeBreak, 
	MinigameIdentifier.DuckHunt, 
	MinigameIdentifier.TrainRace, 
	MinigameIdentifier.KnifeAtTheOffice, 
	MinigameIdentifier.DiscoDodge, 
	MinigameIdentifier.GreenPea, 
	MinigameIdentifier.SpineBreaker, 
	MinigameIdentifier.DvdRoomba, 
	MinigameIdentifier.JunkPlatform, 
	MinigameIdentifier.ForkliftCertified, 
	MinigameIdentifier.BurnRecycle, 


]

const MinigamePaths: Dictionary[MinigameIdentifier, String] = {
	MinigameIdentifier.ChiselGauntlet: "res://minigames/chisel_gauntlet_multiplayer/chisel_gauntlet.tscn", 
	MinigameIdentifier.ExplodingCollarRace: "res://minigames/exploding_collar_race/exploding_collar_race.tscn", 
	MinigameIdentifier.EscalatorPit: "res://minigames/escalator_pit/escalator_pit.tscn", 
	MinigameIdentifier.ManufactureGun: "res://minigames/manufacture_gun/manufacture_gun.tscn", 
	MinigameIdentifier.SmokeBreak: "res://minigames/smoke_break/smoke_break.tscn", 
	MinigameIdentifier.DiscoDodge: "res://minigames/disco_dodge/disco_dodge.tscn", 
	MinigameIdentifier.ShapeCutter: "res://minigames/shape_cutter/shape_cutter.tscn", 
	MinigameIdentifier.KnifeAtTheOffice: "res://minigames/knife_at_the_office/knife_at_the_office.tscn", 
	MinigameIdentifier.ScavangerChairs: "res://minigames/scavenger_chairs/scavenger_chairs.tscn", 
	MinigameIdentifier.TrainRace: "res://minigames/train_race/train_race.tscn", 
	MinigameIdentifier.DuckHunt: "res://minigames/duck_hunt/duck_hunt.tscn", 
	MinigameIdentifier.GreenPea: "res://minigames/green_pea/green_pea.tscn", 
	MinigameIdentifier.DvdRoomba: "res://minigames/dvd_roomba/dvd_roomba.tscn", 
	MinigameIdentifier.JunkPlatform: "res://minigames/junk_platform/junk_platform.tscn", 
	MinigameIdentifier.SpineBreaker: "res://minigames/spine_breaker/spine_breaker.tscn", 
	MinigameIdentifier.MemorizePath: "res://minigames/memorize_path/memorize_path.tscn", 
	MinigameIdentifier.ForkliftCertified: "res://minigames/forklift_certified/forklift_certified.tscn", 
	MinigameIdentifier.BurnRecycle: "res://minigames/burn_recycle/burn_recycle.tscn", 
	MinigameIdentifier.CutsceneTest: "res://minigames/cutscene_test/cutscene_test.tscn", 
	MinigameIdentifier.CutsceneGame02: "res://minigames/cutscene_game_02/cutscene_game_02.tscn", 
}

const MinigameIconPaths: Dictionary[MinigameIdentifier, String] = {
	MinigameIdentifier.ChiselGauntlet: "res://minigames/intermission_new/minigame_icons/minigame icon_chisel_gauntlet.png", 
	MinigameIdentifier.ExplodingCollarRace: "res://minigames/intermission_new/minigame_icons/minigame icon_collar_race.png", 
	MinigameIdentifier.EscalatorPit: "res://minigames/intermission_new/minigame_icons/minigame icon_escalator_pit.png", 
	MinigameIdentifier.ManufactureGun: "res://minigames/intermission_new/minigame_icons/minigame icon_manufacture_gun.png", 
	MinigameIdentifier.SmokeBreak: "res://minigames/intermission_new/minigame_icons/minigame icon_smoke_break.png", 
	MinigameIdentifier.DiscoDodge: "res://minigames/intermission_new/minigame_icons/minigame icon_disco_dodge.png", 
	MinigameIdentifier.ShapeCutter: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
	MinigameIdentifier.KnifeAtTheOffice: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder7.png", 
	MinigameIdentifier.ScavangerChairs: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
	MinigameIdentifier.TrainRace: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder2.png", 
	MinigameIdentifier.DuckHunt: "res://minigames/intermission_new/minigame_icons/minigame icon_duckhunt.png", 
	MinigameIdentifier.GreenPea: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder1.png", 
	MinigameIdentifier.DvdRoomba: "res://minigames/intermission_new/minigame_icons/minigame icon_lethal rebound.png", 
	MinigameIdentifier.JunkPlatform: "res://minigames/intermission_new/minigame_icons/minigame icon_debris platforms.png", 
	MinigameIdentifier.SpineBreaker: "res://minigames/intermission_new/minigame_icons/minigame icon_spinebreaker.png", 
	MinigameIdentifier.MemorizePath: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
	MinigameIdentifier.ForkliftCertified: "res://minigames/intermission_new/minigame_icons/minigame icon_forklift certified.png", 
	MinigameIdentifier.BurnRecycle: "res://minigames/intermission_new/minigame_icons/minigame icon_burn recycle.png", 
	MinigameIdentifier.CutsceneTest: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
	MinigameIdentifier.CutsceneGame02: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
	MinigameIdentifier.EMPTY: "res://minigames/intermission_new/minigame_icons/placeholder_icons/minigame icon_placeholder11.png", 
}

const CutsceneMinigameIdentifiers: Array[MinigameIdentifier] = [
	MinigameIdentifier.CutsceneTest
]

const CutsceneGlitchedPickerMinigameIdentifiers: Array[MinigameIdentifier] = [
	MinigameIdentifier.CutsceneGame02
]

const MinigameReadableNames: Dictionary[MinigameIdentifier, StringName] = {
	MinigameIdentifier.ChiselGauntlet: "LOC_MG_TITLE_04", 
	MinigameIdentifier.ExplodingCollarRace: "LOC_MG_TITLE_05", 
	MinigameIdentifier.EscalatorPit: "LOC_MG_TITLE_03", 
	MinigameIdentifier.ManufactureGun: "LOC_MG_TITLE_02", 
	MinigameIdentifier.SmokeBreak: "LOC_MG_TITLE_01", 
	MinigameIdentifier.DiscoDodge: "LOC_MG_TITLE_07", 
	MinigameIdentifier.ShapeCutter: "LOC_EMPTY", 
	MinigameIdentifier.KnifeAtTheOffice: "LOC_MG_TITLE_09", 
	MinigameIdentifier.ScavangerChairs: "LOC_EMPTY", 
	MinigameIdentifier.TrainRace: "LOC_MG_TITLE_06", 
	MinigameIdentifier.DuckHunt: "LOC_MG_TITLE_10", 
	MinigameIdentifier.GreenPea: "LOC_MG_TITLE_08", 
	MinigameIdentifier.DvdRoomba: "LOC_MG_TITLE_11", 
	MinigameIdentifier.MemorizePath: "LOC_EMPTY", 
	MinigameIdentifier.JunkPlatform: "LOC_MG_TITLE_12", 
	MinigameIdentifier.SpineBreaker: "LOC_MG_TITLE_13", 
	MinigameIdentifier.ForkliftCertified: "LOC_MG_TITLE_15", 
	MinigameIdentifier.BurnRecycle: "LOC_MG_TITLE_14", 
	MinigameIdentifier.CutsceneTest: "LOC_EMPTY", 
	MinigameIdentifier.CutsceneGame02: "LOC_EMPTY", 
	MinigameIdentifier.EMPTY: "N/A", 
}

const MinigameTaglines: Dictionary[MinigameIdentifier, String] = {
	MinigameIdentifier.ChiselGauntlet: "LOC_MG_TAGLINE_01", 
	MinigameIdentifier.ExplodingCollarRace: "LOC_MG_TAGLINE_02", 
	MinigameIdentifier.EscalatorPit: "LOC_MG_TAGLINE_03", 
	MinigameIdentifier.ManufactureGun: "LOC_MG_TAGLINE_04", 
	MinigameIdentifier.SmokeBreak: "LOC_MG_TAGLINE_05", 
	MinigameIdentifier.DiscoDodge: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.ShapeCutter: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.ScavangerChairs: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.JunkPlatform: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.KnifeAtTheOffice: "LOC_MG_TAGLINE_06", 
	MinigameIdentifier.TrainRace: "LOC_MG_TAGLINE_07", 
	MinigameIdentifier.DuckHunt: "LOC_MG_TAGLINE_08", 
	MinigameIdentifier.GreenPea: "LOC_MG_TAGLINE_09", 
	MinigameIdentifier.DvdRoomba: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.SpineBreaker: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.MemorizePath: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.ForkliftCertified: "LOC_MG_TAGLINE_10", 
	MinigameIdentifier.BurnRecycle: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.CutsceneTest: "LOC_MG_TAGLINE_11", 
	MinigameIdentifier.CutsceneGame02: "LOC_MG_TAGLINE_11", 
}

enum CustomizationCharacterSlot{
	Hat, Glasses, SuitColor
}

enum CustomizationColors{
	Red, Blue, Green, Yellow, Purple, Orange, Cyan, Pink
}

enum CustomizationItems{
	None, 
	BeerHat, 
	CapBlade, 
	Sunglasses, 
	ReadingGlasses, 
	RubiksCube, 
	Tophat, 
	TrafficCone, 
	MaskaHelmet
}

const MinigameRoundsByPlayerCount: Dictionary = {
	MinigameIdentifier.DuckHunt: {
		1: 2,
		2: 2,
		3: 2,
		4: 2,
		# 8-PLAYER MOD: Duck Hunt runs one INTERNAL round per player - every
		# player hunts exactly once, because `possible_hunters` is popped without
		# replacement and never refilled (duck_hunt.gd). So the internal round
		# count IS the roster, and the value here multiplies it.
		#
		# Vanilla at 4 players is 4 hunters x 2 = 8 turns. Left at 2 these keys
		# would be absent, `.get()` would fall back to 2, and 8 players would run
		# 8 x 2 = SIXTEEN turns - roughly four times a normal session. One outer
		# round above four keeps 8 players at 8 turns, the same total vanilla
		# already runs, and ducks run concurrently so a 7-duck turn is not much
		# longer than a 3-duck one.
		5: 1,
		6: 1,
		7: 1,
		8: 1
	}
}

const customizations = [
	"beer_hat", 
	"cap_blade", 
	"sunglasses", 
	"reading_glasses", 
	"rubiks_cube", 
	"tophat", 
	"traffic_cone", 
	"maska_helmet", 
	]

const suit_colors = [
	"red",
	"blue",
	"green",
	"yellow",
	"purple",
	"orange",
	"cyan",
	"pink",
]

# 8-PLAYER MOD -----------------------------------------------------------------
# The last three suits have no artwork of their own. CustomizationAssigner
# renders them by tinting one of the five shipped suit textures, so the shading
# and detail of the original art carries over. Keys must stay in sync with
# suit_colors above.
const modded_suit_tints: Dictionary = {
	"orange": ["yellow", Color(1.35, 0.62, 0.18)],
	"cyan": ["blue", Color(0.35, 1.45, 1.5)],
	"pink": ["red", Color(1.45, 0.62, 0.95)],
}

# Minigames whose design does not survive more than four players: they hand out
# fixed physical furniture (workstations, chairs) or hard-code player nodes into
# the level. They stay fully playable at 1-4 and are dropped from the rotation
# above that rather than being broken or removed outright.
#
# DuckHunt was listed here until 2026-08-02, described as "asymmetric: 3 duck
# slots + 1 hunter". That description was wrong and is why it stayed capped: the
# mode is 1 hunter + (N-1) DUCKS, popped from a shuffled pool, so the duck count
# already scales by itself. The "3" was only the spawn-marker count. It now
# scales - see the Duck Hunt section in UPDATING.md.
#
# ForkliftCertified was listed here until 2026-08-04, with the reason "four
# DropAreas ... between them tile the whole 32x32 yard ... There is no room to
# add four more zones". Measured from the scene, that was wrong twice over: the
# yard floor is 53.6 x 58.6 (the inverted CSGBox3D is the only static collider
# in the level, so all of it is drivable) and the four zones cover 24% of it,
# leaving a 16.7-wide channel between the zone columns and an 18.3-deep band
# between the rows. Four more zones fit at the mid-edges. Second wrong-judgement
# entry in a row here - a capped minigame is never run, so a bad reason in this
# table never contradicts itself. Re-derive before trusting one.
#
# BurnRecycle (THE FILTER) was listed here until 2026-08-05. It is the FIRST
# entry in this table whose recorded reason survived inspection: it really does
# hand out fixed physical furniture (4 belts, 4 presses, 4 indicators, 4 death
# presses) and really does differentiate players by rotation alone
# (`90.0 * counter`, which wraps at eight). It was uncapped anyway, because the
# furniture is radially symmetric about the origin - the same shape Chisel
# Gauntlet already solves by cloning at runtime. See MINIGAMES.md section 21.
const modded_minigame_player_cap: Dictionary = {
	MinigameIdentifier.ScavangerChairs: 4,
}

func supports_player_count(identifier: MinigameIdentifier, player_count: int) -> bool:

	return player_count <= modded_minigame_player_cap.get(identifier, 8)

var default_settings: Dictionary = {
	"master_volume": 0.2, 
	"music_volume": 1.0, 
	"sfx_volume": 1.0, 
	"vsync": true, 
	"fullscreen": true, 
	"language": "EN", 
	"original_finished": false, 
	"custom_shuffled": false
}

var game_settings: Dictionary = {
	"duck_hunt:look_sensitivity": 1.0
}

var settings: Dictionary
var active_cosmetic_hat: String
var active_cosmetic_glasses: String
var active_cosmetic_suit_color: String = "blue"

var save_path: String = "user://machine_party_customization.save"
var settings_save_path: String = "user://machine_party_settings.save"
var game_settings_save_path: String = "user://machine_party_game_settings.save"
var playlist_save_path: String = "user://machine_party_playlist.save"

var current_minigame_identifier: MinigameIdentifier
var current_minigame_round: int = -1

signal settings_saved()
signal locale_changed()

func _ready() -> void :
	print("Running version: ", game_version)

	if debug_instant_start:
		debug_skip_brief = true
		debug_skip_intermission = true
		skipping_intro_cutscene = true

	Steamworks.initialize_steam()

	load_preferences()
	load_settings()
	load_game_settings()
	load_playlist()

var debug_locales = [
	"EN", 
	"EE", 
	"FI", 
	"SV", 
	"JA", 
	"ZHS", 
	"ZHT", 
	"FR", 
	"DE", 
	"ES LATAM", 
	"BR", 
	"KO", 
	"PL", 
	"RU", 
	"UA", 
	"TR", 
	]

func save_playlist():

	if session_playlist.is_empty():
		return

	var save_file = FileAccess.open(playlist_save_path, FileAccess.WRITE)

	var data = []
	for mlr in session_playlist:
		data.append({
			"gid": mlr.game_identifier, 
			"r": mlr.total_rounds
		})

	var json_data = JSON.stringify(data)

	@warning_ignore("unused_variable")
	var save_ok = save_file.store_line(json_data)

func load_playlist():

	if not FileAccess.file_exists(playlist_save_path):
		session_playlist.clear()
		var list: Array[MinigameListResource] = []
		for mlr in default_playlist:
			list.append(
				MinigameListResource.create(
					mlr.game_identifier, mlr.total_rounds
				)
			)
		session_playlist = list
		return

	var save_file = FileAccess.open(playlist_save_path, FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		var list: Array[MinigameListResource] = []
		for g in json.data:
			var game_id = int(g.get("gid", -1))
			var rounds = g.get("r", 1)

			if game_id >= 0 and MinigameIdentifier.values().has(game_id):
				list.append(
					MinigameListResource.create(game_id, rounds)
				)

		if not list.is_empty():
			session_playlist = list

func save_current_settings():

	var save_file = FileAccess.open(settings_save_path, FileAccess.WRITE)

	var json_data = JSON.stringify(settings)
	var save_ok = save_file.store_line(json_data)

	if save_ok:
		settings_saved.emit()

func save_settings(_settings: Dictionary):

	var save_file = FileAccess.open(settings_save_path, FileAccess.WRITE)

	var json_data = JSON.stringify(_settings)
	var save_ok = save_file.store_line(json_data)

	if save_ok:

		settings = _settings
		settings_saved.emit()

func load_settings():

	if not FileAccess.file_exists(settings_save_path):
		save_settings(default_settings)

	var save_file = FileAccess.open(settings_save_path, FileAccess.READ)

	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		settings["master_volume"] = (
			json.data.get("master_volume", Globals.default_settings.get("master_volume"))
		)
		settings["music_volume"] = (
			json.data.get("music_volume", Globals.default_settings.get("music_volume"))
		)
		settings["sfx_volume"] = (
			json.data.get("sfx_volume", Globals.default_settings.get("sfx_volume"))
		)
		settings["vsync"] = (
			json.data.get("vsync", Globals.default_settings.get("vsync"))
		)
		settings["fullscreen"] = (
			json.data.get("fullscreen", Globals.default_settings.get("fullscreen"))
		)
		settings["language"] = (
			json.data.get("language", Globals.default_settings.get("language"))
		)
		settings["original_finished"] = (
			json.data.get("original_finished", Globals.default_settings.get("original_finished"))
		)
		settings["custom_shuffled"] = (
			json.data.get("custom_shuffled", Globals.default_settings.get("custom_shuffled"))
		)

		set_bus_volume_linear("Master", settings["master_volume"])
		set_bus_volume_linear("MUSIC", settings["music_volume"])
		set_bus_volume_linear("SFX", settings["sfx_volume"])
		set_vsync(settings["vsync"])
		set_fullscreen(settings["fullscreen"])
		TranslationServer.set_locale(settings["language"])
		Globals.locale_changed.emit()
		showing_post_original_menu = settings["original_finished"]

	PauseMenu.apply_settings()


func save_game_settings():

	var save_file = FileAccess.open(game_settings_save_path, FileAccess.WRITE)
	var json_data = JSON.stringify(game_settings)
	var save_ok = save_file.store_line(json_data)

	if save_ok:
		settings_saved.emit()

func load_game_settings():

	if not FileAccess.file_exists(game_settings_save_path):
		return

	var save_file = FileAccess.open(game_settings_save_path, FileAccess.READ)

	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			return

		if json.data:
			game_settings = json.data


func save_preferences():
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)

	var data = {
		"active_cosmetic_hat": active_cosmetic_hat, 
		"active_cosmetic_glasses": active_cosmetic_glasses, 
		"active_cosmetic_suit_color": active_cosmetic_suit_color, 
	}

	var json_data = JSON.stringify(data)

	@warning_ignore("unused_variable")
	var save_ok = save_file.store_line(json_data)

func load_preferences():

	active_cosmetic_hat = ""
	active_cosmetic_glasses = ""
	active_cosmetic_suit_color = "blue"

	if not FileAccess.file_exists(save_path):
		return

	var save_file = FileAccess.open(save_path, FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		active_cosmetic_hat = json.data.get("active_cosmetic_hat", "")
		active_cosmetic_glasses = json.data.get("active_cosmetic_glasses", "")
		active_cosmetic_suit_color = json.data.get("active_cosmetic_suit_color", "")

func set_bus_volume_linear(bus_name: StringName, value: float):
	var multiplier = audio_channel_multipliers.get(bus_name, 1.0)

	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(bus_idx, value * multiplier)

func set_vsync(_value: bool):
	if _value:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func set_fullscreen(_value: bool):

	settings.set("fullscreen", _value)

	if _value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().physics_frame

		var display_size = DisplayServer.screen_get_size()
		get_window().size = display_size * 0.5

func enable_debug_tools():

	DebugTools.set_active(true)
