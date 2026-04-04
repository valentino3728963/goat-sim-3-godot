extends CharacterBody3D
## Player goat — movement, third-person camera, headbutt, ragdoll toggle.

# ── Movement ────────────────────────────────────────────────────────────────
const WALK_SPEED    := 7.0
const SPRINT_SPEED  := 14.0
const JUMP_VELOCITY := 9.0
const GRAVITY       := 20.0
const MOUSE_SENS    := 0.003
const HEADBUTT_RANGE := 3.2
const HEADBUTT_FORCE := 28.0

# ── State ────────────────────────────────────────────────────────────────────
var score: int        = 0
var is_ragdoll: bool  = false
var hb_cooldown: float = 0.0   # headbutt cooldown timer
var hud_node: Node   = null    # filled in _ready via group lookup

# ── Node refs (built procedurally) ───────────────────────────────────────────
var goat_root:   Node3D
var cam_pivot:   Node3D        # yaw+pitch pivot, follows player position
var spring_arm:  SpringArm3D
var camera:      Camera3D

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_goat_mesh()
	_setup_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Defer HUD lookup so the scene tree is fully built
	call_deferred("_find_hud")

func _find_hud() -> void:
	hud_node = get_tree().get_first_node_in_group("hud")

# ── Mesh construction ────────────────────────────────────────────────────────
func _build_goat_mesh() -> void:
	goat_root = Node3D.new()
	goat_root.name = "GoatMesh"
	add_child(goat_root)

	var tan   := Color(0.85, 0.80, 0.68)
	var dark  := Color(0.40, 0.35, 0.25)
	var horn  := Color(0.55, 0.48, 0.28)
	var hoof  := Color(0.15, 0.12, 0.10)
	var eye_c := Color(0.08, 0.06, 0.04)

	# Body
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.70, 0.45, 1.10), tan,  0.80, 0.00)
	# Neck
	_mcyl(goat_root, Vector3(0, 1.38, 0.40), 0.12, 0.13, 0.35, tan,  0.80, 0.00, Vector3(-0.4, 0, 0))
	# Head
	_mbox(goat_root, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), tan,  0.80, 0.00)
	# Snout
	_mbox(goat_root, Vector3(0, 1.47, 0.94), Vector3(0.22, 0.18, 0.22), Color(0.90, 0.85, 0.73), 0.80, 0.00)
	# Beard
	_mcyl(goat_root, Vector3(0, 1.34, 0.89), 0.03, 0.05, 0.22, Color(0.92, 0.88, 0.78), 0.80, 0.00)
	# Tail
	_msph(goat_root, Vector3(0, 1.05, -0.60), 0.10, Color(0.92, 0.88, 0.78), 0.80, 0.00)
	# Udder
	_msph(goat_root, Vector3(0, 0.70,  0.10), 0.10, Color(0.90, 0.70, 0.70), 0.70, 0.00)

	# Eyes
	for sx in [-1, 1]:
		_msph(goat_root, Vector3(sx * 0.14, 1.63, 0.90), 0.050, eye_c, 0.90, 0.00)

	# Horns
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.12, 1.86, 0.60), 0.025, 0.060, 0.32,
					horn, 0.70, 0.10, Vector3(-0.20, 0, sx * 0.35))
		_msph(goat_root, Vector3(sx * 0.12, 1.86, 0.60) + Vector3(sx * 0.11, 0.28, 0), 0.03, horn, 0.70, 0.10)

	# Ears
	for sx in [-1, 1]:
		_mbox(goat_root, Vector3(sx * 0.22, 1.73, 0.65), Vector3(0.08, 0.16, 0.06), tan,
			0.80, 0.00, Vector3(0, 0, sx * 0.30))

	# Four legs: upper, lower, hoof
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]; var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.62, bz), 0.08, 0.09, 0.32, tan,  0.80, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.28, bz), 0.06, 0.07, 0.32, dark, 0.70, 0.00)
		_mbox(goat_root, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 1.00, 0.00)

# ── Camera setup ─────────────────────────────────────────────────────────────
func _setup_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.name = "CamPivot"
	add_child(cam_pivot)
	cam_pivot.position = Vector3(0, 0.9, 0)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.spring_length = 5.5
	spring_arm.margin = 0.3
	cam_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera"
	spring_arm.add_child(camera)

	spring_arm.add_excluded_object(get_rid())

# ── Input: mouse look ────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_pivot.rotation.y -= event.relative.x * MOUSE_SENS
		cam_pivot.rotation.x -= event.relative.y * MOUSE_SENS
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(30))

# ── Physics update ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if hb_cooldown > 0.0:
		hb_cooldown -= delta

	# ── Gravity ───────────────────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = 0.0

	# ── Jump ─────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		# TODO: play jump sound

	# ── Ragdoll toggle ────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ragdoll"):
		_toggle_ragdoll()

	if is_ragdoll:
		move_and_slide()
		return

	# ── Horizontal movement ───────────────────────────────────────────────────
	var spd  := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var idir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_backward"))

	if idir.length_squared() > 0.0:
		idir = idir.normalized()
		# Project input onto horizontal camera plane
		var basis := cam_pivot.global_transform.basis
		var fwd   := -basis.z; fwd.y = 0.0;  fwd = fwd.normalized()
		var right :=  basis.x; right.y = 0.0; right = right.normalized()
		var dir   := (right * idir.x + fwd * -idir.y).normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		# Smoothly rotate goat to face movement direction
		goat_root.rotation.y = lerp_angle(goat_root.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
	else:
		var friction := spd * 12.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, friction)
		velocity.z = move_toward(velocity.z, 0.0, friction)

	# ── Headbutt ──────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("headbutt") and hb_cooldown <= 0.0:
		_do_headbutt()

	move_and_slide()

	# ── HUD speed update ──────────────────────────────────────────────────────
	if hud_node and hud_node.has_method("update_speed"):
		hud_node.update_speed(Vector2(velocity.x, velocity.z).length())

# ── Headbutt ─────────────────────────────────────────────────────────────────
func _do_headbutt() -> void:
	hb_cooldown = 0.5
	# TODO: play headbutt sound

	# Visual lunge: quick forward nudge
	var tw := create_tween()
	tw.tween_property(goat_root, "position:z", -0.45, 0.08)
	tw.tween_property(goat_root, "position:z",  0.00, 0.14)

	# Shape cast to find nearby RigidBody3D / NPC bodies
	var space  := get_world_3d().direct_space_state
	var query  := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HEADBUTT_RANGE
	query.shape     = sphere
	query.transform = global_transform
	query.exclude   = [get_rid()]

	var results := space.intersect_shape(query, 16)
	for res in results:
		var col: Object = res["collider"]
		# Hit NPCs (which are in npc group)
		if col.is_in_group("npc") or col is RigidBody3D:
			if col.has_method("on_headbutted"):
				col.on_headbutted(global_position, HEADBUTT_FORCE)
			_add_score(10)
		elif col is StaticBody3D:
			# Hitting environment gives small score too
			_add_score(1)

func _add_score(amount: int) -> void:
	score += amount
	if hud_node and hud_node.has_method("update_score"):
		hud_node.update_score(score)

# ── Ragdoll ───────────────────────────────────────────────────────────────────
func _toggle_ragdoll() -> void:
	is_ragdoll = !is_ragdoll
	if is_ragdoll:
		goat_root.rotation.x =  PI * 0.5
		goat_root.position.y =  0.5
		velocity *= 0.3
	else:
		goat_root.rotation.x = 0.0
		goat_root.position.y = 0.0

# ── Mesh helpers (static helpers to build the goat) ──────────────────────────
func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = rough
	m.metallic     = metal
	return m

func _mbox(parent: Node3D, pos: Vector3, sz: Vector3,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)
	parent.add_child(mi); return mi

func _mcyl(parent: Node3D, pos: Vector3,
		top_r: float, bot_r: float, h: float,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r; cm.bottom_radius = bot_r
	cm.height = h; cm.radial_segments = 8
	mi.mesh = cm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)
	parent.add_child(mi); return mi

func _msph(parent: Node3D, pos: Vector3, radius: float,
		color: Color, rough: float, metal: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius; sm.height = radius * 2.0
	sm.radial_segments = 8; sm.rings = 6
	mi.mesh = sm; mi.position = pos
	mi.material_override = _mat(color, rough, metal)
	parent.add_child(mi); return mi
