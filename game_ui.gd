extends CanvasLayer

# --- UI ELEMENTS ---
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var skill_box: HBoxContainer
var skills = {}

# --- REFERENCES ---
var player_node: Node2D
var cl_controller
var fc_controller
var meteor_controller

func _ready():
	# Root Control
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Allow mouse pass-through for gameplay
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	add_child(root)
	
	# --- BOTTOM WIDGET PANEL ---
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(500, 100)
	panel.position.y -= 20 # Padding from bottom
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Style the panel (Dark transparent)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_vbox.add_theme_constant_override("margin_top", 10)
	content_vbox.add_theme_constant_override("margin_left", 20)
	content_vbox.add_theme_constant_override("margin_right", 20)
	content_vbox.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(content_vbox)
	
	# --- 1. STATUS BARS (HP / MP) ---
	var bars_hbox = HBoxContainer.new()
	bars_hbox.custom_minimum_size.y = 20
	content_vbox.add_child(bars_hbox)
	
	# HP
	hp_bar = create_bar(Color(0.8, 0.2, 0.2), "HP: 100/100")
	bars_hbox.add_child(hp_bar)
	
	# Charge (Power Surge)
	mp_bar = create_bar(Color(1.0, 0.6, 0.2), "POWER SURGE: 0/130")
	bars_hbox.add_child(mp_bar)
	
	# --- 2. SKILLS ---
	skill_box = HBoxContainer.new()
	skill_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_box.add_theme_constant_override("separation", 20)
	content_vbox.add_child(skill_box)
	
	# Add Skills
	add_skill_icon("Attack", "4", Color(0.7, 0.7, 0.7))
	add_skill_icon("Lightning", "3", Color(0.2, 0.6, 1.0))
	add_skill_icon("Fire Chains", "F", Color(1.0, 0.4, 0.0))
	add_skill_icon("Meteor", "R", Color(1.0, 0.1, 0.1))

func create_bar(color: Color, label_text: String) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.value = 100
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2)
	bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = color
	bar.add_theme_stylebox_override("fill", style_fill)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	
	return bar

func add_skill_icon(skill_name: String, keybind: String, color: Color):
	var cont = VBoxContainer.new()
	skill_box.add_child(cont)
	
	# Icon Representation
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.color = color
	cont.add_child(icon)
	
	# Cooldown Overlay (Darken)
	var cd_overlay = ColorRect.new()
	cd_overlay.color = Color(0, 0, 0, 0.7)
	cd_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_overlay.visible = false
	icon.add_child(cd_overlay)
	
	# Label
	var lbl = Label.new()
	lbl.text = keybind
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	cont.add_child(lbl)
	
	skills[skill_name] = {
		"icon": icon,
		"cd_overlay": cd_overlay
	}

func _process(delta):
	# Update Cooldown Visuals
	if cl_controller:
		update_cooldown("Lightning", cl_controller.chain_cooldown, cl_controller.CHAIN_COOLDOWN_MAX)
		
	if fc_controller:
		update_cooldown("Fire Chains", fc_controller.cooldown, fc_controller.COOLDOWN_MAX)
		
	if meteor_controller:
		# Meteor doesn't have a simple COOLDOWN_MAX var in the script yet, 
		# but we know it from DataManager or hardcode for UI
		update_cooldown("Meteor", 0.0, 15.0) # Placeholder for now

	# Update Charge Bar
	if player_node:
		mp_bar.max_value = 130
		mp_bar.value = player_node.global_charge
		var lbl = mp_bar.get_child(0)
		if lbl is Label:
			lbl.text = "POWER SURGE: %d/130" % int(player_node.global_charge)

func update_cooldown(skill_name, current_cd, max_cd):
	if skill_name in skills:
		var ui = skills[skill_name]
		if current_cd > 0:
			ui.cd_overlay.visible = true
			# Scale height based on remaining time? Or just alpha?
			# Simple vertical slider effect
			var ratio = current_cd / max_cd
			ui.cd_overlay.size.y = 40 * ratio
		else:
			ui.cd_overlay.visible = false
