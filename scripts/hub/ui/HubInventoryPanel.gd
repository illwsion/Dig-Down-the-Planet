extends PanelContainer

signal dollars_changed

#region Constants
const c_ItemRowScene := preload("res://scenes/hub/ui/ItemRow.tscn")
const c_CategoryRaw := &"raw"
const c_CategoryProcessed := &"processed"
#endregion

#region Private Fields
@onready var m_tab_bar: TabBar = $VBoxContainer/TabBar
@onready var m_item_list: VBoxContainer = $VBoxContainer/ScrollContainer/ItemListContainer
@onready var m_sell_all_button: Button = $VBoxContainer/SellAllButton

var m_current_category: StringName = c_CategoryRaw
#endregion

#region Unity Lifecycle
func _ready() -> void:
	m_tab_bar.tab_changed.connect(_on_tab_changed)
	m_sell_all_button.pressed.connect(_on_sell_all_pressed)
	GameState.hub_inventory.inventory_changed.connect(refresh)
#endregion

#region Public Methods
## 외부에서 갱신이 필요할 때 호출 (귀환 후, 판매 후 등).
func refresh() -> void:
	_refresh_list(m_current_category)
#endregion

#region Private Methods
func _on_tab_changed(_tab: int) -> void:
	m_current_category = c_CategoryProcessed if _tab == 1 else c_CategoryRaw
	_refresh_list(m_current_category)


func _on_sell_all_pressed() -> void:
	for item_id in GameState.hub_inventory.items.duplicate():
		var def: ItemDef = ItemDatabase.get_def(item_id)
		if def == null or def.sell_price <= 0:
			continue
		var count: int = GameState.hub_inventory.get_count(item_id)
		GameState.hub_inventory.remove_item(item_id, count)
		GameState.dollars += def.sell_price * count
	_refresh_list(m_current_category)
	dollars_changed.emit()


func _refresh_list(_category: StringName) -> void:
	for child in m_item_list.get_children():
		child.queue_free()

	for item_id in GameState.hub_inventory.discovered:
		var def: ItemDef = ItemDatabase.get_def(item_id)
		if def == null or def.category != _category:
			continue
		var count: int = GameState.hub_inventory.get_count(item_id)
		var row: HBoxContainer = c_ItemRowScene.instantiate()
		m_item_list.add_child(row)
		row.setup(def, count)
		row.item_sold.connect(func(): dollars_changed.emit())
#endregion
