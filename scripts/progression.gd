extends Node
const Store = preload("res://scripts/progression_store.gd")
var store
var save_timer = 0.0
var active_slot = 0
var slots: Array = []
var selection_path = ""

func _ready() -> void:
	# Automation never reads or writes the player's permanent progress.
	configure("" if Data.automation else "user://")

func configure(directory: String) -> void:
	slots.clear()
	active_slot = 0
	selection_path = directory.path_join("incremental-slots.json") if not directory.is_empty() else ""
	for index in 3:
		var filename = "incremental-progress-v1.json" if index == 0 else "incremental-progress-slot-%d.json" % (index+1)
		slots.append(Store.new(directory.path_join(filename) if not directory.is_empty() else ""))
	if not selection_path.is_empty() and FileAccess.file_exists(selection_path):
		var selected = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
		if selected is Dictionary and Store.bounded_integer(selected.get("slot"),2): active_slot = int(selected.slot)
	store = slots[active_slot]

func select_slot(index: int) -> bool:
	if index < 0 or index >= slots.size() or not store.save(): return false
	if not selection_path.is_empty():
		var file = FileAccess.open(selection_path+".tmp",FileAccess.WRITE)
		if not file: return false
		file.store_string(JSON.stringify({"slot":index}))
		file.flush()
		var error = file.get_error()
		file.close()
		if error != OK or DirAccess.rename_absolute(selection_path+".tmp",selection_path) != OK: return false
	active_slot = index
	store = slots[index]
	return true

func _process(dt: float) -> void:
	save_timer += dt
	if save_timer >= 1.0:
		save_timer = 0.0
		store.save()
