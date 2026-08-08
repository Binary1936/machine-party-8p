# 8-PLAYER MOD: a plain text roster of who is in the lobby.
#
# The seated characters stay as they are, but at eight players they are packed
# tightly enough that the floating nametags are hard to read, so this is the
# reliable "who is actually here" readout. Names are the Steam persona names -
# the backends already store them as player_info["name"] via
# Steam.getFriendPersonaName().
#
# Styling copies the lobby's own "message" Label verbatim (Terminal F4, black
# outline 5, shadow offset 2) so it sits in the vanilla look rather than beside
# it.
#
# Deliberately no `class_name`: global class names live in the pck's
# global_script_class_cache.cfg, which the mod does not regenerate, so a new one
# would not resolve. Callers preload this script instead.
extends VBoxContainer

const FONT: FontFile = preload("res://fonts/Terminal F4.ttf")

const HEADER_SIZE: int = 18
const ENTRY_SIZE: int = 15
const NAME_MAX_CHARS: int = 16

var _header: Label
var _entries: Array[Label] = []


static func attach(parent: Control, max_players: int) -> Node:
	"""Build the roster and add it to the top-left of `parent`."""
	if parent == null:
		return null
	var list = (load("res://modules/multiplayer_lobby/mod_player_name_list.gd")
		as GDScript).new()
	parent.add_child(list)
	list._build(max_players)
	return list


func _build(max_players: int) -> void:

	name = "ModPlayerNameList"
	# Top-left, clear of the button rows which anchor to the bottom.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 10)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_header = _make_label(HEADER_SIZE)
	add_child(_header)

	for i in max_players:
		var entry := _make_label(ENTRY_SIZE)
		add_child(entry)
		_entries.append(entry)


func _make_label(size: int) -> Label:

	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func refresh(seat_order: Array, connected: Dictionary, local_peer_id: int) -> void:
	"""seat_order: network ids by seat, -1 for empty. connected: peer -> info."""
	if _header == null:
		return

	var row: int = 0
	var occupied: int = 0

	for network_id in seat_order:
		if row >= _entries.size():
			break
		var entry: Label = _entries[row]

		if network_id < 0 or not connected.has(network_id):
			entry.text = ""
			entry.visible = false
			row += 1
			continue

		var info: Dictionary = connected[network_id]
		if info.get("debug", false):
			# Free-fly observer camera, not a competitor.
			entry.text = ""
			entry.visible = false
			row += 1
			continue

		var player_name := str(info.get("name", "?")).left(NAME_MAX_CHARS)
		var marker := ">" if info.get("peer_id", -1) == local_peer_id else " "
		entry.text = "%s %d %s" % [marker, occupied + 1, player_name]
		entry.visible = true
		occupied += 1
		row += 1

	while row < _entries.size():
		_entries[row].visible = false
		row += 1

	_header.text = "PLAYERS %d/%d" % [occupied, _entries.size()]
