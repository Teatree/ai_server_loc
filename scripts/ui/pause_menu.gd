extends Control

func _ready() -> void:
	process_mode = Control.PROCESS_MODE_ALWAYS
	show()

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_on_resume)
	add_child(resume)

	var title := Button.new()
	title.text = "Return to Title"
	title.pressed.connect(_on_title)
	add_child(title)

	_setup_layout([resume, title])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.resume()


func _on_resume() -> void:
	GameFlow.resume()


func _on_title() -> void:
	GameFlow.request_return_to_title()


func _setup_layout(buttons: Array[Button]) -> void:
	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.offset_left = -100
	vbox.offset_top = -80
	vbox.offset_right = 100
	vbox.offset_bottom = 80
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		vbox.add_child(b)
	add_child(vbox)
