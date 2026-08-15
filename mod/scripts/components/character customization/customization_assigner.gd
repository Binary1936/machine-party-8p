class_name CustomizationAssigner extends Node

@export var character_mesh: MeshInstance3D
@export var shake_on_cosmetic_change: bool
@export var use_cutoff_textures: bool
@export var assigning: bool = true

@export_group("nested in instance")
@export var bone_attachment_hat: BoneAttachment3D
@export var bone_attachment_glasses: BoneAttachment3D

@export_group("default")
@export var suit_texture_red: Texture
@export var suit_texture_blue: Texture
@export var suit_texture_green: Texture
@export var suit_texture_yellow: Texture
@export var suit_texture_purple: Texture

@export var shaker_hat: ShakerComponent3D
@export var shaker_glasses: ShakerComponent3D

@export_group("torso cut off")
@export var suit_texture_cutoff_red: Texture
@export var suit_texture_cutoff_blue: Texture
@export var suit_texture_cutoff_green: Texture
@export var suit_texture_cutoff_yellow: Texture
@export var suit_texture_cutoff_purple: Texture

var assigned_suit_color: String
var character_material: StandardMaterial3D

var is_first_shake = true

func _ready() -> void :
	if !assigning: return

	get_character_material()

	link_bone_attachments()

	assign_hat(Globals.active_cosmetic_hat)
	assign_glasses(Globals.active_cosmetic_glasses)
	assign_suit_color(Globals.active_cosmetic_suit_color)

func set_visibility_layer(_layer: int):

	for hat_parent in bone_attachment_hat.get_children():
		for hat_mesh in hat_parent.get_children():
			if hat_mesh is MeshInstance3D:
				hat_mesh.layers = _layer

func get_character_material():

	if not character_material:
		character_material = character_mesh.get_active_material(0).duplicate()
		character_mesh.set_surface_override_material(0, character_material)

func link_bone_attachments():
	bone_attachment_glasses.set_use_external_skeleton(true)
	bone_attachment_glasses.set_external_skeleton(get_parent().get_path())
	bone_attachment_glasses.bone_name = "head"
	bone_attachment_glasses.bone_idx = 4

	bone_attachment_hat.set_use_external_skeleton(true)
	bone_attachment_hat.set_external_skeleton(get_parent().get_path())
	bone_attachment_hat.bone_name = "hat"
	bone_attachment_hat.bone_idx = 5

func hide_hat():
	bone_attachment_hat.visible = false

func assign_hat(cosmetic_name: String):
	for child in bone_attachment_hat.get_children():
		child.visible = false
		if child.name == cosmetic_name:
			child.visible = true
	bone_attachment_hat.visible = true
	is_first_shake = false

func assign_glasses(cosmetic_name: String):
	for child in bone_attachment_glasses.get_children():
		child.visible = false
		if child.name == cosmetic_name:
			child.visible = true
	is_first_shake = false

func get_assigned_hat():
	for child in bone_attachment_hat.get_children():
		if child.visible:
			return child.name
	return "none"

func get_suit_texture(color_name: String) -> Texture:

	var texture: Texture

	# 8-PLAYER MOD: the three added suits borrow a shipped texture and are told
	# apart by an albedo tint instead (see get_suit_tint).
	if Globals.modded_suit_tints.has(color_name):
		color_name = Globals.modded_suit_tints[color_name][0]

	if !use_cutoff_textures:
		match color_name:
			"red": texture = suit_texture_red
			"blue": texture = suit_texture_blue
			"green": texture = suit_texture_green
			"yellow": texture = suit_texture_yellow
			"purple": texture = suit_texture_purple
			_: texture = suit_texture_blue
	else:
		match color_name:
			"red": texture = suit_texture_cutoff_red
			"blue": texture = suit_texture_cutoff_blue
			"green": texture = suit_texture_cutoff_green
			"yellow": texture = suit_texture_cutoff_yellow
			"purple": texture = suit_texture_cutoff_purple
			_: texture = suit_texture_blue

	return texture

func get_suit_tint(color_name: String) -> Color:

	if Globals.modded_suit_tints.has(color_name):
		return Globals.modded_suit_tints[color_name][1]
	return Color.WHITE

func assign_suit_color(color_name: String):

	assigned_suit_color = color_name
	get_character_material()
	character_material.set("albedo_texture", get_suit_texture(color_name))
	# Reset to white for the five original suits, so a character that switches
	# away from a modded colour does not keep the previous tint.
	character_material.set("albedo_color", get_suit_tint(color_name))

func remove_hat():
	for child in bone_attachment_hat.get_children():
		child.visible = false

func remove_glasses():
	for child in bone_attachment_glasses.get_children():
		child.visible = false
