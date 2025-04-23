# dialog_container.gd
class_name DialogContainer
extends Resource

@export var dialog_id: String = ""
var dialog_entries: Array[DialogEntry] = []

func add_entry(speaker: String, text: String, mood: String = "neutral", animation_hint: String = "") -> void:
	var entry = DialogEntry.new(speaker, text, mood, animation_hint)
	dialog_entries.append(entry)

func get_entry(index: int) -> DialogEntry:
	if index >= 0 and index < dialog_entries.size():
		return dialog_entries[index]
	return null
