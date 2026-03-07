extends Node2D

# ----------------------------
# 1. Variables & Dimensions (Pixel Perfect 320x180)
# ----------------------------
const SCREEN_WIDTH = 320
const SCREEN_HEIGHT = 180
var center = Vector2(SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0)

# --- MANAGERS ---
var parallax_manager: NativeParallaxManager
var player: PlayerController
var enemies = []
const MAX_MAGES = 5

# --- REFLECTIONS ---
var reflection_manager: NativeReflectionManager
var all_ponds: Array[Node2D] = []
var reflection_nodes: Dictionary = {} # Entity -> ReflectionNode
var background_sprites: Array[Node] = []


# ----------------------------
# 2. Setup
# ----------------------------

func _ready_viewport_container_subpixel_fix():
	var vp = get_viewport()
	Globals.viewport = vp
	
	if vp is SubViewport:
		var parent = vp.get_parent()
		if parent is SubViewportContainer:
			Globals.viewport_container = parent
			print("[ShowSpectrum2] Subpixel fix: Identified parent SubViewportContainer.")
		else:
			print("[ShowSpectrum2] Subpixel fix: Running in SubViewport, but parent is not a Container.")
	else:
		print("[ShowSpectrum2] Subpixel fix: Running in root viewport.")

func _ready():
	_ready_viewport_container_subpixel_fix()
	
	# 1. Window & Viewport Setup (Pixel Perfect)
	var win = get_window()
	win.size = Vector2i(SCREEN_WIDTH * 4, SCREEN_HEIGHT * 4) # 4x upscale for visibility but 1x logical
	get_tree().root.content_scale_size = Vector2i(SCREEN_WIDTH, SCREEN_HEIGHT)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	
	print("[ShowSpectrum2] Initialized Pixel-Perfect 320x180 Viewport.")

	# 2. Backgrounds
	setup_parallax_background()
	
	# 3. Physics Floor
	setup_physics_floor()

	# 4. Player
	setup_player()
	
	# 5. Arcane Mages
	setup_mages()
	
	# 6. Reflections
	setup_reflection_manager()
	setup_ponds()
	
	# 7. Camera
	setup_camera()
	
	# Set CombatManager context
	if CombatManager:
		CombatManager.current_game_node = self

func setup_parallax_background():
	if not ClassDB.class_exists("NativeParallaxManager"):
		return
		
	parallax_manager = NativeParallaxManager.new()
	parallax_manager.name = "NativeParallaxManager"
	add_child(parallax_manager)
	
	var bg_dir = "res://art/environment/parallax-background/night/"
	var layers_config = [
		{"name": "ParallaxMountainBackground - 0.png", "factor": Vector2(1.0, 1.0), "z": - 10}, # Sky stays with camera
		{"name": "ParallaxMountainBackground - 1.png", "factor": Vector2(0.2, 1.0), "z": - 11}, # clouds
		{"name": "ParallaxMountainBackground - 2.png", "factor": Vector2(0.025, 0.05), "z": - 8}, # fog
		{"name": "ParallaxMountainBackground - 3.png", "factor": Vector2(0.6, 0.1), "z": - 7}, # Mid range
		{"name": "ParallaxMountainBackground - 4.png", "factor": Vector2(0.55, 0.1), "z": - 6}, # Mid range
		{"name": "ParallaxMountainBackground - 5.png", "factor": Vector2(0.45, 0.1), "z": - 5}, # Mid range
		{"name": "ParallaxMountainBackground - 6.png", "factor": Vector2(0.0, 0.0), "z": - 4}, # THE GROUND (Gameplay Plane)
		{"name": "ParallaxMountainBackground - 7.png", "factor": Vector2(-0.8, 0.0), "z": 1000} # Foreground passing by
	]
	
	for layer_info in layers_config:
		var tex = load(bg_dir + layer_info.name)
		if tex:
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			
			sprite.region_enabled = true
			var w_mult = 100.0 # Wide enough for infinite feel
			sprite.region_rect = Rect2(0, 0, tex.get_width() * w_mult, tex.get_height())
			
			sprite.scale = Vector2(1, 1) # PIXEL PERFECT 1:1
			
			# Apply -90px vertical offset for Factor.y=1.0 alignment
			var y_offset = 0.0
			if layer_info.name.ends_with("- 0.png"):
				y_offset = -90.0
			if layer_info.name.ends_with("- 1.png"):
				y_offset = -90.0
				sprite.modulate = (Color(1, 1, 1, 0.7)) # Slightly faded for clouds
			if layer_info.name.ends_with("- 2.png"):
				sprite.modulate = (Color(1, 1, 1, 0.3)) # Slightly faded for fog
			if layer_info.name.ends_with("- 3.png"):
				y_offset = -10.0
			if layer_info.name.ends_with("- 4.png"):
				y_offset = -10.0
				
			sprite.position = Vector2(-tex.get_width() * w_mult / 2.0, y_offset)
			sprite.z_index = layer_info.z
			add_child(sprite)
			background_sprites.append(sprite)
			
			# Add subtle drift
			var drift = Vector2(-2.0 * abs(layer_info.z) / 10.0, 0)
			if layer_info.z > 0: drift = Vector2.ZERO
			
			parallax_manager.add_layer_ext(sprite, layer_info.factor, drift)

func setup_physics_floor():
	var static_body = StaticBody2D.new()
	static_body.name = "GroundPhysics"
	add_child(static_body)
	
	var col = CollisionShape2D.new()
	var shape = WorldBoundaryShape2D.new()
	shape.normal = Vector2(0, -1)
	col.shape = shape
	# Place floor near bottom of 180 height image
	col.position = Vector2(0, SCREEN_HEIGHT - 38)
	static_body.add_child(col)
	
	if PhysicsManager:
		PhysicsManager.floor_y = 150

func setup_player():
	player = load("res://player_controller.gd").new()
	player.name = "PixelPlayer"
	player.game_node = self
	# Start on ground
	player.position = Vector2(center.x, SCREEN_HEIGHT - 60)
	add_child(player)

	# ---- SETUP OWL PET ---
	var owl = load("res://owl_pet.gd").new()
	owl.position = player.position + Vector2(-50, -50)
	owl.assign_host(player)
	add_child(owl)
	
	if CombatManager:
		CombatManager.register_entity(player)

func setup_mages():
	for i in range(MAX_MAGES):
		var mage_scene = load("res://arcane_mage.tscn")
		if mage_scene:
			var mage = mage_scene.instantiate()
			mage.position = Vector2(center.x + 300 + i * 200, SCREEN_HEIGHT - 60)
			mage.name = "ArcaneMage_" + str(i)
			enemies.append(mage)
			add_child(mage)
			if CombatManager:
				CombatManager.register_entity(mage)

func setup_camera():
	var cam = get_node_or_null("Camera2D")
	if not cam:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		add_child(cam)
		
	cam.set_script(load("res://game_camera.gd"))
	
	# Adjust for 180p height: We want to see more sky
	# With player at ~140, we want camera at 90 => offset is -50
	cam.target_offset = Vector2(0, -30)
	cam.lerp_speed = 5.0
	
	cam.make_current()
	cam.setup(player)
	
	# Initial snap center on background
	cam.position = Vector2(SCREEN_WIDTH / 3, SCREEN_HEIGHT / 3)
	
	if parallax_manager:
		parallax_manager.camera_node = cam

func setup_reflection_manager():
	if ClassDB.class_exists("NativeReflectionManager"):
		reflection_manager = NativeReflectionManager.new()
		add_child(reflection_manager)

func setup_ponds():
	# We want ponds "between layer 0 and 1"
	# Layer 0 (Sky): Z=-10, Factor=1.0
	# Layer 1 (Mt): Z=-8, Factor=0.8
	var pond_configs = [
		{"pos": Vector2(-150, -5), "size": Vector2(120, 30)},
		{"pos": Vector2(200, -20), "size": Vector2(80, 20)},
		{"pos": Vector2(500, -45), "size": Vector2(150, 40)}
	]
	
	for cfg in pond_configs:
		var pond = Node2D.new()
		pond.name = "Pond_" + str(all_ponds.size())
		pond.position = cfg.pos
		pond.z_index = -9 # Between -10 and -8
		add_child(pond)
		
		# structure required by C++: Pond -> Polygon2D "PondWater" -> Node2D "Reflections"
		var water = Polygon2D.new()
		water.name = "PondWater"
		var half_w = cfg.size.x / 2.0
		var half_h = cfg.size.y / 2.0
		water.polygon = PackedVector2Array([
			Vector2(-half_w, 0),
			Vector2(half_w, 0),
			Vector2(half_w * 0.8, cfg.size.y),
			Vector2(-half_w * 0.8, cfg.size.y)
		])
		water.color = Color(0.1, 0.3, 0.6, 0.5) # Deep water blue, semi-trans
		water.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		pond.add_child(water)
		
		var ref_cont = Node2D.new()
		ref_cont.name = "Reflections"
		water.add_child(ref_cont)
		
		all_ponds.append(pond)
		
		# Add to parallax manager, snapped to sky (Factor 1.0)
		if parallax_manager:
			parallax_manager.add_layer_ext(pond, Vector2(1.0, 1.0), Vector2.ZERO)

func _update_reflections():
	if not reflection_manager: return
	
	# 1. Collect entities to reflect
	var reflect_targets: Array[Node2D] = []
	if is_instance_valid(player):
		reflect_targets.append(player)
		# Ensure player has a reflection node
		if not reflection_nodes.has(player):
			var ref = Node2D.new()
			ref.name = "PlayerReflection"
			# The manager will Parent it to the correct pond container dynamically
			reflection_nodes[player] = ref

	for mage in enemies:
		if is_instance_valid(mage):
			reflect_targets.append(mage)
			if not reflection_nodes.has(mage):
				var ref = Node2D.new()
				ref.name = "MageReflection_" + mage.name
				reflection_nodes[mage] = ref
	
	# 2. Cleanup invalid nodes in dictionary
	var to_erase = []
	for key in reflection_nodes.keys():
		if not is_instance_valid(key):
			if is_instance_valid(reflection_nodes[key]):
				reflection_nodes[key].queue_free()
			to_erase.append(key)
	for key in to_erase:
		reflection_nodes.erase(key)

	# 3. Process
	# void process_reflections(all_ponds, reflection_nodes, entities, world_children, player, player_light, moon_light, current_frame, screen_height)
	reflection_manager.process_reflections(
		all_ponds,
		reflection_nodes,
		reflect_targets,
		background_sprites, # manual_visuals
		player,
		null, # player_light (optional)
		null, # moon_light (optional)
		Engine.get_process_frames(),
		SCREEN_HEIGHT
	)

func _process(delta):
	# Center logical focus (used by some spell math)
	if is_instance_valid(player):
		center = player.position
	
	_update_reflections()

# --- SIGNAL STUBS (to prevent crashes if player emits) ---
func _on_player_cast_start(_duration): pass
func _on_player_cast_finished(): pass
