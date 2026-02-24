extends Node2D

class_name ItemComponent

## ItemComponent
## Attach to any Node2D to make it a world item: floating name label, pickup, drop.
## Works with InventoryComponent and InteractionComponent.

signal picked_up(by: Node2D)
signal dropped(at: Vector2)

@export var item_id: String = "unknown_item"
@export var item_name: String = "Item"
@export var pickup_radius: float = 48.0
@export var auto_pickup: bool = false  ## If true, picks up when player walks into range

var _floating_label: Label
var _label_container: Node2D
var _bob_tween: Tween

func _ready() -> void:
	_build_floating_label()
	if auto_pickup:
		var area = Area2D.new()
		var shape_node = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = pickup_radius
		shape_node.shape = circle
		area.add_child(shape_node)
		area.body_entered.connect(_on_body_entered)
		add_child(area)

func _build_floating_label() -> void:
	_label_container = Node2D.new()
	_label_container.position = Vector2(0, -32)

	_floating_label = Label.new()
	_floating_label.text = item_name
	_floating_label.add_theme_font_size_override("font_size", 11)
	_floating_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_floating_label.position = Vector2(-_floating_label.size.x * 0.5, 0)
	_label_container.add_child(_floating_label)
	add_child(_label_container)

	# Bobbing animation
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_label_container, "position:y", -38.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_label_container, "position:y", -28.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Called by InteractionComponent when player presses E near this item.
func interact(by: Node2D) -> void:
	pickup(by)

## Pick up this item: adds to picker's InventoryComponent if present, then removes from world.
func pickup(by: Node2D) -> void:
	var inv: InventoryComponent = _find_inventory(by)
	if inv:
		inv.add_item(item_id, item_name)
	emit_signal("picked_up", by)
	if _bob_tween:
		_bob_tween.kill()
	# Fade out and free
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)

## Drop this item in the world at a given position.
func drop(at: Vector2) -> void:
	# We don't queue_free here — the item may already be in the scene or be re-created
	global_position = at
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
	# Bounce effect
	t.parallel().tween_property(self, "position:y", at.y - 12.0, 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", at.y, 0.1).set_ease(Tween.EASE_IN)
	emit_signal("dropped", at)

# --- INTERNALS ---

func _find_inventory(node: Node2D) -> InventoryComponent:
	for child in node.get_children():
		if child is InventoryComponent:
			return child
	return null

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		pickup(body)
