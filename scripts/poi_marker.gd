extends Control

var target: Node3D
var main_camera: Camera3D

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Icon/Label

func _ready() -> void:
	# Hide initially until setup is called
	hide()

func setup(target_node: Node3D, icon_texture: Texture2D, marker_label: String = "") -> void:
	target = target_node
	icon.texture = icon_texture
	label.text = marker_label
	
	# Find the main camera (assuming it's in the "main_camera" group)
	main_camera = get_tree().get_first_node_in_group("main_camera")
	if not main_camera:
		push_error("No main camera found for POI marker")
		return
		
	show()

func _process(_delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(main_camera):
		queue_free()
		return
		
	var screen_pos = main_camera.unproject_position(target.global_position)
	
	# Check if target is behind the camera
	var target_dir = target.global_position - main_camera.global_position
	var is_behind = target_dir.dot(main_camera.global_transform.basis.z) > 0
	
	if is_behind:
		icon.modulate.a = 0.5
		screen_pos = screen_pos.clamp(Vector2.ZERO, get_viewport_rect().size)
	else:
		icon.modulate.a = 1.0
	
	# Update position, accounting for icon size
	position = screen_pos - icon.size / 2
