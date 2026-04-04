extends Node3D
## WorldBuilder — procedurally generates the entire game world:
##   terrain, city buildings, roads, beach, water, trees, props, NPCs, player.

const TERRAIN_HALF := 100.0
const CITY_HALF    := 38.0
const GRID_CELLS   := 5       # grid extends from -GRID_CELLS to +GRID_CELLS
const CELL_SIZE    := 13.0
const NPC_COUNT    := 8

var _rng := RandomNumberGenerator.new()

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	_create_terrain()
	_create_city()
	_create_roads()
	_create_beach()
	_create_trees()
	_create_props()
	_spawn_npcs()
	_spawn_player()
	_spawn_hud()
	_spawn_pause_menu()

# ── Environment (sky, sun, fog, glow, SSAO) ───────────────────────────────────
func _setup_environment() -> void:
	# ── WorldEnvironment ──────────────────────────────────────────────────────
	var we  := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	add_child(we)

	var env := Environment.new()

	# Procedural sky
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color     = Color(0.16, 0.44, 0.88)
	sky_mat.sky_horizon_color = Color(0.72, 0.85, 0.98)
	sky_mat.ground_horizon_color = Color(0.44, 0.55, 0.32)
	sky_mat.ground_bottom_color  = Color(0.18, 0.22, 0.08)
	sky_mat.sun_angle_max     = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.sky                   = sky
	env.background_mode       = Environment.BG_SKY
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy  = 0.75

	# Fog
	env.fog_enabled           = true
	env.fog_density           = 0.0028
	env.fog_aerial_perspective = 0.55

	# Tonemap
	env.tonemap_mode          = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure      = 1.05

	# Glow / bloom
	env.glow_enabled          = true
	env.glow_normalized       = true
	env.glow_intensity        = 0.50
	env.glow_bloom            = 0.12
	env.glow_hdr_threshold    = 1.0

	# SSAO
	env.ssao_enabled          = true
	env.ssao_radius           = 1.2
	env.ssao_intensity        = 2.2
	env.ssao_power            = 1.5

	we.environment = env

	# ── Directional sun light ─────────────────────────────────────────────────
	var sun       := DirectionalLight3D.new()
	sun.name      = "Sun"
	add_child(sun)
	sun.rotation_degrees          = Vector3(-48, 42, 0)
	sun.light_color               = Color(1.00, 0.94, 0.82)
	sun.light_energy              = 1.80
	sun.shadow_enabled            = true
	sun.directional_shadow_mode   = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0

# ── Ground / terrain ──────────────────────────────────────────────────────────
func _create_terrain() -> void:
	var root := _node("Terrain")

	# Large grass plane
	_sbox(root, Vector3(0, -0.5, 0),
		Vector3(TERRAIN_HALF * 2, 1.0, TERRAIN_HALF * 2),
		Color(0.26, 0.50, 0.17), 0.95, 0.0)

	# City concrete pad (slightly raised)
	_sbox(root, Vector3(0, -0.05, 0),
		Vector3(CITY_HALF * 2 + 10, 0.55, CITY_HALF * 2 + 10),
		Color(0.52, 0.52, 0.50), 0.95, 0.0)

	# Rolling hills (sphere halves outside city)
	var hill_data := [
		[Vector3(72, 0, 42),  8.0, 18.0],
		[Vector3(-66, 0, 56), 6.0, 14.0],
		[Vector3(62, 0, -62), 7.5, 16.0],
		[Vector3(-72, 0, -46),5.5, 13.0],
		[Vector3(82, 0, 12),  9.0, 20.0],
		[Vector3(-50, 0, -70),5.0, 12.0],
	]
	for hd in hill_data:
		var h   := float(hd[1])
		var r   := float(hd[2])
		var sm  := SphereMesh.new()
		sm.radius = r; sm.height = h
		sm.radial_segments = 16; sm.rings = 8
		var mi  := _plain_mesh(root, hd[0] + Vector3(0, h * 0.28, 0), sm,
			_mat(Color(0.24, 0.47, 0.14), 0.95, 0.0))
		_add_static_sphere(mi, r)

	# Dirt paths from city centre outward
	for i in 6:
		var a := i * TAU / 6.0
		_sbox(root,
			Vector3(cos(a) * 48, 0.02, sin(a) * 48),
			Vector3(2.8, 0.06, 28.0),
			Color(0.50, 0.38, 0.26), 0.95, 0.0,
			Vector3(0, a, 0))

# ── City buildings ────────────────────────────────────────────────────────────
func _create_city() -> void:
	var root := _node("City")

	var palettes := [
		Color(0.70, 0.70, 0.76),  # gray concrete
		Color(0.58, 0.68, 0.80),  # blue-glass
		Color(0.78, 0.73, 0.62),  # tan brick
		Color(0.52, 0.58, 0.63),  # slate
		Color(0.62, 0.70, 0.60),  # greenish
		Color(0.76, 0.66, 0.55),  # warm brown
		Color(0.86, 0.86, 0.84),  # white concrete
		Color(0.48, 0.53, 0.64),  # steel blue
	]
	var idx := 0

	for gx in range(-GRID_CELLS, GRID_CELLS + 1):
		for gz in range(-GRID_CELLS, GRID_CELLS + 1):
			# Leave road corridors empty
			if abs(gx) <= 1 or abs(gz) <= 1:
				continue
			if _rng.randf() < 0.30:
				continue

			var bx    := gx * CELL_SIZE
			var bz    := gz * CELL_SIZE
			var w     := _rng.randf_range(4.5, 9.5)
			var d     := _rng.randf_range(4.5, 9.5)
			# Taller buildings near centre
			var h     := _rng.randf_range(5.0, 14.0)
			if abs(gx) <= 2 and abs(gz) <= 2:
				h = _rng.randf_range(18.0, 36.0)

			var col := palettes[idx % palettes.size()]
			idx += 1

			# Main building body
			_sbox(root, Vector3(bx, h * 0.5, bz), Vector3(w, h, d), col, 0.45, 0.20)

			# Roof penthouse
			if _rng.randf() > 0.45:
				_sbox(root, Vector3(bx, h + 0.9, bz),
					Vector3(w * 0.5, 1.8, d * 0.5), col * 0.82, 0.50, 0.12)

			# Window strips on front & back face
			var win_rows := int(h / 3.2)
			for row in win_rows:
				var wy := 2.2 + row * 3.2
				for sign in [-1, 1]:
					var wmi := MeshInstance3D.new()
					var wm  := BoxMesh.new()
					wm.size  = Vector3(w - 0.5, 1.5, 0.06)
					wmi.mesh = wm
					wmi.position = Vector3(bx, wy, bz + sign * (d * 0.5 + 0.04))
					wmi.material_override = _mat(
						Color(0.45, 0.62, 0.88) * _rng.randf_range(0.7, 1.1),
						0.08, 0.75)
					root.add_child(wmi)

# ── Roads ─────────────────────────────────────────────────────────────────────
func _create_roads() -> void:
	var root     := _node("Roads")
	var asphalt  := Color(0.19, 0.19, 0.21)
	var yellow   := Color(0.95, 0.88, 0.15)
	var white_c  := Color(0.90, 0.90, 0.90)
	var road_w   := 7.5
	var road_len := CITY_HALF * 2.2
	var road_y   := 0.03

	# Road corridors: every CELL_SIZE*1 and *-1 on each axis
	for i in range(-GRID_CELLS, GRID_CELLS + 1):
		if abs(i) > 1:
			continue     # only the two central corridor rows/cols
		var pos_z := i * CELL_SIZE
		# Horizontal road
		_sbox(root, Vector3(0, road_y, pos_z),
			Vector3(road_len, 0.12, road_w), asphalt, 0.95, 0.0)
		# Vertical road
		_sbox(root, Vector3(pos_z, road_y, 0),
			Vector3(road_w, 0.12, road_len), asphalt, 0.95, 0.0)

		# Centre dashes
		for d in range(-8, 9):
			var dm := MeshInstance3D.new()
			var db := BoxMesh.new()
			db.size = Vector3(3.2, 0.06, 0.22)
			dm.mesh = db
			dm.position = Vector3(d * 7.5, road_y + 0.07, pos_z)
			dm.material_override = _mat(yellow, 0.9, 0.0)
			root.add_child(dm)
			# Vertical dashes
			var vm := MeshInstance3D.new()
			var vb := BoxMesh.new()
			vb.size = Vector3(0.22, 0.06, 3.2)
			vm.mesh = vb
			vm.position = Vector3(pos_z, road_y + 0.07, d * 7.5)
			vm.material_override = _mat(yellow, 0.9, 0.0)
			root.add_child(vm)

		# Edge white lines
		for side in [-1, 1]:
			var em := MeshInstance3D.new()
			var eb := BoxMesh.new()
			eb.size = Vector3(road_len, 0.06, 0.22)
			em.mesh = eb
			em.position = Vector3(0, road_y + 0.07, pos_z + side * (road_w * 0.5 - 0.3))
			em.material_override = _mat(white_c, 0.9, 0.0)
			root.add_child(em)

		# Raised kerbs
		for side in [-1, 1]:
			_sbox(root,
				Vector3(0, road_y + 0.12, pos_z + side * (road_w * 0.5 + 1.0)),
				Vector3(road_len, 0.24, 2.0),
				Color(0.62, 0.62, 0.60), 0.9, 0.0)
			_sbox(root,
				Vector3(pos_z + side * (road_w * 0.5 + 1.0), road_y + 0.12, 0),
				Vector3(2.0, 0.24, road_len),
				Color(0.62, 0.62, 0.60), 0.9, 0.0)

# ── Beach ─────────────────────────────────────────────────────────────────────
func _create_beach() -> void:
	var root := _node("Beach")

	# Sand strip
	_sbox(root, Vector3(88, -0.28, 0), Vector3(52, 0.55, 88),
		Color(0.94, 0.88, 0.68), 1.0, 0.0)

	# Transition slope (stepped)
	for i in 8:
		_sbox(root,
			Vector3(CITY_HALF + 2 + i * 3.2, -0.30 - i * 0.04, 0),
			Vector3(3.2, 0.32, 88),
			Color(0.62 + i * 0.04, 0.60 + i * 0.04, 0.52 + i * 0.04),
			0.92, 0.0)

	# Water plane with wave shader
	var water := MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	pm.subdivide_width  = 32
	pm.subdivide_depth  = 32
	water.mesh = pm
	water.position = Vector3(130, -0.45, 0)

	var shader_mat := ShaderMaterial.new()
	var shader     := load("res://shaders/water.gdshader") as Shader
	if shader:
		shader_mat.shader           = shader
		water.material_override     = shader_mat
	else:
		# Fallback: simple transparent blue material
		var fb := StandardMaterial3D.new()
		fb.albedo_color  = Color(0.14, 0.44, 0.76, 0.70)
		fb.roughness     = 0.06; fb.metallic = 0.30
		fb.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
		fb.cull_mode     = BaseMaterial3D.CULL_DISABLED
		water.material_override = fb
	root.add_child(water)

	# Beach umbrellas
	for zoff in [-14.0, -4.0, 6.0, 16.0]:
		_make_umbrella(root, Vector3(78, 0.25, zoff))

	# Volleyball net
	_sbox(root, Vector3(84, 1.2, 0), Vector3(0.12, 2.4, 9.0),
		Color(0.88, 0.88, 0.88), 0.9, 0.0)

func _make_umbrella(parent: Node3D, pos: Vector3) -> void:
	# Pole
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04; pm.bottom_radius = 0.05
	pm.height = 2.2; pm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 1.1, 0), pm,
		_mat(Color(0.68, 0.50, 0.30), 0.8, 0.0))
	# Canopy
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10; cm.bottom_radius = 1.6
	cm.height = 0.32; cm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 2.3, 0), cm,
		_mat(Color(0.90, 0.28, 0.18), 0.8, 0.0))

# ── Trees ─────────────────────────────────────────────────────────────────────
func _create_trees() -> void:
	var root := _node("Trees")

	# Sidewalk / perimeter positions
	var positions: Array[Vector3] = []
	for i in range(-GRID_CELLS, GRID_CELLS + 1):
		var t := i * CELL_SIZE
		positions.append_array([
			Vector3(t, 0, -CITY_HALF - 2),
			Vector3(t, 0,  CITY_HALF + 2),
			Vector3(-CITY_HALF - 2, 0, t),
			Vector3( CITY_HALF + 2, 0, t),
		])
	# Random scatter outside city
	for _i in 28:
		var a   := _rng.randf() * TAU
		var d   := _rng.randf_range(46.0, 88.0)
		positions.append(Vector3(cos(a) * d, 0, sin(a) * d))

	for p in positions:
		if _rng.randf() < 0.18:   # thin out a bit
			continue
		_make_tree(root, p)

func _make_tree(parent: Node3D, pos: Vector3) -> void:
	var trunk_h  := _rng.randf_range(1.6, 3.6)
	var canopy_r := _rng.randf_range(1.2, 2.6)

	# Trunk
	var tm := CylinderMesh.new()
	tm.top_radius = 0.14; tm.bottom_radius = 0.22
	tm.height = trunk_h; tm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, trunk_h * 0.5, 0), tm,
		_mat(Color(0.36, 0.26, 0.14), 1.0, 0.0))

	var green := Color(_rng.randf_range(0.14, 0.32),
					   _rng.randf_range(0.44, 0.65),
					   0.14)
	if _rng.randf() > 0.45:
		# Sphere canopy
		var sm := SphereMesh.new()
		sm.radius = canopy_r; sm.height = canopy_r * 2.0
		sm.radial_segments = 8; sm.rings = 6
		_plain_mesh(parent, pos + Vector3(0, trunk_h + canopy_r * 0.7, 0), sm,
			_mat(green, 1.0, 0.0))
	else:
		# Layered cone canopy (pine-like)
		for layer in 3:
			var lr  := canopy_r * (1.0 - layer * 0.22)
			var cm  := CylinderMesh.new()
			cm.top_radius = 0.06; cm.bottom_radius = lr
			cm.height = lr * 1.3; cm.radial_segments = 6
			_plain_mesh(parent,
				pos + Vector3(0, trunk_h + layer * lr * 0.78, 0), cm,
				_mat(green.darkened(layer * 0.06), 1.0, 0.0))

# ── Props ─────────────────────────────────────────────────────────────────────
func _create_props() -> void:
	var root := _node("Props")

	# Street lamps along main road corridors
	for axis_coord in [-6.5, 6.5]:
		for along in range(-5, 6):
			var t := along * CELL_SIZE
			_make_lamp(root, Vector3(t, 0, axis_coord + CELL_SIZE * 0.5))
			_make_lamp(root, Vector3(axis_coord + CELL_SIZE * 0.5, 0, t))

	# Park benches around centre plaza
	for i in 10:
		var a   := (i / 10.0) * TAU
		var r   := 18.0
		_make_bench(root, Vector3(cos(a) * r, 0.12, sin(a) * r), a + PI * 0.5)

	# Parked cars
	var car_spots := [
		[Vector3(-12, 0, -22), Color(0.80, 0.10, 0.10)],
		[Vector3(-12, 0,  -9), Color(0.10, 0.30, 0.82)],
		[Vector3( 12, 0,   8), Color(0.88, 0.82, 0.18)],
		[Vector3( 12, 0,  22), Color(0.12, 0.12, 0.12)],
		[Vector3(-22, 0,  12), Color(0.82, 0.82, 0.82)],
		[Vector3(  6, 0, -12), Color(0.10, 0.62, 0.22)],
		[Vector3( 22, 0,  -8), Color(0.70, 0.30, 0.75)],
		[Vector3( -6, 0,  20), Color(0.88, 0.55, 0.18)],
	]
	for cs in car_spots:
		_make_car(root, cs[0], cs[1])

	# Fences around city edge
	for i in 12:
		var fx := -55.0 + i * 10.0
		_sbox(root, Vector3(fx, 0.55, -CITY_HALF - 4), Vector3(9.5, 1.1, 0.22),
			Color(0.52, 0.42, 0.28), 0.9, 0.0)
		_sbox(root, Vector3(fx, 0.55,  CITY_HALF + 4), Vector3(9.5, 1.1, 0.22),
			Color(0.52, 0.42, 0.28), 0.9, 0.0)

	# Trash bins
	for _i in 8:
		var bx  := _rng.randf_range(-32.0, 32.0)
		var bz  := _rng.randf_range(-32.0, 32.0)
		_make_bin(root, Vector3(bx, 0, bz))

func _make_lamp(parent: Node3D, pos: Vector3) -> void:
	# Pole
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05; pm.bottom_radius = 0.07
	pm.height = 5.2; pm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 2.6, 0), pm,
		_mat(Color(0.52, 0.52, 0.58), 0.30, 0.85))
	# Head orb
	var hm := SphereMesh.new()
	hm.radius = 0.22; hm.height = 0.44
	_plain_mesh(parent, pos + Vector3(0, 5.35, 0), hm,
		_mat(Color(1.0, 1.0, 0.88), 0.05, 0.0))
	# Point light
	var light       := OmniLight3D.new()
	light.position  = pos + Vector3(0, 5.4, 0)
	light.light_color   = Color(1.0, 0.94, 0.72)
	light.light_energy  = 1.6
	light.omni_range    = 14.0
	light.shadow_enabled = false   # keep perf. reasonable
	parent.add_child(light)

func _make_bench(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	var wood  := Color(0.54, 0.38, 0.22)
	var metal := Color(0.40, 0.40, 0.48)
	# Seat
	_sbox(parent, pos + Vector3(0, 0.46, 0), Vector3(1.4, 0.10, 0.42), wood, 0.9, 0.0,
		Vector3(0, rot_y, 0))
	# Back rest
	_sbox(parent, pos + Vector3(0, 0.78, -0.17).rotated(Vector3.UP, rot_y),
		Vector3(1.4, 0.40, 0.09), wood, 0.9, 0.0, Vector3(0, rot_y, 0))
	# Legs
	for lx in [-0.58, 0.58]:
		_sbox(parent,
			pos + Vector3(lx, 0.22, 0).rotated(Vector3.UP, rot_y),
			Vector3(0.07, 0.44, 0.36), metal, 0.40, 0.75, Vector3(0, rot_y, 0))

func _make_car(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Body
	_sbox(parent, pos + Vector3(0, 0.50, 0), Vector3(1.85, 0.72, 3.90), color, 0.30, 0.42)
	# Cabin
	_sbox(parent, pos + Vector3(0, 1.08, -0.18), Vector3(1.62, 0.56, 2.20), color * 0.86, 0.30, 0.30)
	# Windscreens
	_sbox(parent, pos + Vector3(0, 1.05, 0.92), Vector3(1.52, 0.50, 0.06),
		Color(0.58, 0.75, 0.92, 0.6), 0.05, 0.5)
	_sbox(parent, pos + Vector3(0, 1.05, -1.28), Vector3(1.52, 0.50, 0.06),
		Color(0.58, 0.75, 0.92, 0.6), 0.05, 0.5)
	# Wheels
	for wx in [-0.96, 0.96]:
		for wz in [-1.22, 1.22]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.30; wm.bottom_radius = 0.30
			wm.height = 0.22; wm.radial_segments = 10
			var wmi := _plain_mesh(parent, pos + Vector3(wx, 0.30, wz), wm,
				_mat(Color(0.10, 0.10, 0.10), 1.0, 0.0))
			wmi.rotation.z = PI * 0.5
	# Headlights
	for hx in [-0.72, 0.72]:
		_sbox(parent, pos + Vector3(hx, 0.56, 1.95), Vector3(0.30, 0.15, 0.06),
			Color(1.0, 1.0, 0.82), 0.08, 0.0)

func _make_bin(parent: Node3D, pos: Vector3) -> void:
	var bm := CylinderMesh.new()
	bm.top_radius = 0.20; bm.bottom_radius = 0.17
	bm.height = 0.72; bm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.36, 0), bm,
		_mat(Color(0.18, 0.52, 0.20), 0.80, 0.10))
	var lm := CylinderMesh.new()
	lm.top_radius = 0.22; lm.bottom_radius = 0.22
	lm.height = 0.08; lm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.76, 0), lm,
		_mat(Color(0.14, 0.42, 0.14), 0.80, 0.0))

# ── NPC spawning ──────────────────────────────────────────────────────────────
func _spawn_npcs() -> void:
	var npc_scene := preload("res://scenes/npc.tscn")
	var colors := [
		Color(0.85, 0.28, 0.28), Color(0.28, 0.40, 0.88),
		Color(0.28, 0.75, 0.36), Color(0.88, 0.76, 0.18),
		Color(0.72, 0.28, 0.78), Color(0.88, 0.54, 0.18),
		Color(0.28, 0.76, 0.76), Color(0.88, 0.88, 0.88),
	]
	var spots := [
		Vector3( 5,  1.5,  5), Vector3(-9,  1.5, 13),
		Vector3(16,  1.5, -5), Vector3(-13, 1.5, -9),
		Vector3(21,  1.5, 10), Vector3(-5,  1.5, 19),
		Vector3(10,  1.5,-16), Vector3(-19, 1.5,  5),
	]
	for i in min(NPC_COUNT, spots.size()):
		var npc             := npc_scene.instantiate() as CharacterBody3D
		npc.body_color      = colors[i % colors.size()]
		npc.position        = spots[i]
		add_child(npc)

# ── Player spawning ───────────────────────────────────────────────────────────
func _spawn_player() -> void:
	var player_scene := preload("res://scenes/player.tscn")
	var player       := player_scene.instantiate()
	player.position  = Vector3(0, 1.5, 0)
	add_child(player)

# ── HUD + Pause menu ──────────────────────────────────────────────────────────
func _spawn_hud() -> void:
	var hud_scene := preload("res://scenes/hud.tscn")
	add_child(hud_scene.instantiate())

func _spawn_pause_menu() -> void:
	var pm_scene := preload("res://scenes/pause_menu.tscn")
	add_child(pm_scene.instantiate())

# ── Utility helpers ───────────────────────────────────────────────────────────

## Create a named Node3D child
func _node(name_str: String) -> Node3D:
	var n := Node3D.new()
	n.name = name_str
	add_child(n)
	return n

## StandardMaterial3D factory
func _mat(color: Color, rough: float, metal: float,
		transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = rough
	m.metallic     = metal
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode    = BaseMaterial3D.CULL_DISABLED
	return m

## Static-body box (world geometry with collision)
func _sbox(parent: Node3D, pos: Vector3, size: Vector3,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)

	var sb  := StaticBody3D.new()
	var cs  := CollisionShape3D.new()
	var bs  := BoxShape3D.new(); bs.size = size
	cs.shape = bs; cs.rotation = rot
	sb.add_child(cs)
	mi.add_child(sb)
	parent.add_child(mi)
	return mi

## MeshInstance3D without collision (decorative)
func _plain_mesh(parent: Node3D, pos: Vector3, mesh: Mesh,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var mi          := MeshInstance3D.new()
	mi.mesh         = mesh
	mi.position     = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## Add a sphere StaticBody to an existing MeshInstance3D
func _add_static_sphere(mi: MeshInstance3D, radius: float) -> void:
	var sb  := StaticBody3D.new()
	var cs  := CollisionShape3D.new()
	var ss  := SphereShape3D.new(); ss.radius = radius
	cs.shape = ss
	sb.add_child(cs)
	mi.add_child(sb)
