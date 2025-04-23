# scannable_selector.gd
extends Node
class_name ScannableSelector

# Category enum for readability
enum Category { EXOBOTANY, EXOGEOLOGY, EXOBIOLOGY, ARTIFACTS }

# Elevation zones
enum ElevationZone { LOW, MEDIUM, HIGH }

# Category weights based on elevation zone (LOW, MEDIUM, HIGH)
const CATEGORY_ELEVATION_WEIGHTS = {
	Category.EXOBOTANY:  [0.15, 0.45, 0.30],  # uncommon low, abundant mid, common high
	Category.EXOGEOLOGY: [0.30, 0.15, 0.45],  # common low, uncommon mid, abundant high
	Category.EXOBIOLOGY: [0.45, 0.30, 0.15],  # abundant low, common mid, uncommon high
	Category.ARTIFACTS:  [0.10, 0.10, 0.10]   # rare at all elevations
}

# Rarity tier weights (becomes progressively rarer)
const RARITY_TIER_WEIGHTS = [0.50, 0.25, 0.15, 0.07, 0.03]  # Tier 1-5

# Cache for loaded scenes
var _scene_cache = {}

# Mission configuration (optional)
var _mission_config = null

func _ready() -> void:
	# Preload all scannable scenes
	_preload_all_scannables()

# Load all available scannable objects from the objects directory
func _preload_all_scannables() -> void:
	var dir = DirAccess.open("res://scenes/objects/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var path = "res://scenes/objects/" + file_name
				var scene = load(path)
				
				# Check if it's a scannable object
				if scene and scene.can_instantiate():
					var instance = scene.instantiate()
					if instance is ScannableObject:
						var collection_data = instance.collection_data
						if collection_data and not collection_data.is_default:
							_scene_cache[path] = {
								"scene": scene,
								"id": collection_data.id,
								"category": collection_data.category,
								"tier": collection_data.rarity_tier
							}
						instance.queue_free()
					else:
						instance.queue_free()
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

# Set mission configuration from MissionManager singleton
func set_mission_config() -> void:
	var mission_manager = get_node("/root/MissionManager")
	_mission_config = {
		"min_rarity_tier": mission_manager.min_rarity_tier,
		"max_rarity_tier": mission_manager.max_rarity_tier,
		"exclude_cats": mission_manager.exclude_cats
	}

# Get appropriate scannable for a specific location
func get_scannable_for_location(world_pos: Vector3, terrain_height: float) -> PackedScene:
	# Determine which scenes are in scope
	var scannables_in_scope = {}
	
	# Apply mission filters if configured
	if _mission_config:
		for path in _scene_cache:
			var item = _scene_cache[path]
			# Check if item meets rarity tier requirements and isn't in excluded categories
			if (item.tier >= _mission_config.min_rarity_tier and 
				item.tier <= _mission_config.max_rarity_tier and 
				not _mission_config.exclude_cats.has(item.category)):
				scannables_in_scope[path] = item
	else:
		# Use all available scannables if no mission config
		scannables_in_scope = _scene_cache
	
	# If no valid scannables, return default tree
	if scannables_in_scope.size() == 0:
		return load("res://scenes/objects/basic_tree.tscn")
		
	# Rest of the function remains the same...
	# Determine elevation zone based on terrain height
	var elevation_zone = _get_elevation_zone(terrain_height)
	
	# Calculate weights for all scannables in scope
	var weighted_selection = []
	var total_weight = 0.0
	
	for path in scannables_in_scope:
		var item = scannables_in_scope[path]
		var category = item.category
		var tier = item.tier
		
		# Calculate weight based on category and elevation
		var category_weight = CATEGORY_ELEVATION_WEIGHTS[category][elevation_zone]
		
		# Calculate weight based on rarity tier
		var tier_weight = RARITY_TIER_WEIGHTS[tier - 1] if tier <= RARITY_TIER_WEIGHTS.size() else 0.01
		
		# Combined weight (multiply for proper distribution)
		var final_weight = category_weight * tier_weight
		
		# Apply pseudorandom variation to ensure less predictable spawning
		# but maintain overall distribution pattern
		var variation = randf_range(0.8, 1.2)  # ±20% variation
		final_weight *= variation
		
		if final_weight > 0:
			weighted_selection.append({
				"path": path,
				"scene": item.scene,
				"weight": final_weight
			})
			total_weight += final_weight
	
	# If even after weighting nothing is valid, return default
	if weighted_selection.size() == 0 or total_weight <= 0:
		return load("res://scenes/objects/basic_tree.tscn")
	
	# Select random scannable based on weights
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for selection in weighted_selection:
		current_weight += selection.weight
		if roll <= current_weight:
			return selection.scene
	
	# Fallback to first valid scannable
	return weighted_selection[0].scene

# Determine elevation zone based on terrain height
func _get_elevation_zone(height: float) -> int:
	# Get terrain height range from WorldGenerator
	var world_gen = get_node_or_null("/root/WorldGenerator")
	var height_range = Vector2(-4.0, 4.5)  # Default from your script
	
	if world_gen and world_gen.has_method("get_terrain_height_range"):
		height_range = world_gen.get_terrain_height_range()
	
	# Calculate zone thresholds
	var range_size = height_range.y - height_range.x
	var low_threshold = height_range.x + (range_size * 0.33)
	var high_threshold = height_range.x + (range_size * 0.66)
	
	# Determine zone
	if height < low_threshold:
		return ElevationZone.LOW
	elif height > high_threshold:
		return ElevationZone.HIGH
	else:
		return ElevationZone.MEDIUM
