extends HBoxContainer

signal item_sold

#region Private Fields
@onready var m_icon: TextureRect = $Icon
@onready var m_name_label: Label = $NameLabel
@onready var m_count_label: Label = $CountLabel
@onready var m_sell_button: Button = $SellButton
@onready var m_initial_delay_timer: Timer = $InitialDelayTimer
@onready var m_repeat_timer: Timer = $RepeatTimer

var m_item_id: StringName = &""
var m_sell_price: int = 0
#endregion

#region Unity Lifecycle
func _ready() -> void:
	m_sell_button.button_down.connect(_on_sell_button_down)
	m_sell_button.button_up.connect(_on_sell_button_up)
	m_initial_delay_timer.timeout.connect(_on_initial_delay_timeout)
	m_repeat_timer.timeout.connect(_on_repeat_timeout)
#endregion

#region Public Methods
func setup(_def: ItemDef, _count: int) -> void:
	m_item_id    = _def.id
	m_sell_price = _def.sell_price

	if _def.icon != null:
		m_icon.texture = _def.icon
	m_name_label.text  = _def.display_name
	m_count_label.text = "×%d" % _count
	m_sell_button.disabled = (_count <= 0)
#endregion

#region Private Methods
func _on_sell_button_down() -> void:
	_sell_one()
	m_initial_delay_timer.start()

func _on_sell_button_up() -> void:
	m_initial_delay_timer.stop()
	m_repeat_timer.stop()

func _on_initial_delay_timeout() -> void:
	m_repeat_timer.start()

func _on_repeat_timeout() -> void:
	_sell_one()

func _sell_one() -> void:
	if GameState.hub_inventory.get_count(m_item_id) <= 0:
		m_repeat_timer.stop()
		m_initial_delay_timer.stop()
		return

	GameState.hub_inventory.remove_item(m_item_id, 1)
	GameState.dollars += m_sell_price
	item_sold.emit()

	var remaining: int = GameState.hub_inventory.get_count(m_item_id)
	m_count_label.text = "×%d" % remaining
	if remaining <= 0:
		m_repeat_timer.stop()
		m_initial_delay_timer.stop()
		m_sell_button.disabled = true
#endregion
