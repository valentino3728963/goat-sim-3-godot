extends Node3D
## Intro cinematic — plays before the game starts.
## Four scenes: Farm → Escape → City → Title Drop, then loads game.tscn

var _camera: Camera3D
var _canvas: CanvasLayer
var _text_label: Label
var _title_label: Label
var _overlay: ColorRect
var _farm_root: Node3D
var _skip_pressed: bool = false

func _ready() -> void:
	_build_scene()
	_play_intro()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_skip_pressed = true
		_go_to_game()

func _build_scene() -> void:
	# ── Camera ────────────────────────────────────────────────────────────────
	_camera = Camera3D.new()
	_camera.name = "IntroCam"
	add_child(_camera)
	_camera.position = Vector3(0, 3, 12)
	_camera.rotation_degrees.x = -10.0

	# ── Simple lighting ───────────────────────────────────────────────────────
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.6
	add_child(sun)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color     = Color(0.16, 0.44, 0.88)
	sky_mat.sky_horizon_color = Color(0.72, 0.85, 0.98)
	sky_mat.ground_horizon_color = Color(0.44, 0.55, 0.32)
	sky_mat.ground_bottom_color  = Color(0.18, 0.22, 0.08)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)

	# ── Farm scene ────────────────────────────────────────────────────────────
	_farm_root = Node3D.new()
	_farm_root.name = "Farm"
	add_child(_farm_root)

	# Grass ground
	_sbox(_farm_root, Vector3(0, -0.25, 0), Vector3(80, 0.5, 80), Color(0.24, 0.52, 0.16), 0.95, 0.0)

	# Barn
	_sbox(_farm_root, Vector3(-8, 2.5, -5), Vector3(10, 5, 8), Color(0.62, 0.18, 0.12), 0.80, 0.0)
	_sbox(_farm_root, Vector3(-8, 6.0, -5), Vector3(10.4, 0.4, 8.4), Color(0.45, 0.12, 0.08), 0.80, 0.0)

	# Fence pen (4 sides)
	var fence_col: Color = Color(0.68, 0.50, 0.28)
	_sbox(_farm_root, Vector3(4, 0.6, -2),  Vector3(12, 1.2, 0.2), fence_col, 0.9, 0.0)
	_sbox(_farm_root, Vector3(4, 0.6,  4),  Vector3(12, 1.2, 0.2), fence_col, 0.9, 0.0)
	_sbox(_farm_root, Vector3(-2, 0.6, 1),  Vector3(0.2, 1.2, 6),  fence_col, 0.9, 0.0)
	_sbox(_farm_root, Vector3(10, 0.6, 1),  Vector3(0.2, 1.2, 6),  fence_col, 0.9, 0.0)

	# Goat in pen (simple procedural goat)
	var goat_node := Node3D.new()
	goat_node.name = "IntroGoat"
	goat_node.position = Vector3(4, 0.0, 1)
	_farm_root.add_child(goat_node)
	_build_goat_mesh(goat_node)

	# ── Canvas UI ─────────────────────────────────────────────────────────────
	_canvas = CanvasLayer.new()
	_canvas.layer = 15
	add_child(_canvas)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_overlay)

	_text_label = Label.new()
	_text_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_text_label.offset_top    = -120
	_text_label.offset_bottom = -20
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 36)
	_text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 0.0))
	_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_text_label.add_theme_constant_override("shadow_offset_x", 3)
	_text_label.add_theme_constant_override("shadow_offset_y", 3)
	_canvas.add_child(_text_label)

	_title_label = Label.new()
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_label.offset_left   = -400
	_title_label.offset_right  =  400
	_title_label.offset_top    = -80
	_title_label.offset_bottom =  80
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 96)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 0.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("shadow_offset_x", 5)
	_title_label.add_theme_constant_override("shadow_offset_y", 5)
	_title_label.text = "GOAT SIM 3"
	_canvas.add_child(_title_label)

	# Skip hint
	var skip_lbl := Label.new()
	skip_lbl.text = "SPACE / ENTER — Skip"
	skip_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_lbl.offset_left = -260; skip_lbl.offset_top = 20
	skip_lbl.add_theme_font_size_override("font_size", 18)
	skip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	_canvas.add_child(skip_lbl)

func _build_goat_mesh(parent: Node3D) -> void:
	var goat_tan := Color(0.85, 0.80, 0.68)
	var dark     := Color(0.40, 0.35, 0.25)
	var horn     := Color(0.55, 0.48, 0.28)
	var _hoof    := Color(0.15, 0.12, 0.10)
	# Body
	_box(parent, Vector3(0, 1.00, 0),    Vector3(0.70, 0.45, 1.10), goat_tan,  0.80, 0.00)
	_box(parent, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), goat_tan,  0.80, 0.00)
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_box(parent, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.60, 0.12), dark, 0.80, 0.00)
	for sx in [-1, 1]:
		_box(parent, Vector3(sx * 0.12, 1.86, 0.60) + Vector3(sx * 0.11, 0.28, 0),
			Vector3(0.06, 0.32, 0.06), horn, 0.70, 0.10)

func _play_intro() -> void:
	_run_intro()

func _run_intro() -> void:
	# ── Scene 1: The Farm (3 s) ───────────────────────────────────────────────
	_camera.position = Vector3(8, 2.5, 10)
	_camera.rotation_degrees = Vector3(-5, -30, 0)
	_show_text("Once upon a time...", 3.0)
	await _wait_or_skip(3.0)
	if _skip_pressed: return
	_hide_text()

	# ── Scene 2: The Escape (3 s) ─────────────────────────────────────────────
	var tw2 := create_tween()
	tw2.tween_property(_camera, "position", Vector3(4, 1.6, 7), 2.5)
	tw2.parallel().tween_property(_camera, "rotation_degrees",
		Vector3(-8, -15, 0), 2.5)
	_show_text("A goat decided to see the world...", 3.0)
	await _wait_or_skip(3.0)
	if _skip_pressed: return
	_hide_text()

	# ── Scene 3: The City (3 s) ───────────────────────────────────────────────
	var tw3 := create_tween()
	tw3.tween_property(_camera, "position", Vector3(0, 60, 0), 0.1)
	tw3.tween_property(_camera, "rotation_degrees", Vector3(-80, 0, 0), 0.1)
	await _wait_or_skip(0.2)
	if _skip_pressed: return
	var tw3b := create_tween()
	tw3b.tween_property(_camera, "position", Vector3(0, 8, 16), 2.5)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw3b.parallel().tween_property(_camera, "rotation_degrees", Vector3(-12, 0, 0), 2.5)
	_show_text("And chaos was never the same.", 3.0)
	await _wait_or_skip(3.0)
	if _skip_pressed: return
	_hide_text()

	# ── Scene 4: Title Drop (2 s) ─────────────────────────────────────────────
	var tw4 := create_tween()
	tw4.tween_property(_overlay, "color", Color(0, 0, 0, 0.5), 0.3)
	tw4.tween_property(_title_label, "modulate:a", 1.0, 0.6)
	_title_label.scale = Vector2(0.4, 0.4)
	_title_label.pivot_offset = Vector2(400, 80)
	tw4.parallel().tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.8)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait_or_skip(2.0)
	if _skip_pressed: return

	_go_to_game()

func _show_text(txt: String, _duration: float) -> void:
	_text_label.text = txt
	var tw := create_tween()
	tw.tween_property(_text_label, "modulate:a", 1.0, 0.4)

func _hide_text() -> void:
	var tw := create_tween()
	tw.tween_property(_text_label, "modulate:a", 0.0, 0.3)

func _wait_or_skip(t: float) -> Signal:
	return get_tree().create_timer(t).timeout

func _go_to_game() -> void:
	if get_tree() == null:
		return
	# Fade out
	var tw := create_tween()
	tw.tween_property(_overlay, "color", Color(0, 0, 0, 1.0), 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")

# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _sbox(parent: Node3D, pos: Vector3, size: Vector3,
		color: Color, rough: float, metal: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.position = pos
	mi.material_override = _mat(color, rough, metal)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	mi.add_child(sb)
	parent.add_child(mi)

func _box(parent: Node3D, pos: Vector3, sz: Vector3,
		color: Color, rough: float, metal: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.position = pos
	mi.material_override = _mat(color, rough, metal)
	parent.add_child(mi)
