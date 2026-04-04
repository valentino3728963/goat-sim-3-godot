extends CanvasLayer
## HUD — score, speed, goat type, vehicle hints, lick/map/goat hints.

@onready var score_label:     Label      = $Panel/VBox/ScoreRow/ScoreValue
@onready var speed_label:     Label      = $Panel/VBox/SpeedRow/SpeedValue
@onready var goat_label:      Label      = $Panel/VBox/GoatRow/GoatValue
@onready var car_speed_label: Label      = $Panel/VBox/CarSpeedRow/CarSpeedValue
@onready var speed_row:       HBoxContainer = $Panel/VBox/SpeedRow
@onready var car_speed_row:   HBoxContainer = $Panel/VBox/CarSpeedRow
@onready var hint_label:      Label      = $HintLabel
@onready var enter_hint:      Label      = $EnterHint

func _ready() -> void:
	add_to_group("hud")
	car_speed_row.visible = false
	enter_hint.visible = false

# ── Called by player.gd / car.gd ─────────────────────────────────────────────
func update_score(new_score: int) -> void:
	score_label.text = str(new_score)

func update_speed(spd: float) -> void:
	speed_label.text = "%.1f m/s" % spd

func update_goat_name(name_str: String) -> void:
	goat_label.text = name_str

func update_car_speed(spd: float) -> void:
	car_speed_label.text = "%.0f km/h" % (spd * 3.6)

func show_enter_hint(show: bool) -> void:
	enter_hint.visible = show

func set_driving_mode(driving: bool) -> void:
	speed_row.visible     = not driving
	car_speed_row.visible = driving
	if driving:
		enter_hint.visible = false

# ── Show / hide mouse-lock hint ───────────────────────────────────────────────
func _process(_delta: float) -> void:
	hint_label.visible = (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
