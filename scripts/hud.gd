extends CanvasLayer
## HUD — score counter, speed display, mouse-lock hint.

@onready var score_label:  Label = $Panel/VBox/ScoreRow/ScoreValue
@onready var speed_label:  Label = $Panel/VBox/SpeedRow/SpeedValue
@onready var hint_label:   Label = $HintLabel

func _ready() -> void:
	add_to_group("hud")

# ── Called by player.gd ───────────────────────────────────────────────────────
func update_score(new_score: int) -> void:
	score_label.text = str(new_score)

func update_speed(spd: float) -> void:
	speed_label.text = "%.1f m/s" % spd

# ── Show / hide mouse-lock hint ───────────────────────────────────────────────
func _process(_delta: float) -> void:
	hint_label.visible = (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
