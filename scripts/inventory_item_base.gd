# res://resources/inventory/inventory_item_base.gd
extends Resource
class_name InventoryItemBase

## Base class for all items tracked in the inventory/player progress.

enum ItemType {
	SCAN_ITEM,         # Result of scanning world objects
	NPC,               # Non-Player Character encountered
	CHALLENGE,         # A specific challenge/quest objective
	ENCOUNTER_LOG,     # Log entry from dialogue or finding info
	COLLECTIBLE_CATEGORY,# Represents a category in the collection log (e.g., EXOBOTANY)
	PLAYER_EQUIPMENT   # Gear the player has (Scanner, Backpack)
	# Add more as needed
	}

# String names corresponding to ItemType enum for display
const ITEM_TYPE_NAMES = [
	"Scan Data",
	"Personnel",
	"Objective",
	"Log Entry",
	"Collection",
	"Equipment"
]

@export var item_uid: String = ""       # Unique identifier (e.g., "scan_res_abstract_cube", "npc_lucy")
@export var item_key: int = 0           # Unique NUMERIC key so we can track our assets CMDB style!
@export var display_name: String = ""   # Name shown in UI (e.g., "Abstract Cube", "Lucy Borgiya")
@export var item_type: ItemType = ItemType.SCAN_ITEM
@export var icon: Texture2D = null     # Icon for the inventory card

# Optional common property
@export_multiline var card_description: String = ""

# Helper to get the display name for the item type enum
static func get_item_type_name(type_enum: ItemType) -> String:
	if type_enum >= 0 and type_enum < ITEM_TYPE_NAMES.size():
		return ITEM_TYPE_NAMES[type_enum]
	return "Unknown Type"
