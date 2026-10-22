extends VBoxContainer
# Hallmark · component scope · existing field palette and fonts
# Pre-emit critique: P4 H5 E4 S5 R5 V4
var ui
var report
var issue: TextEdit
var solution: TextEdit
var previews: HBoxContainer
var image_count: Label
var status: Label
var add_button: Button
var export_button: Button
var image_picker: FileDialog
var save_picker: FileDialog

func setup(owner_ui, draft) -> void:
	ui = owner_ui
	report = draft
	name = "FeedbackForm"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var scroll = ScrollContainer.new()
	scroll.name = "FeedbackScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var fields = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation",10)
	scroll.add_child(fields)
	fields.add_child(ui.label("问题与现象 · 必填",20,ui.SETTINGS_INK))
	issue = editor(fields,"请描述遇到的问题、发生前的操作及实际表现。",130)
	issue.name = "FeedbackDescription"
	issue.text = report.description
	issue.accessibility_name = "问题与现象（必填）"
	issue.text_changed.connect(func(): report.description = issue.text)
	fields.add_child(ui.label("建议方案 · 选填",20,ui.SETTINGS_INK))
	solution = editor(fields,"你希望怎样调整或改进？",90)
	solution.name = "FeedbackSuggestion"
	solution.text = report.suggestion
	solution.accessibility_name = "建议方案（选填）"
	solution.text_changed.connect(func(): report.suggestion = solution.text)
	var attachment_heading = HBoxContainer.new()
	fields.add_child(attachment_heading)
	image_count = ui.label("",20,ui.SETTINGS_INK)
	image_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attachment_heading.add_child(image_count)
	add_button = ui.home_button(attachment_heading,"添加截图",choose_images)
	add_button.name = "AddFeedbackImages"
	add_button.custom_minimum_size.x = 144
	previews = HBoxContainer.new()
	previews.name = "FeedbackPreviews"
	previews.add_theme_constant_override("separation",12)
	fields.add_child(previews)
	ui.paragraph(fields,"PNG / JPG · 最多3张 · 单张原图≤10MB，压缩后合计≤3MB",15,ui.SETTINGS_MUTED)
	status = ui.label("",17,ui.SETTINGS_INK)
	status.name = "FeedbackStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var group = ui.label("QQ群聊号：1072344640",20,ui.SETTINGS_BRASS)
	group.name = "FeedbackQQGroup"
	add_child(group)
	ui.paragraph(self,"导出反馈包后，请将ZIP文件发送至QQ群；导出不会自动提交。",16,ui.SETTINGS_MUTED)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	add_child(actions)
	var back = ui.home_button(actions,"返回主菜单",ui.show_home)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button = ui.home_button(actions,"导出反馈包",choose_destination,true)
	export_button.name = "ExportFeedback"
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# All file picking stays inside the game window; QA never opens a picker.
	get_window().gui_embed_subwindows = true
	image_picker = FileDialog.new()
	image_picker.name = "FeedbackImagePicker"
	image_picker.use_native_dialog = false
	image_picker.access = FileDialog.ACCESS_FILESYSTEM
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	image_picker.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; 截图（PNG、JPG）"])
	image_picker.files_selected.connect(add_images)
	add_child(image_picker)
	save_picker = FileDialog.new()
	save_picker.name = "FeedbackSavePicker"
	save_picker.use_native_dialog = false
	save_picker.access = FileDialog.ACCESS_FILESYSTEM
	save_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_picker.filters = PackedStringArray(["*.zip ; 反馈包（ZIP）"])
	save_picker.file_selected.connect(export_to)
	add_child(save_picker)
	refresh_images()

func editor(parent: Node, placeholder: String, height: float) -> TextEdit:
	var control = TextEdit.new()
	control.custom_minimum_size.y = height
	control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	control.placeholder_text = placeholder
	control.add_theme_font_size_override("font_size",19)
	control.add_theme_stylebox_override("normal",ui.settings_box(ui.PAPER.darkened(.25),ui.SETTINGS_MUTED.darkened(.5),12))
	control.add_theme_stylebox_override("focus",ui.settings_box(ui.PAPER.darkened(.25),ui.SETTINGS_BRASS,12))
	parent.add_child(control)
	return control

func choose_images() -> void:
	if Data.automation or DisplayServer.get_name() == "headless": return
	image_picker.popup_centered_clamped(Vector2i(820,540))

func add_images(paths: PackedStringArray) -> void:
	var errors: Array[String] = []
	for path in paths:
		if not report.add_image(path): errors.append(report.notice)
	refresh_images()
	show_status("截图已添加。" if errors.is_empty() else "\n".join(errors),not errors.is_empty())

func refresh_images() -> void:
	for child in previews.get_children():
		previews.remove_child(child)
		child.queue_free()
	image_count.text = "截图 · 选填（%d / 3）" % report.attachments.size()
	add_button.disabled = report.attachments.size() >= 3
	if report.attachments.is_empty():
		previews.add_child(ui.label("尚未选择截图",16,ui.SETTINGS_MUTED))
	for index in report.attachments.size():
		var attachment: Dictionary = report.attachments[index]
		var card = VBoxContainer.new()
		card.custom_minimum_size.x = 164
		previews.add_child(card)
		var image = TextureRect.new()
		image.texture = ImageTexture.create_from_image(attachment.preview)
		image.custom_minimum_size = Vector2(164,92)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(image)
		var filename = ui.label(attachment.name,15,ui.SETTINGS_MUTED)
		filename.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		filename.custom_minimum_size.x = 164
		card.add_child(filename)
		ui.home_button(card,"移除",remove_image.bind(index))

func remove_image(index: int) -> void:
	report.remove_image(index)
	refresh_images()
	show_status("")

func show_status(message: String, failed := false) -> void:
	status.text = message
	status.add_theme_color_override("font_color",Color("e06b61") if failed else ui.SETTINGS_INK)

func choose_destination() -> void:
	if not report.validate():
		show_status(report.notice,true)
		issue.grab_focus()
		return
	if Data.automation or DisplayServer.get_name() == "headless": return
	save_picker.current_file = "Undead-Survivor-Feedback-"+Time.get_datetime_string_from_system().replace(":","-")+".zip"
	save_picker.popup_centered_clamped(Vector2i(820,540))

func export_to(path: String) -> void:
	export_button.disabled = true
	export_button.text = "正在导出…"
	var success: bool = report.export_package(path)
	export_button.disabled = false
	export_button.text = "导出反馈包"
	show_status(report.notice,not success)
