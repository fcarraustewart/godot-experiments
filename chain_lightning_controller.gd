extends Node

# --- SKILL: CHAIN LIGHTNING VARIABLES ---
var chain_cooldown = 0.0
const CHAIN_COOLDOWN_MAX = 3.0 
const CHAIN_RANGE = 500.0 # Increased range
const CHAIN_JUMPS = 3
const CHAIN_DMG_DECAY = 0.8
const OVERLOAD_CHANCE = 0.33

# --- CASTING VARIABLES ---
var is_casting = false
var cast_timer = 0.0
const CAST_TIME = 1.5 # 3.5 seconds charge time
var current_target: Sprite2D = null
var charge_effect_node: Node2D = null

# Reference to the main game node 
var game_node: Node2D

func _ready():
	pass

func _process(delta):
	# Cooldown management
	if chain_cooldown > 0 and not is_casting:
		chain_cooldown -= delta
	if chain_cooldown > 0 and is_casting:
		chain_cooldown = 0


func cast(casting_elapsed_time: int, _from_above: bool = false):
	# Casting Logic
	if is_casting:
		cast_timer = casting_elapsed_time
		# Update Charge Effect position if target moved or player moved (optional, for now on player)
		if charge_effect_node and game_node:
			charge_effect_node.position = game_node.player.position
			
		if cast_timer >= CAST_TIME:
			is_casting = false
			cast_timer = 0.0
			# Fire the skill
			fire_chain_lightning(game_node.player.position)
			if charge_effect_node:
				charge_effect_node.queue_free()
				charge_effect_node = null
	else:
		cast_timer = 0.0
		interrupt_charging()

# Public API
func try_cast_chain_lightning(source: Vector2):
	if chain_cooldown <= 0 and not is_casting:
		# Find target first
		var target = get_nearest_enemy(source, null)
		if target:
			start_charging(source, target)
			return target.position
		else:
			print("No targets in range!")
			return Vector2.ZERO

func interrupt_charging():
	is_casting = false
	cast_timer = 0.0
	current_target = null

	if charge_effect_node:
		charge_effect_node.queue_free()
		charge_effect_node = null


	print("Interrupted Casting Chain Lightning...")

func start_charging(source: Vector2, target):
	is_casting = true
	cast_timer = 0.0
	current_target = target
	
	# Visual Charge Effect (Blue gathering energy)
	charge_effect_node = Node2D.new()
	var charge_circle = Polygon2D.new() 
	var points = PackedVector2Array()
	var radius = 30.0
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	charge_circle.polygon = points
	charge_circle.color = Color(0.6, 0.9, 1.0, 0.6) # Bright Blue Core
	charge_circle.position = source

	charge_effect_node.add_child(charge_circle)
	
	game_node.player.add_child(charge_effect_node)
	
	# Tween the charge up (expanding glow)
	var tween = create_tween()
	tween.parallel().tween_property(charge_circle, "modulate:a", 1.5, CAST_TIME)
	tween.parallel().tween_property(charge_circle, "modulate:scale", 2.5, CAST_TIME)
	tween.tween_callback(charge_circle.queue_free)

func fire_chain_lightning(source: Vector2 = Vector2.ZERO):
	if not game_node or not current_target: return
	
	# Re-validate target distance? For now, just fire if they exist.
	chain_cooldown = CHAIN_COOLDOWN_MAX
	cast_chain_lightning(source, current_target, CHAIN_JUMPS, 1.0, true)

# Internal Logic
func get_nearest_enemy(from_pos: Vector2, exclude_enemy: Sprite2D) -> Sprite2D:
	var nearest: Sprite2D = null
	var min_dist = 999999.0
	
	if not game_node or "enemies" not in game_node: return null
		
	for enemy in game_node.enemies:
		if enemy == exclude_enemy: continue
		var d = from_pos.distance_to(enemy.position)
		if d < CHAIN_RANGE and d < min_dist:
			min_dist = d
			nearest = enemy
	return nearest

func cast_chain_lightning(start_pos: Vector2, target: Sprite2D, jumps: int, power: float, is_primary: bool):
	if target == null or jumps <= 0: return

	# 1. BEAM from Source to Target
	# Increased duration to 0.5s for visibility
	create_lightning_beam(start_pos, target.position, power, 0.5) 
	
	# 2. EXPLOSION at Target
	create_lightning_explosion(target.position, power)
	
	# 3. Hit Effect
	target.modulate = Color(4.0, 4.0, 20.0) # EVEN BRIGHTER BLUE
	
	# 4. Overload logic
	if is_primary and randf() < OVERLOAD_CHANCE:
		print("Overload!")
		# Secondary beam styling
		create_lightning_beam(start_pos + Vector2(50*randf(),50*randf()), target.position, power * 0.5, 0.3)
		create_lightning_explosion(target.position + Vector2(50*randf(),50*randf()), power * 0.5)

	# 5. Chain next
	await get_tree().create_timer(0.15).timeout
	var next_target = get_nearest_enemy(target.position, target)
	
	if next_target:
		cast_chain_lightning(target.position, next_target, jumps - 1, power * CHAIN_DMG_DECAY, true)

func create_lightning_beam(from: Vector2, to: Vector2, power: float, duration: float):
	var line = Line2D.new()
	# Much Thicker: was 15, now 60 to accomodate shader glow space
	line.width = 60.0 * power 
	line.default_color = Color(0.6, 0.9, 1.0, 1.0) # Cyan-ish White
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH # Stretch UVs 0..1 across whole line
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://chain_lightning.gdshader")
	# Customize shader params for "High Energy" look
	mat.set_shader_parameter("beams", 5.0) # More strands
	mat.set_shader_parameter("energy", 5.0) # Even Brighter
	mat.set_shader_parameter("thickness", 0.08 * power) # Thicker core
	mat.set_shader_parameter("roughness", 0.4)
	mat.set_shader_parameter("frequency", 15.0)
	mat.set_shader_parameter("speed", 4.0) # Faster
	mat.set_shader_parameter("outline_color", Color(0.1, 0.4, 1.5, 1.0)) # HDR Blue
	line.material = mat
	
	line.add_point(from)
	line.add_point(to)
	
	game_node.add_child(line)
	
	# Flash & Fade
	var tween = create_tween()
	# Stay fully visible for a fraction of the duration (Pop in)
	tween.tween_interval(duration * 0.3) 
	# Then quickly fade out
	tween.tween_property(line, "modulate:a", 0.0, duration * 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(line.queue_free)

func create_lightning_explosion(pos: Vector2, power: float):
	var sprite = Sprite2D.new()
	sprite.texture = load("res://art/lightning_impact.png")
	sprite.position = pos
	sprite.scale = Vector2(0.1, 0.1) * power
	
	# HDR Blue Glow
	sprite.modulate = Color(2.0, 4.0, 10.0, 1.0)
	
	game_node.add_child(sprite)

		# Create a flashy sprite or circle expanding
	var burst = Line2D.new()
	burst.width = 0
	burst.default_color = Color(0.5, 0.8, 1.0, 0.8)
	burst.begin_cap_mode = Line2D.LINE_CAP_ROUND
	burst.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Draw a small circle approximation
	for i in range(10):
		burst.add_point(Vector2.ZERO) 
	
	# Actually, simple Sprite or Polygon is better, but let's use a thick Line2D point for "flash"
	var flash = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = 30.0 * power
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	flash.polygon = points
	flash.color = Color(0.6, 0.9, 1.0, 1.0) # Bright Blue Core
	flash.position = pos
	
	game_node.add_child(flash)
	
	var tween = create_tween()
	# Pop in and grow
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2) * power, 0.1)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	# Add a bit of rotation for chaos
	sprite.rotation = randf() * TAU
	
	tween.tween_callback(sprite.queue_free)


	var tween2 = create_tween()
	tween2.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.2)
	tween2.parallel().tween_property(flash, "modulate:a", 0.0, 0.62)
	tween2.tween_callback(flash.queue_free)
