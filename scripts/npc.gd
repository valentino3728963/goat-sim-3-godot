extends CharacterBody3D
## NPC pedestrian — walks randomly around the city and reacts to headbutts.

# ── Constants ─────────────────────────────────────────────────────────────────
const WALK_SPEED        := 2.4
const GRAVITY           := 20.0
const WAYPOINT_DIST     := 18.0   # max waypoint pick distance
const REACH_THRESH      := 1.8    # waypoint "reached" radius
const WAYPOINT_TIMEOUT  := 9.0    # give up and repick after N seconds
const RAGDOLL_DURATION  := 3.5
const RECOVER_DURATION  := 0.8

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WALKING, RAGDOLL, RECOVERING }
var _state := State.WALKING

# ── Configurable (set by spawner before _ready) ───────────────────────────────
var body_color := Color(0.85, 0.35, 0.35)

# ── Internals ─────────────────────────────────────────────────────────────────
var _mesh_root:     Node3D
var _waypoint:      Vector3
var _wp_timer:      float = 0.0
var _ragdoll_timer: float = 0.0
var _recover_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.randomize()
	_build_mesh()
	_pick_waypoint()
	add_to_group("npc")
	# NPCs live on layer 3 (npc), collide with world (layer 1) and players (layer 2)
	collision_layer = 4   # bit 3
	collision_mask  = 3   # bits 1+2

# ── Mesh construction ─────────────────────────────────────────────────────────
func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "Mesh"
	add_child(_mesh_root)

	var skin_color   := Color(0.92, 0.78, 0.65)
	var pants_color  := Color(0.22, 0.24, 0.45)
	var shoe_color   := Color(0.12, 0.10, 0.08)
	var hair_choices: Array[Color] = [
		Color(0.18, 0.12, 0.06),
		Color(0.80, 0.70, 0.40),
		Color(0.55, 0.28, 0.10),
		Color(0.12, 0.12, 0.12),
	]
	var hair_color: Color = hair_choices[randi() % hair_choices.size()]

	# Lower body / pants
	_box(_mesh_root, Vector3(0, 0.50, 0),  Vector3(0.36, 0.42, 0.22), pants_color, 0.90, 0.0)
	# Upper body / shirt
	_box(_mesh_root, Vector3(0, 1.00, 0),  Vector3(0.40, 0.56, 0.24), body_color,  0.80, 0.0)
	# Head
	_sph(_mesh_root, Vector3(0, 1.65, 0),  0.20, skin_color, 0.90, 0.0)
	# Hair
	_box(_mesh_root, Vector3(0, 1.92, 0),  Vector3(0.40, 0.13, 0.40), hair_color,  0.90, 0.0)
	# Eyes
	for sx in [-1, 1]:
		_sph(_mesh_root, Vector3(sx * 0.08, 1.67, 0.18), 0.040, Color(0.08, 0.07, 0.06), 0.9, 0.0)
	# Arms
	for sx in [-1, 1]:
		_cyl(_mesh_root, Vector3(sx * 0.29, 1.00, 0), 0.056, 0.056, 0.50, body_color, 0.8, 0.0,
			Vector3(0, 0, sx * 0.25))
		# Hands
		_sph(_mesh_root, Vector3(sx * 0.36, 0.77, 0), 0.062, skin_color, 0.9, 0.0)
	# Legs
	for sx in [-1, 1]:
		_cyl(_mesh_root, Vector3(sx * 0.10, 0.25, 0), 0.070, 0.070, 0.44, pants_color, 0.9, 0.0)
		# Shoes
		_box(_mesh_root, Vector3(sx * 0.10, 0.01, 0.04), Vector3(0.14, 0.09, 0.24), shoe_color, 1.0, 0.0)

# ── Waypoint picking ──────────────────────────────────────────────────────────
func _pick_waypoint() -> void:
	var angle := _rng.randf() * TAU
	var dist  := _rng.randf_range(4.0, WAYPOINT_DIST)
	_waypoint   = global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_waypoint.x = clamp(_waypoint.x, -46.0, 46.0)
	_waypoint.z = clamp(_waypoint.z, -46.0, 46.0)
	_waypoint.y = global_position.y
	_wp_timer   = 0.0

# ── Physics loop ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	match _state:
		State.WALKING:    _tick_walking(delta)
		State.RAGDOLL:    _tick_ragdoll(delta)
		State.RECOVERING: _tick_recovering(delta)

func _tick_walking(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5  # keep on ground

	_wp_timer += delta
	var diff := _waypoint - global_position
	diff.y   = 0.0
	var dist := diff.length()

	if dist < REACH_THRESH or _wp_timer >= WAYPOINT_TIMEOUT:
		_pick_waypoint()
		return

	var dir   := diff.normalized()
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED

	# Rotate mesh to face movement
	_mesh_root.rotation.y = lerp_angle(
		_mesh_root.rotation.y, atan2(dir.x, dir.z), 6.0 * delta)

	# Subtle walk bob
	_mesh_root.position.y = sin(Time.get_ticks_msec() * 0.009) * 0.05

	move_and_slide()

func _tick_ragdoll(delta: float) -> void:
	_ragdoll_timer -= delta
	# Visual tumble
	_mesh_root.rotation.x = lerp(_mesh_root.rotation.x, PI * 0.48, 4.0 * delta)
	# Apply gravity so they "fall"
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 3.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 3.0 * delta)
	move_and_slide()

	if _ragdoll_timer <= 0.0:
		_state = State.RECOVERING
		_recover_timer = RECOVER_DURATION

func _tick_recovering(delta: float) -> void:
	_recover_timer -= delta
	# Slowly stand back up
	_mesh_root.rotation.x = lerp(_mesh_root.rotation.x, 0.0, 5.0 * delta)
	_mesh_root.position.y = lerp(_mesh_root.position.y, 0.0, 5.0 * delta)
	if _recover_timer <= 0.0:
		_state = State.WALKING
		velocity = Vector3.ZERO
		_pick_waypoint()

# ── Called by player headbutt ─────────────────────────────────────────────────
func on_headbutted(from_pos: Vector3, force: float) -> void:
	if _state == State.RAGDOLL:
		return
	_state          = State.RAGDOLL
	_ragdoll_timer  = RAGDOLL_DURATION
	# Launch NPC away from goat
	var dir        := (global_position - from_pos).normalized()
	velocity        = dir * force + Vector3.UP * force * 0.6
	# TODO: play hit sound

# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = rough; m.metallic = metal
	return m

func _box(p: Node3D, pos: Vector3, sz: Vector3,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)
	p.add_child(mi); return mi

func _cyl(p: Node3D, pos: Vector3, tr: float, br: float, h: float,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = tr; cm.bottom_radius = br
	cm.height = h; cm.radial_segments = 8
	mi.mesh = cm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)
	p.add_child(mi); return mi

func _sph(p: Node3D, pos: Vector3, r: float,
		color: Color, rough: float, metal: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 8; sm.rings = 6
	mi.mesh = sm; mi.position = pos
	mi.material_override = _mat(color, rough, metal)
	p.add_child(mi); return mi
