extends Control
# Hallmark · pre-emit critique: P4 H4 E4 S4 R5 V4
var kind = "ultimate"
var compact = false
var icon: Control
var progress = 1.0
var locked = false
var caption = ""
var detail = ""
var animation_clock = 0.0
var ready_flash = 0.0
var ready_flash_count = 0
var charge_known = false
var was_ready = false
const FLASH_DURATION = .65
const TRACK_COLOR = Color("243c54")
const LOCKED_COLOR = Color("303c35")
const LOW_COLOR = Color("285ee8")
const HIGH_COLOR = Color("55dcff")
const GLEAM_COLOR = Color("e8fcff")
const TEXT_COLOR = Color("f2eedf")
const MUTED_COLOR = Color("829084")
const DETAIL_COLOR = Color("ddceb0")
const DetailFont = preload("res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf")

func radius() -> float:
	return 27.0 if compact else 36.0
func center() -> Vector2:
	return Vector2(size.x*.5,32 if compact else 44)
func charge_color(fraction: float) -> Color:
	var color = LOW_COLOR.lerp(HIGH_COLOR,clampf(fraction,0,1))
	if kind == "ultimate":
		var gleam = pow(maxf(0,sin((fraction*2.0-animation_clock*.7)*TAU)),8)
		color = color.lerp(GLEAM_COLOR,gleam*.72)
	return color
func _init() -> void:
	custom_minimum_size = Vector2(120,136)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	icon = preload("res://scripts/hud_equipment_icon.gd").new()
	icon.kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	resized.connect(layout_icon)
	layout_icon()
func layout_icon() -> void:
	if not icon: return
	icon.size = Vector2.ONE*(40 if compact else 52)
	icon.position = center()-icon.size*.5
func _process(dt: float) -> void:
	if is_visible_in_tree(): advance_visual(dt)
func advance_visual(dt: float) -> void:
	animation_clock += dt
	ready_flash = maxf(0,ready_flash-dt)
	queue_redraw()
func sync(value: float, title: String, note: String, unavailable := false) -> void:
	locked = unavailable
	progress = clampf(value,0,1)
	caption = title
	detail = note
	var now_ready: bool = not locked and progress >= 1.0
	if kind == "ultimate" and charge_known and now_ready and not was_ready:
		ready_flash = FLASH_DURATION
		ready_flash_count += 1
	charge_known = true
	was_ready = now_ready
	if locked: ready_flash = 0.0
	if icon: icon.modulate = MUTED_COLOR if locked else TEXT_COLOR
	queue_redraw()
func _draw() -> void:
	var origin = center()
	var width = 7.0 if compact else 10.0
	var r = radius()
	# A dim backing keeps the silhouette readable over bright terrain.
	draw_circle(origin,r-width*.6,Color(.025,.045,.055,.70))
	draw_arc(origin,r,0,TAU,128,LOCKED_COLOR if locked else TRACK_COLOR,width,true)
	if progress > 0:
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		var steps = maxi(2,ceili(progress*160))
		for index in steps+1:
			var fraction = progress*float(index)/steps
			var angle = -PI/2+TAU*fraction
			points.append(origin+Vector2(cos(angle),sin(angle))*r)
			colors.append(charge_color(fraction))
		draw_polyline_colors(points,colors,width,true)
	if kind == "ultimate" and ready_flash > 0:
		var age = 1.0-ready_flash/FLASH_DURATION
		var alpha = sin(age*PI)
		draw_circle(origin,r-width*.6,Color(HIGH_COLOR,alpha*.35))
		draw_arc(origin,r,-PI/2,TAU-PI/2,128,Color(GLEAM_COLOR,alpha),width+2,true)
		draw_arc(origin,r+6+age*10,0,TAU,128,Color(HIGH_COLOR,alpha*.8),3,true)
	if compact: return
	var font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x)/2,104),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED_COLOR if locked else TEXT_COLOR)
	var detail_size = 24 if locked else 32
	draw_string(DetailFont,Vector2((size.x-DetailFont.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size).x)/2,136),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size,DETAIL_COLOR)
