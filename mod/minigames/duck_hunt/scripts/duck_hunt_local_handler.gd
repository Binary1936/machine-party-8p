extends Node

class_name DuckHuntLocalHandler

@export var viewport_parent: Control
@export var canvas_layer: CanvasLayer
@export var background_parent: Control

const Layouts: Dictionary = {
	0: [
		[Vector2(0.0, 0.0), Vector2(1.0, 1.0)], 
	], 
	1: [
		[Vector2(0.0, 0.0), Vector2(1.0, 1.0)], 
	], 
	2: [
		[Vector2(0.0, 0.0), Vector2(0.5, 0.5)], 
		[Vector2(0.5, 0.5), Vector2(0.5, 0.5)], 
	], 
	3: [
		[Vector2(0.0, 0.0), Vector2(0.5, 0.5)], 
		[Vector2(0.5, 0.5), Vector2(0.5, 0.5)], 
		[Vector2(0.0, 0.5), Vector2(0.5, 0.5)], 
	], 
	4: [
		[Vector2(0.0, 0.0), Vector2(0.5, 0.5)],
		[Vector2(0.5, 0.0), Vector2(0.5, 0.5)],
		[Vector2(0.0, 0.5), Vector2(0.5, 0.5)],
		[Vector2(0.5, 0.5), Vector2(0.5, 0.5)],
	],
	# 8-PLAYER MOD: keys 5-8. `set_players()` below does `Layouts[player_count]`,
	# and duck_hunt.gd calls it UNCONDITIONALLY at the end of spawn_players() -
	# not only in couch mode - so a missing key errors every round even online.
	# Same 3x2 / 4x2 grids the mod already uses in
	# chisel_gauntlet_local_handler.gd. Keys 0-4 are untouched.
	5: [
		[Vector2(0.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(1.0 / 3.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(2.0 / 3.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(0.0, 0.5), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(1.0 / 3.0, 0.5), Vector2(1.0 / 3.0, 0.5)],
	],
	6: [
		[Vector2(0.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(1.0 / 3.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(2.0 / 3.0, 0.0), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(0.0, 0.5), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(1.0 / 3.0, 0.5), Vector2(1.0 / 3.0, 0.5)],
		[Vector2(2.0 / 3.0, 0.5), Vector2(1.0 / 3.0, 0.5)],
	],
	7: [
		[Vector2(0.0, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.25, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.5, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.75, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.0, 0.5), Vector2(0.25, 0.5)],
		[Vector2(0.25, 0.5), Vector2(0.25, 0.5)],
		[Vector2(0.5, 0.5), Vector2(0.25, 0.5)],
	],
	8: [
		[Vector2(0.0, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.25, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.5, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.75, 0.0), Vector2(0.25, 0.5)],
		[Vector2(0.0, 0.5), Vector2(0.25, 0.5)],
		[Vector2(0.25, 0.5), Vector2(0.25, 0.5)],
		[Vector2(0.5, 0.5), Vector2(0.25, 0.5)],
		[Vector2(0.75, 0.5), Vector2(0.25, 0.5)],
	],
}

var keyboard_player: ChiselGauntletPlayer
var keyboard_rect: TextureRect
var texture_rects: Array[TextureRect]

func _ready() -> void :

	var viewport_rect: Rect2 = viewport_parent.get_viewport_rect()
	var layout = Layouts[4]

	for i in background_parent.get_child_count():
		var values = layout[i]
		var texture_rect = background_parent.get_child(i)

		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.position = viewport_rect.end * values[0]
		texture_rect.size = viewport_rect.end * values[1]

func set_players(players: Array):

	var player_count = players.size()
	# 8P MOD: belt-and-braces. Layouts now covers 0-8, but an out-of-range key
	# here would abort silently mid-function (see pitfall 23 in UPDATING.md),
	# leaving a half-built splitscreen with no error in the log.
	if not Layouts.has(player_count):
		push_warning("[DUCK8] no splitscreen layout for %d players" % player_count)
		return
	var layout = Layouts[player_count]
	var viewport_rect: Rect2 = viewport_parent.get_viewport_rect()

	for i in players.size():
		var player = players[i]
		var values = layout[i]

		var texture = player.local_viewport.get_texture()
		var texture_rect: = TextureRect.new()
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.texture = texture
		texture_rect.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

		viewport_parent.add_child(texture_rect)
		texture_rect.position = viewport_rect.end * values[0]
		texture_rect.size = viewport_rect.end * values[1]
