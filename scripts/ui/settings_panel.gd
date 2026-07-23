# settings_panel.gd
# Reusable settings panel. Currently a placeholder.
class_name SettingsPanel
extends Control


func _ready() -> void:
	visible = false
	var close_btn: Button = $PanelContainer/VBoxContainer/CloseButton as Button
	if close_btn:
		close_btn.pressed.connect(close)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
