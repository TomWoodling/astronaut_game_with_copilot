# res://scripts/ui/hud_element.gd
# Base class for HUD elements providing standardized fade animations.
# Attach this to the root Control node of your HUD panel scenes.
class_name HUDElement 
extends Control

# Export allows tweaking fade duration per element instance if needed
@export var fade_duration: float = 0.2

var _active_tween: Tween = null

func _ready() -> void:
	# Ensure elements start hidden and fully transparent
	modulate.a = 0.0
	visible = false

## Shows the element with a fade-in animation.
func show_element() -> void:
	_kill_existing_tween() # Prevent conflicting animations

	# Start visible but transparent
	modulate.a = 0.0
	visible = true

	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(func(): _active_tween = null) # Clear ref on finish

## Hides the element with a fade-out animation.
func hide_element() -> void:
	# Don't try to hide if already hidden or fading out
	if not visible or (modulate.a == 0.0 and not _active_tween):
		return
	if _active_tween and _active_tween.is_running() and modulate.a < 1.0:
		# Already fading out, let it finish or kill it below
		pass

	_kill_existing_tween() # Prevent conflicting animations

	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 0.0, fade_duration)\
				 .set_trans(Tween.TRANS_CUBIC)\
				 .set_ease(Tween.EASE_IN) # Ease in looks better for fade out

	# Hide the control *after* the tween finishes
	_active_tween.tween_callback(func():
		visible = false
		_active_tween = null # Clear ref on finish
	)

## Immediately sets visibility without animation.
func show_immediately() -> void:
	_kill_existing_tween()
	modulate.a = 1.0
	visible = true

## Immediately sets invisibility without animation.
func hide_immediately() -> void:
	_kill_existing_tween()
	modulate.a = 0.0
	visible = false

## Checks if the element is currently visible and not fading out.
func is_fully_visible() -> bool:
	# Visible property check AND alpha check AND not currently fading out
	return visible and modulate.a > 0.95 and (not _active_tween or modulate.a == 1.0)

## Helper to safely stop any active tween.
func _kill_existing_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
