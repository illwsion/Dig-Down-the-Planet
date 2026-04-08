extends Node2D

@onready var m_start_button: Button = $UILayer/StartButton
@onready var m_skill_tree_button: Button = $UILayer/SkillTreeButton
@onready var m_skill_tree_panel: PanelContainer = $UILayer/SkillTreePanel
@onready var m_close_button: Button = $UILayer/SkillTreePanel/VBox/HeaderBar/CloseButton
@onready var m_skill_tree_view = $UILayer/SkillTreePanel/VBox/SkillTreeView
@onready var m_dollars_label: Label = $UILayer/DollarsLabel
@onready var m_inventory_panel = $UILayer/HubInventoryPanel


func _ready() -> void:
	m_start_button.pressed.connect(_on_start_button_pressed)
	m_skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	m_close_button.pressed.connect(_on_close_button_pressed)
	m_inventory_panel.dollars_changed.connect(update_dollars_label)
	m_inventory_panel.refresh()
	update_dollars_label()


## 달러 레이블 갱신. HubInventoryPanel 판매 후, 귀환 직후 등에서 호출한다.
func update_dollars_label() -> void:
	m_dollars_label.text = "$ %d" % GameState.dollars


func _on_start_button_pressed() -> void:
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_skill_tree_button_pressed() -> void:
	m_skill_tree_panel.visible = true
	# visible = true 이후 레이아웃 계산이 끝난 다음 프레임에 refresh 호출
	m_skill_tree_view.call_deferred("refresh")


func _on_close_button_pressed() -> void:
	m_skill_tree_panel.visible = false
