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

# ----------------------------
# 2. Setup
# ----------------------------

func _ready():
	# 1. Window & Viewport Setup (Pixel Perfect)
	var win = get_window()
	win.size = Vector2i(SCREEN_WIDTH * 4, SCREEN_HEIGHT * 4) # 4x upscale for visibility but 1x logical
	get_tree().root.content_scale_size = Vector2i(SCREEN_WIDTH, SCREEN_HEIGHT)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	print("[ShowSpectrum2] Initialized Pixel-Perfect 320x180 Viewport.")

	# 2. Backgrounds
	setup_parallax_background()
	
	# 3. Physics Floor (Based on Mountain 3 ground level)
	# Assuming the 'ground' in the 180px high image is near the bottom
	setup_physics_floor()

	# 4. Player
	setup_player()
	
	# 5. Arcane Mages
	setup_mages()
	
	# 6. Camera
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
	
	var bg_dir = "res://art/environment/parallax-background/"
	var layers_config = [
		{"name": "ParallaxMountainBackground - 0.png", "factor": Vector2(0.005, 0.0), "z": - 10},
		{"name": "ParallaxMountainBackground - 1.png", "factor": Vector2(0.012, 0.0), "z": - 8},
		{"name": "ParallaxMountainBackground - 2.png", "factor": Vector2(0.25, 0.0), "z": - 6},
		{"name": "ParallaxMountainBackground - 3.png", "factor": Vector2(0.50, 0.0), "z": - 4}, # The Ground
		{"name": "ParallaxMountainBackground - 4.png", "factor": Vector2(-1.20, 0.0), "z": 1000} # Foreground
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
			sprite.position = Vector2(-tex.get_width() * w_mult / 2.0, 0)
			sprite.z_index = layer_info.z
			add_child(sprite)
			
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
	col.position = Vector2(0, 150)
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
	cam.target_offset = Vector2(0, -50)
	cam.lerp_speed = 5.0
	
	cam.make_current()
	cam.setup(player)
	
	# Initial snap center on background
	cam.position = Vector2(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
	
	if parallax_manager:
		parallax_manager.camera_node = cam

func _process(delta):
	# Center logical focus (used by some spell math)
	if is_instance_valid(player):
		center = player.position

# --- SIGNAL STUBS (to prevent crashes if player emits) ---
func _on_player_cast_start(_duration): pass
func _on_player_cast_finished(): pass
