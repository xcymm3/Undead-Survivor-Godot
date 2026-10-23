extends Node
## Per-player cinematic; authority waits for every connected client under black.
var game
var phase = "animation"
var elapsed = 0.0
var victorious = false
var cooperative = false
var animation_seconds = 3.0
var transitioning = false
var layer: CanvasLayer
var black: ColorRect
var caption: Label

func _ready() -> void:
	victorious = game.sim.won
	cooperative = Session.playing
	animation_seconds = 1.4 if victorious else 3.0
	layer = CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	black = ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0,0,0,0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	caption = Label.new()
	caption.text = "太阳升起，你活下来了..." if victorious else "今晚，无人生还..."
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/SourceHanSerifSC-SemiBold.otf"))
	caption.add_theme_font_size_override("font_size",40)
	caption.add_theme_color_override("font_color",Color("f1eadc"))
	black.add_child(caption)
	caption.modulate.a = 0.0
	caption.hide()

func step(dt: float) -> void:
	elapsed += dt
	if phase == "animation" and elapsed >= animation_seconds: phase = "fade_out"; elapsed = 0.0
	elif phase == "fade_out":
		black.color.a = clampf(elapsed,0,1)
		if elapsed >= 1: phase = "caption"; elapsed = 0.0; caption.show()
	elif phase == "caption":
		caption.modulate.a = minf(1,elapsed/.5)
		if elapsed >= 2.8:
			phase = "wait"
			caption.hide()
			if Session.playing: Session.mark_ending_ready()
	elif phase == "wait":
		if game.finished:
			transitioning = true
			if cooperative:
				if Session.active and Session.playing and not Session.loading and Session.is_host():
					var ids: Array = game.sim.pawns.values().filter(func(p): return p.get("connected",true)).map(func(p): return p.id)
					if Session.all_ending_ready(ids):
						if ids.size() >= 2: game.restart_coop()
						else: game.start_solo("defense")
			else: game.start_solo("defense")
			transitioning = false
		if not game.finished and not Session.loading and game.sim != null and not game.awaiting_coop_snapshot:
			phase = "fade_in"
			elapsed = 0.0
	elif phase == "fade_in":
		black.color.a = 1-clampf(elapsed,0,1)
		if elapsed >= 1:
			game.ending_sequence = null
			queue_free()
