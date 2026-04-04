extends CharacterBody3D
## Player goat — movement, third-person camera, headbutt, ragdoll toggle,
## goat switching (TAB), lick (F), enter/exit vehicles (E).

# ── Goat type definitions ────────────────────────────────────────────────────
const GOAT_NAMES: Array[String] = [
	"Normal Goat", "Tall Goat", "Muscle Goat", "Speed Goat",
	"Rocket Goat", "Giant Goat", "Ghost Goat", "Bouncy Goat"
]

# Per-type stats: [walk_speed, sprint_speed, jump_velocity, headbutt_force, scale]
const GOAT_STATS: Array = [
	[7.0,  14.0, 9.0,  28.0, 1.0],
	[7.0,  14.0, 14.0, 25.0, 1.0],
	[5.0,  10.0, 9.0,  60.0, 1.1],
	[12.0, 25.0, 9.0,  15.0, 0.9],
	[7.0,  14.0, 9.0,  28.0, 1.0],
	[5.0,  10.0, 8.0,  50.0, 2.0],
	[7.0,  14.0, 9.0,  28.0, 1.0],
	[7.0,  14.0, 12.0, 28.0, 1.0],
]

# ── Movement ─────────────────────────────────────────────────────────────────
var WALK_SPEED: float    = 7.0
var SPRINT_SPEED: float  = 14.0
var JUMP_VELOCITY: float = 9.0
const GRAVITY: float       = 20.0
const MOUSE_SENS: float    = 0.003
const HEADBUTT_RANGE: float = 3.2
var HEADBUTT_FORCE: float  = 28.0

# ── State ─────────────────────────────────────────────────────────────────────
var score: int        = 0
var is_ragdoll: bool  = false
var hb_cooldown: float = 0.0
var hud_node: Node   = null

# ── Goat switching ────────────────────────────────────────────────────────────
var current_goat_idx: int  = 0
var _switch_cooldown: float = 0.0

# ── Double-jump (Rocket Goat) ─────────────────────────────────────────────────
var _double_jumped: bool = false

# ── Bouncy Goat ───────────────────────────────────────────────────────────────
var _was_on_floor: bool = false

# ── Lick ──────────────────────────────────────────────────────────────────────
var _tongue_node: MeshInstance3D = null
var _tongue_active: bool = false
var _lick_target: Node3D = null
var _lick_cooldown: float = 0.0

# ── Vehicle ───────────────────────────────────────────────────────────────────
var _in_vehicle: bool = false
var _near_vehicle: Node = null

# ── Node refs ─────────────────────────────────────────────────────────────────
var goat_root:  Node3D
var cam_pivot:  Node3D
var spring_arm: SpringArm3D
var camera:     Camera3D

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_build_goat_mesh()
	_setup_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("_find_hud")

func _find_hud() -> void:
	hud_node = get_tree().get_first_node_in_group("hud")

# ── Goat type switching ───────────────────────────────────────────────────────
func _apply_goat_stats() -> void:
	var stats: Array = GOAT_STATS[current_goat_idx]
	WALK_SPEED     = float(stats[0])
	SPRINT_SPEED   = float(stats[1])
	JUMP_VELOCITY  = float(stats[2])
	HEADBUTT_FORCE = float(stats[3])
	var s: float   = float(stats[4])
	if goat_root:
		goat_root.scale = Vector3(s, s, s)

func _do_switch_goat() -> void:
	if _switch_cooldown > 0.0:
		return
	_switch_cooldown = 0.4
	current_goat_idx = (current_goat_idx + 1) % GOAT_NAMES.size()
	_rebuild_goat_mesh()
	_apply_goat_stats()
	var name_str: String = GOAT_NAMES[current_goat_idx]
	if hud_node and hud_node.has_method("update_goat_name"):
		hud_node.update_goat_name(name_str)
	_double_jumped = false

# ── Mesh construction ─────────────────────────────────────────────────────────
func _rebuild_goat_mesh() -> void:
	if goat_root:
		goat_root.queue_free()
		goat_root = null
	_build_goat_mesh()

func _build_goat_mesh() -> void:
	goat_root = Node3D.new()
	goat_root.name = "GoatMesh"
	add_child(goat_root)
	_apply_goat_stats()
	match current_goat_idx:
		0: _mesh_normal()
		1: _mesh_tall()
		2: _mesh_muscle()
		3: _mesh_speed()
		4: _mesh_rocket()
		5: _mesh_giant()
		6: _mesh_ghost()
		7: _mesh_bouncy()
		_: _mesh_normal()

func _mesh_normal() -> void:
	var tan   := Color(0.85, 0.80, 0.68)
	var dark  := Color(0.40, 0.35, 0.25)
	var horn  := Color(0.55, 0.48, 0.28)
	var hoof  := Color(0.15, 0.12, 0.10)
	var eye_c := Color(0.08, 0.06, 0.04)
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.70, 0.45, 1.10), tan,  0.80, 0.00)
	_mcyl(goat_root, Vector3(0, 1.38, 0.40), 0.12, 0.13, 0.35, tan,  0.80, 0.00, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), tan,  0.80, 0.00)
	_mbox(goat_root, Vector3(0, 1.47, 0.94), Vector3(0.22, 0.18, 0.22), Color(0.90, 0.85, 0.73), 0.80, 0.00)
	_mcyl(goat_root, Vector3(0, 1.34, 0.89), 0.03, 0.05, 0.22, Color(0.92, 0.88, 0.78), 0.80, 0.00)
	_msph(goat_root, Vector3(0, 1.05, -0.60), 0.10, Color(0.92, 0.88, 0.78), 0.80, 0.00)
	_msph(goat_root, Vector3(0, 0.70,  0.10), 0.10, Color(0.90, 0.70, 0.70), 0.70, 0.00)
	for sx in [-1, 1]:
		_msph(goat_root, Vector3(sx * 0.14, 1.63, 0.90), 0.050, eye_c, 0.90, 0.00)
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.12, 1.86, 0.60), 0.025, 0.060, 0.32,
					horn, 0.70, 0.10, Vector3(-0.20, 0, sx * 0.35))
		_msph(goat_root, Vector3(sx * 0.12, 1.86, 0.60) + Vector3(sx * 0.11, 0.28, 0), 0.03, horn, 0.70, 0.10)
	for sx in [-1, 1]:
		_mbox(goat_root, Vector3(sx * 0.22, 1.73, 0.65), Vector3(0.08, 0.16, 0.06), tan,
			0.80, 0.00, Vector3(0, 0, sx * 0.30))
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.62, bz), 0.08, 0.09, 0.32, tan,  0.80, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.28, bz), 0.06, 0.07, 0.32, dark, 0.70, 0.00)
		_mbox(goat_root, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 1.00, 0.00)

func _mesh_tall() -> void:
	var tan  := Color(0.92, 0.85, 0.55)
	var dark := Color(0.50, 0.40, 0.20)
	var horn := Color(0.55, 0.48, 0.28)
	var hoof := Color(0.15, 0.12, 0.10)
	_mbox(goat_root, Vector3(0, 1.20, 0),    Vector3(0.65, 0.42, 1.00), tan, 0.80, 0.00)
	_mcyl(goat_root, Vector3(0, 2.20, 0.35), 0.10, 0.12, 1.20, tan, 0.80, 0.00, Vector3(-0.3, 0, 0))
	_mbox(goat_root, Vector3(0, 2.90, 0.65), Vector3(0.36, 0.32, 0.42), tan, 0.80, 0.00)
	_mbox(goat_root, Vector3(0, 2.80, 0.88), Vector3(0.20, 0.17, 0.20), Color(0.90, 0.85, 0.73), 0.80, 0.00)
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.12, 3.20, 0.55), 0.025, 0.06, 0.40,
			horn, 0.70, 0.10, Vector3(-0.20, 0, sx * 0.35))
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.80, bz), 0.07, 0.08, 0.60, tan,  0.80, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.32, bz), 0.05, 0.06, 0.50, dark, 0.70, 0.00)
		_mbox(goat_root, Vector3(bx, 0.04, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 1.00, 0.00)

func _mesh_muscle() -> void:
	var c    := Color(0.55, 0.22, 0.14)
	var dark := Color(0.30, 0.12, 0.08)
	var hoof := Color(0.15, 0.12, 0.10)
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.90, 0.60, 1.20), c, 0.70, 0.00)
	_mcyl(goat_root, Vector3(0, 1.45, 0.42), 0.14, 0.16, 0.38, c, 0.70, 0.00, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.62, 0.76), Vector3(0.44, 0.40, 0.50), c, 0.70, 0.00)
	_mbox(goat_root, Vector3(0, 1.50, 1.00), Vector3(0.24, 0.20, 0.24), Color(0.65, 0.35, 0.20), 0.70, 0.00)
	var leg_x: Array[float] = [-0.28, 0.28, -0.28, 0.28]
	var leg_z: Array[float] = [ 0.35,  0.35, -0.35, -0.35]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.60, bz), 0.12, 0.13, 0.36, c,    0.70, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.24, bz), 0.09, 0.10, 0.34, dark, 0.70, 0.00)
		_mbox(goat_root, Vector3(bx, 0.04, bz + 0.04), Vector3(0.14, 0.08, 0.16), hoof, 1.00, 0.00)
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.14, 1.95, 0.62), 0.04, 0.09, 0.50,
			Color(0.40, 0.34, 0.18), 0.70, 0.10, Vector3(-0.15, 0, sx * 0.40))

func _mesh_speed() -> void:
	var c    := Color(0.20, 0.60, 0.90)
	var dark := Color(0.10, 0.35, 0.60)
	var hoof := Color(0.08, 0.08, 0.10)
	_mbox(goat_root, Vector3(0, 0.92, 0),    Vector3(0.52, 0.38, 1.20), c, 0.20, 0.10)
	_mcyl(goat_root, Vector3(0, 1.28, 0.46), 0.09, 0.10, 0.30, c, 0.20, 0.10, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.44, 0.74), Vector3(0.32, 0.28, 0.38), c, 0.20, 0.10)
	_mbox(goat_root, Vector3(0, 1.36, 0.94), Vector3(0.18, 0.15, 0.20), Color(0.30, 0.70, 1.0), 0.20, 0.10)
	for sx in [-1, 1]:
		_mbox(goat_root, Vector3(sx * 0.27, 0.92, 0), Vector3(0.04, 0.22, 0.90),
			Color(1.0, 0.90, 0.0), 0.20, 0.30)
	var leg_x: Array[float] = [-0.18, 0.18, -0.18, 0.18]
	var leg_z: Array[float] = [ 0.35,  0.35, -0.35, -0.35]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.56, bz), 0.055, 0.065, 0.30, c,    0.20, 0.10)
		_mcyl(goat_root, Vector3(bx, 0.22, bz), 0.045, 0.055, 0.30, dark, 0.20, 0.10)
		_mbox(goat_root, Vector3(bx, 0.04, bz + 0.04), Vector3(0.08, 0.07, 0.12), hoof, 1.00, 0.00)

func _mesh_rocket() -> void:
	_mesh_normal()
	_mbox(goat_root, Vector3(0, 1.10, -0.55), Vector3(0.50, 0.50, 0.30),
		Color(0.30, 0.30, 0.36), 0.40, 0.80)
	for jx in [-0.14, 0.14]:
		_mcyl(goat_root, Vector3(jx, 0.80, -0.70), 0.07, 0.09, 0.28,
			Color(0.22, 0.22, 0.26), 0.40, 0.70, Vector3(-0.2, 0, 0))
	for jx2 in [-0.14, 0.14]:
		_msph(goat_root, Vector3(jx2, 0.72, -0.80), 0.08, Color(1.0, 0.45, 0.10), 0.10, 0.0)

func _mesh_giant() -> void:
	var c    := Color(0.40, 0.65, 0.30)
	var dark := Color(0.22, 0.40, 0.14)
	var horn := Color(0.62, 0.54, 0.28)
	var hoof := Color(0.15, 0.12, 0.10)
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.70, 0.45, 1.10), c,    0.80, 0.00)
	_mcyl(goat_root, Vector3(0, 1.38, 0.40), 0.12, 0.13, 0.35, c,    0.80, 0.00, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), c,    0.80, 0.00)
	_mbox(goat_root, Vector3(0, 1.47, 0.94), Vector3(0.22, 0.18, 0.22), Color(0.55, 0.80, 0.45), 0.80, 0.00)
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.12, 1.86, 0.60), 0.025, 0.060, 0.32,
			horn, 0.70, 0.10, Vector3(-0.20, 0, sx * 0.35))
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.62, bz), 0.08, 0.09, 0.32, c,    0.80, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.28, bz), 0.06, 0.07, 0.32, dark, 0.70, 0.00)
		_mbox(goat_root, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 1.00, 0.00)

func _mesh_ghost() -> void:
	var c    := Color(0.80, 0.85, 1.0, 0.50)
	var dark := Color(0.55, 0.60, 0.80, 0.50)
	var hoof := Color(0.40, 0.45, 0.70, 0.50)
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.70, 0.45, 1.10), c, 0.20, 0.10)
	_mcyl(goat_root, Vector3(0, 1.38, 0.40), 0.12, 0.13, 0.35, c, 0.20, 0.10, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), c, 0.20, 0.10)
	_mbox(goat_root, Vector3(0, 1.47, 0.94), Vector3(0.22, 0.18, 0.22), Color(0.90, 0.95, 1.0, 0.50), 0.20, 0.10)
	for sx in [-1, 1]:
		_mcyl(goat_root, Vector3(sx * 0.12, 1.86, 0.60), 0.025, 0.060, 0.32,
			Color(0.75, 0.80, 1.0, 0.50), 0.20, 0.10, Vector3(-0.20, 0, sx * 0.35))
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.62, bz), 0.08, 0.09, 0.32, c,    0.20, 0.10)
		_mcyl(goat_root, Vector3(bx, 0.28, bz), 0.06, 0.07, 0.32, dark, 0.20, 0.10)
		_mbox(goat_root, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 0.80, 0.00)
	_apply_alpha_to_mesh(goat_root, 0.50)

func _mesh_bouncy() -> void:
	var c    := Color(1.0, 0.45, 0.80)
	var dark := Color(0.70, 0.20, 0.55)
	var hoof := Color(0.40, 0.10, 0.28)
	_mbox(goat_root, Vector3(0, 1.00, 0),    Vector3(0.72, 0.48, 1.12), c, 0.60, 0.00)
	_mcyl(goat_root, Vector3(0, 1.38, 0.40), 0.12, 0.13, 0.35, c, 0.60, 0.00, Vector3(-0.4, 0, 0))
	_mbox(goat_root, Vector3(0, 1.56, 0.72), Vector3(0.38, 0.34, 0.44), c, 0.60, 0.00)
	_mbox(goat_root, Vector3(0, 1.47, 0.94), Vector3(0.22, 0.18, 0.22), Color(1.0, 0.75, 0.88), 0.60, 0.00)
	var leg_x: Array[float] = [-0.22, 0.22, -0.22, 0.22]
	var leg_z: Array[float] = [ 0.33,  0.33, -0.33, -0.33]
	for i in 4:
		var bx: float = leg_x[i]
		var bz: float = leg_z[i]
		_mcyl(goat_root, Vector3(bx, 0.62, bz), 0.08, 0.09, 0.32, c,    0.60, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.28, bz), 0.07, 0.08, 0.32, dark, 0.60, 0.00)
		_mbox(goat_root, Vector3(bx, 0.06, bz + 0.04), Vector3(0.10, 0.08, 0.14), hoof, 1.00, 0.00)
		_mcyl(goat_root, Vector3(bx, 0.02, bz), 0.06, 0.06, 0.10, Color(1.0, 0.85, 0.0), 0.30, 0.50)

func _apply_alpha_to_mesh(root: Node3D, alpha: float) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
				m.albedo_color.a = alpha
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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
	if _in_vehicle:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_pivot.rotation.y -= event.relative.x * MOUSE_SENS
		cam_pivot.rotation.x -= event.relative.y * MOUSE_SENS
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(30))

# ── Physics update ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _in_vehicle:
		return

	if hb_cooldown > 0.0:
		hb_cooldown -= delta
	if _switch_cooldown > 0.0:
		_switch_cooldown -= delta
	if _lick_cooldown > 0.0:
		_lick_cooldown -= delta

	# ── Gravity ───────────────────────────────────────────────────────────────
	var on_floor: bool = is_on_floor()
	if not on_floor:
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	# ── Bouncy Goat ───────────────────────────────────────────────────────────
	if current_goat_idx == 7:
		if on_floor and not _was_on_floor:
			velocity.y = JUMP_VELOCITY * 1.5
	_was_on_floor = on_floor

	# ── Jump ─────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("jump"):
		if on_floor:
			velocity.y = JUMP_VELOCITY
			_double_jumped = false
		elif current_goat_idx == 4 and not _double_jumped:
			velocity.y = JUMP_VELOCITY * 0.9
			_double_jumped = true

	# ── Switch goat ───────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("switch_goat"):
		_do_switch_goat()

	# ── Enter vehicle ─────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("enter_vehicle"):
		_try_enter_vehicle()

	# ── Lick ──────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("lick"):
		if not _tongue_active:
			_do_lick()
		else:
			_release_lick()

	# ── Ragdoll toggle ────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ragdoll"):
		_toggle_ragdoll()

	if is_ragdoll:
		move_and_slide()
		return

	# ── Horizontal movement ───────────────────────────────────────────────────
	var spd: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var idir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_backward"))

	if idir.length_squared() > 0.0:
		idir = idir.normalized()
		var basis := cam_pivot.global_transform.basis
		var fwd   := -basis.z; fwd.y = 0.0; fwd = fwd.normalized()
		var right :=  basis.x; right.y = 0.0; right = right.normalized()
		var dir   := (right * idir.x + fwd * -idir.y).normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		goat_root.rotation.y = lerp_angle(goat_root.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
	else:
		var friction: float = spd * 12.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, friction)
		velocity.z = move_toward(velocity.z, 0.0, friction)

	# ── Headbutt ──────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("headbutt") and hb_cooldown <= 0.0:
		_do_headbutt()

	move_and_slide()

	# ── HUD speed update ──────────────────────────────────────────────────────
	if hud_node and hud_node.has_method("update_speed"):
		hud_node.update_speed(Vector2(velocity.x, velocity.z).length())

	# ── Near-vehicle detection ────────────────────────────────────────────────
	_check_near_vehicle()

	# ── Drag lick target ─────────────────────────────────────────────────────
	if _tongue_active and _lick_target and is_instance_valid(_lick_target):
		var tongue_pos: Vector3 = global_position + (-transform.basis.z * 1.0) + Vector3(0, 1.4, 0)
		_lick_target.global_position = tongue_pos

# ── Vehicle interaction ───────────────────────────────────────────────────────
func _check_near_vehicle() -> void:
	_near_vehicle = null
	var cars: Array = get_tree().get_nodes_in_group("drivable_car")
	for car in cars:
		if car is Node3D:
			var c3d: Node3D = car as Node3D
			if global_position.distance_to(c3d.global_position) < 4.0:
				_near_vehicle = car
				break
	if hud_node and hud_node.has_method("show_enter_hint"):
		hud_node.show_enter_hint(_near_vehicle != null)

func _try_enter_vehicle() -> void:
	if _near_vehicle != null and _near_vehicle.has_method("enter_car"):
		_near_vehicle.enter_car(self)

func on_enter_car(_car: Node) -> void:
	_in_vehicle = true
	if goat_root:
		goat_root.visible = false
	camera.current = false
	if hud_node and hud_node.has_method("set_driving_mode"):
		hud_node.set_driving_mode(true)

func on_exit_car(exit_pos: Vector3) -> void:
	_in_vehicle = false
	global_position = exit_pos
	if goat_root:
		goat_root.visible = true
	camera.current = true
	velocity = Vector3.ZERO
	if hud_node and hud_node.has_method("set_driving_mode"):
		hud_node.set_driving_mode(false)

# ── Lick ─────────────────────────────────────────────────────────────────────
func _do_lick() -> void:
	if _lick_cooldown > 0.0:
		return
	_tongue_active = true
	_lick_cooldown = 0.8

	if _tongue_node:
		_tongue_node.queue_free()
	_tongue_node = MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.08, 0.08, 0.60)
	_tongue_node.mesh = tm
	var tongue_mat := StandardMaterial3D.new()
	tongue_mat.albedo_color = Color(0.95, 0.40, 0.55)
	tongue_mat.roughness = 0.7
	_tongue_node.material_override = tongue_mat
	_tongue_node.position = Vector3(0, 1.47, 1.40)
	goat_root.add_child(_tongue_node)

	var tw := create_tween()
	tw.tween_property(_tongue_node, "scale:z", 2.0, 0.15)
	tw.tween_interval(0.30)
	tw.tween_property(_tongue_node, "scale:z", 1.0, 0.15)
	tw.tween_callback(_finish_lick_anim)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_origin: Vector3 = global_position + Vector3(0, 1.4, 0)
	var ray_end: Vector3    = ray_origin + (-global_transform.basis.z * 2.5)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	var result: Dictionary = space.intersect_ray(query)
	if result.size() > 0:
		var hit: Object = result["collider"]
		if hit is Node3D:
			var hit_node: Node3D = hit as Node3D
			if hit_node.is_in_group("npc"):
				_lick_target = hit_node
			elif hit_node.get_parent() != null and hit_node.get_parent().is_in_group("npc"):
				_lick_target = hit_node.get_parent() as Node3D
		_add_score(5)

func _finish_lick_anim() -> void:
	if _lick_target == null:
		_tongue_active = false
		if _tongue_node:
			_tongue_node.queue_free()
			_tongue_node = null

func _release_lick() -> void:
	_tongue_active = false
	_lick_target = null
	if _tongue_node:
		var tw := create_tween()
		tw.tween_property(_tongue_node, "scale:z", 0.01, 0.12)
		tw.tween_callback(_free_tongue)

func _free_tongue() -> void:
	if _tongue_node:
		_tongue_node.queue_free()
		_tongue_node = null

# ── Headbutt ─────────────────────────────────────────────────────────────────
func _do_headbutt() -> void:
	hb_cooldown = 0.5

	var tw := create_tween()
	tw.tween_property(goat_root, "position:z", -0.45, 0.08)
	tw.tween_property(goat_root, "position:z",  0.00, 0.14)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query  := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HEADBUTT_RANGE
	if current_goat_idx == 5:
		sphere.radius = HEADBUTT_RANGE * 2.0
	query.shape     = sphere
	query.transform = global_transform
	query.exclude   = [get_rid()]

	var results := space.intersect_shape(query, 16)
	for res in results:
		var col: Object = res["collider"]
		if col.is_in_group("npc") or col is RigidBody3D:
			if col.has_method("on_headbutted"):
				col.on_headbutted(global_position, HEADBUTT_FORCE)
			_add_score(10)
		elif col is StaticBody3D:
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

# ── Mesh helpers ─────────────────────────────────────────────────────────────
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
