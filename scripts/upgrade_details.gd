extends Control
# Hallmark · component: upgrade dossier · atmospheric arcade · existing field palette
# Pre-emit critique: P4 H5 E4 S5 R4 V4
const Art = preload("res://scripts/upgrade_art.gd")
var details: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(348,350)
	hide()

func sync(value: Dictionary) -> void:
	visible = not value.is_empty()
	if details == value: return
	details = value
	size.y = 160+value.get("rows",[]).size()*48+(32 if not value.get("note","").is_empty() else 0)
	queue_redraw()

func lettering(at: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string_outline(Art.font(),at+Vector2(2,3),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,6,Art.INK)
	draw_string(Art.font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if details.is_empty(): return
	var w = size.x
	var h = size.y
	var outline = PackedVector2Array([Vector2(0,12),Vector2(12,0),Vector2(w-18,0),Vector2(w,18),Vector2(w,h-14),Vector2(w-14,h),Vector2(0,h)])
	draw_colored_polygon(outline,Art.INK)
	draw_rect(Rect2(5,8,w-10,h-16),Art.PANEL)
	draw_rect(Rect2(5,8,5,h-16),Art.GOLD)
	draw_rect(Rect2(14,8,w-38,4),Art.PAPER)
	for x in [w-40,w-22]: draw_rect(Rect2(x,h-12,10,4),Art.RUST)
	lettering(Vector2(24,51),details.title,27,Art.PAPER)
	lettering(Vector2(24,82),details.level,15,Art.MUTED)
	draw_rect(Rect2(24,98,w-48,2),Art.STEEL)
	var selection: bool = details.get("selection",false)
	lettering(Vector2(146,123),"属性" if selection else "当前",12,Art.MUTED)
	if not selection: lettering(Vector2(245,123),"升级后",12,Art.GOLD)
	var y = 159.0
	for row in details.rows:
		lettering(Vector2(24,y),row[0],17,Art.PAPER)
		lettering(Vector2(145,y),row[1],19,Art.MUTED)
		if not selection:
			lettering(Vector2(222,y),"›",22,Art.GOLD)
			lettering(Vector2(247,y),row[2],19,Art.SUCCESS)
		draw_rect(Rect2(24,y+13,w-48,1),Art.STEEL*Color(1,1,1,.35))
		y += 48
	if not details.note.is_empty(): lettering(Vector2(24,y+5),details.note,14,Art.GOLD)
