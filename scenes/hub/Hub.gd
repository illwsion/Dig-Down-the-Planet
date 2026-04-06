extends Node2D

@onready var m_start_button: Button = $UILayer/StartButton
@onready var m_skill_tree_button: Button = $UILayer/SkillTreeButton
@onready var m_skill_tree_panel: PanelContainer = $UILayer/SkillTreePanel
@onready var m_close_button: Button = $UILayer/SkillTreePanel/VBox/HeaderBar/CloseButton
@onready var m_skill_tree_view = $UILayer/SkillTreePanel/VBox/SkillTreeView

var m_hub_inventory_label: Label


func _ready() -> void:
	m_start_button.pressed.connect(_on_start_button_pressed)
	m_skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	m_close_button.pressed.connect(_on_close_button_pressed)

	m_hub_inventory_label = Label.new()
	m_hub_inventory_label.anchor_left   = 1.0
	m_hub_inventory_label.anchor_right  = 1.0
	m_hub_inventory_label.anchor_top    = 0.5
	m_hub_inventory_label.anchor_bottom = 0.5
	m_hub_inventory_label.offset_left   = -220
	m_hub_inventory_label.offset_right  = -16
	m_hub_inventory_label.offset_top    = -80
	m_hub_inventory_label.offset_bottom = 80
	$UILayer.add_child(m_hub_inventory_label)

	_update_hub_inventory_label()


func _update_hub_inventory_label() -> void:
	var inv: HubInventory = GameState.hub_inventory
	var lines: Array[String] = []
	lines.append("[ 보관함 ]")
	if inv.items.is_empty():
		lines.append("  (비어 있음)")
	else:
		for item_id in inv.items:
			var def: ItemDef = ItemDatabase.get_def(item_id)
			var name: String = def.display_name if def != null else str(item_id)
			lines.append("  %s × %d" % [name, inv.items[item_id]])
	m_hub_inventory_label.text = "\n".join(lines)


func _on_start_button_pressed() -> void:
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_skill_tree_button_pressed() -> void:
	m_skill_tree_panel.visible = true
	# visible = true 이후 레이아웃 계산이 끝난 다음 프레임에 refresh 호출
	m_skill_tree_view.call_deferred("refresh")


func _on_close_button_pressed() -> void:
	m_skill_tree_panel.visible = false
