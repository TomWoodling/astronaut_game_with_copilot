@tool
extends Control

signal generate_preview
signal apply_terrain

var terrain_generator # Keep the variable declaration

# Node references (keep these)
@onready var type_option: OptionButton = $VBoxContainer/TypeSection/TypeOption
@onready var preset_option: OptionButton = $VBoxContainer/PresetSection/PresetOption
@onready var size_slider: HSlider = $VBoxContainer/SizeSection/SizeSlider
@onready var chunks_slider: HSlider = $VBoxContainer/ChunksSection/ChunksSlider
@onready var height_slider: HSlider = $VBoxContainer/HeightSection/HeightSlider
@onready var steep_slider: HSlider = $VBoxContainer/SteepSection/SteepSlider
@onready var roughness_slider: HSlider = $VBoxContainer/RoughnessSection/RoughnessSlider
@onready var elevation_slider: HSlider = $VBoxContainer/ElevationSection/ElevationSlider
@onready var seed_spin: SpinBox = $VBoxContainer/SeedSection/SeedSpin
@onready var dir_x_spin: SpinBox = $VBoxContainer/DirectionSection/DirXSpin
@onready var dir_y_spin: SpinBox = $VBoxContainer/DirectionSection/DirYSpin
@onready var rim_slider: HSlider = $VBoxContainer/AdvancedSection/RimSlider
@onready var edge_slider: HSlider = $VBoxContainer/AdvancedSection/EdgeSlider
@onready var preview_button: Button = $VBoxContainer/ButtonSection/PreviewButton
@onready var apply_button: Button = $VBoxContainer/ButtonSection/ApplyButton


func _ready():
	# --- REMOVE THE CHECK FOR terrain_generator HERE ---
	# It's okay if it's null at this exact moment.

	# Connect UI signals - These connections can be made even if terrain_generator is null initially.
	# The callbacks themselves will use the terrain_generator reference later when invoked.
	type_option.connect("item_selected", Callable(self, "_on_type_selected"))
	preset_option.connect("item_selected", Callable(self, "_on_preset_selected"))
	size_slider.connect("value_changed", Callable(self, "_on_size_changed"))
	chunks_slider.connect("value_changed", Callable(self, "_on_chunks_changed"))
	height_slider.connect("value_changed", Callable(self, "_on_height_changed"))
	steep_slider.connect("value_changed", Callable(self, "_on_steep_changed"))
	roughness_slider.connect("value_changed", Callable(self, "_on_roughness_changed"))
	elevation_slider.connect("value_changed", Callable(self, "_on_elevation_changed"))
	seed_spin.connect("value_changed", Callable(self, "_on_seed_changed"))
	dir_x_spin.connect("value_changed", Callable(self, "_on_direction_changed"))
	dir_y_spin.connect("value_changed", Callable(self, "_on_direction_changed"))
	rim_slider.connect("value_changed", Callable(self, "_on_rim_changed"))
	edge_slider.connect("value_changed", Callable(self, "_on_edge_changed"))

	preview_button.connect("pressed", Callable(self, "_on_preview_pressed"))
	apply_button.connect("pressed", Callable(self, "_on_apply_pressed"))

	# --- REMOVE THE _setup_ui CALL FROM HERE ---
	# It will be called explicitly by set_terrain_generator


# This function is called by the plugin *after* _ready might have run
func set_terrain_generator(generator):
	if terrain_generator == generator: # Avoid redundant setup if called multiple times
		return
		
	terrain_generator = generator
	
	if not terrain_generator:
		# If it's being set to null (e.g., during cleanup), handle appropriately
		# Maybe disable controls or clear fields. For now, just return.
		push_warning("Terrain generator reference set to null.")
		# Optionally disable UI elements here
		return

	# Now that we *know* terrain_generator is valid, setup the UI.
	# The is_inside_tree check is still good practice, though in this specific
	# plugin flow, it should always be true when called from _enter_tree.
	if is_inside_tree():
		_setup_ui()
	else:
		# If somehow called before being added, wait for _ready (though unlikely here)
		# Or push an error if this state is unexpected.
		push_error("set_terrain_generator called before dock was added to tree!")


func _setup_ui():
	# --- ADD A GUARD CLAUSE AT THE START ---
	# Ensure terrain_generator is valid before proceeding with setup.
	if not terrain_generator:
		push_error("Cannot set up UI: terrain_generator is null")
		# You might want to disable controls here as well
		type_option.disabled = true
		preset_option.disabled = true
		# ... disable other controls ...
		return
	else:
		# Re-enable controls if they were disabled
		type_option.disabled = false
		preset_option.disabled = false
		# ... enable other controls ...
		
	# (Rest of the _setup_ui function remains the same)
	# Setup type options
	type_option.clear()
	# ... (add items) ...
	type_option.select(terrain_generator.current_type) # Select initial value

	# Setup preset options
	preset_option.clear()
	# ... (add items) ...
	preset_option.select(0) # Default to custom initially

	# Setup slider ranges and values
	size_slider.min_value = 50.0
	size_slider.max_value = 200.0
	size_slider.value = terrain_generator.area_size
	
	# ... (rest of the slider/spinbox setups) ...
	chunks_slider.min_value = 1
	chunks_slider.max_value = 6
	chunks_slider.step = 1 # Ensure integer steps for chunks
	chunks_slider.value = terrain_generator.num_chunks
	
	height_slider.min_value = 10.0
	height_slider.max_value = 50.0
	height_slider.value = terrain_generator.wall_height
	
	steep_slider.min_value = 0.5
	steep_slider.max_value = 0.95
	steep_slider.step = 0.01 # Allow finer control
	steep_slider.value = terrain_generator.wall_steepness
	
	roughness_slider.min_value = 0.0
	roughness_slider.max_value = 1.0
	roughness_slider.step = 0.01
	roughness_slider.value = terrain_generator.floor_roughness
	
	elevation_slider.min_value = -10.0
	elevation_slider.max_value = 10.0
	elevation_slider.step = 0.1
	elevation_slider.value = terrain_generator.floor_elevation
	
	seed_spin.min_value = 0
	seed_spin.max_value = 999999
	seed_spin.value = terrain_generator.noise_seed
	
	rim_slider.min_value = 0.0
	rim_slider.max_value = 5.0
	rim_slider.step = 0.1
	rim_slider.value = terrain_generator.rim_height
	
	edge_slider.min_value = 0.0
	edge_slider.max_value = 0.5
	edge_slider.step = 0.01
	edge_slider.value = terrain_generator.edge_noise
	
	dir_x_spin.min_value = -1.0
	dir_x_spin.max_value = 1.0
	dir_x_spin.step = 0.1
	dir_x_spin.value = terrain_generator.direction.x
	
	dir_y_spin.min_value = -1.0
	dir_y_spin.max_value = 1.0
	dir_y_spin.step = 0.1
	dir_y_spin.value = terrain_generator.direction.y

	# Update visibility of terrain-specific controls
	_update_control_visibility()

# --- Add checks for terrain_generator in callbacks ---
# Ensure terrain_generator is valid before trying to access its properties/methods

func _update_control_visibility():
	if not terrain_generator: return # Add guard clause
	var type = terrain_generator.current_type
	# ... rest of the function ...

func _on_type_selected(index: int):
	if not terrain_generator: return # Add guard clause
	terrain_generator.set_type(index)
	_update_control_visibility()
	preset_option.select(0) # Set to Custom when type changes manually

func _on_preset_selected(index: int):
	if not terrain_generator: return # Add guard clause
	if index == 0:  # Custom
		return

	var preset = preset_option.get_item_text(index)
	terrain_generator.set_preset(preset)

	# Update UI to reflect the new settings
	_update_ui_from_generator()

func _update_ui_from_generator():
	if not terrain_generator: return # Add guard clause
	type_option.select(terrain_generator.current_type)
	# ... rest of the UI updates ...
	_update_control_visibility()

func _on_size_changed(value: float):
	if not terrain_generator: return # Add guard clause
	terrain_generator.area_size = value
	preset_option.select(0)  # Set to Custom

func _on_chunks_changed(value: float):
	if not terrain_generator: return # Add guard clause
	terrain_generator.num_chunks = int(value)
	preset_option.select(0)  # Set to Custom

# ... Add guard clauses (if not terrain_generator: return) to ALL other _on_..._changed methods ...

func _on_height_changed(value: float):
	if not terrain_generator: return
	terrain_generator.wall_height = value
	preset_option.select(0)

func _on_steep_changed(value: float):
	if not terrain_generator: return
	terrain_generator.wall_steepness = value
	preset_option.select(0)

func _on_roughness_changed(value: float):
	if not terrain_generator: return
	terrain_generator.floor_roughness = value
	preset_option.select(0)

func _on_elevation_changed(value: float):
	if not terrain_generator: return
	terrain_generator.floor_elevation = value
	preset_option.select(0)

func _on_seed_changed(value: float):
	if not terrain_generator: return
	terrain_generator.noise_seed = int(value)
	preset_option.select(0)

func _on_direction_changed(_value: float): # Value isn't strictly needed as we read both spins
	if not terrain_generator: return
	var new_dir = Vector2(dir_x_spin.value, dir_y_spin.value)
	# Avoid division by zero if both are 0
	if new_dir.length_squared() > 0.0001:
		terrain_generator.direction = new_dir.normalized()
	else: # Handle the zero vector case (e.g., default to X axis)
		terrain_generator.direction = Vector2.RIGHT
		# Optionally update spins to reflect the normalized/default value if needed
		# dir_x_spin.value = terrain_generator.direction.x
		# dir_y_spin.value = terrain_generator.direction.y
	preset_option.select(0)

func _on_rim_changed(value: float):
	if not terrain_generator: return
	terrain_generator.rim_height = value
	preset_option.select(0)

func _on_edge_changed(value: float):
	if not terrain_generator: return
	terrain_generator.edge_noise = value
	preset_option.select(0)

# --- Signals emitted don't strictly need the check, but the receiving methods do ---

func _on_preview_pressed():
	# Check if generator exists before emitting, as the receiver expects it
	if not terrain_generator:
		push_warning("Cannot generate preview: Terrain generator not available.")
		return
	emit_signal("generate_preview")

func _on_apply_pressed():
	# Check if generator exists before emitting
	if not terrain_generator:
		push_warning("Cannot apply terrain: Terrain generator not available.")
		return
	emit_signal("apply_terrain")
