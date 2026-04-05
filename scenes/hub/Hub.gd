extends Node2D

@onready var m_start_button: Button = $UILayer/StartButton
@onready var m_skill_tree_button: Button = $UILayer/SkillTreeButton
@onready var m_skill_tree_panel: PanelContainer = $UILayer/SkillTreePanel
@onready var m_close_button: Button = $UILayer/SkillTreePanel/VBox/HeaderBar/CloseButton


func _ready() -> void:
	m_start_button.pressed.connect(_on_start_button_pressed)
	m_skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	m_close_button.pressed.connect(_on_close_button_pressed)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_skill_tree_button_pressed() -> void:
	m_skill_tree_panel.visible = true


func _on_close_button_pressed() -> void:
	m_skill_tree_panel.visible = false
