class_name BaseFlockSwarm
extends NativeSwarmManager

# --- CONFIGURATION ---
@export_group("Visuals")
@export var unit_count: int = 10
@export var spawn_radius: float = 100.0
@export var texture: Texture2D
@export var unit_mesh_scale: Vector2 = Vector2(1.0, 1.0)
@export var use_colors: bool = false
@export var manual_spawn: bool = false  ## Set true to skip auto setup_swarm in _ready
@export var debug_mode: bool = false : set = _set_debug_mode

var mm_instance: MultiMeshInstance2D
var debug_mm_instance: MultiMeshInstance2D

func _ready():
	_setup_rendering()
	if debug_mode:
		_setup_debug_rendering()
	if not manual_spawn:
		spawn_flock()

func _process(_delta):
	# Keep native base color in sync with Node2D's modulate for tweens/anims
	base_color = modulate
	
	if debug_mode:
		_update_debug_visuals()

func _set_debug_mode(val):
	debug_mode = val
	if is_inside_tree():
		_setup_rendering()
		if debug_mode:
			_setup_debug_rendering()
		elif is_instance_valid(debug_mm_instance):
			debug_mm_instance.visible = false

func _setup_rendering():
	if is_instance_valid(mm_instance): mm_instance.queue_free()
	
	mm_instance = MultiMeshInstance2D.new()
	mm_instance.name = "MainSwarmRenderer"
	add_child(mm_instance)
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = use_colors
	mm.instance_count = 0
	
	# Fix: Always provide at least a tiny mesh to avoid rasterizer errors if no texture
	var mesh = QuadMesh.new()
	if texture:
		mesh.size = texture.get_size() * unit_mesh_scale
	else:
		mesh.size = Vector2(1, 1) # Tiny placeholder
	mm.mesh = mesh
	
	mm_instance.multimesh = mm
	
	if texture:
		var sprite_mat = ShaderMaterial.new()
		sprite_mat.shader = load("res://art/simple_texture.gdshader")
		sprite_mat.set_shader_parameter("main_texture", texture)
		mm_instance.material = sprite_mat
	elif not debug_mode:
		# If no texture and no debug mode, make it invisible
		mm_instance.visible = false
	
	set_multimesh_instance(mm_instance)
	
	# Handle debug rendering setup/teardown here
	if debug_mode:
		_setup_debug_rendering()
	elif is_instance_valid(debug_mm_instance):
		debug_mm_instance.queue_free()
		debug_mm_instance = null # Clear the reference

func _setup_debug_rendering():
	if is_instance_valid(debug_mm_instance): debug_mm_instance.queue_free()
	
	debug_mm_instance = MultiMeshInstance2D.new()
	debug_mm_instance.name = "DebugRenderer"
	add_child(debug_mm_instance)
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = 0
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(32, 32) # Larger debug circles
	mm.mesh = mesh
	debug_mm_instance.multimesh = mm
	
	var debug_mat = ShaderMaterial.new()
	debug_mat.shader = load("res://art/debug_swarm.gdshader")
	debug_mm_instance.material = debug_mat
	
	debug_mm_instance.z_as_relative = false
	debug_mm_instance.z_index = 100 

func _update_debug_visuals():
	if not is_instance_valid(debug_mm_instance) or not is_instance_valid(mm_instance): return
	var count = get_unit_count()
	if debug_mm_instance.multimesh.instance_count != count:
		debug_mm_instance.multimesh.instance_count = count
		
	for i in range(count):
		var xform = mm_instance.multimesh.get_instance_transform_2d(i)
		# Ensure debug mesh is visible even if main unit is scaled small
		var s = xform.get_scale()
		if s.length() < 0.5:
			# FIX: Only scale the basis (rotation/scale), NOT the origin (position)
			xform.x = xform.x.normalized() * 2.0
			xform.y = xform.y.normalized() * 2.0
			
		debug_mm_instance.multimesh.set_instance_transform_2d(i, xform)
		debug_mm_instance.multimesh.set_instance_color(i, Color.CYAN)

func spawn_flock():
	setup_swarm(unit_count, spawn_radius)


