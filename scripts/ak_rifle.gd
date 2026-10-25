extends Node3D
## Blender-authored mesh shared by first person, partners, displays and pickups.
## Geometry is baked offline; only the two moving parts are posed at runtime.
const ASSET = preload("res://assets/models/ak47.glb")
const MUZZLE = Vector3(0,.055,-1.03)
const RIGHT_GRIP = Vector3(0,-.17,.075)
const LEFT_GRIP = Vector3(-.025,-.04,-.52)
var magazine: Node3D
var bolt: Node3D
var magazine_rest: Transform3D
var bolt_rest: Transform3D

func _init() -> void:
	name = "AK47"
	var asset = ASSET.instantiate()
	add_child(asset)
	magazine = asset.find_child("CurvedMagazine",true,false) as Node3D
	bolt = asset.find_child("ChargingHandle",true,false) as Node3D
	magazine_rest = magazine.transform
	bolt_rest = bolt.transform
	set_meta("model_source","Blender / assets/models/ak47.glb")

func pose(reloading: bool, progress: float, recoil: float) -> void:
	var pulse = sin(clampf(progress,0.0,1.0)*PI) if reloading else 0.0
	magazine.transform = magazine_rest
	magazine.position += Vector3(0,-.30*pulse,.07*pulse)
	magazine.rotate_x(-.12*pulse)
	bolt.transform = bolt_rest
	bolt.position.z += clampf(recoil,0.0,1.0)*.05
