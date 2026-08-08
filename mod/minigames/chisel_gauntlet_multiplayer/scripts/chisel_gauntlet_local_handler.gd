extends Node

class_name ChiselGauntletLocalHandler

@export var local_canvas_root: Control
@export var canvas_layer: CanvasLayer
@export var background_parent: Control
@export var fake_cursor: Control

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
	# 8-PLAYER MOD: 5 and 6 use a 3x2 grid, 7 and 8 a 4x2 grid. Cells are
	# normalised (position, size) pairs against the viewport, same as above.
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

	var viewport_rect: Rect2 = local_canvas_root.get_viewport_rect()
	var layout = Layouts[4]

	for i in background_parent.get_child_count():
		var values = layout[i]
		var texture_rect = background_parent.get_child(i)

		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.position = viewport_rect.end * values[0]
		texture_rect.size = viewport_rect.end * values[1]

func _process(_delta: float) -> void :

	if keyboard_player:
		var size = local_canvas_root.get_viewport_rect().end
		var mouse_position = local_canvas_root.get_global_mouse_position()
		var mouse_normalized = mouse_position / size

		fake_cursor.position = keyboard_rect.position + (
			mouse_normalized * keyboard_rect.size
		)

func set_players(players: Array[ChiselGauntletPlayer]):

	var player_count = players.size()
	var layout = Layouts[player_count]
	var viewport_rect: Rect2 = local_canvas_root.get_viewport_rect()

	for i in players.size():
		var player: ChiselGauntletPlayer = players[i]
		var values = layout[i]

		var texture = player.local_viewport.get_texture()
		var texture_rect: = TextureRect.new()
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.texture = texture
		texture_rect.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

		local_canvas_root.add_child(texture_rect)
		texture_rect.position = viewport_rect.end * values[0]
		texture_rect.size = viewport_rect.end * values[1]

		if not keyboard_player:
			if not player.player_presence.using_joystick:
				keyboard_player = player
				keyboard_rect = texture_rect
				fake_cursor.reparent(texture_rect)
