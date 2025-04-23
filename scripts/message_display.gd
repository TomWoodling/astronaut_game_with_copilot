extends Control
class_name MessageDisplay

@onready var label: Label = $Panel/Label
@onready var panel: Panel = $Panel

var tween: Tween

func _ready() -> void:
	# Start invisible
	modulate.a = 0

func display_message(message_data: Dictionary) -> void:
	# Cancel any existing tween
	if tween and tween.is_valid():
		tween.kill()
	
	# Set message properties
	label.text = message_data.text
	label.add_theme_color_override("font_color", message_data.color)
	
	# Create fade-in tween
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Schedule fade-out and cleanup
	await get_tree().create_timer(message_data.duration).timeout
	
	# Check if we still exist (scene might have changed)
	if not is_instance_valid(self):
		return
		
	# Create fade-out tween
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
