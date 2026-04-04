extends Control
## Main menu — shows title, "Press ENTER to Play", and animates the title.

@onready var title_label: Label = $CenterContainer/VBox/Title
@onready var blink_label: Label = $CenterContainer/VBox/PressEnter

var _blink_timer: float = 0.0
var _blink_visible: bool = true

func _ready() -> void:
	# Style the title
	title_label.add_theme_font_size_override("font_size", 96)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)

	blink_label.add_theme_font_size_override("font_size", 36)
	blink_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	# Animate title scale in (deferred so layout is ready and size is known)
	title_label.scale = Vector2(0.5, 0.5)
	await get_tree().process_frame
	title_label.pivot_offset = title_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	# Blink the "Press ENTER" label
	_blink_timer += delta
	if _blink_timer >= 0.55:
		_blink_timer = 0.0
		_blink_visible = !_blink_visible
		blink_label.modulate.a = 1.0 if _blink_visible else 0.25

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		# Transition to game scene
		get_tree().change_scene_to_file("res://scenes/game.tscn")
