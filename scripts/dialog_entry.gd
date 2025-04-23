# dialog_entry.gd
class_name DialogEntry

var speaker: String
var text: String
var mood: String = "neutral"  # Can be "neutral", "positive", "negative"
var animation_hint: String = ""  # Optional hint for specific NPC animation

func _init(p_speaker: String = "", p_text: String = "", p_mood: String = "neutral", p_anim_hint: String = ""):
	speaker = p_speaker
	text = p_text
	mood = p_mood
	animation_hint = p_anim_hint
