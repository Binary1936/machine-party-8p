extends Node

class_name KnifeAtTheOfficeCountdownHandler

@export var countdown_time: int = 30
@export var countdown_label: Label
@export var countdown_background: ColorRect
@export var timer: Timer

@export var anim_fade: AnimationPlayer
@export var anim_change: AnimationPlayer

@export var alive_indicator_icons: Array[TextureRect]
@export var anim_alive_indicator_blink: AnimationPlayer
@export var anim_alive_indicator_fader: AnimationPlayer

var time_remaining: int
var active: bool = false

signal expired()

# --- 8P MOD ------------------------------------------------------------------
# `alive_indicator_icons` is wired to exactly four TextureRects in the scene,
# and both readers below walk it with `for i in num_of_alive_players`. At five
# or more players indices 4+ are out of bounds, so the hunt HUD showed four
# "human alive" icons however many humans were really left - it under-reported
# the thing the whole hunting phase is about.
#
# Measured, not assumed: in the release template an out-of-bounds read on a
# typed Array returns null and prints NOTHING, and `null.visible = true` is a
# silent no-op that does not even abort the function. So the vanilla loop just
# quietly does nothing past index 3 - no error, no crash, no log line. (A
# *method* call on that same null is different: it segfaults the process. See
# pitfall 23 in PITFALLS.md.) A control run with this file removed from
# the overlay confirmed it: identical timings, zero errors, four icons.
#
# The icons are bare TextureRects in an HBoxContainer with nothing but a
# `texture` set - no `node_paths` exports - so `duplicate()` is safe here and
# pitfall 20 does not apply.
#
# Nothing is cloned at four players or fewer: `_mod_ensure_indicator_capacity`
# returns immediately when the array is already big enough, so a 1-4 player
# game has the shipped four nodes and nothing else.
func _mod_ensure_indicator_capacity(_needed: int) -> void :

	if _needed <= alive_indicator_icons.size():
		return

	if alive_indicator_icons.is_empty():
		push_warning("[KATO8] alive_indicator_icons is empty - cannot grow")
		return

	var template: TextureRect = alive_indicator_icons[0]
	var parent: Node = template.get_parent()
	if parent == null:
		push_warning("[KATO8] indicator template has no parent - cannot grow")
		return

	while alive_indicator_icons.size() < _needed:
		var clone: TextureRect = template.duplicate()
		clone.name = "human alive indicator%d_MOD" % alive_indicator_icons.size()
		parent.add_child(clone)
		alive_indicator_icons.append(clone)

	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[KATO8] indicators is_server=", multiplayer.is_server(),
			" peer=", multiplayer.get_unique_id(),
			" needed=", _needed, " icons=", alive_indicator_icons.size())

func _ready() -> void :

	countdown_label.visible = false
	countdown_background.visible = false
	time_remaining = countdown_time

	if not multiplayer.is_server():
		return

	timer.timeout.connect(_on_timer_tick)



@rpc("any_peer", "call_local", "reliable")
func set_active_rpc(num_of_players: int = 1):

	countdown_label.text = "00:%s" % [str(countdown_time).pad_zeros(2)]
	countdown_label.visible = true
	countdown_background.visible = true
	anim_fade.play("fade in")

	setup_alive_indicator(num_of_players)

	if not multiplayer.is_server():
		return

	timer.wait_time = 1.0
	timer.start()



func _on_timer_tick():

	time_remaining -= 1

	if time_remaining > 0:

		timer.wait_time = 1.0
		timer.start()

	else:

		expired.emit()

	update_timers_rpc.rpc(time_remaining)

func setup_alive_indicator(num_of_alive_players: int):
	_mod_ensure_indicator_capacity(num_of_alive_players)
	for i in alive_indicator_icons:
		i.visible = false
	for i in num_of_alive_players:
		alive_indicator_icons[i].visible = true


	anim_alive_indicator_fader.play("show")

@rpc("authority", "call_local", "reliable")
func update_timers_rpc(_time: int):

	countdown_label.text = "00:%s" % [str(_time).pad_zeros(2)]
	anim_change.play("RESET")
	anim_change.play("change")

@rpc("authority", "call_local", "reliable")
func update_alive_indicator_rpc(num_of_alive_players: int):
	_mod_ensure_indicator_capacity(num_of_alive_players)
	anim_alive_indicator_fader.play("hide")
	await get_tree().create_timer(0.16, false).timeout
	for i in alive_indicator_icons:
		i.visible = false
	for i in num_of_alive_players:
		alive_indicator_icons[i].visible = true
	anim_alive_indicator_fader.play("show")
