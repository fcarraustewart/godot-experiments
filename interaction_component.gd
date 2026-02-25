extends Node

class_name InteractionComponent

## InteractionComponent
## Scans nearby BaseEntity nodes for interaction, shows a floating [E] prompt bubble,
## and opens a small dialog when the player presses KEY_E (action: "interact").

signal interaction_started(entity: Node2D)
signal interaction_ended()

@export var scan_radius: float = 80.0

var _player: Node2D
var _prompt_label: Label = null
var _prompt_tween: Tween = null
var _dialog_panel: Panel = null
var _active_entity: Node2D = null
var _prompt_base_y: float = 0.0

func _init(player: Node2D) -> void:
	_player = player

func _ready() -> void:
	# Hook into KeybindListener for KEY_E
	if KeybindListener:
		if KeybindListener.has_signal("action_triggered"):
			KeybindListener.action_triggered.connect(_on_action)

func update(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var nearest = _scan_nearest()
	if is_instance_valid(nearest):
		if nearest != _active_entity:
			hide_prompt()
			_active_entity = nearest
			show_prompt(nearest)
	else:
		if is_instance_valid(_active_entity):
			hide_prompt()
			_active_entity = null

# --- PROMPT ---

func show_prompt(entity: Node2D) -> void:
	if _prompt_label and is_instance_valid(_prompt_label):
		_prompt_label.queue_free()

	_prompt_label = Label.new()
	_prompt_label.text = "[E]"
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	_prompt_label.add_theme_font_size_override("font_size", 14)

	# Position above the entity
	var entity_height = entity.get("feet_offset") if "feet_offset" in entity else 32.0
	_prompt_base_y = -entity_height - 24.0

	var container = Node2D.new()
	container.name = "InteractPrompt"
	container.position = Vector2(-10, _prompt_base_y)
	container.add_child(_prompt_label)
	entity.add_child(container)

	# Bobbing tween
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = entity.create_tween().set_loops()
	_prompt_tween.tween_property(container, "position:y", _prompt_base_y - 6.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(container, "position:y", _prompt_base_y, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func hide_prompt() -> void:
	if is_instance_valid(_prompt_label):
		var parent = _prompt_label.get_parent()
		if parent:
			parent.queue_free()
		else:
			_prompt_label.queue_free()
		_prompt_label = null
	if _prompt_tween:
		_prompt_tween.kill()
		_prompt_tween = null

# --- DIALOG ---

func open_dialog(entity: Node2D) -> void:
	if _dialog_panel and is_instance_valid(_dialog_panel):
		return  # Already open

	var entity_height = entity.get("feet_offset") if "feet_offset" in entity else 32.0
	var entity_name_str = entity.get("entity_name") if "entity_name" in entity else entity.name

	# Build bubble panel
	_dialog_panel = Panel.new()
	_dialog_panel.custom_minimum_size = Vector2(160, 50)
	_dialog_panel.position = Vector2(-80, -entity_height - 80.0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.8, 1.0, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_dialog_panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = entity_name_str + "\n\"Hello, traveller.\""
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	lbl.position = Vector2(8, 8)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(144, 0)
	_dialog_panel.add_child(lbl)

	entity.add_child(_dialog_panel)
	emit_signal("interaction_started", entity)

func close_dialog() -> void:
	if is_instance_valid(_dialog_panel):
		_dialog_panel.queue_free()
		_dialog_panel = null
	emit_signal("interaction_ended")

# --- INTERNALS ---

func _scan_nearest() -> Node2D:
	var entities = _player.get_tree().get_nodes_in_group("Enemies") + \
				   _player.get_tree().get_nodes_in_group("NPC")
	var best: Node2D = null
	var best_dist: float = scan_radius * scan_radius
	for e in entities:
		if not is_instance_valid(e): continue
		var d = _player.global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func _on_action(action_name: String, _data: Dictionary) -> void:
	if action_name != "interact":
		return
	if is_instance_valid(_dialog_panel):
		close_dialog()
	elif is_instance_valid(_active_entity):
		# Check for ItemComponent first
		if _active_entity.has_method("interact"):
			_active_entity.interact(_player)
		else:
			open_dialog(_active_entity)
