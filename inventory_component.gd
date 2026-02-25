extends Node

class_name InventoryComponent

## InventoryComponent
## Stores a list of items, opens/closes a floating inventory UI panel via KEY_I.

signal inventory_opened()
signal inventory_closed()
signal item_added(item_id: String)
signal item_removed(item_id: String)

var items: Array = []  # Array of {id, name, quantity} Dictionaries

var _ui_layer: CanvasLayer = null
var _panel: Panel = null
var _grid: GridContainer = null
var _is_open: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(260, 300)
	_panel.position = Vector2(20, 20)
	_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)

	var title = Label.new()
	title.text = "⚗ Inventory"
	title.position = Vector2(10, 8)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_panel.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.position = Vector2(10, 36)
	_grid.custom_minimum_size = Vector2(240, 240)
	_panel.add_child(_grid)

	_ui_layer.add_child(_panel)

# --- PUBLIC API ---

func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()

func _open() -> void:
	_is_open = true
	_refresh_grid()
	_panel.visible = true
	emit_signal("inventory_opened")

func _close() -> void:
	_is_open = false
	_panel.visible = false
	emit_signal("inventory_closed")

func add_item(item_id: String, item_name: String = "", quantity: int = 1) -> void:
	for i in items:
		if i["id"] == item_id:
			i["quantity"] += quantity
			if _is_open: _refresh_grid()
			emit_signal("item_added", item_id)
			return
	items.append({"id": item_id, "name": item_name if item_name else item_id, "quantity": quantity})
	if _is_open: _refresh_grid()
	emit_signal("item_added", item_id)

func remove_item(item_id: String, quantity: int = 1) -> void:
	for i in range(items.size()):
		if items[i]["id"] == item_id:
			items[i]["quantity"] -= quantity
			if items[i]["quantity"] <= 0:
				items.remove_at(i)
			if _is_open: _refresh_grid()
			emit_signal("item_removed", item_id)
			return

func has_item(item_id: String) -> bool:
	for i in items:
		if i["id"] == item_id: return true
	return false

# --- INTERNALS ---

func _refresh_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for item in items:
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(52, 52)
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.3, 0.4, 0.6)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", slot_style)

		var lbl = Label.new()
		lbl.text = item["name"].substr(0, 6) + "\nx" + str(item["quantity"])
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		lbl.position = Vector2(3, 4)
		slot.add_child(lbl)
		_grid.add_child(slot)

func _on_action(action_name: String, _data: Dictionary) -> void:
	if action_name == "inventory":
		toggle()
