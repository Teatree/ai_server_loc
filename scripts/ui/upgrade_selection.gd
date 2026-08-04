extends PanelContainer

signal choice_made(upgrade_id: StringName)

var _choices: Array[Dictionary] = []
var _upgrade_runtime: Node = null
var _buttons: Array[Button] = []
var _title: Label = null


func _ready() -> void:
	_title = get_node_or_null("VBox/Title") as Label
	_buttons = [
		get_node_or_null("VBox/Choice1") as Button,
		get_node_or_null("VBox/Choice2") as Button,
		get_node_or_null("VBox/Choice3") as Button
	]
	for button in _buttons:
		if button:
			button.pressed.connect(_on_choice_pressed)


func setup(choices: Array[Dictionary], upgrade_runtime: Node) -> void:
	_choices = choices
	_upgrade_runtime = upgrade_runtime
	if not _title:
		_title = get_node_or_null("VBox/Title") as Label
	if _buttons.is_empty():
		_buttons = [
			get_node_or_null("VBox/Choice1") as Button,
			get_node_or_null("VBox/Choice2") as Button,
			get_node_or_null("VBox/Choice3") as Button
		]
	for button in _buttons:
		if button:
			button.pressed.disconnect(_on_choice_pressed)
	for i in range(_buttons.size()):
		if i < choices.size():
			var choice: Dictionary = choices[i]
			_buttons[i].text = "%s\n%s" % [choice.display_name, choice.description]
			_buttons[i].visible = true
		else:
			_buttons[i].visible = false
	if _title:
		_title.visible = not choices.is_empty()


func _on_choice_pressed() -> void:
	for i in range(_buttons.size()):
		if _buttons[i] and _buttons[i].button_pressed:
			_select_choice(i)
			break


func _select_choice(index: int) -> void:
	if index >= _choices.size():
		return
	var choice: Dictionary = _choices[index]
	if _upgrade_runtime and _upgrade_runtime.has_method("apply_upgrade"):
		_upgrade_runtime.apply_upgrade(choice.upgrade_id)
	choice_made.emit(choice.upgrade_id)
	queue_free()
