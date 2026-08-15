extends Node

class_name ChiselGauntletLocalHandler

const LOCAL_OVERLAY_TEMPLATE = preload("uid://dt53xylkacp5y")

@export var local_canvas_root: Control
@export var canvas_layer: CanvasLayer
@export var fake_cursor: Control
@export var fake_cursor_texture_rect: TextureRect
@export var jumbotron_viewport: SubViewport
@export var jumbotron_texture_rect: TextureRect
@export var fade_color_rect: ColorRect

@export var cursor_pointer_texture: Texture2D
@export var cursor_hover_texture: Texture2D

@export var local_after_post_processing_canvas: CanvasLayer
@export var local_after_post_processing_root: Control

const Layouts: Dictionary = {
	0: [
		[Vector2(0.0, 0.0), Vector2(1.0, 1.0)], 
	], 
	1: [
		[Vector2(0.0, 0.0), Vector2(1.0, 1.0)], 
	], 

	2: [
		[Vector2(0.0, 0.0), Vector2(0.5, 1.0)], 
		[Vector2(0.5, 0.0), Vector2(0.5, 1.0)], 
	], 





	3: [
		[Vector2(0.0, 0.0), Vector2(0.5, 0.5)], 
		[Vector2(0.5, 0.0), Vector2(0.5, 0.5)], 
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
var keyboard_values: Array
var texture_rects: Array[TextureRect]
var overlay_templates: Dictionary[ChiselGauntletPlayer, LocalOverlayTemplate]

func _process(_delta: float) -> void :

	if keyboard_player:

		var size = local_canvas_root.get_viewport_rect().end
		var mouse_position = local_canvas_root.get_global_mouse_position()
		var mouse_normalized = mouse_position / size
		var reciprocal: Vector2 = Vector2(
			1.0 / keyboard_values[1].x, 1.0 / keyboard_values[1].y
		)

		fake_cursor.position = mouse_normalized * (keyboard_rect.size * reciprocal)

func show_all_tags(duration: float = 1.0):

	for player in overlay_templates.keys():
		if player.alive:
			overlay_templates[player].fade_in_name_label(duration)

func hide_all_tags(duration: float = 1.0):

	for o in overlay_templates.values():
		o.fade_out_name_label(duration)

func hide_player_tag(player: ChiselGauntletPlayer):

	if overlay_templates.has(player):
		overlay_templates[player].fade_out_name_label(0.5)

func center_mouse():

	if keyboard_player:

		var mouse_normalized = Vector2(0.5, 0.5)
		Input.warp_mouse(mouse_normalized * keyboard_rect.size)

func set_players(players: Array[ChiselGauntletPlayer]):

	jumbotron_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	jumbotron_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	var player_count = players.size()
	var layout = Layouts[player_count]
	var viewport_rect: Rect2 = local_canvas_root.get_viewport_rect()

	for i in players.size():
		var player: ChiselGauntletPlayer = players[i]
		var values = layout[i]

		player.local_viewport.size = viewport_rect.end * values[1]
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
				keyboard_values = values
				fake_cursor.reparent(texture_rect)
				keyboard_player.interaction_handler.entered_interactable.connect(_on_entered_interactible)
				keyboard_player.interaction_handler.left_interactable.connect(_on_left_interactible)



		var overlay_template = LOCAL_OVERLAY_TEMPLATE.instantiate()
		overlay_template.name_label.text = player.player_presence.network_name

		local_after_post_processing_root.add_child(overlay_template)
		overlay_template.position = viewport_rect.end * values[0]
		overlay_template.size = viewport_rect.end * values[1]

		overlay_templates[player] = overlay_template

func _on_entered_interactible():
	fake_cursor_texture_rect.texture = cursor_hover_texture

func _on_left_interactible():
	fake_cursor_texture_rect.texture = cursor_pointer_texture
