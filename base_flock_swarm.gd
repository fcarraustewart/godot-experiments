class_name BaseFlockSwarm
extends NativeSwarmManager

# --- CONFIGURATION ---
@export_group("Visuals")
@export var unit_count: int = 10
@export var spawn_radius: float = 100.0
@export var texture: Texture2D
@export var unit_mesh_scale: Vector2 = Vector2(1.0, 1.0)
@export var use_colors: bool = false
@export var manual_spawn: bool = false ## Set true to skip auto setup_swarm in _ready
@export var debug_mode: bool = false: set = _set_debug_mode

var mm_instance: MultiMeshInstance2D
var debug_mm_instance: MultiMeshInstance2D
# New array to hold the individual light nodes
var light_nodes: Array[LightSpirit] = []

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

	# Sync each light to its corresponding unit
	# Note: Instance transforms are local to the MultiMeshInstance node
	var base_pos = mm_instance.global_position
	for i in range(get_unit_count()):
		var xform = mm_instance.multimesh.get_instance_transform_2d(i)
		if i < light_nodes.size():
			# Apply the unit's local offset to the renderer's global position
			light_nodes[i].global_position = base_pos + xform.origin

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

func update_material(new_texture):
	mm_instance.material.set_shader_parameter("main_texture", new_texture)

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

	# Clean up old lights if re-initializing
	for l in light_nodes:
		if is_instance_valid(l):
			l.queue_free()
	light_nodes.clear()

	var count = get_unit_count()

	# Create one LightSpirit for every unit
	for i in range(count):
		var l: LightSpirit = LightSpirit.new()
		l.color = Color(1.5, 0.6, 1.2, 0.8)
		l.radius = 10.0
		l.intensity = 2.0
		l.z_index = 100 # Ensure lights render above the swarm units but below other effects
		# Add to the SWARM manager, not the MultiMeshInstance
		add_child(l)
		light_nodes.append(l)

func on_interaction_failed(reason: String):
	# get_children().on_interaction_failed()
	print("[BaseFlockSwarm] combat manager failed interaction. Reason ", reason)
	pass

func on_interaction_success(msg, _meta):
	print("[BaseFlockSwarm] combat manager interaction success. Reason ", msg)
	# On CombatManager ack: Explode the missile that hit player

	# Sync each light to its corresponding unit
	# Note: Instance transforms are local to the MultiMeshInstance node
	var base_pos = mm_instance.global_position
	for i in range(get_unit_count()):
		var xform = mm_instance.multimesh.get_instance_transform_2d(i)
		if i < light_nodes.size():
			# Apply the unit's local offset to the renderer's global position
			light_nodes[i].global_position = base_pos + xform.origin
			light_nodes[i].radius = 200.0
			light_nodes[i].intensity = 20.0
			var tween = create_tween()
			tween.parallel().tween_property(light_nodes[i], "intensity", 0, 0.2)
			set_new_color(i, Color.WHITE)
	
	var tween = create_tween()
	tween.parallel().tween_property(light_nodes[light_nodes.size()-1], "intensity", 0, 0.9)
	tween.tween_callback(self.queue_free)

	pass

func set_new_color(index: int, color: Color):
    # # 1. Update the Main Visuals
	pass
    # mm_instance.multimesh.set_instance_color(index, color)
    
    # # 2. Update the Debug Visuals if they exist
    # if is_instance_valid(debug_mm_instance):
    #     debug_mm_instance.multimesh.set_instance_color(index, color)
        
    # # 3. If using the Node Array approach, recolor the light too
    # if index < light_nodes.size():
    #     light_nodes[index].color = color
    #     light_nodes[index].setup_visuals() # Refresh the light visuals
