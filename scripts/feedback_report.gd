extends RefCounted
## Local report data; no network calls or mail credentials belong in the game.
const MAX_IMAGES = 3
const MAX_SOURCE_BYTES = 10*1024*1024
const MAX_TOTAL_BYTES = 3*1024*1024
const MAX_PIXELS = 32*1024*1024
const MAX_EDGE = 1920
var description = ""
var suggestion = ""
var attachments: Array[Dictionary] = []
var notice = ""

func validate() -> bool:
	if description.strip_edges().is_empty():
		notice = "请填写问题与现象。"
		return false
	if description.length() > 8000 or suggestion.length() > 4000:
		notice = "问题与现象请控制在8000字以内，建议方案请控制在4000字以内。"
		return false
	notice = ""
	return true

static func image_dimensions(bytes: PackedByteArray, extension: String) -> Vector2i:
	if extension == "png":
		if bytes.size() < 33 or bytes.slice(0,8) != PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(12,16).get_string_from_ascii() != "IHDR": return Vector2i.ZERO
		return Vector2i((bytes[16]<<24)|(bytes[17]<<16)|(bytes[18]<<8)|bytes[19],(bytes[20]<<24)|(bytes[21]<<16)|(bytes[22]<<8)|bytes[23])
	if bytes.size() < 4 or bytes[0] != 255 or bytes[1] != 216: return Vector2i.ZERO
	var offset = 2
	while offset+3 < bytes.size():
		if bytes[offset] != 255: return Vector2i.ZERO
		while offset < bytes.size() and bytes[offset] == 255: offset += 1
		if offset+2 >= bytes.size(): break
		var marker = bytes[offset]
		offset += 1
		if marker == 218 or marker == 217: break
		if marker == 1 or marker in range(208,216): continue
		var length = (bytes[offset]<<8)|bytes[offset+1]
		if length < 2 or offset+length > bytes.size(): break
		if marker in [192,193,194,195,197,198,199,201,202,203,205,206,207] and length >= 8:
			return Vector2i((bytes[offset+5]<<8)|bytes[offset+6],(bytes[offset+3]<<8)|bytes[offset+4])
		offset += length
	return Vector2i.ZERO

func add_image(path: String) -> bool:
	notice = ""
	if attachments.size() >= MAX_IMAGES:
		notice = "截图最多添加3张，请先移除一张。"
		return false
	var extension = path.get_extension().to_lower()
	if extension not in ["png","jpg","jpeg"]:
		notice = "请选择PNG或JPG图片。"
		return false
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		notice = "无法读取图片，请重新选择。"
		return false
	if file.get_length() <= 0 or file.get_length() > MAX_SOURCE_BYTES:
		notice = "单张原始图片不能超过10MB。"
		return false
	var bytes = file.get_buffer(file.get_length())
	file.close()
	var dimensions = image_dimensions(bytes,extension)
	if dimensions.x <= 0 or dimensions.y <= 0 or int(dimensions.x)*int(dimensions.y) > MAX_PIXELS:
		notice = "图片无效或像素过大，请选择3200万像素以内的PNG或JPG。"
		return false
	var image = Image.new()
	var error = image.load_png_from_buffer(bytes) if extension == "png" else image.load_jpg_from_buffer(bytes)
	if error != OK:
		notice = "图片损坏或格式不受支持，请重新选择。"
		return false
	if maxi(image.get_width(),image.get_height()) > MAX_EDGE:
		var scale = float(MAX_EDGE)/maxi(image.get_width(),image.get_height())
		image.resize(maxi(1,roundi(image.get_width()*scale)),maxi(1,roundi(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	# Re-encoding drops source metadata; original screenshots are never modified.
	var encoded = image.save_jpg_to_buffer(.85)
	var used = 0
	for attachment in attachments: used += attachment.bytes.size()
	if encoded.is_empty() or used+encoded.size() > MAX_TOTAL_BYTES:
		notice = "截图压缩后合计不能超过3MB，请减少图片或缩小尺寸。"
		return false
	var preview = image.duplicate()
	var preview_scale = minf(1.0,160.0/maxi(image.get_width(),image.get_height()))
	preview.resize(maxi(1,roundi(image.get_width()*preview_scale)),maxi(1,roundi(image.get_height()*preview_scale)),Image.INTERPOLATE_BILINEAR)
	attachments.append({"name":path.get_file(),"bytes":encoded,"preview":preview,"width":image.get_width(),"height":image.get_height()})
	return true

func remove_image(index: int) -> void:
	if index >= 0 and index < attachments.size(): attachments.remove_at(index)
	notice = ""

func document() -> Dictionary:
	var images: Array = []
	for index in attachments.size():
		images.append({"file":"screenshots/screenshot_%02d.jpg" % (index+1),"width":attachments[index].width,"height":attachments[index].height})
	return {"format":1,"game_version":str(ProjectSettings.get_setting("application/config/version","")),"system":OS.get_name(),"system_version":OS.get_version(),"created_at":Time.get_datetime_string_from_system(true)+"Z","description":description.strip_edges(),"suggestion":suggestion.strip_edges(),"screenshots":images}

func export_package(path: String) -> bool:
	if not validate(): return false
	if path.get_extension().to_lower() != "zip":
		notice = "请选择ZIP格式的保存位置。"
		return false
	var temporary = path+".tmp-"+str(Time.get_ticks_usec())
	var writer = ZIPPacker.new()
	if writer.open(temporary) != OK:
		notice = "无法写入所选位置，请换一个文件夹。"
		return false
	var data = document()
	var report = "问题反馈\n游戏版本：%s\n系统：%s %s\n时间：%s\n\n问题与现象：\n%s\n\n建议方案：\n%s\n\n截图：%d张\n" % [data.game_version,data.system,data.system_version,data.created_at,data.description,data.suggestion if not data.suggestion.is_empty() else "（未填写）",attachments.size()]
	var entries = [{"name":"report.txt","bytes":report.to_utf8_buffer()},{"name":"report.json","bytes":JSON.stringify(data,"\t").to_utf8_buffer()}]
	for index in attachments.size(): entries.append({"name":data.screenshots[index].file,"bytes":attachments[index].bytes})
	var result = OK
	for entry in entries:
		result = writer.start_file(entry.name)
		if result != OK: break
		result = writer.write_file(entry.bytes)
		var entry_closed = writer.close_file()
		if result == OK: result = entry_closed
		if result != OK: break
	var archive_closed = writer.close()
	if result == OK: result = archive_closed
	if result == OK: result = DirAccess.rename_absolute(temporary,path)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		notice = "反馈包导出失败，请检查保存位置和剩余空间。"
		return false
	notice = "反馈包已导出，请将ZIP文件发送至QQ群：1072344640。"
	return true
