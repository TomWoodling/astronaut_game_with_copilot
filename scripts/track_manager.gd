extends Node

@onready var start_track = $start
@onready var continual_track = $continual
@onready var switch_track = $switcher
@onready var first_change = $change1
@onready var first_track = $change1_continual
@onready var second_change = $change2
@onready var second_track = $change2_continue
@onready var boss_track = $boss_full
@onready var switch_factor = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	start_track.play()
	# Don't stop the music
	process_mode = PROCESS_MODE_ALWAYS

func _on_start_finished():
	var switch_time = (randi() % 11 + 1)
	if switch_time < switch_factor:
		switch_track.play()
	else:
		continual_track.play()
		switch_factor = switch_factor + 1

func _on_continual_finished():
	var switch_time = (randi() % 11 + 1)
	if switch_time == 5:
		switch_track.play()
	else:
		continual_track.play()

func _on_switcher_finished():
	var switch_time = (randi() % 11 + 1)
	if switch_time <= 4:
		first_change.play()
	else:
		second_change.play()
		
func _on_change_1_finished():
	first_track.play()
	
func _on_change_1_continual_finished():
	var switch_time = (randi() % 11 + 1)
	if switch_time < 3:
		start_track.play()
		switch_factor = 0
	else:
		first_track.play()
		
func _on_change_2_finished():
	second_track.play()
	
func _on_change_2_continue_finished():
	boss_track.play()
	
func _on_boss_full_finished():
	switch_track.play()
	switch_factor = 2
