extends Node3D
## WorldBuilder — procedurally generates the entire game world:
##   terrain, city buildings, roads, beach, water, trees, props, NPCs, player.

const TERRAIN_HALF  := 500.0
const CITY_HALF     := 38.0
const GRID_CELLS    := 5       # grid extends from -GRID_CELLS to +GRID_CELLS
const CELL_SIZE     := 13.0
const NPC_COUNT     := 35

# District centre offsets
const RESIDENTIAL_CENTER := Vector3(180, 0, 0)
const INDUSTRIAL_CENTER  := Vector3(-200, 0, 80)
const PARK_CENTER        := Vector3(0, 0, 180)
const HARBOR_CENTER      := Vector3(300, 0, 0)
const MOUNTAIN_CENTER    := Vector3(-250, 0, -250)

var _rng := RandomNumberGenerator.new()
var _sun: DirectionalLight3D  # reference to sun for day/night cycle
var _day_timer: float = 0.0
const DAY_LENGTH := 300.0   # seconds for a full day/night cycle

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	_create_terrain()
	_create_city()
	_create_roads()
	_create_beach()
	_create_residential_district()
	_create_industrial_district()
	_create_park_district()
	_create_harbor_district()
	_create_mountain_area()
	_create_highway()
	_create_trees()
	_create_props()
	_create_traffic_lights()
	_create_collectibles()
	_create_explosive_barrels()
	_create_trampolines()
	_spawn_npcs()
	_spawn_player()
	_spawn_hud()
	_spawn_pause_menu()

func _process(delta: float) -> void:
	# Day/night cycle
	_day_timer += delta
	if _day_timer > DAY_LENGTH:
		_day_timer -= DAY_LENGTH
	var day_frac := _day_timer / DAY_LENGTH
	# Sun sweeps from east (-90°) to west (+90°) through noon (0°)
	var sun_angle := -90.0 + day_frac * 360.0
	if _sun:
		_sun.rotation_degrees.x = sun_angle
		# Dim at night
		var brightness := clamp(sin(day_frac * PI * 2.0 - PI * 0.5) * 0.5 + 0.5, 0.05, 1.0)
		_sun.light_energy = brightness * 1.80

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
	sun.directional_shadow_max_distance = 400.0
	_sun = sun

# ── Ground / terrain ──────────────────────────────────────────────────────────
func _create_terrain() -> void:
	var root := _node("Terrain")

	# Large grass plane (uses subdivided mesh for visual variety)
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(TERRAIN_HALF * 2, TERRAIN_HALF * 2)
	terrain_mesh.subdivide_width  = 64
	terrain_mesh.subdivide_depth  = 64
	_plain_mesh(root, Vector3(0, -0.5, 0), terrain_mesh,
		_mat(Color(0.26, 0.50, 0.17), 0.95, 0.0))
	# Collision for grass plane
	var sb_grass := StaticBody3D.new()
	var cs_grass := CollisionShape3D.new()
	var bs_grass := BoxShape3D.new()
	bs_grass.size = Vector3(TERRAIN_HALF * 2, 0.2, TERRAIN_HALF * 2)
	cs_grass.shape = bs_grass
	sb_grass.add_child(cs_grass)
	root.add_child(sb_grass)

	# City concrete pad (slightly raised)
	_sbox(root, Vector3(0, -0.05, 0),
		Vector3(CITY_HALF * 2 + 10, 0.55, CITY_HALF * 2 + 10),
		Color(0.52, 0.52, 0.50), 0.95, 0.0)

	# Rolling hills (25+ hills spread across the big map)
	var hill_positions: Array[Vector3] = [
		Vector3(72, 0, 42),   Vector3(-66, 0, 56),
		Vector3(62, 0, -62),  Vector3(-72, 0, -46),
		Vector3(82, 0, 12),   Vector3(-50, 0, -70),
		Vector3(120, 0, 100), Vector3(-130, 0, 90),
		Vector3(110, 0,-110), Vector3(-140, 0,-80),
		Vector3(200, 0, 60),  Vector3(-180, 0, 130),
		Vector3(160, 0,-140), Vector3(-160, 0,-160),
		Vector3(230, 0,-50),  Vector3(-220, 0,-40),
		Vector3(90,  0, 200), Vector3(-80,  0, 220),
		Vector3(150, 0, 180), Vector3(-200, 0, 200),
		Vector3(280, 0, 80),  Vector3(-280, 0,-100),
		Vector3(50,  0,-200), Vector3(-60,  0,-180),
		Vector3(320, 0,-80),
	]
	var hill_heights: Array[float] = [
		8.0, 6.0, 7.5, 5.5, 9.0, 5.0,
		12.0, 10.0, 11.0, 8.0, 14.0, 9.0,
		10.0, 7.0, 13.0, 8.5, 6.0, 11.0,
		9.0, 15.0, 18.0, 20.0, 7.0, 8.0, 16.0
	]
	var hill_radii: Array[float] = [
		18.0, 14.0, 16.0, 13.0, 20.0, 12.0,
		26.0, 22.0, 24.0, 18.0, 30.0, 20.0,
		22.0, 16.0, 28.0, 19.0, 14.0, 24.0,
		20.0, 32.0, 38.0, 44.0, 16.0, 18.0, 36.0
	]
	for idx2 in hill_heights.size():
		var h: float = hill_heights[idx2]
		var r: float = hill_radii[idx2]
		var sm  := SphereMesh.new()
		sm.radius = r; sm.height = h
		sm.radial_segments = 20; sm.rings = 10
		var mi  := _plain_mesh(root, hill_positions[idx2] + Vector3(0, h * 0.28, 0), sm,
			_mat(Color(0.22 + _rng.randf_range(0,0.08),
					   0.44 + _rng.randf_range(0,0.08), 0.14), 0.95, 0.0))
		_add_static_sphere(mi, r)

	# Dirt paths from city centre outward
	for i in 8:
		var a := i * TAU / 8.0
		_sbox(root,
			Vector3(cos(a) * 60, 0.02, sin(a) * 60),
			Vector3(3.0, 0.06, 36.0),
			Color(0.50, 0.38, 0.26), 0.95, 0.0,
			Vector3(0, a, 0))

	# Connecting paths to districts
	_sbox(root, Vector3(110, 0.02, 0),  Vector3(160, 0.08, 6.0),  Color(0.50, 0.38, 0.26), 0.95, 0.0)
	_sbox(root, Vector3(-120, 0.02, 40), Vector3(6.0, 0.08, 120),  Color(0.50, 0.38, 0.26), 0.95, 0.0)
	_sbox(root, Vector3(0, 0.02, 110),   Vector3(6.0, 0.08, 160),  Color(0.50, 0.38, 0.26), 0.95, 0.0)

# ── City buildings ────────────────────────────────────────────────────────────
func _create_city() -> void:
	var root := _node("City")

	var palettes: Array[Color] = [
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

			var col: Color = palettes[idx % palettes.size()]
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

	# Sidewalk / perimeter positions (city border)
	var positions: Array[Vector3] = []
	for i in range(-GRID_CELLS, GRID_CELLS + 1):
		var t := i * CELL_SIZE
		positions.append_array([
			Vector3(t, 0, -CITY_HALF - 2),
			Vector3(t, 0,  CITY_HALF + 2),
			Vector3(-CITY_HALF - 2, 0, t),
			Vector3( CITY_HALF + 2, 0, t),
		])
	# Random scatter in mid zone
	for _i in 60:
		var a   := _rng.randf() * TAU
		var d   := _rng.randf_range(50.0, 130.0)
		positions.append(Vector3(cos(a) * d, 0, sin(a) * d))
	# Scatter in far zones
	for _i in 40:
		var a   := _rng.randf() * TAU
		var d   := _rng.randf_range(130.0, 300.0)
		positions.append(Vector3(cos(a) * d, 0, sin(a) * d))

	for p in positions:
		if _rng.randf() < 0.12:   # thin out a bit
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
	for i in 12:
		var a   := (i / 12.0) * TAU
		var r   := 18.0
		_make_bench(root, Vector3(cos(a) * r, 0.12, sin(a) * r), a + PI * 0.5)

	# Central city cars
	var car_pos: Array[Vector3] = [
		Vector3(-12, 0, -22), Vector3(-12, 0,  -9),
		Vector3( 12, 0,   8), Vector3( 12, 0,  22),
		Vector3(-22, 0,  12), Vector3(  6, 0, -12),
		Vector3( 22, 0,  -8), Vector3( -6, 0,  20),
		Vector3(-28, 0, -18), Vector3( 28, 0, -18),
		Vector3(-28, 0,  18), Vector3( 28, 0,  18),
		Vector3(  0, 0, -26), Vector3(  0, 0,  26),
		Vector3(-34, 0,   0), Vector3( 34, 0,   0),
	]
	var car_col: Array[Color] = [
		Color(0.80, 0.10, 0.10), Color(0.10, 0.30, 0.82),
		Color(0.88, 0.82, 0.18), Color(0.12, 0.12, 0.12),
		Color(0.82, 0.82, 0.82), Color(0.10, 0.62, 0.22),
		Color(0.70, 0.30, 0.75), Color(0.88, 0.55, 0.18),
		Color(0.22, 0.66, 0.88), Color(0.88, 0.44, 0.22),
		Color(0.44, 0.22, 0.66), Color(0.66, 0.44, 0.22),
		Color(0.20, 0.80, 0.60), Color(0.60, 0.80, 0.20),
		Color(0.80, 0.20, 0.60), Color(0.20, 0.60, 0.80),
	]
	for ci in car_pos.size():
		_make_car(root, car_pos[ci], car_col[ci])

	# Buses on main roads
	_make_bus(root, Vector3(-5, 0, 40), Color(0.96, 0.82, 0.10))
	_make_bus(root, Vector3( 5, 0,-40), Color(0.88, 0.22, 0.18))
	_make_bus(root, Vector3(50, 0, 13), Color(0.24, 0.48, 0.88))
	_make_bus(root, Vector3(-50, 0,-13), Color(0.22, 0.72, 0.32))

	# Fences around city edge
	for i in 16:
		var fx := -75.0 + i * 10.0
		_sbox(root, Vector3(fx, 0.55, -CITY_HALF - 4), Vector3(9.5, 1.1, 0.22),
			Color(0.52, 0.42, 0.28), 0.9, 0.0)
		_sbox(root, Vector3(fx, 0.55,  CITY_HALF + 4), Vector3(9.5, 1.1, 0.22),
			Color(0.52, 0.42, 0.28), 0.9, 0.0)

	# Trash bins scattered in city
	for _i in 14:
		var bx  := _rng.randf_range(-36.0, 36.0)
		var bz  := _rng.randf_range(-36.0, 36.0)
		_make_bin(root, Vector3(bx, 0, bz))

	# Major buildings on city outskirts
	_make_hospital(root, Vector3(-55, 0, -20))
	_make_school(root, Vector3(55, 0, 30))
	_make_stadium(root, Vector3(-55, 0, 55))
	_make_shopping_mall(root, Vector3(58, 0, -45))
	_make_gas_station(root, Vector3(48, 0, 15))
	_make_gas_station(root, Vector3(-48, 0, -35))


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

# ── Truck (bigger than a car) ─────────────────────────────────────────────────
func _make_truck(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Cab
	_sbox(parent, pos + Vector3(0, 1.20, 2.2), Vector3(2.4, 2.0, 2.6), color, 0.40, 0.20)
	# Cargo box
	_sbox(parent, pos + Vector3(0, 1.40, -1.8), Vector3(2.4, 2.8, 5.2), color * 0.85, 0.55, 0.10)
	# Wheels (6 wheels)
	for wx in [-1.20, 1.20]:
		for wz in [2.2, 0.0, -2.2]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.46; wm.bottom_radius = 0.46
			wm.height = 0.32; wm.radial_segments = 10
			var wmi := _plain_mesh(parent, pos + Vector3(wx, 0.46, wz), wm,
				_mat(Color(0.10, 0.10, 0.10), 1.0, 0.0))
			wmi.rotation.z = PI * 0.5
	# Headlights
	for hx in [-0.90, 0.90]:
		_sbox(parent, pos + Vector3(hx, 1.10, 3.52), Vector3(0.38, 0.20, 0.06),
			Color(1.0, 1.0, 0.82), 0.08, 0.0)

# ── Bus ───────────────────────────────────────────────────────────────────────
func _make_bus(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Main body
	_sbox(parent, pos + Vector3(0, 1.45, 0), Vector3(2.50, 2.60, 9.50), color, 0.45, 0.15)
	# Roof
	_sbox(parent, pos + Vector3(0, 2.82, 0), Vector3(2.42, 0.18, 9.30), color * 0.90, 0.50, 0.10)
	# Windows strip
	for wz_off in [-3.2, -1.6, 0.0, 1.6, 3.2]:
		_sbox(parent, pos + Vector3(1.26, 1.80, wz_off),
			Vector3(0.06, 0.80, 1.20), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
		_sbox(parent, pos + Vector3(-1.26, 1.80, wz_off),
			Vector3(0.06, 0.80, 1.20), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
	# Wheels
	for wx in [-1.24, 1.24]:
		for wz in [-3.20, 3.20]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.44; wm.bottom_radius = 0.44
			wm.height = 0.28; wm.radial_segments = 10
			var wmi := _plain_mesh(parent, pos + Vector3(wx, 0.44, wz), wm,
				_mat(Color(0.10, 0.10, 0.10), 1.0, 0.0))
			wmi.rotation.z = PI * 0.5

# ── Boat ──────────────────────────────────────────────────────────────────────
func _make_boat(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Hull
	_sbox(parent, pos + Vector3(0, 0.35, 0), Vector3(2.8, 0.70, 7.0), color, 0.45, 0.20)
	# Cabin
	_sbox(parent, pos + Vector3(0, 1.20, -0.5), Vector3(2.4, 1.0, 3.0), color * 0.80, 0.40, 0.15)
	# Mast
	var mast_m := CylinderMesh.new()
	mast_m.top_radius = 0.04; mast_m.bottom_radius = 0.06
	mast_m.height = 5.0; mast_m.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 3.5, -0.5), mast_m,
		_mat(Color(0.60, 0.48, 0.30), 0.7, 0.0))
	# Windshield
	_sbox(parent, pos + Vector3(0, 1.55, 1.0), Vector3(2.2, 0.60, 0.06),
		Color(0.58, 0.75, 0.92, 0.5), 0.05, 0.5)

# ── Train car ─────────────────────────────────────────────────────────────────
func _make_train_car(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Body
	_sbox(parent, pos + Vector3(0, 1.60, 0), Vector3(3.0, 3.0, 10.0), color, 0.50, 0.20)
	# Undercarriage
	_sbox(parent, pos + Vector3(0, 0.40, 0), Vector3(2.8, 0.50, 9.0), Color(0.22,0.22,0.24), 0.8, 0.3)
	# Windows
	for wz_off in [-3.5, -1.5, 0.5, 2.5]:
		_sbox(parent, pos + Vector3(1.52, 1.80, wz_off),
			Vector3(0.06, 0.90, 1.40), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
	# Wheels (represented as boxes on rails)
	for wz in [-3.8, 0.0, 3.8]:
		_sbox(parent, pos + Vector3(0, 0.16, wz), Vector3(3.2, 0.28, 1.2),
			Color(0.22,0.22,0.24), 0.8, 0.4)

# ── Residential house ─────────────────────────────────────────────────────────
func _make_house(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Walls
	_sbox(parent, pos + Vector3(0, 2.2, 0), Vector3(7.0, 4.4, 6.0), color, 0.75, 0.0)
	# Roof (wedge shape using two boxes)
	_sbox(parent, pos + Vector3(0, 5.0, 0), Vector3(7.4, 0.4, 6.4), color * 0.70, 0.80, 0.0)
	_sbox(parent, pos + Vector3(0, 5.5, 0), Vector3(6.6, 0.8, 5.6),
		Color(0.60, 0.20, 0.12), 0.85, 0.0, Vector3(deg_to_rad(22), 0, 0))
	# Door
	_sbox(parent, pos + Vector3(0, 1.1, 3.02), Vector3(1.0, 2.2, 0.10),
		Color(0.44, 0.28, 0.12), 0.85, 0.0)
	# Windows
	for wx in [-2.0, 2.0]:
		_sbox(parent, pos + Vector3(wx, 2.6, 3.02), Vector3(1.2, 1.0, 0.08),
			Color(0.60, 0.80, 0.95, 0.6), 0.05, 0.30)
	# Chimney
	_sbox(parent, pos + Vector3(2.5, 6.0, 0), Vector3(0.6, 1.5, 0.6),
		Color(0.50, 0.32, 0.22), 0.85, 0.0)

# ── Warehouse ─────────────────────────────────────────────────────────────────
func _make_warehouse(parent: Node3D, pos: Vector3, color: Color) -> void:
	# Main structure
	_sbox(parent, pos + Vector3(0, 5.5, 0), Vector3(16.0, 11.0, 22.0), color, 0.60, 0.15)
	# Corrugated roof
	_sbox(parent, pos + Vector3(0, 11.5, 0), Vector3(16.4, 0.5, 22.4), color * 0.75, 0.70, 0.20)
	# Big loading doors
	_sbox(parent, pos + Vector3(0, 3.5, 11.02), Vector3(6.0, 7.0, 0.20),
		Color(0.30, 0.30, 0.34), 0.60, 0.40)
	# Windows near top
	for wx in [-5.0, 0.0, 5.0]:
		_sbox(parent, pos + Vector3(wx, 9.5, 11.04), Vector3(2.5, 1.2, 0.08),
			Color(0.60, 0.80, 0.95, 0.4), 0.05, 0.30)

# ── Container stack ───────────────────────────────────────────────────────────
func _make_container_stack(parent: Node3D, pos: Vector3) -> void:
	var container_colors: Array[Color] = [
		Color(0.80, 0.15, 0.10), Color(0.10, 0.30, 0.80),
		Color(0.80, 0.65, 0.10), Color(0.12, 0.55, 0.20),
		Color(0.70, 0.35, 0.10), Color(0.55, 0.55, 0.60),
	]
	for layer in 3:
		for col_i in 2:
			var cx: float = col_i * 2.8
			var c: Color = container_colors[(layer * 2 + col_i) % container_colors.size()]
			_sbox(parent, pos + Vector3(cx, 1.45 + layer * 2.8, 0),
				Vector3(2.4, 2.6, 6.0), c, 0.60, 0.25)

# ── Park fountain ─────────────────────────────────────────────────────────────
func _make_fountain(parent: Node3D, pos: Vector3) -> void:
	# Basin outer ring
	var bm := CylinderMesh.new()
	bm.top_radius = 2.8; bm.bottom_radius = 2.8
	bm.height = 0.60; bm.radial_segments = 16
	_plain_mesh(parent, pos + Vector3(0, 0.30, 0), bm,
		_mat(Color(0.72, 0.72, 0.80), 0.40, 0.30))
	# Center pedestal
	var pm := CylinderMesh.new()
	pm.top_radius = 0.25; pm.bottom_radius = 0.40
	pm.height = 1.6; pm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.80, 0), pm,
		_mat(Color(0.75, 0.75, 0.82), 0.40, 0.25))
	# Top bowl
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12; tm.bottom_radius = 0.80
	tm.height = 0.30; tm.radial_segments = 12
	_plain_mesh(parent, pos + Vector3(0, 1.75, 0), tm,
		_mat(Color(0.75, 0.75, 0.82), 0.40, 0.25))
	# Water
	var wm := CylinderMesh.new()
	wm.top_radius = 2.5; wm.bottom_radius = 2.5
	wm.height = 0.08; wm.radial_segments = 16
	_plain_mesh(parent, pos + Vector3(0, 0.54, 0), wm,
		_mat(Color(0.20, 0.55, 0.90, 0.70), 0.05, 0.30))

# ── Traffic light ─────────────────────────────────────────────────────────────
func _make_traffic_light(parent: Node3D, pos: Vector3) -> void:
	# Pole
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06; pm.bottom_radius = 0.08
	pm.height = 5.0; pm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 2.5, 0), pm,
		_mat(Color(0.25, 0.25, 0.28), 0.40, 0.80))
	# Light box
	_sbox(parent, pos + Vector3(0, 5.5, 0), Vector3(0.40, 1.2, 0.30),
		Color(0.18, 0.18, 0.20), 0.70, 0.30)
	# Red light
	_sbox(parent, pos + Vector3(0, 5.95, 0.16), Vector3(0.22, 0.22, 0.06),
		Color(0.95, 0.10, 0.10), 0.10, 0.0)
	# Yellow light
	_sbox(parent, pos + Vector3(0, 5.50, 0.16), Vector3(0.22, 0.22, 0.06),
		Color(0.95, 0.85, 0.10), 0.10, 0.0)
	# Green light
	_sbox(parent, pos + Vector3(0, 5.05, 0.16), Vector3(0.22, 0.22, 0.06),
		Color(0.10, 0.90, 0.20), 0.10, 0.0)

# ── Fire hydrant ──────────────────────────────────────────────────────────────
func _make_hydrant(parent: Node3D, pos: Vector3) -> void:
	var bm := CylinderMesh.new()
	bm.top_radius = 0.14; bm.bottom_radius = 0.14
	bm.height = 0.62; bm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.31, 0), bm,
		_mat(Color(0.88, 0.12, 0.12), 0.40, 0.20))
	var tm := CylinderMesh.new()
	tm.top_radius = 0.16; tm.bottom_radius = 0.16
	tm.height = 0.12; tm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.66, 0), tm,
		_mat(Color(0.88, 0.12, 0.12), 0.40, 0.20))
	# Side nozzles
	for sx in [-1, 1]:
		_sbox(parent, pos + Vector3(sx * 0.20, 0.38, 0), Vector3(0.14, 0.10, 0.10),
			Color(0.88, 0.12, 0.12), 0.40, 0.20)

# ── Stop sign ─────────────────────────────────────────────────────────────────
func _make_stop_sign(parent: Node3D, pos: Vector3) -> void:
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04; pm.bottom_radius = 0.04
	pm.height = 2.4; pm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 1.2, 0), pm,
		_mat(Color(0.72, 0.72, 0.74), 0.50, 0.70))
	# Octagonal sign (approximated with 8-sided cylinder)
	var sm := CylinderMesh.new()
	sm.top_radius = 0.44; sm.bottom_radius = 0.44
	sm.height = 0.04; sm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 2.6, 0), sm,
		_mat(Color(0.90, 0.08, 0.08), 0.50, 0.0))

# ── Playground swing ──────────────────────────────────────────────────────────
func _make_swing_set(parent: Node3D, pos: Vector3) -> void:
	var metal := Color(0.50, 0.50, 0.58)
	# A-frame poles
	for sx in [-2.0, 2.0]:
		for sz in [-1.0, 1.0]:
			var pm := CylinderMesh.new()
			pm.top_radius = 0.06; pm.bottom_radius = 0.06
			pm.height = 3.5; pm.radial_segments = 6
			var mi := _plain_mesh(parent, pos + Vector3(sx, 1.75, sz), pm,
				_mat(metal, 0.40, 0.70))
			mi.rotation.z = sz * deg_to_rad(18)
	# Top bar
	_sbox(parent, pos + Vector3(0, 3.5, 0), Vector3(5.0, 0.12, 0.12), metal, 0.40, 0.70)
	# Seat chains + seat (2 swings)
	for sx in [-0.8, 0.8]:
		_sbox(parent, pos + Vector3(sx, 2.5, 0), Vector3(0.04, 2.0, 0.04), metal, 0.40, 0.70)
		_sbox(parent, pos + Vector3(sx, 1.4, 0), Vector3(0.60, 0.10, 0.32),
			Color(0.22, 0.45, 0.80), 0.70, 0.0)

# ── Slide ─────────────────────────────────────────────────────────────────────
func _make_slide(parent: Node3D, pos: Vector3) -> void:
	# Platform
	_sbox(parent, pos + Vector3(0, 2.4, -1.0), Vector3(1.8, 0.14, 1.8),
		Color(0.88, 0.58, 0.12), 0.70, 0.0)
	# Steps
	for step in 4:
		_sbox(parent, pos + Vector3(0, step * 0.62 + 0.3, 1.0 - step * 0.45),
			Vector3(1.6, 0.14, 0.4), Color(0.55, 0.55, 0.60), 0.60, 0.30)
	# The slide surface
	_sbox(parent, pos + Vector3(0, 1.5, 2.0), Vector3(1.6, 0.10, 3.0),
		Color(0.88, 0.20, 0.20), 0.20, 0.10, Vector3(deg_to_rad(-40), 0, 0))

# ── Explosive barrel ──────────────────────────────────────────────────────────
func _make_explosive_barrel(parent: Node3D, pos: Vector3) -> void:
	var bm := CylinderMesh.new()
	bm.top_radius = 0.28; bm.bottom_radius = 0.28
	bm.height = 0.72; bm.radial_segments = 10
	_plain_mesh(parent, pos + Vector3(0, 0.36, 0), bm,
		_mat(Color(0.85, 0.12, 0.08), 0.55, 0.15))
	# Bands
	for by in [0.18, 0.54]:
		var bnm := CylinderMesh.new()
		bnm.top_radius = 0.30; bnm.bottom_radius = 0.30
		bnm.height = 0.07; bnm.radial_segments = 10
		_plain_mesh(parent, pos + Vector3(0, by, 0), bnm,
			_mat(Color(0.30, 0.30, 0.34), 0.60, 0.50))
	# Skull warning
	_sbox(parent, pos + Vector3(0, 0.42, 0.29), Vector3(0.20, 0.20, 0.04),
		Color(1.0, 1.0, 0.10), 0.50, 0.0)

# ── Trampoline ────────────────────────────────────────────────────────────────
func _make_trampoline(parent: Node3D, pos: Vector3) -> void:
	# Frame ring
	var fm := CylinderMesh.new()
	fm.top_radius = 2.2; fm.bottom_radius = 2.2
	fm.height = 0.16; fm.radial_segments = 20
	_plain_mesh(parent, pos + Vector3(0, 0.80, 0), fm,
		_mat(Color(0.80, 0.80, 0.85), 0.40, 0.60))
	# Bounce surface
	var sm := CylinderMesh.new()
	sm.top_radius = 2.0; sm.bottom_radius = 2.0
	sm.height = 0.06; sm.radial_segments = 20
	_plain_mesh(parent, pos + Vector3(0, 0.80, 0), sm,
		_mat(Color(0.12, 0.48, 0.88), 0.50, 0.0))
	# Legs (4 legs)
	for lx in [-1.5, 1.5]:
		for lz in [-1.5, 1.5]:
			var lm := CylinderMesh.new()
			lm.top_radius = 0.06; lm.bottom_radius = 0.06
			lm.height = 0.80; lm.radial_segments = 6
			_plain_mesh(parent, pos + Vector3(lx, 0.40, lz), lm,
				_mat(Color(0.80, 0.80, 0.85), 0.40, 0.60))
	# Collision body
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var ss := CylinderShape3D.new()
	ss.radius = 2.0; ss.height = 0.16
	cs.shape = ss
	cs.position = Vector3(0, 0.80, 0)
	sb.add_child(cs)
	# Custom metadata to mark as trampoline
	sb.set_meta("is_trampoline", true)
	parent.add_child(sb)

# ── Golden collectible statue ─────────────────────────────────────────────────
func _make_golden_statue(parent: Node3D, pos: Vector3) -> void:
	# Base
	_sbox(parent, pos + Vector3(0, 0.15, 0), Vector3(0.6, 0.30, 0.6),
		Color(0.90, 0.72, 0.10), 0.10, 0.85)
	# Body
	var bm := CylinderMesh.new()
	bm.top_radius = 0.14; bm.bottom_radius = 0.18
	bm.height = 0.60; bm.radial_segments = 8
	_plain_mesh(parent, pos + Vector3(0, 0.60, 0), bm,
		_mat(Color(0.95, 0.78, 0.15), 0.08, 0.95))
	# Head (sphere)
	var hm := SphereMesh.new()
	hm.radius = 0.16; hm.height = 0.32
	hm.radial_segments = 8; hm.rings = 6
	_plain_mesh(parent, pos + Vector3(0, 1.06, 0), hm,
		_mat(Color(0.95, 0.78, 0.15), 0.08, 0.95))
	# Horns
	for sx in [-1, 1]:
		var hom := CylinderMesh.new()
		hom.top_radius = 0.02; hom.bottom_radius = 0.05
		hom.height = 0.22; hom.radial_segments = 6
		_plain_mesh(parent, pos + Vector3(sx * 0.08, 1.28, 0), hom,
			_mat(Color(0.95, 0.78, 0.15), 0.08, 0.95))
	# Add an Area3D so player can detect collection
	var area := Area3D.new()
	area.name = "CollectArea"
	area.set_meta("is_collectible", true)
	var ac := CollisionShape3D.new()
	var as2 := SphereShape3D.new(); as2.radius = 1.2
	ac.shape = as2
	area.add_child(ac)
	area.position = pos + Vector3(0, 0.6, 0)
	parent.add_child(area)

# ── Pier/dock ─────────────────────────────────────────────────────────────────
func _make_pier(parent: Node3D, pos: Vector3, length: float) -> void:
	# Deck planks
	_sbox(parent, pos + Vector3(length * 0.5, 0.1, 0),
		Vector3(length, 0.25, 5.0), Color(0.52, 0.38, 0.20), 0.85, 0.0)
	# Railing sides
	_sbox(parent, pos + Vector3(length * 0.5, 0.60, 2.6),
		Vector3(length, 0.12, 0.10), Color(0.52, 0.38, 0.20), 0.85, 0.0)
	_sbox(parent, pos + Vector3(length * 0.5, 0.60, -2.6),
		Vector3(length, 0.12, 0.10), Color(0.52, 0.38, 0.20), 0.85, 0.0)
	# Support pillars
	for pil in range(0, int(length), 6):
		for ps in [-2.2, 2.2]:
			var pm := CylinderMesh.new()
			pm.top_radius = 0.18; pm.bottom_radius = 0.18
			pm.height = 2.2; pm.radial_segments = 6
			_plain_mesh(parent, pos + Vector3(pil, -0.9, ps), pm,
				_mat(Color(0.36, 0.26, 0.14), 0.85, 0.0))

# ── Lifeguard tower ───────────────────────────────────────────────────────────
func _make_lifeguard_tower(parent: Node3D, pos: Vector3) -> void:
	# Legs
	for lx in [-0.8, 0.8]:
		for lz in [-0.5, 0.5]:
			var lm := CylinderMesh.new()
			lm.top_radius = 0.07; lm.bottom_radius = 0.07
			lm.height = 2.8; lm.radial_segments = 6
			_plain_mesh(parent, pos + Vector3(lx, 1.4, lz), lm,
				_mat(Color(0.68, 0.50, 0.30), 0.80, 0.0))
	# Floor
	_sbox(parent, pos + Vector3(0, 2.9, 0), Vector3(2.0, 0.14, 1.4),
		Color(0.68, 0.50, 0.30), 0.80, 0.0)
	# Walls
	_sbox(parent, pos + Vector3(0, 3.5, 0), Vector3(2.0, 1.2, 1.4),
		Color(0.96, 0.96, 0.96), 0.70, 0.0)
	# Roof
	_sbox(parent, pos + Vector3(0, 4.25, 0), Vector3(2.2, 0.20, 1.6),
		Color(0.88, 0.20, 0.12), 0.80, 0.0)

# ── Church/cathedral ─────────────────────────────────────────────────────────
func _make_church(parent: Node3D, pos: Vector3) -> void:
	# Nave
	_sbox(parent, pos + Vector3(0, 5.0, 0), Vector3(8.0, 10.0, 18.0),
		Color(0.88, 0.86, 0.80), 0.75, 0.0)
	# Bell tower
	_sbox(parent, pos + Vector3(0, 14.0, -7.5), Vector3(4.0, 18.0, 4.0),
		Color(0.88, 0.86, 0.80), 0.75, 0.0)
	# Spire
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05; sm.bottom_radius = 1.8
	sm.height = 6.0; sm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(0, 26.0, -7.5), sm,
		_mat(Color(0.40, 0.40, 0.50), 0.50, 0.30))
	# Arched windows (boxes representing arched windows)
	for wz in [-5.0, 0.0, 5.0]:
		_sbox(parent, pos + Vector3(4.02, 5.5, wz), Vector3(0.08, 3.0, 1.8),
			Color(0.50, 0.65, 0.85, 0.5), 0.05, 0.30)
	# Cross on top
	_sbox(parent, pos + Vector3(0, 24.0, -7.5), Vector3(0.30, 2.5, 0.15),
		Color(0.80, 0.72, 0.20), 0.20, 0.80)
	_sbox(parent, pos + Vector3(0, 25.5, -7.5), Vector3(1.4, 0.30, 0.15),
		Color(0.80, 0.72, 0.20), 0.20, 0.80)

# ── Hospital ──────────────────────────────────────────────────────────────────
func _make_hospital(parent: Node3D, pos: Vector3) -> void:
	# Main building
	_sbox(parent, pos + Vector3(0, 7.5, 0), Vector3(22.0, 15.0, 16.0),
		Color(0.94, 0.94, 0.94), 0.60, 0.10)
	# Wing left
	_sbox(parent, pos + Vector3(-14.0, 5.5, 3.0), Vector3(6.0, 11.0, 10.0),
		Color(0.94, 0.94, 0.94), 0.60, 0.10)
	# Wing right
	_sbox(parent, pos + Vector3(14.0, 5.5, 3.0), Vector3(6.0, 11.0, 10.0),
		Color(0.94, 0.94, 0.94), 0.60, 0.10)
	# Red cross on front face
	_sbox(parent, pos + Vector3(0, 9.0, 8.02), Vector3(0.60, 3.5, 0.10),
		Color(0.90, 0.10, 0.10), 0.50, 0.0)
	_sbox(parent, pos + Vector3(0, 10.0, 8.02), Vector3(2.8, 0.60, 0.10),
		Color(0.90, 0.10, 0.10), 0.50, 0.0)
	# Window strips
	for floor_y in [3.5, 7.5, 11.5]:
		for wx in [-7.0, -3.5, 0.0, 3.5, 7.0]:
			_sbox(parent, pos + Vector3(wx, floor_y, 8.02),
				Vector3(2.0, 2.0, 0.08), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)

# ── School ────────────────────────────────────────────────────────────────────
func _make_school(parent: Node3D, pos: Vector3) -> void:
	# Main block
	_sbox(parent, pos + Vector3(0, 4.5, 0), Vector3(24.0, 9.0, 12.0),
		Color(0.82, 0.74, 0.50), 0.70, 0.0)
	# Roof
	_sbox(parent, pos + Vector3(0, 9.2, 0), Vector3(24.4, 0.40, 12.4),
		Color(0.45, 0.45, 0.48), 0.80, 0.20)
	# Entrance steps
	for step in 3:
		_sbox(parent, pos + Vector3(0, step * 0.22, 6.0 + step * 0.30),
			Vector3(5.0, 0.22, 0.60), Color(0.60, 0.60, 0.62), 0.85, 0.0)
	# Windows row
	for wx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		for wy in [2.5, 6.0]:
			_sbox(parent, pos + Vector3(wx, wy, 6.02),
				Vector3(2.5, 1.8, 0.08), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
	# Flagpole
	var fm := CylinderMesh.new()
	fm.top_radius = 0.04; fm.bottom_radius = 0.05
	fm.height = 8.0; fm.radial_segments = 6
	_plain_mesh(parent, pos + Vector3(10.0, 4.0, 6.5), fm,
		_mat(Color(0.80, 0.80, 0.85), 0.30, 0.75))
	# Flag
	_sbox(parent, pos + Vector3(11.2, 8.2, 6.5), Vector3(2.4, 1.2, 0.04),
		Color(0.80, 0.10, 0.10), 0.70, 0.0)

# ── Gas station ───────────────────────────────────────────────────────────────
func _make_gas_station(parent: Node3D, pos: Vector3) -> void:
	# Canopy over pumps
	_sbox(parent, pos + Vector3(0, 3.5, 2.0), Vector3(12.0, 0.40, 8.0),
		Color(0.88, 0.88, 0.90), 0.60, 0.20)
	# Canopy supports
	for sx in [-4.5, 4.5]:
		_sbox(parent, pos + Vector3(sx, 1.75, 2.0), Vector3(0.30, 3.5, 0.30),
			Color(0.50, 0.50, 0.55), 0.50, 0.40)
	# Shop building
	_sbox(parent, pos + Vector3(0, 2.5, -5.0), Vector3(10.0, 5.0, 6.0),
		Color(0.94, 0.92, 0.86), 0.65, 0.0)
	# Pumps
	for px in [-3.0, 3.0]:
		_sbox(parent, pos + Vector3(px, 0.80, 2.0), Vector3(0.50, 1.6, 0.35),
			Color(0.88, 0.10, 0.10), 0.40, 0.20)
		_sbox(parent, pos + Vector3(px, 1.60, 2.18), Vector3(0.42, 0.60, 0.08),
			Color(0.20, 0.20, 0.24), 0.30, 0.30)
	# Price sign
	_sbox(parent, pos + Vector3(5.5, 3.0, -1.0), Vector3(0.10, 3.0, 2.0),
		Color(0.20, 0.20, 0.24), 0.50, 0.30)
	_sbox(parent, pos + Vector3(5.6, 4.0, -1.0), Vector3(2.8, 1.5, 0.10),
		Color(0.88, 0.88, 0.10), 0.50, 0.0)

# ── Stadium ───────────────────────────────────────────────────────────────────
func _make_stadium(parent: Node3D, pos: Vector3) -> void:
	# Oval wall
	for seg in 16:
		var ang: float = seg * TAU / 16.0
		var rx: float = cos(ang) * 28.0
		var rz: float = sin(ang) * 20.0
		_sbox(parent, pos + Vector3(rx, 6.0, rz), Vector3(4.0, 12.0, 4.0),
			Color(0.72, 0.72, 0.78), 0.60, 0.15)
	# Roof ring
	for seg in 16:
		var ang: float = seg * TAU / 16.0
		var rx: float = cos(ang) * 28.0
		var rz: float = sin(ang) * 20.0
		_sbox(parent, pos + Vector3(rx, 12.5, rz), Vector3(4.5, 0.40, 4.5),
			Color(0.40, 0.40, 0.46), 0.70, 0.25)
	# Playing field (green)
	_sbox(parent, pos + Vector3(0, 0.05, 0), Vector3(44.0, 0.10, 32.0),
		Color(0.18, 0.56, 0.20), 0.90, 0.0)
	# Score board
	_sbox(parent, pos + Vector3(0, 10.0, 22.0), Vector3(14.0, 6.0, 0.30),
		Color(0.12, 0.12, 0.14), 0.70, 0.20)

# ── Shopping mall ─────────────────────────────────────────────────────────────
func _make_shopping_mall(parent: Node3D, pos: Vector3) -> void:
	# Main body
	_sbox(parent, pos + Vector3(0, 5.0, 0), Vector3(30.0, 10.0, 20.0),
		Color(0.86, 0.84, 0.80), 0.60, 0.10)
	# Glass atrium center
	_sbox(parent, pos + Vector3(0, 8.0, 0), Vector3(8.0, 10.0, 20.0),
		Color(0.62, 0.80, 0.95, 0.4), 0.05, 0.40)
	# Entrance awnings
	for ex in [-8.0, 0.0, 8.0]:
		_sbox(parent, pos + Vector3(ex, 4.5, 10.2), Vector3(5.0, 0.40, 2.0),
			Color(0.22, 0.42, 0.78), 0.50, 0.10)
	# Signs
	for sx in range(-10, 11, 6):
		var sign_m := StandardMaterial3D.new()
		sign_m.albedo_color = Color(_rng.randf(), _rng.randf_range(0.3, 1.0), _rng.randf_range(0.3, 1.0))
		sign_m.emission_enabled = true
		sign_m.emission = sign_m.albedo_color * 0.6
		var mi := MeshInstance3D.new()
		var bm2 := BoxMesh.new(); bm2.size = Vector3(4.0, 1.2, 0.10)
		mi.mesh = bm2
		mi.position = pos + Vector3(sx, 8.5, 10.15)
		mi.material_override = sign_m
		parent.add_child(mi)

# ── Construction crane ────────────────────────────────────────────────────────
func _make_crane(parent: Node3D, pos: Vector3) -> void:
	# Vertical tower
	_sbox(parent, pos + Vector3(0, 12.0, 0), Vector3(1.2, 24.0, 1.2),
		Color(0.88, 0.65, 0.08), 0.50, 0.30)
	# Horizontal jib
	_sbox(parent, pos + Vector3(6.0, 24.5, 0), Vector3(14.0, 0.80, 0.80),
		Color(0.88, 0.65, 0.08), 0.50, 0.30)
	# Counter-jib
	_sbox(parent, pos + Vector3(-3.5, 24.5, 0), Vector3(5.0, 0.80, 0.80),
		Color(0.88, 0.65, 0.08), 0.50, 0.30)
	# Hook line
	_sbox(parent, pos + Vector3(10.0, 19.5, 0), Vector3(0.10, 10.0, 0.10),
		Color(0.50, 0.50, 0.54), 0.50, 0.60)
	# Concrete base
	_sbox(parent, pos + Vector3(0, 0.75, 0), Vector3(4.0, 1.5, 4.0),
		Color(0.50, 0.50, 0.52), 0.90, 0.0)

# ── Residential district ──────────────────────────────────────────────────────
func _create_residential_district() -> void:
	var root := _node("Residential")
	var c    := RESIDENTIAL_CENTER
	# Ground pad
	_sbox(root, c + Vector3(0, -0.05, 0), Vector3(120, 0.40, 120),
		Color(0.54, 0.54, 0.50), 0.90, 0.0)
	# Roads
	for rz in [-30.0, 0.0, 30.0]:
		_sbox(root, c + Vector3(0, 0.02, rz), Vector3(120, 0.10, 7.0),
			Color(0.18, 0.18, 0.20), 0.90, 0.0)
	for rx in [-30.0, 0.0, 30.0]:
		_sbox(root, c + Vector3(rx, 0.02, 0), Vector3(7.0, 0.10, 120),
			Color(0.18, 0.18, 0.20), 0.90, 0.0)
	# Houses on a grid
	var house_colors: Array[Color] = [
		Color(0.88, 0.76, 0.60), Color(0.70, 0.82, 0.68),
		Color(0.68, 0.72, 0.86), Color(0.90, 0.70, 0.62),
		Color(0.84, 0.84, 0.78), Color(0.72, 0.62, 0.80),
		Color(0.78, 0.86, 0.72), Color(0.90, 0.82, 0.60),
	]
	var h_idx := 0
	for gx in [-2, -1, 1, 2]:
		for gz in [-2, -1, 1, 2]:
			var hpos := c + Vector3(gx * 28.0, 0, gz * 28.0)
			_make_house(root, hpos, house_colors[h_idx % house_colors.size()])
			h_idx += 1
	# Parked cars in residential area
	for pi in 10:
		var px := c.x + _rng.randf_range(-50, 50)
		var pz := c.z + _rng.randf_range(-50, 50)
		var pc := Color(_rng.randf_range(0.4, 1.0), _rng.randf_range(0.2, 0.8),
			_rng.randf_range(0.2, 0.8))
		_make_car(root, Vector3(px, 0, pz), pc)
	# Mailboxes + hydrants
	for mi2 in 8:
		var a := mi2 * TAU / 8.0
		_make_hydrant(root, c + Vector3(cos(a) * 45, 0, sin(a) * 45))
	# Church
	_make_church(root, c + Vector3(-45, 0, -50))

# ── Industrial district ───────────────────────────────────────────────────────
func _create_industrial_district() -> void:
	var root := _node("Industrial")
	var c    := INDUSTRIAL_CENTER
	# Ground (darker concrete)
	_sbox(root, c + Vector3(0, -0.05, 0), Vector3(140, 0.40, 120),
		Color(0.42, 0.42, 0.40), 0.90, 0.0)
	# Wide roads
	_sbox(root, c + Vector3(0, 0.02, 0), Vector3(140, 0.10, 9.0),
		Color(0.16, 0.16, 0.18), 0.90, 0.0)
	_sbox(root, c + Vector3(0, 0.02, 0), Vector3(9.0, 0.10, 120),
		Color(0.16, 0.16, 0.18), 0.90, 0.0)
	# Warehouses
	var wh_positions: Array[Vector3] = [
		Vector3(-40, 0, -35), Vector3(20, 0, -35),
		Vector3(-40, 0,  30), Vector3(20, 0,  30),
	]
	var wh_colors: Array[Color] = [
		Color(0.54, 0.52, 0.50), Color(0.44, 0.50, 0.52),
		Color(0.52, 0.48, 0.44), Color(0.50, 0.54, 0.48),
	]
	for wi in wh_positions.size():
		_make_warehouse(root, c + wh_positions[wi], wh_colors[wi])
	# Container stacks
	for ci2 in 6:
		var cx2: float = -50.0 + ci2 * 16.0
		_make_container_stack(root, c + Vector3(cx2, 0, -55))
	# Trucks
	for ti in 6:
		var tx: float = -45.0 + ti * 18.0
		var tc := Color(_rng.randf_range(0.3, 0.8), _rng.randf_range(0.3, 0.7), 0.15)
		_make_truck(root, c + Vector3(tx, 0, 5), tc)
	# Cranes (construction site)
	_make_crane(root, c + Vector3(55, 0, -20))
	_make_crane(root, c + Vector3(60, 0,  20))
	# Safety barricades
	for bi in 8:
		_sbox(root, c + Vector3(-65 + bi * 18, 0.40, -58), Vector3(1.0, 0.80, 0.20),
			Color(0.90, 0.60, 0.10), 0.70, 0.0)
	# Explosive barrels (industrial area)
	for br in 12:
		var bpos := c + Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-50, 50))
		_make_explosive_barrel(root, bpos)

# ── Park district ─────────────────────────────────────────────────────────────
func _create_park_district() -> void:
	var root := _node("Park")
	var c    := PARK_CENTER
	# Green ground
	_sbox(root, c + Vector3(0, -0.05, 0), Vector3(120, 0.20, 120),
		Color(0.20, 0.56, 0.16), 0.95, 0.0)
	# Paths
	for i in 8:
		var a := i * TAU / 8.0
		_sbox(root, c + Vector3(cos(a) * 30, 0.02, sin(a) * 30),
			Vector3(2.5, 0.06, 28.0), Color(0.55, 0.48, 0.36), 0.90, 0.0,
			Vector3(0, a, 0))
	# Fountains
	_make_fountain(root, c + Vector3(0, 0, 0))
	_make_fountain(root, c + Vector3(-35, 0, -35))
	_make_fountain(root, c + Vector3(35, 0, 35))
	# Benches scattered around park
	for i in 16:
		var a := (i / 16.0) * TAU
		var r := 22.0 + _rng.randf_range(-4, 4)
		_make_bench(root, c + Vector3(cos(a) * r, 0.12, sin(a) * r), a + PI * 0.5)
	# Playground equipment
	_make_swing_set(root, c + Vector3(20, 0, -20))
	_make_slide(root, c + Vector3(-20, 0, 20))
	_make_swing_set(root, c + Vector3(-20, 0, -30))
	# Trampolines in park
	_make_trampoline(root, c + Vector3(30, 0, -10))
	_make_trampoline(root, c + Vector3(-30, 0, 10))
	# Trees in park (many)
	for _i in 40:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(10.0, 52.0)
		_make_tree(root, c + Vector3(cos(a) * d, 0, sin(a) * d))
	# Lamps along paths
	for i in 12:
		var a := (i / 12.0) * TAU
		_make_lamp(root, c + Vector3(cos(a) * 18, 0, sin(a) * 18))

# ── Harbor district ───────────────────────────────────────────────────────────
func _create_harbor_district() -> void:
	var root := _node("Harbor")
	var c    := HARBOR_CENTER
	# Dock concrete
	_sbox(root, c + Vector3(0, -0.05, 0), Vector3(100, 0.40, 60),
		Color(0.48, 0.46, 0.42), 0.90, 0.0)
	# Harbor water
	var hwm := PlaneMesh.new()
	hwm.size = Vector2(200, 200)
	hwm.subdivide_width = 32; hwm.subdivide_depth = 32
	var hw_mat := ShaderMaterial.new()
	var hw_shader := load("res://shaders/water.gdshader") as Shader
	if hw_shader:
		hw_mat.shader = hw_shader
		_plain_mesh(root, c + Vector3(80, -0.80, 0), hwm, StandardMaterial3D.new())
		# Re-apply shader mat
		var hw_mi := root.get_children().back() as MeshInstance3D
		if hw_mi:
			hw_mi.material_override = hw_mat
	else:
		var fw := StandardMaterial3D.new()
		fw.albedo_color = Color(0.10, 0.36, 0.68, 0.72)
		fw.roughness = 0.04; fw.metallic = 0.25
		fw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_plain_mesh(root, c + Vector3(80, -0.80, 0), hwm, fw)
	# Main pier
	_make_pier(root, c + Vector3(-10, 0.0, -15), 60.0)
	_make_pier(root, c + Vector3(-10, 0.0,  15), 60.0)
	# Boats moored at pier
	var boat_colors2: Array[Color] = [
		Color(0.92, 0.92, 0.88), Color(0.18, 0.38, 0.68),
		Color(0.80, 0.25, 0.15), Color(0.22, 0.48, 0.28),
	]
	for bi2 in 4:
		_make_boat(root, c + Vector3(bi2 * 18.0, 0, -22), boat_colors2[bi2])
		_make_boat(root, c + Vector3(bi2 * 18.0, 0,  22), boat_colors2[(bi2 + 2) % 4])
	# Container stacks on dock
	for csi in 4:
		_make_container_stack(root, c + Vector3(-40 + csi * 18, 0, -25))
	# Lifeguard tower
	_make_lifeguard_tower(root, c + Vector3(-45, 0, 20))
	# Cranes
	_make_crane(root, c + Vector3(30, 0, -20))
	# Warehouse
	_make_warehouse(root, c + Vector3(-30, 0, -15), Color(0.48, 0.50, 0.54))
	# Trucks on dock
	for ti2 in 3:
		_make_truck(root, c + Vector3(-40 + ti2 * 16, 0, 10),
			Color(_rng.randf_range(0.3, 0.7), _rng.randf_range(0.3, 0.7), 0.2))

# ── Mountain area ─────────────────────────────────────────────────────────────
func _create_mountain_area() -> void:
	var root := _node("Mountain")
	var c    := MOUNTAIN_CENTER
	# Main mountain peaks
	var peak_offsets: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(30, 0, 20), Vector3(-25, 0, 30),
		Vector3(20, 0, -30), Vector3(-15, 0, -20),
	]
	var peak_heights: Array[float] = [80.0, 55.0, 48.0, 62.0, 44.0]
	var peak_radii:   Array[float] = [60.0, 42.0, 36.0, 48.0, 32.0]
	for pi2 in peak_heights.size():
		var ph: float = peak_heights[pi2]
		var pr: float = peak_radii[pi2]
		var sm2 := CylinderMesh.new()
		sm2.top_radius = 1.5; sm2.bottom_radius = pr
		sm2.height = ph; sm2.radial_segments = 12
		var mi := _plain_mesh(root, c + peak_offsets[pi2] + Vector3(0, ph * 0.5, 0), sm2,
			_mat(Color(0.58, 0.55, 0.52), 0.90, 0.0))
		_add_static_sphere(mi, pr * 0.85)
		# Snow cap
		var snow_m := CylinderMesh.new()
		snow_m.top_radius = 0.5; snow_m.bottom_radius = pr * 0.25
		snow_m.height = ph * 0.25; snow_m.radial_segments = 12
		_plain_mesh(root, c + peak_offsets[pi2] + Vector3(0, ph * 0.92, 0), snow_m,
			_mat(Color(0.96, 0.96, 0.98), 0.80, 0.0))
	# Rocky cliffs (steep boxes)
	for cl in 8:
		var ang: float = cl * TAU / 8.0 + 0.2
		_sbox(root, c + Vector3(cos(ang) * 55, 15.0, sin(ang) * 55),
			Vector3(8.0, 30.0, 8.0), Color(0.50, 0.46, 0.42), 0.90, 0.0,
			Vector3(_rng.randf_range(-0.2, 0.2), ang, _rng.randf_range(-0.1, 0.1)))
	# Pine trees on mountain slopes
	for _ti in 50:
		var ta := _rng.randf() * TAU
		var td := _rng.randf_range(20, 75)
		var tpos := c + Vector3(cos(ta) * td, 0, sin(ta) * td)
		_make_tree(root, tpos)

# ── Highway / freeway ─────────────────────────────────────────────────────────
func _create_highway() -> void:
	var root     := _node("Highway")
	var asphalt  := Color(0.16, 0.16, 0.18)
	var yellow   := Color(0.95, 0.88, 0.15)
	# East-West highway through the map
	_sbox(root, Vector3(0, 0.05, -140), Vector3(800, 0.20, 12.0), asphalt, 0.90, 0.0)
	# Divider strips
	for d in range(-52, 53, 8):
		_sbox(root, Vector3(d * 4, 0.15, -140), Vector3(5.0, 0.10, 0.30), yellow, 0.90, 0.0)
	# North-South highway
	_sbox(root, Vector3(-140, 0.05, 0), Vector3(12.0, 0.20, 800), asphalt, 0.90, 0.0)
	for d in range(-52, 53, 8):
		_sbox(root, Vector3(-140, 0.15, d * 4), Vector3(0.30, 0.10, 5.0), yellow, 0.90, 0.0)
	# Highway on-ramps
	_sbox(root, Vector3(-50, 0.02, -110), Vector3(7.0, 0.14, 60),
		asphalt, 0.90, 0.0, Vector3(deg_to_rad(2), 0, 0))
	_sbox(root, Vector3(50, 0.02, -110), Vector3(7.0, 0.14, 60),
		asphalt, 0.90, 0.0, Vector3(deg_to_rad(-2), 0, 0))
	# Highway guard rails
	for gri in range(-100, 101, 10):
		_sbox(root, Vector3(gri, 0.30, -146.5), Vector3(9.5, 0.60, 0.20),
			Color(0.70, 0.70, 0.75), 0.50, 0.50)
		_sbox(root, Vector3(gri, 0.30, -133.5), Vector3(9.5, 0.60, 0.20),
			Color(0.70, 0.70, 0.75), 0.50, 0.50)
	# Train tracks (along the highway)
	_sbox(root, Vector3(0, 0.06, -165), Vector3(800, 0.12, 1.6),
		Color(0.48, 0.38, 0.28), 0.85, 0.0)
	# Rail ties
	for rti in range(-100, 101, 3):
		_sbox(root, Vector3(rti * 4, 0.06, -165), Vector3(1.2, 0.12, 4.0),
			Color(0.30, 0.22, 0.14), 0.90, 0.0)
	# Train cars
	var train_colors2: Array[Color] = [
		Color(0.14, 0.34, 0.62), Color(0.62, 0.14, 0.14),
		Color(0.14, 0.14, 0.14), Color(0.14, 0.52, 0.28),
	]
	for tci in 5:
		_make_train_car(root, Vector3(-80 + tci * 12, 0.5, -165), train_colors2[tci % 4])

# ── Traffic lights ────────────────────────────────────────────────────────────
func _create_traffic_lights() -> void:
	var root := _node("TrafficLights")
	# At every road intersection in the city
	var intersections: Array[Vector3] = [
		Vector3(-CELL_SIZE, 0, -CELL_SIZE), Vector3(CELL_SIZE, 0, -CELL_SIZE),
		Vector3(-CELL_SIZE, 0,  CELL_SIZE), Vector3(CELL_SIZE, 0,  CELL_SIZE),
	]
	for ip in intersections:
		for corner in [Vector3(4, 0, 4), Vector3(-4, 0, 4), Vector3(4, 0, -4), Vector3(-4, 0, -4)]:
			_make_traffic_light(root, ip + corner)
	# Stop signs on smaller streets
	for ss_z in [-28.0, 0.0, 28.0]:
		for ss_x in [-28.0, 28.0]:
			_make_stop_sign(root, Vector3(ss_x, 0, ss_z))
	# Fire hydrants along city blocks
	for fh_z in [-20, -7, 7, 20]:
		for fh_x in [-30, -17, 17, 30]:
			_make_hydrant(root, Vector3(fh_x, 0, fh_z))

# ── Collectible golden statues ────────────────────────────────────────────────
func _create_collectibles() -> void:
	var root := _node("Collectibles")
	var statue_positions: Array[Vector3] = [
		# City area
		Vector3(15, 1.5, 15), Vector3(-20, 1.5, -18), Vector3(28, 1.5, -10),
		# Residential
		RESIDENTIAL_CENTER + Vector3(0, 1.5, 0),
		RESIDENTIAL_CENTER + Vector3(30, 1.5, -20),
		# Park
		PARK_CENTER + Vector3(15, 1.5, 15),
		PARK_CENTER + Vector3(-25, 1.5, -10),
		# Harbor
		HARBOR_CENTER + Vector3(-20, 1.5, 0),
		HARBOR_CENTER + Vector3(20, 1.5, 20),
		# Industrial
		INDUSTRIAL_CENTER + Vector3(0, 1.5, -40),
		INDUSTRIAL_CENTER + Vector3(40, 1.5, 30),
		# Mountain
		MOUNTAIN_CENTER + Vector3(20, 5, 20),
		# Highway area
		Vector3(-140, 1.5, -50),
		Vector3(100, 1.5, -140),
		# Scattered across map
		Vector3(-100, 1.5, -200), Vector3(200, 1.5, 100),
		Vector3(-220, 1.5, 150), Vector3(150, 1.5, -280),
		Vector3(-300, 1.5, -100), Vector3(280, 1.5, 200),
	]
	for sp in statue_positions:
		_make_golden_statue(root, sp)

# ── Explosive barrels ─────────────────────────────────────────────────────────
func _create_explosive_barrels() -> void:
	var root := _node("ExplosiveBarrels")
	# City area barrels
	var barrel_spots: Array[Vector3] = [
		Vector3(28, 0, 8), Vector3(-25, 0, -15), Vector3(18, 0, -22),
		Vector3(-8, 0, 28), Vector3(32, 0, -28), Vector3(-30, 0, 20),
		Vector3(10, 0, 30), Vector3(-18, 0, -28),
	]
	for bp in barrel_spots:
		_make_explosive_barrel(root, bp)
	# Beach/harbor barrels
	_make_explosive_barrel(root, Vector3(82, 0.25, -8))
	_make_explosive_barrel(root, Vector3(78, 0.25, 10))
	_make_explosive_barrel(root, HARBOR_CENTER + Vector3(-35, 0, 5))
	_make_explosive_barrel(root, HARBOR_CENTER + Vector3(-35, 0, -5))

# ── Trampolines ───────────────────────────────────────────────────────────────
func _create_trampolines() -> void:
	var root := _node("Trampolines")
	# Scattered trampolines
	_make_trampoline(root, Vector3(18, 0, 5))
	_make_trampoline(root, Vector3(-15, 0, -18))
	_make_trampoline(root, Vector3(72, 0, 5))
	_make_trampoline(root, PARK_CENTER + Vector3(40, 0, -5))
	_make_trampoline(root, RESIDENTIAL_CENTER + Vector3(-15, 0, 25))

# ── NPC spawning (35+ NPCs) ───────────────────────────────────────────────────
func _spawn_npcs() -> void:
	var npc_scene := preload("res://scenes/npc.tscn")
	var colors: Array[Color] = [
		Color(0.85, 0.28, 0.28), Color(0.28, 0.40, 0.88),
		Color(0.28, 0.75, 0.36), Color(0.88, 0.76, 0.18),
		Color(0.72, 0.28, 0.78), Color(0.88, 0.54, 0.18),
		Color(0.28, 0.76, 0.76), Color(0.88, 0.88, 0.88),
		Color(0.90, 0.40, 0.60), Color(0.40, 0.88, 0.60),
		Color(0.60, 0.40, 0.90), Color(0.88, 0.60, 0.28),
	]
	var spots: Array[Vector3] = [
		# City centre
		Vector3( 5, 1.5,  5), Vector3(-9,  1.5, 13),
		Vector3(16, 1.5, -5), Vector3(-13, 1.5, -9),
		Vector3(21, 1.5, 10), Vector3(-5,  1.5, 19),
		Vector3(10, 1.5,-16), Vector3(-19, 1.5,  5),
		# Residential
		RESIDENTIAL_CENTER + Vector3(10,  1.5,  5),
		RESIDENTIAL_CENTER + Vector3(-15, 1.5, 12),
		RESIDENTIAL_CENTER + Vector3( 20, 1.5,-10),
		RESIDENTIAL_CENTER + Vector3(-8,  1.5,-18),
		RESIDENTIAL_CENTER + Vector3( 30, 1.5, 20),
		# Park joggers
		PARK_CENTER + Vector3(12, 1.5, -8),
		PARK_CENTER + Vector3(-18, 1.5, 15),
		PARK_CENTER + Vector3(25, 1.5, 25),
		PARK_CENTER + Vector3(-30, 1.5,-20),
		PARK_CENTER + Vector3( 8,  1.5,-28),
		# Harbor workers
		HARBOR_CENTER + Vector3(-20, 1.5, -5),
		HARBOR_CENTER + Vector3(-30, 1.5, 10),
		HARBOR_CENTER + Vector3(-10, 1.5, -12),
		HARBOR_CENTER + Vector3(-5,  1.5, 18),
		# Industrial workers
		INDUSTRIAL_CENTER + Vector3(10, 1.5,-15),
		INDUSTRIAL_CENTER + Vector3(-20, 1.5,  5),
		INDUSTRIAL_CENTER + Vector3( 30, 1.5, 20),
		# Beach / water area
		Vector3(78, 1.5,-18), Vector3(82, 1.5, 12),
		Vector3(92, 1.5, -4), Vector3(70, 1.5, 8),
		# Scattered outliers
		Vector3(55, 1.5, 60), Vector3(-60, 1.5, 50),
		Vector3(80, 1.5,-80), Vector3(-70, 1.5,-60),
		Vector3(120, 1.5, 40), Vector3(-100, 1.5, 60),
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
