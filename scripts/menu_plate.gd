extends Control
## Subtle machined corners and rivets shared by every native dialog.
const BRASS = Color("c59b62")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	for corner in [Vector2(-16,-16),Vector2(size.x+16,-16),Vector2(-16,size.y+16),size+Vector2(16,16)]:
		var dx = 1.0 if corner.x < 0 else -1.0
		var dy = 1.0 if corner.y < 0 else -1.0
		draw_line(corner,corner+Vector2(dx*28,0),BRASS,2)
		draw_line(corner,corner+Vector2(0,dy*28),BRASS,2)
		var screw = corner+Vector2(dx*8,dy*8)
		draw_circle(screw,2.6,BRASS.darkened(.35))
		draw_line(screw-Vector2(1.5,0),screw+Vector2(1.5,0),Color("10201b"),1)
