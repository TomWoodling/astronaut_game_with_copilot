# res://scripts/ui/item_card_display.gd
class_name ItemCardDisplay
extends HUDElement

# UI Nodes (to be assigned in the editor)
@onready var icon_texture: TextureRect = $VBoxContainer/IconContainer/Icon
@onready var title_label: Label = $VBoxContainer/TitleContainer/Title
@onready var type_label: Label = $VBoxContainer/TypeContainer/Type
@onready var id_label: Label = $VBoxContainer/IDContainer/ID
@onready var description_label: Label = $VBoxContainer/DescriptionContainer/Description

# Current item data
var current_item: InventoryItemBase = null

func _ready() -> void:
	super._ready() # Call HUDElement's _ready to ensure we start hidden

# Set up the card with item data
func setup_card(item: InventoryItemBase) -> void:
	current_item = item
	
	if item == null:
		clear_card()
		return
	print(item)
	# Set icon
	if item.icon:
		icon_texture.texture = item.icon
		icon_texture.visible = true
	else:
		icon_texture.texture = null
		icon_texture.visible = false
	
	# Set text fields
	title_label.text = item.display_name
	type_label.text = InventoryItemBase.get_item_type_name(item.item_type)
	id_label.text = "ID: " + str(item.item_key)
	description_label.text = item.card_description if item.card_description else "No description available."

# Clear the card data
func clear_card() -> void:
	current_item = null
	icon_texture.texture = null
	title_label.text = ""
	type_label.text = ""
	id_label.text = ""
	description_label.text = ""
