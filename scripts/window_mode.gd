extends RefCounted
## Keep display transitions separate from audio and rendering settings.
var windowed_mode: int = DisplayServer.WINDOW_MODE_WINDOWED

static func is_fullscreen(mode: int) -> bool:
	return mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func apply(enabled: bool, read_mode: Callable, write_mode: Callable) -> void:
	var current: int = read_mode.call()
	if is_fullscreen(current) == enabled:
		return
	if enabled:
		windowed_mode = DisplayServer.WINDOW_MODE_MAXIMIZED if current == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_WINDOWED
	write_mode.call(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else windowed_mode)
