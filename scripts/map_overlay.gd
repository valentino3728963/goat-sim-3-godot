extends CanvasLayer
## Map overlay — press M to toggle a full-screen bird's-eye map.
## Draws the world layout procedurally using 2D draw calls.

var _visible_map: bool = false
var _panel: ColorRect
var _map_ctrl: Control
var _player_ref: Node3D = null

const MAP_SCALE := 0.8          # world units per pixel (lower = more zoomed in)
const MAP_SIZE  := 700.0        # map panel size in pixels
const WORLD_HALF := 500.0

func _ready() -> void:
	layer = 20
	visible = false

	# Dark background
	_panel = ColorRect.new()
	_panel.color = Color(0.0, 0.0, 0.0, 0.85)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	# Map drawing control
	_map_ctrl = Control.new()
	_map_ctrl.name = "MapDraw"
	_map_ctrl.set_anchors_preset(Control.PRESET_CENTER)
	_map_ctrl.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map_ctrl.offset_left   = -MAP_SIZE * 0.5
	_map_ctrl.offset_right  =  MAP_SIZE * 0.5
	_map_ctrl.offset_top    = -MAP_SIZE * 0.5
	_map_ctrl.offset_bottom =  MAP_SIZE * 0.5
	_map_ctrl.connect("draw", _on_map_draw)
	add_child(_map_ctrl)

	# "M — Close" label
	var hint := Label.new()
	hint.text = "M — Close Map"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 0.6, 0.9))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_map"):
		_visible_map = !_visible_map
		visible = _visible_map
		if _visible_map:
			_find_player()
			_map_ctrl.queue_redraw()

func _find_player() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p and p is Node3D:
		_player_ref = p as Node3D

# ── Draw callback ─────────────────────────────────────────────────────────────
func _on_map_draw() -> void:
	var half: float = MAP_SIZE * 0.5

	# Background (grass)
	_map_ctrl.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.18, 0.38, 0.14))

	# Compute scale: world coords [-WORLD_HALF..WORLD_HALF] → [0..MAP_SIZE]
	# world_to_map: px = (wx / WORLD_HALF) * half + half
	# ── Roads (dark lines) ──────────────────────────────────────────────────
	var asphalt: Color = Color(0.18, 0.18, 0.20)
	var road_w_px: float = 6.0
	# Central city corridors
	for i in [-1, 0, 1]:
		var wz: float = i * 13.0
		var z_px: float = _w2p_z(wz, half)
		_map_ctrl.draw_rect(Rect2(0, z_px - road_w_px * 0.5, MAP_SIZE, road_w_px), asphalt)
		var x_px: float = _w2p_x(wz, half)
		_map_ctrl.draw_rect(Rect2(x_px - road_w_px * 0.5, 0, road_w_px, MAP_SIZE), asphalt)
	# Highways
	var hy_z: float = _w2p_z(-140.0, half)
	_map_ctrl.draw_rect(Rect2(0, hy_z - 5, MAP_SIZE, 10), asphalt)
	var hy_x: float = _w2p_x(-140.0, half)
	_map_ctrl.draw_rect(Rect2(hy_x - 5, 0, 10, MAP_SIZE), asphalt)

	# ── Water / Beach ──────────────────────────────────────────────────────
	var beach_x: float = _w2p_x(88.0, half)
	_map_ctrl.draw_rect(Rect2(beach_x, 0, MAP_SIZE - beach_x, MAP_SIZE),
		Color(0.14, 0.44, 0.76, 0.80))

	# ── City pad (concrete) ───────────────────────────────────────────────
	var city_px1: float = _w2p_x(-38.0, half)
	var city_py1: float = _w2p_z(-38.0, half)
	var city_pw: float  = _w2p_x(38.0, half) - city_px1
	var city_ph: float  = _w2p_z(38.0, half) - city_py1
	_map_ctrl.draw_rect(Rect2(city_px1, city_py1, city_pw, city_ph),
		Color(0.50, 0.50, 0.48, 0.70))

	# ── Buildings (gray rectangles) ───────────────────────────────────────
	var bld_color: Color = Color(0.55, 0.58, 0.65, 0.9)
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			if abs(gx) <= 1 or abs(gz) <= 1:
				continue
			var bx: float = gx * 13.0
			var bz: float = gz * 13.0
			var bpx: float = _w2p_x(bx - 4.5, half)
			var bpz: float = _w2p_z(bz - 4.5, half)
			var bsz: float = (_w2p_x(bx + 4.5, half) - bpx)
			_map_ctrl.draw_rect(Rect2(bpx, bpz, bsz, bsz), bld_color)

	# ── NPC dots ─────────────────────────────────────────────────────────
	var npcs: Array = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc is Node3D:
			var n3d: Node3D = npc as Node3D
			var np: Vector2 = _world_to_map(n3d.global_position, half)
			_map_ctrl.draw_circle(np, 3.0, Color(0.90, 0.55, 0.10))

	# ── Car dots ──────────────────────────────────────────────────────────
	var cars: Array = get_tree().get_nodes_in_group("drivable_car")
	for car in cars:
		if car is Node3D:
			var c3d: Node3D = car as Node3D
			var cp: Vector2 = _world_to_map(c3d.global_position, half)
			_map_ctrl.draw_rect(Rect2(cp.x - 4, cp.y - 3, 8, 6), Color(0.20, 0.70, 0.95))

	# ── Player dot (last, on top) ─────────────────────────────────────────
	if _player_ref and is_instance_valid(_player_ref):
		var pp: Vector2 = _world_to_map(_player_ref.global_position, half)
		_map_ctrl.draw_circle(pp, 6.0, Color(1.0, 1.0, 0.0))
		# Direction arrow
		var fwd: Vector3 = -_player_ref.transform.basis.z
		var arrow_end: Vector2 = pp + Vector2(fwd.x, fwd.z).normalized() * 12.0
		_map_ctrl.draw_line(pp, arrow_end, Color(1.0, 0.8, 0.0), 2.0)

# ── Coordinate helpers ────────────────────────────────────────────────────────
func _w2p_x(wx: float, half: float) -> float:
	return (wx / WORLD_HALF) * half + half

func _w2p_z(wz: float, half: float) -> float:
	return (wz / WORLD_HALF) * half + half

func _world_to_map(wpos: Vector3, half: float) -> Vector2:
	return Vector2(_w2p_x(wpos.x, half), _w2p_z(wpos.z, half))
