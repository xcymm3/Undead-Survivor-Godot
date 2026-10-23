extends Node3D
## Shared keycap, contextual name/price and currency icon for all upgrade desks.
var focus_label: Label3D
var price_icon: Sprite3D
var ring: Node3D

func _ready() -> void:
	focus_label = Label3D.new()
	focus_label.name = "FocusedInformation"
	focus_label.font = preload("res://scripts/upgrade_art.gd").font()
	focus_label.font_size = 38
	focus_label.pixel_size = .0026
	focus_label.outline_size = 12
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_label.modulate = Color("fff0ca")
	focus_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Visibility is gated by the authority's scenery ray; the owner's mesh must
	# not hide its own contextual text (notably the tall crystal).
	focus_label.no_depth_test = true
	focus_label.visible = false
	add_child(focus_label)
	price_icon = Sprite3D.new()
	price_icon.name = "UpgradeCurrencyIcon"
	price_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	price_icon.no_depth_test = true
	price_icon.pixel_size = .00055
	price_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	price_icon.hide()
	add_child(price_icon)
	ring = preload("res://scripts/interaction_ring.gd").new()
	add_child(ring)
	ring.hide()

func sync(at: Vector3, eye: Vector3, camera: Camera3D, text: String, price: String, currency: Texture2D, progress: float, enabled: bool, status := "ready") -> void:
	ring.position = at
	ring.show()
	ring.sync(progress,eye,enabled,status)
	focus_label.show()
	focus_label.text = text
	var right = camera.global_basis.x
	focus_label.position = at+right*.24+Vector3(0,.04,0)
	price_icon.visible = currency != null
	if currency:
		price_icon.texture = currency
		var width = focus_label.font.get_string_size(price,HORIZONTAL_ALIGNMENT_LEFT,-1,focus_label.font_size).x*focus_label.pixel_size
		var line_height = focus_label.font.get_height(focus_label.font_size)*focus_label.pixel_size
		price_icon.position = focus_label.position+right*(width+.085)-camera.global_basis.y*line_height*.5
