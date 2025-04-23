@tool
extends Control

signal generate_preview
signal apply_cave

var cave_generator

# Primitive section references
@onready var primitive_type_option = $VBoxContainer/PrimitiveSection/PrimitiveType
@onready var width_slider = $VBoxContainer/PrimitiveSection/Width/WidthSlider
@onready var width_spinner = $VBoxContainer/PrimitiveSection/Width/WidthSpinner
@onready var height_slider = $VBoxContainer/PrimitiveSection/Height/HeightSlider
@onready var height_spinner = $VBoxContainer/PrimitiveSection/Height/HeightSpinner
@onready var segments_slider = $VBoxContainer/PrimitiveSection/Segments/SegmentsSlider
@onready var segments_spinner = $VBoxContainer/PrimitiveSection/Segments/SegmentsSpinner
@onready var rings_slider = $VBoxContainer/PrimitiveSection/Rings/RingsSlider
@onready var rings_spinner = $VBoxContainer/PrimitiveSection/Rings/RingsSpinner

# Noise section references
@onready var noise_type_option = $VBoxContainer/NoiseSection/NoiseType
@onready var noise_amplitude_slider = $VBoxContainer/NoiseSection/Amplitude/AmplitudeSlider
@onready var noise_amplitude_spinner = $VBoxContainer/NoiseSection/Amplitude/AmplitudeSpinner
@onready var noise_frequency_slider = $VBoxContainer/NoiseSection/Frequency/FrequencySlider
@onready var noise_frequency_spinner = $VBoxContainer/NoiseSection/Frequency/FrequencySpinner
@onready var noise_seed_spinner = $VBoxContainer/NoiseSection/Seed/SeedSpinner
@onready var noise_octaves_spinner = $VBoxContainer/NoiseSection/Octaves/OctavesSpinner

# Floor section references
@onready var floor_checkbox = $VBoxContainer/FloorSection/AddFloor
@onready var floor_height_slider = $VBoxContainer/FloorSection/FloorHeight/HeightSlider
@onready var floor_height_spinner = $VBoxContainer/FloorSection/FloorHeight/HeightSpinner
@onready var floor_roughness_slider = $VBoxContainer/FloorSection/FloorRoughness/RoughnessSlider
@onready var floor_roughness_spinner = $VBoxContainer/FloorSection/FloorRoughness/RoughnessSpinner

# Preset section references
@onready var preset_option = $VBoxContainer/PresetSection/PresetOption

# Button references
@onready var generate_button = $VBoxContainer/ButtonSection/GenerateButton
@onready var apply_button = $VBoxContainer/ButtonSection/ApplyButton

func _ready():
	# Link sliders with spinners using the share() method
	width_slider.share(width_spinner)
	height_slider.share(height_spinner)
	segments_slider.share(segments_spinner)
	rings_slider.share(rings_spinner)
	noise_amplitude_slider.share(noise_amplitude_spinner)
	noise_frequency_slider.share(noise_frequency_spinner)
	floor_height_slider.share(floor_height_spinner)
	floor_roughness_slider.share(floor_roughness_spinner)
	
	# Connect the remaining necessary signals
	primitive_type_option.connect("item_selected", Callable(self, "_on_primitive_type_selected"))
	noise_type_option.connect("item_selected", Callable(self, "_on_noise_type_selected"))
	noise_seed_spinner.connect("value_changed", Callable(self, "_on_noise_seed_changed"))
	noise_octaves_spinner.connect("value_changed", Callable(self, "_on_noise_octaves_changed"))
	
	floor_checkbox.connect("toggled", Callable(self, "_on_floor_toggled"))
	preset_option.connect("item_selected", Callable(self, "_on_preset_selected"))
	
	generate_button.connect("pressed", Callable(self, "_on_generate_button_pressed"))
	apply_button.connect("pressed", Callable(self, "_on_apply_button_pressed"))
	
	# Setup UI with initial values
	_setup_ui()

func _setup_ui():
	# Populate primitive type options
	primitive_type_option.clear()
	primitive_type_option.add_item("Cylinder", 0)
	primitive_type_option.add_item("Cone", 1)
	primitive_type_option.add_item("Sphere", 2)
	primitive_type_option.add_item("Capsule", 3)
	primitive_type_option.add_item("Torus", 4)
	primitive_type_option.select(0)
	
	# Populate noise type options
	noise_type_option.clear()
	noise_type_option.add_item("Perlin", 0)
	noise_type_option.add_item("Simplex", 1)
	noise_type_option.add_item("Cellular", 2)
	noise_type_option.add_item("Value", 3)
	noise_type_option.select(0)
	
	# Populate preset options
	preset_option.clear()
	preset_option.add_item("Custom", 0)
	preset_option.add_item("Small Chamber", 1)
	preset_option.add_item("Large Cavern", 2)
	preset_option.add_item("Tunnel Section", 3)
	preset_option.add_item("Cenote", 4)
	preset_option.add_item("Underground Dome", 5)
	preset_option.select(0)
	
	# Since sliders and spinners are linked, we only need to set values on one of them
	width_spinner.value = 10.0
	height_spinner.value = 25.0
	segments_spinner.value = 64
	rings_spinner.value = 32
	
	noise_amplitude_spinner.value = 1.5
	noise_frequency_spinner.value = 0.2
	noise_seed_spinner.value = 0
	noise_octaves_spinner.value = 3
	
	floor_checkbox.button_pressed = true
	floor_height_spinner.value = 0.0
	floor_roughness_spinner.value = 0.2

# Signal handlers for primitive section
func _on_primitive_type_selected(index):
	cave_generator.set_primitive_type(index)
	# Update rings and segments based on primitive type
	match index:
		0: # Cylinder
			rings_spinner.value = 8
		1: # Cone
			rings_spinner.value = 1
		2, 4: # Sphere or Torus
			rings_spinner.value = 32
		3: # Capsule
			rings_spinner.value = 8

# Since sliders and spinners are now linked with share(), we only need these value_changed handlers
# for controls that aren't sliders or aren't linked

func _on_noise_type_selected(index):
	cave_generator.set_noise_type(index)

func _on_noise_seed_changed(value):
	cave_generator.noise_seed = int(value)

func _on_noise_octaves_changed(value):
	cave_generator.noise_octaves = int(value)

# Signal handlers for floor section
func _on_floor_toggled(toggled):
	cave_generator.add_floor = toggled
	$VBoxContainer/FloorSection/FloorHeight.visible = toggled
	$VBoxContainer/FloorSection/FloorRoughness.visible = toggled

# Signal handlers for presets
func _on_preset_selected(index):
	if index == 0:  # Custom
		return
	
	var preset_name = preset_option.get_item_text(index)
	cave_generator.set_preset(preset_name)
	
	# Update UI to match preset
	_update_ui_from_generator()

func _update_ui_from_generator():
	primitive_type_option.select(cave_generator.primitive_type)
	
	# Only need to update one of each linked pair
	width_spinner.value = cave_generator.width
	height_spinner.value = cave_generator.height
	segments_spinner.value = cave_generator.radial_segments
	rings_spinner.value = cave_generator.rings
	
	noise_type_option.select(cave_generator.noise_type)
	noise_amplitude_spinner.value = cave_generator.noise_amplitude
	noise_frequency_spinner.value = cave_generator.noise_frequency
	noise_seed_spinner.value = cave_generator.noise_seed
	noise_octaves_spinner.value = cave_generator.noise_octaves
	
	floor_checkbox.button_pressed = cave_generator.add_floor
	floor_height_spinner.value = cave_generator.floor_height
	floor_roughness_spinner.value = cave_generator.floor_roughness
	
	$VBoxContainer/FloorSection/FloorHeight.visible = cave_generator.add_floor
	$VBoxContainer/FloorSection/FloorRoughness.visible = cave_generator.add_floor

# We need these value_changed events to connect to the generator
# The HSlider and SpinBox are linked, so changing one changes the other
func _process_value_changes():
	cave_generator.width = width_spinner.value
	cave_generator.height = height_spinner.value
	cave_generator.radial_segments = int(segments_spinner.value)
	cave_generator.rings = int(rings_spinner.value)
	
	cave_generator.noise_amplitude = noise_amplitude_spinner.value
	cave_generator.noise_frequency = noise_frequency_spinner.value
	
	cave_generator.floor_height = floor_height_spinner.value
	cave_generator.floor_roughness = floor_roughness_spinner.value

# Button handlers
func _on_generate_button_pressed():
	_process_value_changes()
	emit_signal("generate_preview")

func _on_apply_button_pressed():
	_process_value_changes()
	emit_signal("apply_cave")
