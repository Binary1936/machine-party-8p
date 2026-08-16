# ---------------------------------------------------------------------------
# LOBBY PREVIEW BUILD ONLY — appended by tools/lobby_preview/build_preview.py,
# never part of mod/ or the shipped pck. Live lap placement for Player5-8.
#   F5-F8  select sitter P5-P8          F10  auto-place on host's lap (from live bones)
#   arrows move X / Z (world)           PgUp/PgDn  move Y      Home/End  yaw about own hips
#   Ins/Del nametag lift                Shift = fine steps
#   F9  print .tscn lines to log + clipboard     F11  reset selected to shipped transform
# ---------------------------------------------------------------------------
var pv_sel: int = 4
var pv_label: Label
var pv_prev: Dictionary = {}
var pv_home: Dictionary = {}

func pv_arm(i: int) -> Node3D:
	return lobby_handler.player_models[i].get_node("Armature_001") as Node3D

func pv_skel(i: int) -> Skeleton3D:
	return pv_arm(i).get_node("Skeleton3D") as Skeleton3D

func pv_bone(i: int, bone: String) -> Vector3:
	var sk := pv_skel(i)
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin

func pv_fwd(i: int) -> Vector3:
	var h := pv_bone(i, "hips")
	var k := (pv_bone(i, "shin.R") + pv_bone(i, "shin.L")) * 0.5
	return Vector3(k.x - h.x, 0.0, k.z - h.z).normalized()

func pv_pressed(key: Key) -> bool:
	return Input.is_physical_key_pressed(key)

func pv_just(key: Key) -> bool:
	var now := Input.is_physical_key_pressed(key)
	var was: bool = pv_prev.get(key, false)
	pv_prev[key] = now
	return now and not was

func pv_translate(i: int, d: Vector3) -> void:
	pv_arm(i).global_position += d
	lobby_handler.nametags[i].global_position += d

func pv_yaw_about_hips(i: int, ang: float) -> void:
	var p := pv_bone(i, "hips")
	var b := Basis(Vector3.UP, ang)
	pv_arm(i).global_transform = Transform3D(b, p - b * p) * pv_arm(i).global_transform

func pv_autoplace(i: int) -> void:
	var host := i - 4
	var hf := pv_fwd(host)
	pv_yaw_about_hips(i, pv_fwd(i).signed_angle_to(hf, Vector3.UP))
	var target := pv_bone(host, "hips") + hf * 0.45 + Vector3.UP * 0.30
	var d := target - pv_bone(i, "hips")
	pv_translate(i, Vector3(d.x, d.y, d.z))
	var host_tag := lobby_handler.nametags[host]
	lobby_handler.nametags[i].global_position = host_tag.global_position + Vector3(d.x, 0, d.z) + Vector3.UP * 0.9 + hf * 0.45

func pv_t3(t: Transform3D) -> String:
	# .tscn text lists the basis by ROWS; Basis.x/y/z are COLUMNS. Printing
	# columns in row slots transposes the basis, which for a yaw-only basis
	# is the inverse yaw - a seat that loads facing the wrong way (pitfall 35).
	var b := t.basis
	var v := [b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z, t.origin.x, t.origin.y, t.origin.z]
	var parts: PackedStringArray = []
	for f in v:
		parts.append(str(snappedf(f, 0.00000001)))
	return "Transform3D(" + ", ".join(parts) + ")"

func pv_export() -> String:
	var out := "# lobby lap layout — live from the preview build\n"
	for i in range(4, 8):
		var host := i - 4
		var d := pv_bone(i, "hips") - pv_bone(host, "hips")
		var hf := pv_fwd(host)
		var right := Vector3.UP.cross(hf)
		out += "P%d on P%d: fwd=%.2f up=%.2f side=%.2f facing_vs_host=%.0f\n" % [i + 1, host + 1, d.dot(hf), d.y, d.dot(right), rad_to_deg(pv_fwd(i).signed_angle_to(hf, Vector3.UP))]
	out += "\n"
	for i in range(4, 8):
		out += "[Player%d]\ntransform = %s\n" % [i + 1, pv_t3(lobby_handler.players[i].transform)]
		out += "[Player%d/main character2/Armature_001]\ntransform = %s\n" % [i + 1, pv_t3(pv_arm(i).transform)]
		out += "[Player%d/main character2/player nametag]\ntransform = %s\n\n" % [i + 1, pv_t3(lobby_handler.nametags[i].transform)]
	return out

func pv_process(delta: float) -> void:
	if lobby_handler == null or lobby_handler.players.size() < 8:
		return
	if pv_label == null:
		pv_label = Label.new()
		pv_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pv_label.position = Vector2(-560, 8)
		pv_label.size = Vector2(540, 200)
		pv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lobby_handler.root.add_child(pv_label)
		for i in range(4, 8):
			pv_home[i] = [pv_arm(i).transform, lobby_handler.nametags[i].transform]
	var fine := pv_pressed(KEY_SHIFT)
	var step := (0.15 if fine else 0.6) * delta
	var rot := deg_to_rad(10.0 if fine else 45.0) * delta
	for k in range(4):
		if pv_just([KEY_F5, KEY_F6, KEY_F7, KEY_F8][k]):
			pv_sel = 4 + k
	var d := Vector3.ZERO
	if pv_pressed(KEY_LEFT): d.x -= step
	if pv_pressed(KEY_RIGHT): d.x += step
	if pv_pressed(KEY_UP): d.z -= step
	if pv_pressed(KEY_DOWN): d.z += step
	if pv_pressed(KEY_PAGEUP): d.y += step
	if pv_pressed(KEY_PAGEDOWN): d.y -= step
	if d != Vector3.ZERO:
		pv_translate(pv_sel, d)
	if pv_pressed(KEY_HOME): pv_yaw_about_hips(pv_sel, rot)
	if pv_pressed(KEY_END): pv_yaw_about_hips(pv_sel, -rot)
	if pv_pressed(KEY_INSERT): lobby_handler.nametags[pv_sel].global_position += Vector3.UP * step
	if pv_pressed(KEY_DELETE): lobby_handler.nametags[pv_sel].global_position -= Vector3.UP * step
	if pv_just(KEY_F10):
		pv_autoplace(pv_sel)
	if pv_just(KEY_F11):
		pv_arm(pv_sel).transform = pv_home[pv_sel][0]
		lobby_handler.nametags[pv_sel].transform = pv_home[pv_sel][1]
	if pv_just(KEY_F9):
		var txt := pv_export()
		print("[PV-EXPORT]\n" + txt + "[/PV-EXPORT]")
		DisplayServer.clipboard_set(txt)
	var host := pv_sel - 4
	var dd := pv_bone(pv_sel, "hips") - pv_bone(host, "hips")
	var hf := pv_fwd(host)
	pv_label.text = "PREVIEW  sel P%d (on P%d)   F5-F8 select  F10 auto-lap  F9 print+copy  F11 reset\narrows X/Z  PgUp/Dn Y  Home/End yaw  Ins/Del tag  Shift fine\nfwd %.2f  up %.2f  side %.2f  facing %.0f°" % [pv_sel + 1, host + 1, dd.dot(hf), dd.y, dd.dot(Vector3.UP.cross(hf)), rad_to_deg(pv_fwd(pv_sel).signed_angle_to(hf, Vector3.UP))]
