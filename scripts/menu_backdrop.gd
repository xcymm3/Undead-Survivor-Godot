extends TextureRect
## Restore the pre-redesign battlefield background and its original shade.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient = Gradient.new()
	gradient.set_color(0,Color(.04,.08,.06,.22))
	gradient.set_color(1,Color(.02,.04,.035,.94))
	gradient.add_point(.42,Color(.04,.07,.05,.38))
	var image = GradientTexture2D.new()
	image.gradient = gradient
	image.fill_from = Vector2(0,.5)
	image.fill_to = Vector2(1,.5)
	texture = image
