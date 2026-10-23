extends "res://scripts/world_geometry.gd"
## Shared shop/exhibition desk, with the original mesh dimensions and solid body.
func _ready() -> void:
	block("StationFoot",Vector3(0,.13,0),Vector3(2.2,.26,1.5),"303c3b",false)
	block("StationDesk",Vector3(0,.52,0),Vector3(1.9,.65,1.25),"66513b",true,false)
	block("StationTop",Vector3(0,.89,0),Vector3(2.12,.1,1.4),"b5a581",false)
	block("StationTrim",Vector3(0,.95,.67),Vector3(2.12,.06,.07),"d1b060",false)
