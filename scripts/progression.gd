extends Node
const Store = preload("res://scripts/progression_store.gd")
var store
var save_timer = 0.0

func _ready() -> void:
	# Automation never reads or writes the player's permanent progress.
	store = Store.new("" if Data.automation else "user://incremental-progress-v1.json")

func _process(dt: float) -> void:
	save_timer += dt
	if save_timer >= 1.0:
		save_timer = 0.0
		store.save()
