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
var all_trees = [] # Track trees for light rays
var all_platforms = [] # Visual platform nodes
# ------------------------

# --- ENEMY VARIABLES ---
var enemies = []
const MAX_ENEMIES = 3

# --- WIND & ENVIRONMENT ---
var wind_manager: Node
var all_leaves = []
var leaf_timer = 0.0
const LEAF_TEX = "res://art/environment/leaf/leaf1.png"

# --- TWEAK PARAMETERS ---
var wind_base_strength = 1.5
var wind_frequency = 0.8
var leaf_spawn_chance = 0.3 # Higher = more leaves
var leaf_gravity = 40.0
var leaf_wind_influence = 80.0 # How much leaves blow sideways
# -----------------------

const VU_COUNT = 16
const FREQ_MAX = 11050.0

# --- DIMENSIONS ---
const SCREEN_WIDTH = 640
const SCREEN_HEIGHT = 360
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
var player_light: LightSpirit
var moon_light: LightSpirit
# -------------------------

# --- UI ---
var game_ui
# ----------


func setup_chill_background():
	# Deep blue "chill" sky
	var sky = ColorRect.new()
	sky.size = Vector2(10000, SCREEN_HEIGHT * 3) # Very wide for scrolling
	sky.position = Vector2(-2000, -SCREEN_HEIGHT)
	sky.color = Color(0.02, 0.02, 0.15) # Dark Midnight Blue
	sky.z_index = -100 # Way back
	sky.name = "ChillSky"
	add_child(sky)

	# Stars
	for i in range(200):
		var star = ColorRect.new()
		star.size = Vector2(randf_range(1, 3), randf_range(1, 3))
		star.position = Vector2(randf() * sky.size.x, randf() * sky.size.y)
		star.color = Color(1, 1, 1, randf() * 0.4 + 0.1)
		sky.add_child(star)
		
	# Distant Mountains (Simple shapes)
	for i in range(10):
		var mtn = Polygon2D.new()
		var w = randf_range(600, 1200) # Slightly wider
		var h = randf_range(300, 600) # Much taller
		var cx = randf_range(0, sky.size.x)
		var cy = sky.size.y - 400 # Move them UP (Positive Y is down, so subtract to move up)
		
		mtn.polygon = PackedVector2Array([
			Vector2(cx - w/2, cy),
			Vector2(cx, cy - h),
			Vector2(cx + w/2, cy)
		])
		mtn.color = Color(0.05, 0.05, 0.2).lightened(0.05 * (i % 3))
		sky.add_child(mtn)

func setup_moon():
	print("Setting up Moon...")
	moon_light = load("res://light_spirit.gd").new()
	moon_light.name = "MoonLight"
	moon_light.color = Color(0.8, 0.9, 1.0, 0.3) # Soft moonlight
	moon_light.radius = 300.0
	moon_light.intensity = 0.3
	# High up in the sky
	moon_light.position = Vector2(SCREEN_WIDTH * 0.7, -200)
	add_child(moon_light)
	
	# Add a visual Moon sprite (Procedural texture)
	var moon_visual = Sprite2D.new()
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.8, 1.0]
	gradient.colors = [Color(1, 1, 0.9, 1.0), Color(0.9, 0.9, 1.0, 0.8), Color(1, 1, 1, 0.0)]
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = 128
	tex.height = 128
	moon_visual.texture = tex
	moon_visual.z_index = -99
	moon_light.add_child(moon_visual)


func setup_trees():
	var tree_tex = load("res://art/environment/trees/Tree1-blue.png")
	if not tree_tex:
		print("ERROR: Tree1-blue.png not found at expected path!")
		return
		
	print("Spawning trees...")
	for i in range(25):
		var tree = Sprite2D.new()
		var tree2 = Sprite2D.new()
		tree.texture = tree_tex
		tree2.texture = tree_tex
		
		# Random Position
		var x_pos = randf_range(-1000, 4000)
		var x_pos2 = randf_range(-1000, 4000)
		var s = randf_range(0.6, 1.4)
		var s2 = randf_range(0.6, 1.4)
		tree.scale = Vector2(s, s)
		tree2.scale = Vector2(s2, s2)
		
		# Flip randomly
		if randf() > 0.5:
			tree.scale.x *= -1
		if randf() > 0.5:
			tree2.scale.x *= -1
			
		# Y Position: Ground level is roughly SCREEN_HEIGHT - 50
		var ground_y = SCREEN_HEIGHT - 50
		var ground_y2 = SCREEN_HEIGHT*2 - 50

		# Sink them a bit into the ground for variation
		var sink = randf_range(10, 40)
		tree.position = Vector2(x_pos, ground_y - (tree_tex.get_height() * s * 0.5) + sink)
		tree2.position = Vector2(x_pos2, ground_y2 - (tree_tex.get_height() * s2 * 0.5) + sink) 

		# Depth sorting visual hack:
		tree.z_index = -11 + int(s * 5) 
		tree2.z_index = -11 + int(s2 * 5)
		tree.modulate = Color(0.6, 0.6, 0.8).darkened((1.4 - s) * 0.5)
		tree2.modulate = Color(0.6, 0.6, 0.8).darkened((1.4 - s2) * 0.5)
		
		add_child(tree)
		add_child(tree2)
		all_trees.append(tree)
		all_trees.append(tree2)

		# --- MUSHROOM DECORATIONS at base of foreground trees ---
		_spawn_mushrooms_at_tree(tree2, s2, tree_tex.get_height())
		# --- MUSHROOM DECORATIONS at base of foreground trees ---
		_spawn_mushrooms_at_tree(tree, s, tree_tex.get_height())


func _spawn_mushrooms_at_tree(tree: Sprite2D, tree_scale: float, tree_tex_height: float):
	var mush_tex = load("res://art/environment/tileset/DecoMushroom-Bottom.png")
	if not mush_tex: return

	var count = randi_range(1, 3)
	var tree_base_y = tree.position.y + tree_tex_height * tree_scale * 0.5 # bottom center

	for j in range(count):
		var mush = Sprite2D.new()
		mush.texture = mush_tex
		
		# Depth-influenced scale: match parent tree scale roughly
		var ms = randf_range(0.4, 0.9) * clamp(tree_scale, 0.6, 1.4)
		mush.scale = Vector2(ms, ms)
		if randf() > 0.5: mush.scale.x *= -1 # random flip
		
		# Cluster at the tree base with small horizontal spread
		var x_off = randf_range(-18.0, 18.0) * tree_scale
		mush.position = Vector2(tree.position.x + x_off, tree_base_y - mush_tex.get_height() * ms * 0.45)
		
		# Z-index: just in front of the tree
		mush.z_index = tree.z_index + 1
		
		# Brighter-at-top look: HDR blue-white glow tint
		# The sprite top should feel lit, base stays dark
		# We achieve this with a warm-glow modulate (slightly above 1.0 for HDR)
		var brightness = randf_range(0.8, 1.3)
		mush.modulate = Color(0.4 * brightness, 0.9 * brightness, 1.8 * brightness, 0.9)
		
		# Additive blend so they glow softly into the background
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mush.material = mat
		
		add_child(mush)

func setup_grass():
	var grass_shader = load("res://grass.gdshader")
	if not grass_shader:
		print("ERROR: grass.gdshader not found!")
		return
		
	var ground_y = SCREEN_HEIGHT + 64
	var tree_base_y = SCREEN_HEIGHT - 50
	var area_height = ground_y - tree_base_y + 40 # extra padding
	
	print("Setting up grass layers for depth...")
	# Create 5 layers of grass for depth
	for i in range(5):
		var grass_layer = ColorRect.new()
		var depth_factor = float(i) / 4.0 # 0.0 (back) to 1.0 (front)
		
		# Position: Move from tree base towards absolute bottom
		var y_pos = lerp(tree_base_y, ground_y - 20, depth_factor)
		
		grass_layer.size = Vector2(SCREEN_WIDTH * 16, 60)
		grass_layer.position = Vector2(-SCREEN_WIDTH * 4, y_pos)
		
		var mat = ShaderMaterial.new()
		mat.shader = grass_shader
		
		# Adjust colors for depth (darker in back)
		var d_col = Color(0.01, 0.03, 0.01).lerp(Color(0.02, 0.06, 0.05), depth_factor)
		var h_col = Color(0.05, 0.1, 0.05).lerp(Color(0.1, 0.2, 0.15), depth_factor)
		
		mat.set_shader_parameter("dark_color", d_col)
		mat.set_shader_parameter("highlight_color", h_col)
		mat.set_shader_parameter("wind_speed", 0.5 + depth_factor * 0.5)
		mat.set_shader_parameter("density", 40.0 + depth_factor * 20.0)
		
		grass_layer.material = mat
		
		# Z-Index: Range from -11 (behind furthest trees) to 1 (in front of floor)
		grass_layer.z_index = -11 + int(depth_factor * 12)
		
		grass_layer.name = "GrassLayer_" + str(i)
		add_child(grass_layer)


var reflection_nodes = {} # Map of original node -> reflection node
var all_ponds = [] # Array to store pond containers

func setup_ponds():
	var water_shader = load("res://water.gdshader")
	if not water_shader:
		print("ERROR: water.gdshader not found!")
		return
		
	var ground_y = SCREEN_HEIGHT + 64
	var tree_base_y = SCREEN_HEIGHT - 50
	
	print("Spawning water ponds...")
	for i in range(16):
		var pond_container = Node2D.new()
		pond_container.name = "Pond_" + str(i)
		
		# Random Position in the ground area
		var x_pos = randf_range(-1500, 4500)
		# Much higher on the screen (clamped to the ground area visually)
		var y_pos = randf_range(tree_base_y + 256, ground_y - 32) 
		pond_container.position = Vector2(x_pos, y_pos)
		
		# The Water Surface
		var w = randf_range(200, 500)
		var h = randf_range(40, 100)
		
		var water = Polygon2D.new()
		var points = PackedVector2Array()
		var segments = 16
		for j in range(segments):
			var angle = (float(j) / segments) * TAU
			var rv = randf_range(0.9, 1.1)
			points.append(Vector2(cos(angle) * w/2 * rv, sin(angle) * h/2 * rv))
		water.polygon = points
		
		var mat = ShaderMaterial.new()
		mat.shader = water_shader
		mat.set_shader_parameter("water_color", Color(0.1, 0.2, 0.4, 0.5))
		water.material = mat
		
		# Water should be behind characters
		water.z_index = -5
		water.name = "PondWater"
		# ENABLE CLIPPING AND DRAWING
		water.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		pond_container.add_child(water)
		
		# Reflection container strictly for clipped content
		var re_cont = Node2D.new()
		re_cont.name = "Reflections"
		water.add_child(re_cont)
		
		# Static Moon reflection in the pond
		if moon_light:
			var moon_ref = Sprite2D.new()
			moon_ref.name = "MoonRef"
			moon_ref.texture = load("res://art/moon_glow.png") # Or similar
			if not moon_ref.texture: 
				# Fallback: create a circle
				pass 
			moon_ref.scale = Vector2(0.4, 0.2)
			moon_ref.modulate = Color(1, 1, 1, 0.15)
			# Distant parallax: move it slightly towards moon
			var moon_dir = (moon_light.global_position - pond_container.global_position).normalized()
			moon_ref.position = moon_dir * 15.0
			re_cont.add_child(moon_ref)
		var splashes = CPUParticles2D.new()
		splashes.amount = 8
		splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		splashes.emission_rect_extents = Vector2(w/2, h/2)
		splashes.direction = Vector2(0, -1)
		splashes.spread = 45.0
		splashes.gravity = Vector2(0, 98)
		splashes.initial_velocity_min = 20.0
		splashes.initial_velocity_max = 50.0
		splashes.scale_amount_min = 1.0
		splashes.scale_amount_max = 2.0
		splashes.color = Color(1, 1, 1, 0.4)
		splashes.lifetime = 0.5
		splashes.z_index = -4
		pond_container.add_child(splashes)
		
		# --- ADD POND GLOW ---
		var pond_light = load("res://light_spirit.gd").new()
		pond_light.color = Color(0.3, 0.5, 1.0, 0.4) # Brighter blue glow
		pond_light.radius = w * 0.40
		pond_light.intensity = 0.3
		pond_container.add_child(pond_light)
		# ---------------------
		
		add_child(pond_container)
		all_ponds.append(pond_container)

func setup_platforms():
	if PhysicsManager:
		PhysicsManager.clear_platforms()
	
	print("Spawning tiled jump platforms...")
	var ground_y = SCREEN_HEIGHT - 50
	for i in range(8):
		# Strict tile count for alignment
		var num_tiles = randi_range(6, 12)
		var w_target = num_tiles * 32
		
		# Snap position to 32px grid for perfect alignment
		var x_pos = floor(randf_range(-500, 3500) / 32.0) * 32.0
		var y_pos = floor((ground_y - randf_range(120, 350)) / 32.0) * 32.0
		
		var area_size = _create_tiled_area(Vector2(x_pos, y_pos), w_target, -2)
		
		# Register in PhysicsManager
		if PhysicsManager:
			PhysicsManager.all_platforms.append(Rect2(Vector2(x_pos, y_pos), area_size))

func setup_tree_rays():
	for tree in all_trees:
		var rays = Line2D.new()
		rays.name = "LightRays"
		rays.width = 0.80
		rays.default_color = Color(1.0, 1.0, 0.6, 0.0) # Transparent yellow
		# Setup multiple points for a fan effect or just one main ray
		rays.add_point(Vector2.ZERO)
		rays.add_point(Vector2(0, -200))
		tree.add_child(rays)
		
		# Make rays pop in front of trees and characters
		rays.z_index = 20
		rays.top_level = true # Ignore parent position/modulation
		rays.material = CanvasItemMaterial.new()
		rays.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		
		# Give them a soft gradient look
		var gradient = Gradient.new()
		gradient.colors = [Color(1, 1, 0.8, 1.0), Color(1, 1, 0.8, 0.0)] # Base color opaque for modulation to work
		rays.gradient = gradient

func update_light_effects(delta):
	# Update Moon position (Parallax-ish)
	if moon_light:
		# Shift moon slightly based on camera but keep it high
		moon_light.position.x = player.position.x + 200
	
	# 1. Update Tree Rays (Follow Moon or Point Lights)
	var all_lights = []
	if player_light: all_lights.append(player_light)
	if moon_light: all_lights.append(moon_light)
	if CombatManager:
		for enemy in enemies:
			if is_instance_valid(enemy) and "light" in enemy:
				all_lights.append(enemy.light)
	
	for child in get_children():
		if child is LightSpirit and child != player_light and child != moon_light:
			all_lights.append(child)
	
	for tree in all_trees:
		var rays = tree.get_node_or_null("LightRays")
		if not rays: continue
		
		# Match tree position
		rays.global_position = tree.global_position
		
		# Find the most relevant light (weighted by distance/intensity)
		var factor_light = moon_light
		var min_score = 10000.0
		
		for l in all_lights:
			var d = tree.global_position.distance_to(l.global_position)
			var score = d / l.intensity
			if score < min_score:
				min_score = score
				factor_light = l
		
		if factor_light:
			var dir = (tree.global_position - factor_light.global_position).normalized()
			rays.points[1] = dir * 350.0 # Longer rays
			rays.width = 25.0 # Thicker rays
			
			var dist = tree.global_position.distance_to(factor_light.global_position)
			# Make moon rays always somewhat visible if moon is factor
			var alpha_target = clamp(1.5 - (dist / (factor_light.radius * 3.0)), 0.1, 0.8)
			if factor_light == moon_light:
				alpha_target = max(alpha_target, 0.3) # Minimum moon presence
			
			rays.modulate.a = lerp(rays.modulate.a, alpha_target, delta * 2.0)
		else:
			rays.modulate.a = lerp(rays.modulate.a, 0.0, delta * 2.0)

	# 2. Sprite Illumination (Approaching sprites)
	# 2. Sprite Illumination (Entities and Leaves)
	var all_renderable = []
	if is_instance_valid(player): 
		all_renderable.append({"type": "entity", "obj": player})
	for enemy in enemies:
		if is_instance_valid(enemy):
			all_renderable.append({"type": "entity", "obj": enemy})
	
	for l_data in all_leaves:
		if is_instance_valid(l_data.node):
			all_renderable.append({"type": "leaf", "obj": l_data.node})

	for item in all_renderable:
		var ent = item.obj
		var boost : float = 0.0
		var pos = ent.global_position
		
		for l in all_lights:
			# FIX: player light should not light up player.
		#	if item.type == "entity" and ent == player and l == player_light:
		#		continue
			if(l in ent.get_children()):
				continue
				
			var dist: float = pos.distance_to(l.global_position)
			if dist < l.radius:
				boost += (1.0 - (dist / l.radius)) * l.intensity * 10
		
		var lit_color = Color(1.0 + boost, 1.0 + boost, 1.0 + boost * 0.5, 1.0)
		
		if item.type == "entity":
			# If entity supports external lighting, use that (preferred for Player)
			if "external_lighting_modulate" in ent:
				ent.external_lighting_modulate = lit_color
			else:
				# Apply directly to sprite
				if ent.has_method("get_active_sprite"):
					var s = ent.call("get_active_sprite")
					if s: s.modulate = lit_color
				elif "sprite" in ent:
					if ent.sprite: ent.sprite.modulate = lit_color
		else:
			# Leaf lighting
			ent.modulate = Color(lit_color.r, lit_color.g, lit_color.b, ent.modulate.a)
			if ent.material and ent.material is ShaderMaterial:
				ent.material.set_shader_parameter("energy", 1.0 + boost * 0.5)
				if moon_light:
					var m_dir = (ent.global_position - moon_light.global_position).normalized()
					ent.material.set_shader_parameter("light_dir", m_dir)

func setup_reflections():
	# We'll create reflections for the player and enemies
	_create_reflection(player)
	for enemy in enemies:
		_create_reflection(enemy)

func _create_reflection(entity: Node2D):
	if not entity: return
	var reflection = Node2D.new()
	reflection.name = entity.name + "_Reflection"
	# No specific parent here, update_reflections will move it to the nearest pond
	reflection_nodes[entity] = reflection

# Track dynamic skill reflections to avoid duplicates

var skill_reflections = {} # Map of skill_instance -> reflection_node

func update_reflections():
	# 1. Update Entities (Player, Enemies)
	for entity in reflection_nodes.keys():
		var reflection = reflection_nodes[entity]
		if not is_instance_valid(entity) or not is_instance_valid(reflection): continue
		
		reflection.visible = false # Default
		
		var best_pond = null
		var min_y_dist = 1000.0 # Wide vertical range
		
		for pond in all_ponds:
			var pond_water = pond.get_node_or_null("PondWater")
			if pond_water and pond_water is Polygon2D:
				# Calculate pond surface and bounds
				var local_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
				for p in pond_water.polygon:
					local_bounds = local_bounds.expand(p)
				
				var pond_width = local_bounds.size.x
				var x_dist = abs(entity.global_position.x - pond.global_position.x)
				var y_dist = abs(entity.global_position.y - pond.global_position.y)
				
				# Relaxed horizontal check: allow reflections if reasonably close to the pond's x-range
				if x_dist < (pond_width / 2.0) + 200.0:
					if y_dist < min_y_dist:
						min_y_dist = y_dist
						best_pond = pond

		
		if best_pond:
			var re_cont = best_pond.get_node_or_null("PondWater/Reflections")
			if re_cont:
				if reflection.get_parent() != re_cont:
					if reflection.get_parent(): reflection.get_parent().remove_child(reflection)
					re_cont.add_child(reflection)
				_update_node_reflection(entity, reflection, best_pond)

	# 2. Update Dynamic Visuals & Skills
	var current_frame = Engine.get_process_frames()
	var visuals_to_reflect = []
	
	# Scrape Entities (Player and Enemies)
	var entities = get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Enemy")
	for ent in entities:
		if is_instance_valid(ent):
			_collect_visual_nodes_recursive(ent, visuals_to_reflect)
	
	# Also scrape world-level skills (e.g. Chain Lightning lines)
	for child in get_children():
		if child.name.contains("Pond") or child.name.contains("Ref_") or child == player_light or child == moon_light: continue
		_collect_visual_nodes_recursive(child, visuals_to_reflect)
			
	for vis in visuals_to_reflect:
		if not is_instance_valid(vis) or not vis.visible or vis.modulate.a < 0.1: continue
		
		# Robust X-position detection for wide nodes like Line2D
		var vis_x = vis.global_position.x
		if vis is Line2D and vis.points.size() > 0:
			# Use the horizontal span's center
			var x_sum = 0.0
			for p in vis.points: x_sum += p.x
			vis_x += x_sum / vis.points.size()
		
		for pond in all_ponds:
			# Skip if pond is off-screen Relative to player
			if abs(pond.global_position.x - player.global_position.x) > 1200: continue
			
			# Broad phase horizontal check
			var dist_x = abs(vis_x - pond.global_position.x)
			if dist_x > 400: continue # Slightly wider for lines
			
			_reflect_node_in_pond(vis, pond, current_frame)
			#break # Only reflect in one pond
			
	# 3. Mark-and-Sweep Cleanup
	_prune_old_reflections(current_frame)

func _collect_visual_nodes_recursive(root: Node, list: Array):
	if root is Sprite2D or root is Line2D or root is Polygon2D:
		if not root.name.contains("Ref_") and not root.name.contains("Reflection"):
			list.append(root)
	
	for child in root.get_children():
		_collect_visual_nodes_recursive(child, list)

func _reflect_node_in_pond(vis: Node2D, pond: Node2D, frame: int):
	var water = pond.get_node_or_null("PondWater")
	if not water: return
	var re_cont = water.get_node_or_null("Reflections")
	if not re_cont: return
	
	var ref_name = "Ref_" + str(vis.get_instance_id())
	var ref = re_cont.get_node_or_null(ref_name)
	
	if not ref:
		if vis is Line2D:
			ref = Line2D.new()
			ref.width = vis.width
			ref.texture = vis.texture
			ref.texture_mode = vis.texture_mode
			ref.material = vis.material
		elif vis is Sprite2D:
			ref = Sprite2D.new()
			ref.texture = vis.texture
			ref.hframes = vis.hframes
			ref.vframes = vis.vframes
		elif vis is Polygon2D:
			ref = Polygon2D.new()
			ref.polygon = vis.polygon
			ref.color = vis.color
		
		if ref:
			ref.name = ref_name
			re_cont.add_child(ref)
	
	if ref:
		ref.set_meta("last_f", frame)
		
		# Position Mapping
		var pond_top_y = pond.global_position.y
		var water_poly = water as Polygon2D
		if water_poly:
			var local_min_y = 0.0
			for p in water_poly.polygon:
				if p.y < local_min_y: local_min_y = p.y
			pond_top_y += local_min_y

		# Reflection Center Calculation with Feet Offset Awareness
		var f_off = vis.get("feet_offset") if "feet_offset" in vis else 0.0
		var vis_center_y = vis.global_position.y
		
		ref.global_position.x = vis.global_position.x
		# Mirror logic: we want the feet (vis_center + f_off) reflected correctly
		# dy is the distance from surface to feet
		var dy = (vis_center_y + f_off) - pond_top_y
		# The reflection's feet should be pond_top_y + dry
		# Since it is flipped, the center is ref_feet + f_off
		ref.global_position.y = pond_top_y + dy + f_off
		
		# Visual State Sync
		ref.visible = vis.visible
		ref.modulate = Color(0.1, 0.4, 0.9, 0.4)
		
		if vis is Line2D:
			ref.points = vis.points
			ref.global_rotation = -vis.global_rotation
			ref.scale.y = -1
		elif vis is Sprite2D:
			ref.frame = vis.frame
			ref.flip_h = vis.flip_h
			ref.flip_v = !vis.flip_v
			ref.scale = vis.scale
			ref.offset = vis.offset
		elif vis is Polygon2D:
			ref.polygon = vis.polygon
			ref.global_rotation = -vis.global_rotation
			ref.scale.y = -vis.scale.y

func _prune_old_reflections(frame: int):
	for pond in all_ponds:
		var water = pond.get_node_or_null("PondWater")
		if not water: continue
		var re_cont = water.get_node_or_null("Reflections")
		if not re_cont: continue
		for ref in re_cont.get_children():
			if ref.has_meta("last_f"):
				if ref.get_meta("last_f") < frame:
					ref.queue_free()

func _update_node_reflection(entity: Node2D, reflection: Node2D, pond: Node2D):
	var active_sprite = null
	if entity.has_method("get_active_sprite"):
		active_sprite = entity.call("get_active_sprite")
	elif "sprite" in entity:
		active_sprite = entity.get("sprite")
	
	if active_sprite and active_sprite is Sprite2D and active_sprite.visible:
		reflection.visible = true
		var rs = reflection.get_node_or_null("Sprite")
		if not rs:
			rs = Sprite2D.new()
			rs.name = "Sprite"
			reflection.add_child(rs)
		
		# Mirroring math relative to pond's TOP surface
		var pond_water = pond.get_node_or_null("PondWater")
		var pond_surface_y = pond.global_position.y
		if pond_water and pond_water is Polygon2D:
			var local_min_y = 0.0
			for p in pond_water.polygon:
				if p.y < local_min_y: local_min_y = p.y
			pond_surface_y += local_min_y # adjust to top edge
			
		reflection.global_position.x = entity.global_position.x
		reflection.global_position.y = pond_surface_y + (pond_surface_y - entity.global_position.y)
		
		rs.texture = active_sprite.texture
		rs.hframes = active_sprite.hframes
		rs.vframes = active_sprite.vframes
		rs.frame = active_sprite.frame
		rs.region_enabled = active_sprite.region_enabled
		rs.region_rect = active_sprite.region_rect
		rs.flip_h = active_sprite.flip_h
		rs.flip_v = true
		rs.scale = active_sprite.scale
		rs.modulate = Color(0.1, 0.4, 0.9, 0.5)
		rs.offset = active_sprite.offset

		# ADD MOON REFLECTION IN POND
		var moon_ref = reflection.get_node_or_null("MoonRef")
		if not moon_ref and moon_light:
			moon_ref = Sprite2D.new()
			moon_ref.name = "MoonRef"
			moon_ref.texture = moon_light.get_child(0).texture
			reflection.add_child(moon_ref)
		
		if moon_ref and moon_light:
			# Simple parallax reflection: offset based on pond pos vs moon pos
			var rel_pos = (moon_light.global_position - pond.global_position)
			moon_ref.position = -rel_pos.normalized() * 30.0
			moon_ref.modulate = Color(1, 1, 1, 0.2)
			moon_ref.scale = Vector2(0.4, 0.2) # Flattened on water
		
		# We don't hide the whole reflection if moon is missing
		pass

			

func _ready():
	_setup_wind_manager()
	setup_chill_background()
	setup_moon()
	setup_trees()
	# setup_grass()
	setup_ponds()
	setup_platforms()
	setup_tree_rays()
	
	print("[ShowSpectrum] _ready started.")
	if CombatManager:
		CombatManager.current_game_node = self
	
	# --- SETUP BACKGROUND NOISE ---
	var bg_noise = AudioStreamPlayer.new()
	bg_noise.name = "BackgroundNoise"
	bg_noise.stream = load("res://art/environment/background noise/birds-forest.WAV")
	bg_noise.volume_db = -18.0 # Soft background
	bg_noise.autoplay = true
	add_child(bg_noise)
	
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
	bg_rect.size = Vector2(SCREEN_WIDTH*2, SCREEN_HEIGHT*2)
	bg_rect.position = Vector2(-SCREEN_WIDTH/2, -SCREEN_HEIGHT/2)
	bg_rect.show_behind_parent = true # Draw BEHIND the _draw logic
	
	var shader = load("res://rain.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sky_color", Color(0, 0, 0, 0)) # Make rain back transparent
	bg_rect.material = mat
	
	add_child(bg_rect)
	# --------------------------------------
	
	# --- SETUP TILE-BASED FLOOR ---
	# Snap floor to 32px as well
	var floor_pos = Vector2(floor(-SCREEN_WIDTH * 4 / 32.0) * 32.0, SCREEN_HEIGHT + 64)
	var floor_width = SCREEN_WIDTH * 16
	var actual_floor_size = _create_tiled_area(floor_pos, floor_width, 0)
	
	if PhysicsManager:
		PhysicsManager.floor_y = floor_pos.y
	# -------------------
	
	# --- SETUP PLAYER CONTROLLER ---
	player = load("res://player_controller.gd").new()
	player.name = "ThePlayer"
	player.game_node = self
	player.position = center
	player.global_position = player.position
	add_child(player)
	
	if CombatManager:
		CombatManager.register_entity(player)
	# -------------------------------
	
	# ---- SETUP CROW PET ---
	var crow = load("res://crow_pet.gd").new()
	crow.position = player.position + Vector2(-50, -50)
	crow.assign_host(player)
	add_child(crow)
	

	var dust_list = []
	dust_list.append(load("res://dust_puff.gd").new())
	dust_list[0].host = player
	add_child(dust_list[0])
	# ---- SETUP DUST PUFFS (Legacy Trail) ---
	for i in range(3):
		var dust = load("res://dust_puff.gd").new()
		dust.host = dust_list[i-1]
		dust.position = player.position + Vector2(0, 30)
		add_child(dust)
		dust_list.append(dust)
		
	# ---- SETUP DUST SWARM (Flocking Particles) ---
	var dust_swarm = BaseFlockSwarm.new()
	dust_swarm.position = player.position + Vector2(0, -10)
	
	# Create a packed scene for the Dust Flock Unit
	var dust_packer = PackedScene.new()
	var dust_unit_node = Node2D.new()
	dust_unit_node.set_script(load("res://flock_dust_unit.gd"))
	dust_packer.pack(dust_unit_node)
	
	dust_swarm.unit_count = 8
	dust_swarm.spawn_radius = 10
	dust_swarm.separation_weight = 2.101   # High separation to keep them fluffy
	dust_swarm.alignment_weight = -0.61
	dust_swarm.cohesion_weight = -0.2    # Low cohesion so they drift a bit
	dust_swarm.target_attraction_weight = 1.0
	dust_swarm.frequency = 1.50
	dust_swarm.damping = 1.00
	dust_swarm.response = 0.0
	dust_swarm.unit_scene = dust_packer
	dust_swarm.target_node = dust_list[0] # Follow the axe for cool effect
	add_child(dust_swarm)
		
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
		
		if player.casting_component:
			# Connect Player Signals for FX
			player.casting_component.cast_started.connect(_on_player_cast_start)
			player.casting_component.cast_done.connect(_on_player_cast_finished)
	else:
		print("[ShowSpectrum] WARNING: Camera2D node not found!")
	# -----------------
	
	# --- SETUP ENEMIES ---
	for i in range(MAX_ENEMIES):
		var enemy = load("res://enemy.gd").new()
		enemy.position = Vector2(100 + i * 250, 100 + (i % 2) * 200)
		enemies.append(enemy)
		add_child(enemy)
		
		if CombatManager:
			CombatManager.register_entity(enemy)
		
		# Give a crow pet to the second enemy
		if i == 1:
			var enemy_crow = load("res://crow_pet.gd").new()
			enemy_crow.assign_host(enemy)
			# Tint the enemy crow to look more sinister
			enemy_crow.modulate = Color(2.0, 0.5, 2.0) # Purple Sinister Crow
			add_child(enemy_crow)
			
	# --- SPAWN ARCANE MAGES ---
	for i in range(4): # Spawn 4 mages
		var mage = load("res://arcane_mage.tscn").instantiate()
		mage.position = Vector2(800 + i * 900, 150) # To the right
		mage.name = "ArcaneMage_" + str(i)
		enemies.append(mage)
		add_child(mage)
		
		if CombatManager:
			CombatManager.register_entity(mage)
			
	# --- SETUP BOSS ---
	var boss = load("res://death_controller.gd").new()
	boss.name = "DeathBoss"
	enemies.append(boss)
	add_child(boss)
	print("[ShowSpectrum] BOSS ADDED: ", boss.name)
	
	if CombatManager:
		CombatManager.register_entity(boss)
	
	# --- SETUP PLAYER LIGHT BEACON ---
	player_light = load("res://light_spirit.gd").new()
	player_light.name = "PlayerLightBeacon"
	player_light.color = Color(1.0, 0.6, 0.2, 0.2) # Cozy fire camp spirit
	player_light.radius = 32.0
	player_light.intensity = 0.46
	add_child(player_light)
	
	setup_reflections()
	print("[ShowSpectrum] _ready complete.")




func _on_player_cast_start(duration):
	if player_light:
		player_light.burst(1.8, duration) # Brighten during cast
		
	var cam = $Camera2D
	if not cam: return
	
	# if spell_id == "sword_attack":
	cam.add_shake(12.0)
	cam.set_zoom_target(1.15) # Zoom in slightly
	if player.casting_component.active_skill_ctrl:
		var spell_id = ""
		if player.casting_component.active_skill_ctrl.has_method("get_spell_id"):
			spell_id = player.casting_component.active_skill_ctrl.get_spell_id()
		else:
			print("[ShowSpectrum] WARNING: casting_component.active_skill_ctrl has no get_spell_id method.")

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
	_update_environment(delta)
	update_reflections()
	update_light_effects(delta)


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
	
	# Update light position
	if player_light:
		player_light.position = player.position
		# If jumping, keep the light on the "floor"? 
		# Or follow the player? "Glow effects on the floor" suggests it should stay low.
		# But usually cozy effects follow the source. Let's follow the feet.
		player_light.position.y += 40 # Offset to ground
	
	# Enemies are now self-updating entities

	var data = []
	var prev_hz = 0
	
	# Run your color/math logic
	# _process_my_orbit_circles()
	
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


func _process_my_orbit_circles():
	# Increment counters
	color_modulation += 10
	circle_x += 1
	
	# Calculate Colors
	r = int(50 + (200 * sin((20 * PI * color_modulation / 2000.0) + 200)))
	g = int(10 + 128 * sin(2 * PI * color_modulation / 2000.0 + 100 * 2))
	b = int(2 + 255 * sin(2 * PI * color_modulation / 2000.0 + 200 * 3))


func _draw():
	# _draw_my_orbit_circles();
	
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


func _draw_my_orbit_circles():
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

func _setup_wind_manager():
	wind_manager = load("res://wind_manager.gd").new()
	wind_manager.wind_strength = wind_base_strength
	wind_manager.wind_frequency = wind_frequency
	add_child(wind_manager)

func _update_environment(delta):
	# 1. Update Wind Influence on Grass
	if wind_manager:
		for i in range(5):
			var grass = get_node_or_null("GrassLayer_" + str(i))
			if grass and grass.material:
				# Scale wind speed in shader based on manager
				grass.material.set_shader_parameter("wind_speed", wind_manager.current_wind_power * 1.5)
		
		# 1b. Sway Trees
		for tree in all_trees:
			var wind_at = wind_manager.get_wind_at(tree.global_position)
			var target_rot = (wind_at - 1.0) * 0.08 # Subtle sway
			tree.rotation = lerp(tree.rotation, target_rot, delta * 2.0)
	
	# 2. Spawn Leaves from Trees
	leaf_timer += delta
	if leaf_timer > 0.8: # Slightly faster spawning
		leaf_timer = 0.0
		var floor_limit = SCREEN_HEIGHT + 100
		
		for tree in all_trees:
			# Check if tree is roughly on screen or above visible floor
			if tree.global_position.y > floor_limit + 500: continue
			
			if randf() < leaf_spawn_chance:
				var h = tree.texture.get_height() * tree.scale.y
				# ONLY spawn leaves if the top of the tree is actually in the air (above floor)
				floor_limit = SCREEN_HEIGHT + 64 # Dynamic floor_y
				#var top_y = tree.global_position.y - h / 2 # Assuming tree origin is center
				#if top_y < floor_limit - 100:
				var canopy_offset = Vector2(randf_range(-80, 80), -h * 0.45)
				_spawn_leaf(tree.global_position + canopy_offset)

	# 3. Update Leaf Physics
	_update_leaves(delta)

func _spawn_leaf(pos: Vector2):
	var leaf = Sprite2D.new()
	leaf.texture = load(LEAF_TEX)
	if not leaf.texture: return # Safety
	
	add_child(leaf) # Add BEFORE setting global_position
	leaf.global_position = pos
	leaf.z_index = 12 # Even higher to ensure visibility over everything
	
	# --- VISIBLE DEBUG OCTAGON (Lasts 1 second) ---
	var debug = Polygon2D.new()
	var sides = 8
	var points = PackedVector2Array()
	for i in range(sides):
		var angle = i * TAU / sides
		points.append(Vector2(cos(angle), sin(angle)) * 8.0)
	debug.polygon = points
	debug.color = Color(1, 1, 1, 0.5)
	add_child(debug)
	debug.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(debug.queue_free)
	# ----------------------------------------------

	leaf.hframes = 15
	leaf.frame = randi() % 15
	leaf.scale = Vector2(0.8, 0.8) * randf_range(0.8, 1.2)
	leaf.rotation = randf() * TAU
	leaf.modulate.a = 0.9
	
	# Apply Leaf Shader for moonlight highlights
	var mat = ShaderMaterial.new()
	mat.shader = load("res://leaf.gdshader")
	leaf.material = mat
	
	# Custom metadata for physics
	var leaf_data = {
		"node": leaf,
		"velocity": Vector2(randf_range(-40, 40), randf_range(20, 50)),
		"rot_speed": randf_range(-3.0, 3.0),
		"life": randf_range(5.0, 8.0),
		"phase": randf() * TAU,
		"sway_intensity": randf_range(30.0, 60.0)
	}
	
	all_leaves.append(leaf_data)

func _update_leaves(delta):
	var wind_power = 0.0
	if wind_manager:
		wind_power = wind_manager.current_wind_power

	for i in range(all_leaves.size() - 1, -1, -1):
		var l = all_leaves[i]
		if not is_instance_valid(l.node):
			all_leaves.remove_at(i)
			continue
			
		# 1. Update Physics
		l.velocity.y += leaf_gravity * delta
		l.velocity.x = lerp(l.velocity.x, wind_power * leaf_wind_influence, delta * 2.0)
		
		# Organic Swaying
		l.phase += delta * 2.5
		var sway = sin(l.phase) * l.sway_intensity
		l.node.global_position += (l.velocity + Vector2(sway, 0)) * delta
		l.node.rotation += l.rot_speed * delta
		
		# 2. Cleanup & Fade
		l.life -= delta
		
		# Animate frames slowly
		if Engine.get_process_frames() % 10 == 0:
			l.node.frame = (l.node.frame + 1) % 15
		
		# Fade out near end of life
		if l.life < 1.0:
			l.node.modulate.a = l.life
			
		if l.life <= 0: #or l.node.global_position.y > (SCREEN_HEIGHT + 200):
			l.node.queue_free()
			all_leaves.remove_at(i)
func _create_tiled_area(pos: Vector2, width: float, z: int) -> Vector2:
	# Tiles are 32x32. Calculate how many we need.
	var num_tiles = max(2, int(ceil(width / 32.0)))
	var total_width = num_tiles * 32
	
	var tile_script = load("res://base_tile.gd")
	
	for i in range(num_tiles):
		var tile = tile_script.new()
		tile.z_index = z
		# Calculate tile position (Tiles are 32x32, with bottom at pos.y+16)
		# To stand ON TOP, the physics floor must be at the tile's Top (global_position.y - 16).
		# By setting global_position.y to pos.y + 16, Top is at pos.y.
		tile.global_position = pos + Vector2(i * 32 + 16, 16)
		
		if i == 0:
			tile.type = tile.TileType.SIDE_END
			tile.is_flipped = false
		elif i == num_tiles - 1:
			tile.type = tile.TileType.SIDE_END
			tile.is_flipped = true
		else:
			# Randomly pick between Default and Grass
			if randf() < 0.4: # 40% chance for grass tile
				tile.type = tile.TileType.WITH_GRASS
			else:
				tile.type = tile.TileType.DEFAULT
		
		if tile.type == tile.TileType.WITH_GRASS:
			tile.connect("stepped_on_tile", _on_tile_stepped_on)
			
		add_child(tile)
	
	return Vector2(total_width, 32)

func _on_tile_stepped_on(tile):
	if tile.type == tile.TileType.WITH_GRASS:
		_spawn_grass_swarm(tile.global_position - Vector2(0, 16)) # Offset to top of tile

func _spawn_grass_swarm(pos: Vector2):
	# User Request: Swarm with flockunit default
	if pos == Vector2.ZERO:
		print("[ShowSpectrum] WARNING: Attempted to spawn grass swarm at (0,0). Check tile position logic.")
		return
	if not player:
		print("[ShowSpectrum] WARNING: Player node not found when spawning grass swarm.")
		return
	if player.position - pos > Vector2(1, 1) and player.position - pos < Vector2(-1, -1):
		print("[ShowSpectrum] Skipping grass swarm spawn due to distance from player.")
		return
	var swarm_container = Node2D.new()
	swarm_container.global_position = pos
	add_child(swarm_container)
	
	# Create Manager
	var manager = BaseFlockSwarm.new()
	manager.target_node = player
	manager.unit_count = 3
	manager.target_attraction_weight = -0.005 # Dispersing
	manager.max_speed = 1.0
	manager.perception_radius = 10.0
	manager.separation_weight = 2.5
	manager.alignment_weight = -2.5
	manager.spawn_radius = 10.0
	manager.frequency = 4.8
	manager.damping = 0.9
	manager.response = 1.0
	swarm_container.add_child(manager)
	
	# Manually spawn units since we don't have a scene but want to use flock_unit.gd script
	var units = []
	var unit_script = load("res://flock_unit.gd")
	for i in range(manager.unit_count):
		var u = Node2D.new()
		u.set_script(unit_script)
		# Start exactly at tile pos
		u.global_position = pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		# u.texture = load("res://art/environment/leaf/leaf1.png")
		# u.frame = 0
		# u.scale = Vector2(0.5, 0.5) * randf_range(0.8, 1.2)
		# u.rotation = randf() * TAU
		manager.add_child(u)
		manager.members.append(u)
		u.initialize_flock_unit(manager, i)
		u.z_index = 11 # Above tiles and leaves
		units.append(u)
		
	# Swarm Life cycle
	var t = create_tween()
	t.tween_interval(0.6) # Short dispersion burst
	t.tween_callback(func():
		for u in units:
			if is_instance_valid(u):
				_spawn_leaf(u.global_position)
	)
	t.tween_interval(0.6) # Short dispersion burst
	t.tween_callback(func():
		for u in units:
			if is_instance_valid(u):
				u.queue_free()
		swarm_container.queue_free()
	)

# ----------------------------
