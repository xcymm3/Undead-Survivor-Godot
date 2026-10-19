extends RefCounted
## Shared arcade lettering and enamel/steel palette for upgrade widgets.
const INK = Color("101a18")
const PAPER = Color("fff1c7")
const GOLD = Color("ffc34c")
const RUST = Color("b86c36")
const STEEL = Color("596d68")
const PANEL = Color(.055,.085,.075,.96)
const MUTED = Color("a0b1a1")
const SUCCESS = Color("9cdd80")
const ERROR = Color("ec8a6e")
static var cached_font: Font

static func font() -> Font:
	if cached_font == null:
		var base = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf").duplicate() as FontFile
		base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		var bold = FontVariation.new()
		bold.base_font = base
		bold.variation_embolden = 1.5
		cached_font = bold
	return cached_font
