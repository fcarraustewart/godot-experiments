extends Polygon2D

class_name DebugMarker

# A reusable debug marker for spatial verification.
# Automatically cleans itself up after a duration.

func _ready():
	z_index = 100 # Top of everything
	if not polygon:
		# Default to a cross shape
		var size = 10.0
		polygon = PackedVector2Array([
			Vector2(-size, -2), Vector2(size, -2), Vector2(size, 2), Vector2(-size, 2), # Horiz
			Vector2(-2, -size), Vector2(2, -size), Vector2(2, size), Vector2(-2, size)  # Vert
		])
	
	if color == Color.WHITE:
		color = Color(1.0, 0.0, 0.5, 0.8) # Default to bright magenta for visibility

func setup(pos: Vector2, duration: float = 1.0, marker_color: Color = Color(1.0, 0.0, 0.5, 0.8)):
	global_position = pos
	color = marker_color
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)

static func create(parent: Node, pos: Vector2, duration: float = 1.0, marker_color: Color = Color(1.0, 0.0, 0.5, 0.8)) -> DebugMarker:
	var marker = DebugMarker.new()
	parent.add_child(marker)
	marker.setup(pos, duration, marker_color)
	return marker
