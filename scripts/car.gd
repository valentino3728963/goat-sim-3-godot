extends CharacterBody3D
## Drivable car — player enters with E, drives with WASD, exits with E again.

# ── Constants ─────────────────────────────────────────────────────────────────
const MAX_SPEED_FWD  := 28.0
const MAX_SPEED_REV  := 10.0
const ACCEL          := 18.0
const BRAKE_FORCE    := 30.0
const STEER_SPEED    := 2.2
const GRAVITY        := 20.0
const ENTER_RADIUS   := 3.5

# ── Car type stats ────────────────────────────────────────────────────────────
# Set by world_builder before _ready
var car_type: String  = "sedan"   # sedan | sports | truck | bus
var car_color: Color  = Color(0.80, 0.10, 0.10)

# ── State ─────────────────────────────────────────────────────────────────────
var _driven_by: Node   = null   # the player node when occupied
var _steer_angle: float = 0.0
var _speed: float       = 0.0
var _enter_cooldown: float = 0.0
var _mesh_root: Node3D

# ── Node refs ─────────────────────────────────────────────────────────────────
var _cam_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("drivable_car")
	_build_mesh()
	# Collision: layer 1 (world-interactable), mask: world
	collision_layer = 1
	collision_mask  = 1

func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "CarMesh"
	add_child(_mesh_root)
	match car_type:
		"sports":
			_build_sports_car()
		"truck":
			_build_truck()
		"bus":
			_build_bus()
		_:
			_build_sedan()
	_build_camera()

func _build_sedan() -> void:
	var c: Color = car_color
	# Body
	_box(_mesh_root, Vector3(0, 0.50, 0),    Vector3(1.85, 0.72, 3.90), c, 0.30, 0.42)
	# Cabin
	_box(_mesh_root, Vector3(0, 1.08, -0.18), Vector3(1.62, 0.56, 2.20), c * 0.86, 0.30, 0.30)
	# Windscreens
	_box(_mesh_root, Vector3(0, 1.05, 0.92), Vector3(1.52, 0.50, 0.06),
		Color(0.58, 0.75, 0.92, 0.6), 0.05, 0.5)
	_box(_mesh_root, Vector3(0, 1.05, -1.28), Vector3(1.52, 0.50, 0.06),
		Color(0.58, 0.75, 0.92, 0.6), 0.05, 0.5)
	_add_wheels(_mesh_root, 0.96, 1.22, 0.30)
	# Headlights
	for hx in [-0.72, 0.72]:
		_box(_mesh_root, Vector3(hx, 0.56, 1.95), Vector3(0.30, 0.15, 0.06),
			Color(1.0, 1.0, 0.82), 0.08, 0.0)

func _build_sports_car() -> void:
	var c: Color = car_color
	# Sleek low body
	_box(_mesh_root, Vector3(0, 0.38, 0),    Vector3(1.80, 0.55, 4.20), c, 0.15, 0.55)
	_box(_mesh_root, Vector3(0, 0.88, -0.30), Vector3(1.55, 0.42, 2.00), c * 0.90, 0.15, 0.45)
	_box(_mesh_root, Vector3(0, 0.80, 0.80), Vector3(1.48, 0.38, 0.06),
		Color(0.58, 0.75, 0.92, 0.5), 0.05, 0.5)
	_add_wheels(_mesh_root, 0.92, 1.40, 0.28)
	# Spoiler
	_box(_mesh_root, Vector3(0, 0.72, -2.1), Vector3(1.60, 0.30, 0.08), c * 0.80, 0.25, 0.40)
	_box(_mesh_root, Vector3(-0.70, 0.52, -2.1), Vector3(0.06, 0.40, 0.14), c * 0.70, 0.25, 0.40)
	_box(_mesh_root, Vector3( 0.70, 0.52, -2.1), Vector3(0.06, 0.40, 0.14), c * 0.70, 0.25, 0.40)

func _build_truck() -> void:
	var c: Color = car_color
	_box(_mesh_root, Vector3(0, 1.20, 2.2),  Vector3(2.4, 2.0, 2.6), c, 0.40, 0.20)
	_box(_mesh_root, Vector3(0, 1.40, -1.8), Vector3(2.4, 2.8, 5.2), c * 0.85, 0.55, 0.10)
	for wx in [-1.20, 1.20]:
		for wz in [2.2, 0.0, -2.2]:
			_add_wheel(_mesh_root, Vector3(wx, 0.46, wz), 0.46, 0.32)
	for hx in [-0.90, 0.90]:
		_box(_mesh_root, Vector3(hx, 1.10, 3.52), Vector3(0.38, 0.20, 0.06),
			Color(1.0, 1.0, 0.82), 0.08, 0.0)

func _build_bus() -> void:
	var c: Color = car_color
	_box(_mesh_root, Vector3(0, 1.45, 0),   Vector3(2.50, 2.60, 9.50), c, 0.45, 0.15)
	_box(_mesh_root, Vector3(0, 2.82, 0),   Vector3(2.42, 0.18, 9.30), c * 0.90, 0.50, 0.10)
	for wz_off in [-3.2, -1.6, 0.0, 1.6, 3.2]:
		_box(_mesh_root, Vector3(1.26, 1.80, wz_off),
			Vector3(0.06, 0.80, 1.20), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
		_box(_mesh_root, Vector3(-1.26, 1.80, wz_off),
			Vector3(0.06, 0.80, 1.20), Color(0.60, 0.80, 0.95, 0.5), 0.05, 0.30)
	for wx in [-1.24, 1.24]:
		for wz in [-3.20, 3.20]:
			_add_wheel(_mesh_root, Vector3(wx, 0.44, wz), 0.44, 0.28)

func _add_wheels(parent: Node3D, half_w: float, half_l: float, r: float) -> void:
	for wx in [-half_w, half_w]:
		for wz in [-half_l, half_l]:
			_add_wheel(parent, Vector3(wx, r, wz), r, 0.22)

func _add_wheel(parent: Node3D, pos: Vector3, r: float, w: float) -> void:
	var wm := CylinderMesh.new()
	wm.top_radius = r; wm.bottom_radius = r
	wm.height = w; wm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = wm
	mi.position = pos
	mi.rotation.z = PI * 0.5
	mi.material_override = _mat(Color(0.10, 0.10, 0.10), 1.0, 0.0)
	parent.add_child(mi)

func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CarCamPivot"
	add_child(_cam_pivot)
	var height: float = 2.0 if car_type == "bus" else 1.4
	_cam_pivot.position = Vector3(0, height, 0)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 8.0
	_spring_arm.margin = 0.3
	_cam_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "CarCamera"
	_spring_arm.add_child(_camera)
	_spring_arm.add_excluded_object(get_rid())
	_camera.current = false

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _enter_cooldown > 0.0:
		_enter_cooldown -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	if _driven_by == null:
		# Parked: no input, just gravity/slide
		velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
		move_and_slide()
		return

	# ── Driving controls ──────────────────────────────────────────────────────
	var fwd_input: float = Input.get_axis("move_backward", "move_forward")
	var steer_input: float = Input.get_axis("move_right", "move_left")

	var max_spd: float = MAX_SPEED_FWD
	if car_type == "sports":
		max_spd = 42.0
	elif car_type == "truck" or car_type == "bus":
		max_spd = 16.0

	# Accelerate / brake
	if fwd_input > 0.0:
		_speed = move_toward(_speed, max_spd, ACCEL * delta)
	elif fwd_input < 0.0:
		if _speed > 0.5:
			_speed = move_toward(_speed, 0.0, BRAKE_FORCE * delta)
		else:
			_speed = move_toward(_speed, -MAX_SPEED_REV, ACCEL * delta)
	else:
		_speed = move_toward(_speed, 0.0, (BRAKE_FORCE * 0.4) * delta)

	# Steering (only effective when moving)
	if abs(_speed) > 0.5:
		_steer_angle = move_toward(_steer_angle, steer_input * 1.2, STEER_SPEED * delta)
	else:
		_steer_angle = move_toward(_steer_angle, 0.0, STEER_SPEED * 2.0 * delta)

	# Rotate car
	var turn_rate: float = _steer_angle * (_speed / max_spd) * 1.8
	rotation.y += turn_rate * delta

	# Forward vector
	var fwd: Vector3 = -transform.basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed

	move_and_slide()

	# Sync camera yaw with car (pivot is child, so position is auto, just fix rotation)
	_cam_pivot.rotation.y = rotation.y + PI

	# Update HUD speed
	var hud_node: Node = get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("update_car_speed"):
		hud_node.update_car_speed(abs(_speed))

	# Exit vehicle
	if Input.is_action_just_pressed("enter_vehicle") and _enter_cooldown <= 0.0:
		_exit_car()

# ── Enter / Exit ──────────────────────────────────────────────────────────────
func enter_car(player: Node) -> void:
	_driven_by = player
	_enter_cooldown = 0.8
	# Hide player mesh, disable player physics
	if player.has_method("on_enter_car"):
		player.on_enter_car(self)
	_camera.current = true

func _exit_car() -> void:
	if _driven_by == null:
		return
	_camera.current = false
	var player: Node = _driven_by
	_driven_by = null
	_speed = 0.0
	if player.has_method("on_exit_car"):
		# Exit to the side of the car
		var side_offset: Vector3 = transform.basis.x * 2.5
		player.on_exit_car(global_position + side_offset + Vector3(0, 1.0, 0))

# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = rough
	m.metallic     = metal
	return m

func _box(parent: Node3D, pos: Vector3, sz: Vector3,
		color: Color, rough: float, metal: float,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz
	mi.mesh = bm; mi.position = pos; mi.rotation = rot
	mi.material_override = _mat(color, rough, metal)
	parent.add_child(mi)
	return mi
