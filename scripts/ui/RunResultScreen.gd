class_name RunResultScreen
extends CanvasLayer

signal hub_requested
signal retry_requested

const END_REASON_FUEL_DEPLETED: StringName = &"fuel_depleted"
const END_REASON_RETURN_TO_HUB: StringName = &"return_to_hub"

@onready var m_root: Control = $Root
@onready var m_title_label: Label = $Root/Center/Card/Margin/Content/TitleLabel
@onready var m_summary_depth_label: Label = $Root/Center/Card/Margin/Content/SummaryDepthLabel
@onready var m_summary_duration_label: Label = $Root/Center/Card/Margin/Content/SummaryDurationLabel
@onready var m_items_list: ItemList = $Root/Center/Card/Margin/Content/ItemsList
@onready var m_hub_button: Button = $Root/Center/Card/Margin/Content/Buttons/HubButton
@onready var m_retry_button: Button = $Root/Center/Card/Margin/Content/Buttons/RetryButton


func _ready() -> void:
	m_hub_button.pressed.connect(_on_hub_button_pressed)
	m_retry_button.pressed.connect(_on_retry_button_pressed)
	m_items_list.focus_mode = Control.FOCUS_NONE
	m_items_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_screen()


func show_results(end_reason: StringName, max_depth_m: float, run_duration_sec: float, items: Dictionary) -> void:
	m_title_label.text = _get_title_for_end_reason(end_reason)
	m_summary_depth_label.text = "최대 깊이: %.1f m" % max_depth_m
	m_summary_duration_label.text = "런 시간: %s" % _format_duration_mm_ss(run_duration_sec)
	_render_items(items)
	show_screen()


func show_screen() -> void:
	m_root.visible = true


func hide_screen() -> void:
	m_root.visible = false


func _render_items(items: Dictionary) -> void:
	m_items_list.clear()
	var has_item: bool = false
	for item_id in items:
		var count: int = int(items[item_id])
		if count <= 0:
			continue
		has_item = true
		var def: ItemDef = ItemDatabase.get_def(StringName(item_id))
		var display_name: String = def.display_name if def != null else str(item_id)
		m_items_list.add_item("%s × %d" % [display_name, count])
	if not has_item:
		m_items_list.add_item("(비어 있음)")


func _get_title_for_end_reason(end_reason: StringName) -> String:
	match end_reason:
		END_REASON_FUEL_DEPLETED:
			return "연료 고갈"
		END_REASON_RETURN_TO_HUB:
			return "거점 복귀"
		_:
			return "런 종료"


func _format_duration_mm_ss(duration_sec: float) -> String:
	var total_sec: int = maxi(int(floor(duration_sec)), 0)
	var minutes: int = total_sec / 60
	var seconds: int = total_sec % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_hub_button_pressed() -> void:
	hub_requested.emit()


func _on_retry_button_pressed() -> void:
	retry_requested.emit()
