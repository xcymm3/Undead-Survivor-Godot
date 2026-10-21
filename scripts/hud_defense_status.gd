# Hallmark · pre-emit critique: P4 H5 E4 S5 R5 V4
extends Control
## Native angular wave badge and segmented crystal integrity display.
const INK = Color("0b171eea")
const EDGE = Color("31505b")
const CYAN = Color("81e5e3")
const CYAN_DARK = Color("234952")
const AMBER = Color("ffb365")
const CORAL = Color("ff725d")
const WHITE = Color("f4eedb")
const MUTED = Color("a6bdc3")
const TRACK = Color("1a3039")
var wave_label: Label
var crystal_label: Label
var wave = 0
var health_ratio = 0.0
var trailing_ratio = 0.0
var warning = false
var attacked = false
var wave_flash = 0.0
var clock = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(300,146)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption = make_label(Vector2(18,8),Vector2(180,20),11,MUTED)
	caption.text = "尸潮 / WAVE"
	wave_label = make_label(Vector2(16,24),Vector2(198,48),35,WHITE)
	crystal_label = make_label(Vector2(18,80),Vector2(264,28),18,CYAN)

func make_label(at: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
	var view = Label.new()
	view.position = at
	view.size = extent
	view.add_theme_font_size_override("font_size",font_size)
	view.add_theme_color_override("font_color",color)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view

func sync(current_wave: int, hp: int, maximum: int, started: bool, under_attack: bool) -> void:
	if wave != current_wave:
		wave_flash = 1.0 if started else 0.0
		wave = current_wave
	var ratio = clampf(float(hp)/maxi(1,maximum),0.0,1.0)
	if ratio > health_ratio: trailing_ratio = ratio
	health_ratio = ratio
	warning = ratio <= .3
	attacked = under_attack
	wave_label.text = "%02d / 10" % current_wave
	wave_label.add_theme_color_override("font_color",AMBER if wave == 10 else WHITE)
	crystal_label.text = "水晶  %d / %d" % [hp,maximum]
	crystal_label.add_theme_color_override("font_color",CORAL if warning else CYAN)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	wave_flash = maxf(0.0,wave_flash-delta)
	var previous = trailing_ratio
	trailing_ratio = move_toward(trailing_ratio,health_ratio,delta*.5)
	if warning or attacked or wave_flash > 0 or previous != trailing_ratio: queue_redraw()

func _draw() -> void:
	var outline = PackedVector2Array([Vector2(0,12),Vector2(12,0),Vector2(300,0),Vector2(300,132),Vector2(286,146),Vector2(0,146)])
	draw_colored_polygon(outline,INK)
	var accent = CORAL if warning or attacked else CYAN
	var pulse = .65+.35*sin(clock*7.0) if warning or attacked else .5
	draw_polyline(PackedVector2Array([Vector2(0,12),Vector2(12,0),Vector2(300,0),Vector2(300,132),Vector2(286,146),Vector2(0,146),Vector2(0,12)]),EDGE,1.0,true)
	draw_line(Vector2(0,30),Vector2(0,123),accent,3.0,true)
	draw_line(Vector2(18,73),Vector2(282,73),EDGE,1.0)
	draw_line(Vector2(202,0),Vector2(300,0),AMBER if wave == 10 else CYAN,2.0+wave_flash*2.0,true)
	# Faceted crystal and the ten-step wave track are drawn, not bitmap assets.
	var crystal = PackedVector2Array([Vector2(259,15),Vector2(272,27),Vector2(265,48),Vector2(253,48),Vector2(246,27)])
	draw_colored_polygon(crystal,CYAN_DARK)
	draw_polyline(PackedVector2Array([Vector2(259,15),Vector2(272,27),Vector2(265,48),Vector2(253,48),Vector2(246,27),Vector2(259,15)]),accent,1.5,true)
	draw_line(Vector2(259,15),Vector2(259,54),accent,1.0,true)
	draw_line(Vector2(246,27),Vector2(272,27),accent,1.0,true)
	for i in 10:
		draw_rect(Rect2(173+i*11,61,8,3),AMBER if i < wave else TRACK)
	for i in 20:
		var segment = Rect2(18+i*13.2,117,10.2,11)
		draw_rect(segment,TRACK)
		var trail = clampf(trailing_ratio*20-i,0.0,1.0)
		if trail > 0: draw_rect(Rect2(segment.position,Vector2(segment.size.x*trail,segment.size.y)),AMBER)
		var fill = clampf(health_ratio*20-i,0.0,1.0)
		if fill > 0: draw_rect(Rect2(segment.position,Vector2(segment.size.x*fill,segment.size.y)),accent)
	if warning or attacked:
		draw_line(Vector2(18,136),Vector2(282,136),Color(accent,pulse),2.0,true)
