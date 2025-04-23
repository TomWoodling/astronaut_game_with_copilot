# collection_item_data.gd
extends InventoryItemBase
class_name CollectionItemData

@export var id: int  # Numeric ID for internal reference
@export_enum("EXOBOTANY", "EXOGEOLOGY", "EXOBIOLOGY", "ARTIFACTS") var category: int
@export var label: String  # Display name/text label
@export_multiline var description: String
@export_file("*.png") var icon_path: String  # Optional icon
@export_file("*.tscn") var model_scene_path: String  # Optional 3D model reference
@export var rarity_tier: int = 1  # Numeric tier (1-5)
@export var is_default: bool = false  # Flag for default objects

# These will be used by the editor to visualize but not affect runtime
@export_group("Debug Visualization")
@export var preview_color: Color = Color(1.0, 1.0, 1.0)  # For debug visualization
