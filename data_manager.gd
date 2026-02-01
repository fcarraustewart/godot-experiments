extends Node

# DataManager Singleton (Autoload)
# Purpose: Single source of truth for game data (spells, stats, etc.)

var spell_db = {}

func _ready():
	load_spell_data()

func load_spell_data():
	var file_path = "res://spells.json"
	if not FileAccess.file_exists(file_path):
		print("Error: spells.json not found!")
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		var data = json.data
		if typeof(data) == TYPE_ARRAY:
			for spell in data:
				_sanitize_data(spell)
				spell_db[spell.id] = spell
			print("DataManager: Successfully loaded %d spells." % spell_db.size())
		else:
			print("Error: Expected array in spells.json")
	else:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())

func _sanitize_data(dict: Dictionary):
	# Keys that MUST be integers for engine compatibility (frames, IDs, indices)
	var int_keys = [
		"casting_frames", 
		"success_frames", 
		"casting_anim_id", 
		"success_anim_id", 
		"jumps",
		"charge_gen",
		"charge_cost"
	]
	
	for key in dict.keys():
		var val = dict[key]
		if typeof(val) == TYPE_FLOAT:
			# Only convert to int if it's in our strict list AND is a whole number
			if key in int_keys or key.ends_with("_id") or key.ends_with("_frames"):
				if is_equal_approx(val, round(val)):
					dict[key] = int(val)
			# Otherwise, it stays a float as received from JSON

func get_spell(spell_id: String) -> Dictionary:
	if spell_db.has(spell_id):
		return spell_db[spell_id]
	print("Warning: Spell ID %s not found in DB." % spell_id)
	return {}
