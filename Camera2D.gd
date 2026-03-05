extends Camera2D
var actual_cam_pos : Vector2
const lerp_speed = 10.0

func _ready_viewport_container_subpixel_fix():
	var vp = get_viewport()
	Globals.viewport = vp
	
	if vp is SubViewport:
		var parent = vp.get_parent()
		if parent is SubViewportContainer:
			Globals.viewport_container = parent
			print("[Camera2D] Subpixel fix: Identified parent SubViewportContainer.")
		else:
			print("[Camera2D] Subpixel fix: Running in SubViewport, but parent is not a Container.")
	else:
		print("[Camera2D] Subpixel fix: Running in root viewport.")
# Called when the node enters the scene tree for the first time.
func _ready():
	_ready_viewport_container_subpixel_fix()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	actual_cam_pos = actual_cam_pos.lerp($"../Player".global_position, lerp_speed * delta)
	var cam_subpixel_offset = actual_cam_pos.round() - actual_cam_pos
	Globals.viewport_container.material.set_shader_parameter("camera_offset", cam_subpixel_offset)

	global_position = actual_cam_pos.round()
	pass
