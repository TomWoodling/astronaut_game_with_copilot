extends InventoryItemBase
class_name NPCInventoryData


@export var id: int  # Numeric ID for internal reference
@export var label: String  # Display name/text label
@export_multiline var description: String
@export var rank_tier: int = 1  # Numeric tier (1-5)
@export var job_title: String
@export_multiline var trivia: String



@export var is_default: bool = false  # Flag for default objects

# These will be used by the editor to visualize but not affect runtime
@export_group("Debug Visualization")
@export var preview_color: Color = Color(1.0, 1.0, 1.0)  # For debug visualization
