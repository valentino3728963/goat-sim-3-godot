extends CanvasLayer
## Pause menu — shown when the player presses ESC.
## Uses PROCESS_MODE_ALWAYS so it can handle input even when the tree is paused.

@onready var panel:         Control = $Panel
@onready var resume_button: Button  = $Panel/VBox/ResumeButton
@onready var quit_button:   Button  = $Panel/VBox/QuitButton

func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if panel.visible:
		_on_resume()
	else:
		_show_pause()

func _show_pause() -> void:
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
