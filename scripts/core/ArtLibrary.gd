class_name ArtLibrary
extends RefCounted
## Khe cắm asset raster (ảnh vẽ sẵn) cho toàn bộ game.
##
## Vì sao có lớp này: phần lớn hình ảnh trong game được vẽ bằng `_draw()` vector
## nên không thể có chất liệu sơn dầu / ánh sáng mềm như art vẽ tay. Lớp này cho
## phép THAY DẦN từng hình bằng file PNG: hễ có ảnh thì dùng ảnh, không có thì
## tự động rơi về bộ vẽ vector cũ — nhờ vậy thêm art không bao giờ làm vỡ game,
## và có thể nâng cấp từng tướng một.
##
## Ba nơi được dò theo thứ tự ưu tiên:
##   1. `res://assets/art/<nhóm>/<tên>.png`  — nằm trong project, đóng gói khi build.
##   2. `<cạnh file .exe>/art/<nhóm>/<tên>.png` — thả ảnh cạnh game là chạy ngay,
##      KHÔNG cần build lại. Đây là đường dùng chính khi muốn thử art mới.
##   3. `user://art/<nhóm>/<tên>.png`        — cho Android (không ghi được cạnh exe).
##
## Quy ước ảnh:
##   - PNG, nền trong suốt (alpha), KHÔNG có chữ trong ảnh (chữ do game vẽ).
##   - Nhân vật neo ở CHÂN (đáy ảnh = mặt đất) để khớp bóng đổ và tâm va chạm.

## Kết quả nạp được cache theo đường dẫn để không đọc đĩa mỗi khung hình.
static var _cache: Dictionary = {}

## Ảnh thẻ tướng (dùng ở màn chọn tướng + khung chi tiết). Tỉ lệ khuyến nghị 3:4.
static func card_texture(id: StringName) -> Texture2D:
	return _load("champions/cards", String(id))

## Ảnh nhân vật trong trận. Tỉ lệ khuyến nghị 1:1, cao ~700px.
static func body_texture(id: StringName) -> Texture2D:
	return _load("champions/bodies", String(id))

## Mảnh giao diện dùng chung (khung, panel giấy da, bệ đá, nút...).
static func ui_texture(piece: String) -> Texture2D:
	return _load("ui", piece)

## Optional full-pack UI lookup. This keeps the existing stable art slots intact
## while allowing selected Kenney panels/buttons to be used without copying 500+
## files into the core UI folder.
static func kenney_ui_texture(pack: String, piece: String) -> Texture2D:
	var roots := [
		"res://assets/art/ui/kenney_full/%s/PNG/Default/%s.png" % [pack, piece],
		"res://assets/art/ui/kenney_full/%s/%s.png" % [pack, piece],
	]
	for path in roots:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

## Xoá cache — gọi khi người chơi thả ảnh mới vào lúc game đang chạy.
static func clear_cache() -> void:
	_cache.clear()

## Đường dẫn của ảnh đầu tiên tìm thấy, hoặc "" nếu chưa có ảnh nào.
## Dùng cho công cụ kiểm tra / báo thiếu asset.
static func find_path(subdir: String, key: String) -> String:
	for p in _candidates(subdir, key):
		if p.begins_with("res://"):
			if ResourceLoader.exists(p):
				return p
		elif FileAccess.file_exists(p):
			return p
	return ""

## Kiểm tra nhanh một nhóm asset có bao nhiêu tướng đã có ảnh.
static func coverage(subdir: String, ids: Array) -> int:
	var n := 0
	for id in ids:
		if find_path(subdir, String(id)) != "":
			n += 1
	return n

# ----------------------------------------------------------------- nội bộ

static func _load(subdir: String, key: String) -> Texture2D:
	var cache_key := subdir + "|" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	var tex: Texture2D = null
	for p in _candidates(subdir, key):
		if p.begins_with("res://"):
			# Ảnh đã import trong project — nạp trực tiếp.
			if ResourceLoader.exists(p):
				tex = load(p) as Texture2D
		else:
			# Ảnh trên đĩa (cạnh exe / user://) — dựng texture lúc chạy.
			tex = _load_from_disk(p)
		if tex != null:
			break

	_cache[cache_key] = tex
	return tex

static func _candidates(subdir: String, key: String) -> Array[String]:
	var list: Array[String] = []
	list.append("res://assets/art/%s/%s.png" % [subdir, key])
	var exe_dir := OS.get_executable_path().get_base_dir()
	if exe_dir != "":
		list.append(exe_dir.path_join("art").path_join(subdir).path_join(key + ".png"))
	list.append(ProjectSettings.globalize_path("user://art/%s/%s.png" % [subdir, key]))
	return list

static func _load_from_disk(abs_path: String) -> Texture2D:
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		push_warning("ArtLibrary: không đọc được ảnh " + abs_path)
		return null
	return ImageTexture.create_from_image(img)
