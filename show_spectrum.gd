extends Node2D

# ----------------------------
# 1. Variables
# ----------------------------
var circle_x = 0
var r = 2
var g = 1
var b = 5
var color_modulation = 0
# --- SPRITE VARIABLES (MAIN CHARACTER) ---

var animation_timer = 0.0     # To track time for animation
var animation_timer_enemies = 0.0     # To track time for animation
var cooldown_up = true
var current_frame = 0         # Current frame index (0, 1, or 2)
var current_frame_enemies = 0         # Current frame index (0, 1, or 2)
# ------------------------

# --- ENEMY VARIABLES ---
var enemies = []
const MAX_ENEMIES = 3
# -----------------------

const VU_COUNT = 16
const FREQ_MAX = 11050.0

# --- DIMENSIONS ---
const SCREEN_WIDTH = 1600
const SCREEN_HEIGHT = 500
const SPECTRUM_BASE_WIDTH = 800.0 # Base width for spectrum math
var center = Vector2(SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0)

const HEIGHT_SCALE = 8.0
const MIN_DB = 60
const SPECTRUM_ANIMATION_SPEED = 0.1 

# Spectrum visual settings
const SPECTRUM_SCALE = Vector2(0.4, 0.4)
const SPECTRUM_POS = Vector2(650, 20) # Top-rightish, considering scale
const SPECTRUM_OPACITY = 0.4

var spectrum
var min_values = []
var max_values = []


# --- BACKGROUND & SHADER VARIABLES ---
var bg_rect: ColorRect
var lightning_timer = 0.0
var lightning_duration = 0.0
var time_until_next_lightning = 5.0

# --- PLAYER CONTROLLER ---
var player: PlayerController
# -------------------------

# --- UI ---
var game_ui
# ----------


func _ready():
	print("[ShowSpectrum] _ready started.")
	if CombatManager:
		CombatManager.current_game_node = self
	
	spectrum = AudioServer.get_bus_effect_instance(0, 0)
	if not spectrum:
		print("[ShowSpectrum] WARNING: Could not find AudioEffectSpectrumInstance on Bus 0, Effect 0.")
	
	min_values.resize(VU_COUNT)
	max_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.fill(0.0)
	
	var screen_size = Vector2i(SCREEN_WIDTH, SCREEN_HEIGHT)
	get_window().size = screen_size
	print("[ShowSpectrum] Window size set to: ", screen_size)

	# --- SETUP BACKGROUND (RAIN SHADER) ---
	bg_rect = ColorRect.new()
	bg_rect.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg_rect.show_behind_parent = true # Draw BEHIND the _draw logic
	
	var shader = load("res://rain.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg_rect.material = mat
	
	add_child(bg_rect)
	# --------------------------------------
	
	# --- SETUP FLOOR ---
	var floor_rect = ColorRect.new()
	floor_rect.size = Vector2(SCREEN_WIDTH, 40)
	floor_rect.position = Vector2(0, SCREEN_HEIGHT - 50)
	floor_rect.color = Color(0.1, 0.1, 0.15, 0.8) # Dark blueish gray
	floor_rect.name = "Floor"
	add_child(floor_rect)
	# -------------------
	
	# --- SETUP PLAYER CONTROLLER ---
	player = load("res://player_controller.gd").new()
	player.game_node = self
	player.position = center
	add_child(player)
	# -------------------------------
	
	# ---- SETUP CROW PET ---
	for i in range(2):
		var crow = load("res://crow_pet.gd").new()
		crow.position = player.position + Vector2(-50 * (i+1), -50)
		crow.assign_host(player)
		add_child(crow)
	
	# ---- SETUP WEAPON CONTROLLER (AXE) ---
	var axe = load("res://weapon_controller.gd").new()
	axe.host = player
	player.set("axe_ctrl", axe) # Link to player for attack sync
	add_child(axe)

	# ---- SETUP DUST PUFFS ---
	for i in range(3):
		var dust = load("res://dust_puff.gd").new()
		dust.host = player
		dust.position = player.position + Vector2(0, 70)
		add_child(dust)
	
	# --- SETUP HUD ---
	game_ui = load("res://game_ui.gd").new()
	game_ui.player_node = player
	game_ui.cl_controller = player.chain_lightning_ctrl
	game_ui.fc_controller = player.fire_chains_ctrl
	game_ui.meteor_controller = player.meteor_strike_ctrl
	add_child(game_ui)
	# --- SETUP CAMERA ---
	var camera = $Camera2D
	if camera:
		camera.set_script(load("res://game_camera.gd"))
		camera.lerp_speed = 5.0
		print("[ShowSpectrum] Found Camera2D node and attached script.")
		camera.enabled = true
		camera.make_current() 
		camera.setup(player)
		print("[ShowSpectrum] Camera setup complete.")
		
		# Connect Player Signals for FX
		player.cast_start.connect(_on_player_cast_start)
		player.cast_finished.connect(_on_player_cast_finished)
	else:
		print("[ShowSpectrum] WARNING: Camera2D node not found!")
	# -----------------
	
	# --- SETUP ENEMIES ---
	for i in range(MAX_ENEMIES):
		var enemy = load("res://enemy.gd").new()
		enemy.position = Vector2(100 + i * 250, 100 + (i % 2) * 200)
		enemies.append(enemy)
		add_child(enemy)
		
		# Give a crow pet to the second enemy
		if i == 1:
			var enemy_crow = load("res://crow_pet.gd").new()
			enemy_crow.assign_host(enemy)
			# Tint the enemy crow to look more sinister
			enemy_crow.modulate = Color(2.0, 0.5, 2.0) # Purple Sinister Crow
			add_child(enemy_crow)
	
	if PhysicsManager:
		var floor_node = find_child("Floor")
		if floor_node:
			PhysicsManager.floor_y = floor_node.position.y
			
	print("[ShowSpectrum] _ready complete.")



func _on_player_cast_start(duration):
	var cam = $Camera2D
	if not cam: return
	
	# if spell_id == "sword_attack":
	cam.add_shake(12.0)
	cam.set_zoom_target(1.15) # Zoom in slightly
	if player.active_skill_ctrl:
		var spell_id = ""
		if player.active_skill_ctrl.has_method("get_spell_id"):
			spell_id = player.active_skill_ctrl.get_spell_id()
		else:
			print("[ShowSpectrum] WARNING: active_skill_ctrl has no get_spell_id method.")

		if spell_id == "chain_lightning":
			cam.add_shake(12.0)
			cam.set_zoom_target(1.15) # Zoom in slightly
		elif spell_id == "fire_chains":
			cam.add_shake(18.0)
			cam.set_zoom_target(1.2)
		elif spell_id == "meteor_strike":
			cam.add_shake(25.0)
			cam.set_zoom_target(0.85) # Zoom out for impact!

func _on_player_cast_finished():
	var cam = $Camera2D
	if cam:
		print("[ShowSpectrum] Cast finished, resetting zoom.")
		cam.reset_zoom()


func create_spectrum_sprite() -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = load("res://art/SpectrumWithSword.png")
	s.hframes = 3
	s.vframes = 1
	s.scale = Vector2(1, 1) # Keep at 1x or adjusting as needed
	return s

# create_main_character REMOVED (Handled by PlayerController)

func _process(delta):

	# --- LIGHTNING LOGIC (Background) ---
	lightning_timer += delta
	if lightning_timer > time_until_next_lightning:
		lightning_duration = 0.2 # Flash duration
		lightning_timer = 0.0
		time_until_next_lightning = randf_range(3.0, 10.0) # Random next strike
	
	if lightning_duration > 0:
		lightning_duration -= delta
		# Flicker effect
		var strength = randf_range(0.5, 1.0) if lightning_duration > 0.05 else 0.0
		(bg_rect.material as ShaderMaterial).set_shader_parameter("lightning_strength", strength)
	else:
		(bg_rect.material as ShaderMaterial).set_shader_parameter("lightning_strength", 0.0)
	# -----------------------

	# --- INPUT HANDLED BY PLAYER CONTROLLER ---
	# Sync 'center' (Camera focus) to player position
	center = player.position
	
	# Enemies are now self-updating entities

	var data = []
	var prev_hz = 0
	
	# Run your color/math logic
	_other_process_my_stuff()
	
	# --- SPECTRUM LOGIC ---
	if spectrum:
		for i in range(1, VU_COUNT + 1):
			var hz = i * FREQ_MAX / VU_COUNT
			var magnitude = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()
			var energy = clampf((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)
			var height = energy * SCREEN_HEIGHT * HEIGHT_SCALE
			data.append(height)
			prev_hz = hz
	else:
		# Fallback to zeros if spectrum is missing
		for i in range(VU_COUNT):
			data.append(0.0)

	for i in range(VU_COUNT):
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerp(max_values[i], data[i], SPECTRUM_ANIMATION_SPEED)

		if data[i] <= 0.0:
			min_values[i] = lerp(min_values[i], 0.0, SPECTRUM_ANIMATION_SPEED)

	queue_redraw()

# -----------------------------


func _other_process_my_stuff():
	# Increment counters
	color_modulation += 10
	circle_x += 1
	
	# Calculate Colors
	r = int(50 + (200 * sin((20 * PI * color_modulation / 2000.0) + 200)))
	g = int(10 + 128 * sin(2 * PI * color_modulation / 2000.0 + 100 * 2))
	b = int(2 + 255 * sin(2 * PI * color_modulation / 2000.0 + 200 * 3))


func _draw():
	_draw_my_stuff();
	
	# --- DRAW DEBUG HITBOXES ---
	# 1. Draw Player Hurtbox (Green - "Don't hit me here")
	var p_rect = player.get_hurtbox()
	draw_rect(p_rect, Color(0, 1, 0, 0.5), false, 2.0)
	
	# 1b. Draw Player ATTACK Hitbox (Yellow)
	if player.current_state == PlayerController.State.ATTACKING:
		var p_sword_rect = player.get_sword_hitbox()
		draw_rect(p_sword_rect, Color(1, 1, 0, 0.6), false, 3.0)
		draw_rect(p_sword_rect, Color(1, 1, 0, 0.1), true)
	
	for enemy in enemies:
		# 2. Draw Enemy Hurtbox (Blue - "Enemy Body")
		var e_rect = enemy.get_hurtbox()
		draw_rect(e_rect, Color(0, 0.5, 1, 0.3), false, 1.0)
		
		# 3. Draw Enemy Sword Hitbox (Red - "DANGER ZONE")
		# ONLY draw if currently active (Frame 2) before  - > 1
		if enemy.sprite.frame == 1:
			var sword_rect = enemy.get_sword_hitbox()
			draw_rect(sword_rect, Color(1, 0, 0, 0.8), false, 3.0)
			# Optional: Fill it slightly to make it obvious
			draw_rect(sword_rect, Color(1, 0, 0, 0.2), true)
	# -------------------------------

	# --- DRAW SPECTRUM (Top Right, Smaller, Faint) ---
	draw_set_transform(SPECTRUM_POS, 0, SPECTRUM_SCALE)
	
	var w = float(SPECTRUM_BASE_WIDTH) / VU_COUNT
	for i in range(VU_COUNT):
		var min_height = min_values[i]
		var max_height = max_values[i]
		var height = lerp(min_height, max_height, SPECTRUM_ANIMATION_SPEED)

		# Main bar
		draw_rect(
				Rect2(w * i, SCREEN_HEIGHT - height, w - 2, height),
				Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 0.6, SPECTRUM_OPACITY)
		)
		# Top Line
		draw_line(
				Vector2(w * i, SCREEN_HEIGHT - height),
				Vector2(w * i + w - 2, SCREEN_HEIGHT - height),
				Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 1.0, SPECTRUM_OPACITY),
				2.0,
				true
		)

		# Draw a reflection of the bars with lower opacity.
		draw_rect(
				Rect2(w * i, SCREEN_HEIGHT, w - 2, height),
				Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 0.6) * Color(1, 1, 1, SPECTRUM_OPACITY * 0.5)
		)
		draw_line(
				Vector2(w * i, SCREEN_HEIGHT + height),
				Vector2(w * i + w - 2, SCREEN_HEIGHT + height),
				Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 1.0) * Color(1, 1, 1, SPECTRUM_OPACITY * 0.5),
				2.0,
				true
		)
	
	# Reset transform for other things if needed (though _draw usually isolates or runs last here)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1)) 


func _draw_my_stuff():
	# background(#1BB1F5) removed in favor of shader
	# draw_rect(Rect2(0, 0, w_window * 2, h_window), Color("1BB1F5"), true)
	
	var xAmplitude = 100
	var yAmplitude = 200.0 / 2.0
	
	# Update Center
	# REMOVED CHAOTIC MOVEMENT FOR WASD CONTROL
	# center.x = (w_window / 2.0) + modulation(w_window / 4.0, circle_x, 0, 0)
	# center.y = (h_window / 2.0) + modulation(h_window / 4.0, circle_x, 0, 0)
	
	# point(center[0], center[1])
	draw_point(center, Color.WHITE)
	
	# --- Draw Crow Pet handled in crow_pet.gd now ---
	
	# --- Draw Circle 2 ---
	var x_pos_mod = modulation(xAmplitude, circle_x * 8, 890, center.x)
	var y_pos_mod = modulation(yAmplitude, -circle_x * 8, 600000 - 1200, center.y)
	
	var col2 = Color8(200, 200, int(100 + 10 * abs(r)))
	draw_circle(Vector2(x_pos_mod, y_pos_mod), 20.0 / 3.0, col2)

	# --- Draw Circle 3 ---
	x_pos_mod = modulation(xAmplitude, circle_x * 8, 100, center.x)
	y_pos_mod = modulation(yAmplitude, -circle_x * 8, 600000 - 800, center.y)
	
	var col3 = Color8(200, 200, int(190 + abs(r)))
	draw_circle(Vector2(x_pos_mod, y_pos_mod), 20.0 / 4.0, col3)

# Helper function
func modulation(A, freq, phase, offset):
	return A * sin(2 * PI * freq / 2000.0 + phase / 2000.0) + offset

# Helper for drawing a single pixel point (Primitive)
func draw_point(pos, color):
	draw_circle(pos, 1.0, color)


# ----------------------------
