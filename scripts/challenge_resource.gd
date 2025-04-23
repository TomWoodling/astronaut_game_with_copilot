# challenge_resource.gd
extends Resource
class_name ChallengeResource

@export_enum("COLLECTION", "PLATFORMING", "TIMED_TASK", "PUZZLE") var type: String
@export var parameters: Dictionary = {}
@export var time_limit: float = 0.0

# For collection challenges
@export var items_to_collect: Array = []
@export var collection_count: int = 1
@export var spawn_radius: float = 10.0

# For platforming challenges
@export var destination_position: Vector3 = Vector3.ZERO
@export var use_npc_relative_position: bool = true
@export var position_offset: Vector3 = Vector3(2, 0, 0)

# For puzzle challenges
@export var puzzle_id: String = ""

# For all challenges
@export var allow_retry: bool = true
@export var success_dialog_id: String = ""
@export var failure_dialog_id: String = ""
