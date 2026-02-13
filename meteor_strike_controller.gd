extends Node2D

# MeteorStrikeController (Tech-Punk Satellite Variant)
# Uses PhysicsManager for a high-impact satellite crash effect.

var SPELL_ID = "meteor_strike"
var game_node: Node2D
var current_target: Node2D

var is_casting = false
var cast_timer = 0.0

# Stats loaded from DataManager
var CAST_TIME = 2.5
var RANGE = 800.0
var DAMAGE = 100.0

var meteor_id: String = ""
var meteor_line: Line2D # The "Plasma Trail"
var electrical_wires = [] # Array of Line2Ds for dangling wires
var head_visual: Node2D

func _ready():
	var data = DataManager.get_spell(SPELL_ID)
	if data:
		CAST_TIME = data.get("cast_time", 2.5)
		RANGE = data.get("range", 800.0)
		DAMAGE = data.get("damage", 100.0)

func get_spell_id():
	return SPELL_ID

func try_cast(source_pos: Vector2) -> Vector2:
	if not is_casting:
		var target = CombatManager.get_nearest_target(source_pos, RANGE, get_parent())
		if target:
			is_casting = true
			cast_timer = 0.0
			current_target = target
			_show_targeting_glitch(target.position)
			return target.position
	return Vector2.ZERO

func _show_targeting_glitch(pos: Vector2):
	var marker = Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-40,0), Vector2(0,-40), Vector2(40,0), Vector2(0,40)])
	marker.color = Color(1, 0, 0, 0.4)
	marker.position = pos
	game_node.add_child(marker)
	
	# Scale Pulse (Looping)
	var t_pulse = create_tween()
	t_pulse.set_loops(10)
	t_pulse.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.05)
	t_pulse.tween_property(marker, "scale", Vector2(1.0, 1.0), 0.05)
	
	# Lifecycle (Fade and Cleanup)
	var t_life = create_tween()
	t_life.tween_property(marker, "modulate:a", 0.0, 1.0)
	t_life.tween_callback(marker.queue_free)

func cast(elapsed_time: float, _from_above: bool):
	if is_casting:
		cast_timer = elapsed_time
		if cast_timer >= CAST_TIME:
			is_casting = false
			_fire_meteor()

func interrupt_charging():
	is_casting = false
	current_target = null

func _fire_meteor():
	if not is_instance_valid(current_target): return
	
	var target_pos = current_target.position
	var start_pos = target_pos + Vector2(randf_range(-400, 400), -800)
	
	# 1. SETUP HEAD (Satellite Core)
	head_visual = Node2D.new()
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-30, -15), Vector2(30, -15), Vector2(40, 0), 
		Vector2(30, 15), Vector2(-30, 15), Vector2(-40, 0)
	])
	body.color = Color(0.2, 0.2, 0.25) # Dark Steel
	head_visual.add_child(body)
	
	# Add Glowy Core
	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-10,-10), Vector2(10,-10), Vector2(10,10), Vector2(-10,10)])
	core.color = Color(5.0, 0.5, 0.0) # HDR Orange
	head_visual.add_child(core)
	
	head_visual.position = start_pos
	game_node.add_child(head_visual)
	
	# --- ADD METEOR GLOW ---
	var light = load("res://light_spirit.gd").new()
	light.color = Color(1.5, 0.6, 0.2, 0.8) # Hot Orange Plasma
	light.radius = 350.0
	light.intensity = 1.0
	head_visual.add_child(light) # Follows the satellite core
	# -----------------------
	
	# 2. SETUP PHYSICS
	var points = [start_pos, start_pos - Vector2(0, 50)]
	meteor_id = "satellite_" + str(get_instance_id())
	PhysicsManager.register_soft_body(meteor_id, points, 40.0) # Corrected Signature
	
	# High Velocity
	var dir = (target_pos - start_pos).normalized()
	PhysicsManager.apply_force(meteor_id, dir * 5000.0)
	
	# 3. SETUP TRAIL
	meteor_line = Line2D.new()
	meteor_line.width = 80.0
	meteor_line.default_color = Color(1.5, 0.8, 0.3, 0.4) # Heat haze
	game_node.add_child(meteor_line)
	
	for i in range(3):
		var wire = Line2D.new()
		wire.width = 2.0
		wire.default_color = Color(0.6, 0.8, 2.0) # Electric Blue
		game_node.add_child(wire)
		electrical_wires.append(wire)
	
	set_process(true)

func _process(delta):
	if meteor_id != "":
		var p_data = PhysicsManager.get_body_data(meteor_id)
		if p_data.size() >= 1:
			var pos = p_data[0]
			var tail_pos = p_data[1]
			
			# Rotation follows movement
			var velocity_proj = pos - tail_pos
			head_visual.position = pos
			head_visual.rotation = velocity_proj.angle()
			
			# Update Trail
			if meteor_line:
				meteor_line.add_point(pos)
				if meteor_line.points.size() > 15: meteor_line.remove_point(0)
				
			# Lingering Sparks/Lightning on Trail
			if randf() < 0.3:
				_spawn_spark(pos, velocity_proj.normalized() * -200)
			
			if randf() < 0.1:
				_spawn_short_circuit(pos)

			# Movement of wires
			for i in range(electrical_wires.size()):
				var wire = electrical_wires[i]
				var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
				wire.add_point(pos + offset)
				if wire.points.size() > 5: wire.remove_point(0)

			# Check Impact
			if is_instance_valid(current_target) and pos.distance_to(current_target.position) < 80:
				_impact(pos)
			elif pos.y > 1500: # Cleanup
				_cleanup()

func _spawn_spark(pos: Vector2, vel: Vector2):
	var spark = Line2D.new()
	spark.width = 2.0
	spark.default_color = Color(2.0, 2.0, 1.0)
	spark.add_point(pos)
	spark.add_point(pos + vel.rotated(randf_range(-0.5, 0.5)) * 0.1)
	game_node.add_child(spark)
	
	var t = create_tween()
	t.tween_property(spark, "position", spark.position + vel * 0.2, 0.3)
	t.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
	t.tween_callback(spark.queue_free)

func _spawn_short_circuit(pos: Vector2):
	var arc = Line2D.new()
	arc.width = 1.5
	arc.default_color = Color(0.5, 1.5, 4.0)
	var pts = [Vector2.ZERO]
	for i in range(4):
		pts.append(Vector2(randf_range(-30,30), randf_range(-30,30)))
	arc.points = PackedVector2Array(pts)
	arc.position = pos
	game_node.add_child(arc)
	
	var t = create_tween()
	t.tween_interval(0.1)
	t.tween_callback(arc.queue_free)

func _impact(pos: Vector2):
	# NASTY BEEFY IMPACT
	# 1. Screen Shake simulation (modulate world position or just heavy visuals)
	# 2. Damage
	var targets = CombatManager.find_targets_in_hitbox(Rect2(pos - Vector2(200, 200), Vector2(400, 400)), self)
	for t in targets:
		CombatManager.request_interaction(get_parent(), t, "damage", {"amount": DAMAGE})
		CombatManager.request_interaction(get_parent(), t, "cc", {"cc_type": "stun", "duration": 3.0})
		CombatManager.request_interaction(get_parent(), t, "cc", {"cc_type": "slow", "amount": 0.2, "duration": 5.0})

	# 3. Disarming Parts (Debris)
	for i in range(8):
		_spawn_debris(pos)

	# 4. Multi-layered Explosion
	_create_beefy_explosion(pos)
	
	_cleanup()

func _spawn_debris(pos: Vector2):
	var junk = Polygon2D.new()
	var size = randf_range(5, 15)
	junk.polygon = PackedVector2Array([Vector2(-size, -size), Vector2(size, -size), Vector2(size, size)])
	junk.color = Color(0.3, 0.3, 0.3)
	junk.position = pos
	game_node.add_child(junk)
	
	var dir = Vector2.UP.rotated(randf_range(-PI, PI))
	var force = randf_range(400, 1000)
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(junk, "position", pos + dir * (force * 0.5), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(junk, "rotation", randf() * 10, 1.0)
	t.tween_property(junk, "modulate:a", 0.0, 1.0).set_delay(0.5)
	t.chain().tween_callback(junk.queue_free)

func _create_beefy_explosion(pos: Vector2):
	# Layer 1: Shockwave Ring
	var shock = Polygon2D.new()
	var pts = []
	for i in range(32):
		pts.append(Vector2(cos(i*TAU/32.0), sin(i*TAU/32.0)) * 50.0)
	shock.polygon = PackedVector2Array(pts)
	shock.color = Color(1, 1, 1, 0.8)
	shock.position = pos
	game_node.add_child(shock)
	
	var t1 = create_tween()
	t1.tween_property(shock, "scale", Vector2(8.0, 8.0), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t1.parallel().tween_property(shock, "modulate:a", 0.0, 0.4)
	t1.tween_callback(shock.queue_free)

	# Layer 2: Main Blast (Fireball)
	var blast = Polygon2D.new()
	blast.polygon = shock.polygon
	blast.color = Color(5.0, 1.5, 0.2) # High intensity orange
	blast.position = pos
	game_node.add_child(blast)
	
	var t2 = create_tween()
	t2.tween_property(blast, "scale", Vector2(4.0, 4.0), 0.6).set_trans(Tween.TRANS_ELASTIC)
	t2.parallel().tween_property(blast, "modulate:a", 0.0, 1.0).set_delay(0.2)
	t2.tween_callback(blast.queue_free)

	# Layer 3: Electrical Discharge
	for i in range(12):
		var arc = Line2D.new()
		arc.width = 3.0
		arc.default_color = Color(0.4, 0.8, 4.0)
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		arc.points = PackedVector2Array([Vector2.ZERO, dir * randf_range(100, 300)])
		arc.position = pos
		game_node.add_child(arc)
		
		var t3 = create_tween()
		t3.tween_interval(randf_range(0.1, 0.4))
		t3.tween_callback(arc.queue_free)

	# Layer 4: Magical Light Spirit Flash
	var impact_light = load("res://light_spirit.gd").new()
	impact_light.color = Color(1.0, 0.4, 0.1, 1.0) # Bright Fire Orange
	impact_light.radius = 128.0
	impact_light.intensity = 2.5
	impact_light.position = pos
	game_node.add_child(impact_light)
	get_tree().create_timer(0.5).timeout.connect(impact_light.queue_free)

func _cleanup():
	if meteor_id != "":
		PhysicsManager.unregister_soft_body(meteor_id)
		meteor_id = ""
	if meteor_line:
		var l = meteor_line
		create_tween().tween_property(l, "modulate:a", 0.0, 0.5).finished.connect(l.queue_free)
		meteor_line = null
	if head_visual:
		head_visual.queue_free()
		head_visual = null
	for wire in electrical_wires:
		create_tween().tween_property(wire, "modulate:a", 0.0, 0.2).finished.connect(wire.queue_free)
	electrical_wires.clear()
	set_process(false)

func _exit_tree():
	_cleanup()
