# res://scripts/managers/hud_manager.gd
# Autoload Singleton named 'HUDManager'
# Manages visibility and content of primary HUD elements.
extends Node

# --- References to HUD Elements ---
# Assign these in the editor or find them in _ready if they are part of the main scene
@export var dialog_display: Control # Assign the DialogDisplay node
@export var scanner_display: Control # Assign the ScannerDisplay node
@export var item_card_display: ItemCardDisplay
# @export var inventory_display: Control # Add later
# @export var pause_menu_display: Control # Add later
@export var message_container: Node # A container (e.g., VBoxContainer) to hold transient messages

# --- Packed Scenes ---
@export var message_display_scene: PackedScene # Assign message_display.tscn

# --- State ---
var _is_dialog_active: bool = false
var _is_scanner_active: bool = false
# var _is_inventory_active: bool = false # Add later
# var _is_pause_menu_active: bool = false # Add later

# --- Item Data Management ---
var _item_registry = {}  # Dictionary to store all loaded item resources by key
var _is_card_active: bool = false

# Signals
signal dialog_over

# --- Initialization ---
func _ready() -> void:
	# Basic validation
	if not dialog_display: push_warning("HUDManager: DialogDisplay node not assigned.")
	if not scanner_display: push_warning("HUDManager: ScannerDisplay node not assigned.")
	if not message_container: push_warning("HUDManager: MessageContainer node not assigned.")
	if not message_display_scene: push_warning("HUDManager: MessageDisplay scene not assigned.")

	# Ensure elements have the HUDElement script and start hidden
	_initialize_hud_element(dialog_display)
	_initialize_hud_element(scanner_display)
	_initialize_hud_element(item_card_display)
	# _initialize_hud_element(inventory_display) # Add later
	# _initialize_hud_element(pause_menu_display) # Add later

	# Connect to GameManager signals
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.cancel_action_requested.connect(_on_cancel_action_requested)

	# Connect to other Managers (these connections are made *by* the other managers typically,
	# but we list them here for clarity of what HUDManager responds to)
	# Example: EncounterManager.dialogue_started.connect(show_dialog)
	ScannerManager.scan_started.connect(show_scanner)
	ScannerManager.scan_completed.connect(hide_scanner)
	dialog_display.dialog_completed.connect(complete_dialog)
	_load_all_item_resources()
	
	print("HUDManager Ready with " + str(_item_registry.size()) + " item resources loaded.")

# --- Public Methods ---

# Dialog Display
func show_dialog(dialog_container) -> void:
	if dialog_display:
		dialog_display.start_dialog(dialog_container) # Assumes DialogDisplay has HUDElement logic handled internally or inherits it.
		_is_dialog_active = true
		# DialogDisplay's start_dialog should call show_element() itself.
	else:
		push_warning("HUDManager: Cannot show dialog, display node invalid or lacks start_dialog method.")

func complete_dialog():
	_is_dialog_active = false
	emit_signal("dialog_over")
	
# I doubt this is ever used
func hide_dialog() -> void:
	if dialog_display:
		dialog_display.hide_element()
		_is_dialog_active = false
	else:
		push_warning("HUDManager: Cannot hide dialog, display node invalid or lacks hide_element method.")

# Scanner Display
func show_scanner(target: ScannableObject) -> void:
	if scanner_display:
		scanner_display.show_element()
		scanner_display.setup_display_for_scan(target)
		_is_scanner_active = true
	else:
		push_warning("HUDManager: Cannot show scanner, display node invalid or lacks required methods.")

func hide_scanner(_target,_data) -> void:
	if scanner_display:
		scanner_display.clear_display_state()
		scanner_display.hide_element()
		_is_scanner_active = false
	else:
		push_warning("HUDManager: Cannot hide scanner, display node invalid or lacks required methods.")
	var idx: int = _data.id
	_preview_card(idx)

# Transient Messages
func show_message(message_data: Dictionary) -> void:
	if not message_display_scene or not message_container:
		push_warning("HUDManager: Cannot show message, scene or container not set.")
		return

	if not message_data.has("text") or not message_data.has("color") or not message_data.has("duration"):
		push_warning("HUDManager: Invalid message_data format. Requires 'text', 'color', 'duration'.")
		return

	var message_instance = message_display_scene.instantiate()
	if message_instance.has_method("display_message"):
		message_container.add_child(message_instance)
		message_instance.display_message(message_data) # The instance manages its own lifecycle
	else:
		push_error("HUDManager: message_display scene instance lacks 'display_message' method.")
		message_instance.queue_free() # Clean up if unusable

# --- Signal Handlers ---

func _on_game_state_changed(_previous_state: GameManager.GameState, new_state: GameManager.GameState) -> void:
	# Hide certain UI elements when not playing
	if new_state != GameManager.GameState.PLAYING:
		if _is_dialog_active: hide_dialog()
		if _is_scanner_active: hide_scanner(1,2)
		# if _is_inventory_active: hide_inventory() # Add later
		# Clear transient messages maybe? Or let them fade out naturally.

	# Handle Pause Menu visibility (add later)
	# if new_state == GameManager.GameState.PAUSED: show_pause_menu()
	# elif _previous_state == GameManager.GameState.PAUSED: hide_pause_menu()
	pass


func _on_cancel_action_requested() -> void:
	# Handle Esc key press for UI elements
	# In V1, mainly relevant if we add Inventory or Pause Menu later.
	# Dialog advancement is handled by EncounterManager listening to this signal.

	# Add card display handling
	if _is_card_active:
		hide_item_card()
		return
	pass

# --- Private Helpers ---

func _initialize_hud_element(element: Control) -> void:
	if element:
		if not element is HUDElement:
			push_warning("HUDManager: Node '%s' does not inherit from HUDElement. Fade animations might not work as expected." % element.name)
		elif element.has_method("hide_immediately"): # Use immediate hide during setup
				element.hide_immediately()

func _preview_card(card_key: int) -> void:
	show_item_card(card_key)
	await get_tree().create_timer(4.0).timeout
	hide_item_card()

# Card display and management - will move to inventory when it's added
# --- Item Card Management ---
func show_item_card(item_key: int) -> void:
	if not item_card_display:
		push_warning("HUDManager: Cannot show item card, display node invalid.")
		return
	
	if not _item_registry.has(item_key):
		push_warning("HUDManager: Item key " + str(item_key) + " not found in registry.")
		return
	
	item_card_display.setup_card(_item_registry[item_key])
	item_card_display.show_element()
	_is_card_active = true

func hide_item_card() -> void:
	if item_card_display:
		item_card_display.hide_element()
		_is_card_active = false
	else:
		push_warning("HUDManager: Cannot hide item card, display node invalid.")

# --- Item Resource Loading ---
func _load_all_item_resources() -> void:
	# Directories to scan for .tres files
	var dirs = [
		"res://resources/challenges",
		"res://resources/collection_items",
		"res://resources/encounters",
		"res://resources/npcs"
	]
	
	# Scan each directory
	for dir_path in dirs:
		_scan_directory_for_resources(dir_path)
	
	print("Item resource loading complete. Found " + str(_item_registry.size()) + " items.")

func _scan_directory_for_resources(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("HUDManager: Failed to access directory: " + path)
		return
	
	# List all files in the directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			# Check if it's a .tres file
			if file_name.ends_with(".tres"):
				var full_path = path + "/" + file_name
				_load_item_resource(full_path)
		
		# Check subdirectories recursively
		elif file_name != "." and file_name != "..":
			_scan_directory_for_resources(path + "/" + file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _load_item_resource(path: String) -> void:
	var resource = load(path)
	
	# Check if it's a valid InventoryItemBase resource
	if resource is InventoryItemBase:
		var item = resource as InventoryItemBase
		
		# Add to registry using item_key as the key
		if item.item_key > 0:  # Ensure it has a valid key
			_item_registry[item.item_key] = item
			print("Loaded item: " + item.display_name + " (Key: " + str(item.item_key) + ")")
		else:
			push_warning("HUDManager: Item at " + path + " has invalid item_key: " + str(item.item_key))
	else:
		# Not an InventoryItemBase, ignore it
		pass
