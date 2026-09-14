class_name ArenaPreview
extends Control
## Sàn đấu thử nghiệm 2.5D Isometric (Live Arena Preview) ở nửa dưới màn hình Chọn Tướng.

var champion_id: StringName = &"fire_mage"
var _champ: Champion = null
var _t: float = 0.0

# Vệt đạn / Quả cầu kỹ năng bay lượn thử nghiệm
var _orb_angle: float = 0.0
var _lava_cracks: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_init_lava()
	_update_champion()

func _init_lava() -> void:
	_lava_cracks.clear()
	# Tạo các rãnh nứt dung nham giả lập dưới sàn
	_lava_cracks.append({"start": Vector2(-180, 40), "end": Vector2(-60, 90), "width": 4.0})
	_lava_cracks.append({"start": Vector2(80, 70), "end": Vector2(190, 45), "width": 3.5})
	_lava_cracks.append({"start": Vector2(-120, -60), "end": Vector2(-40, -30), "width": 2.5})
	_lava_cracks.append({"start": Vector2(110, -50), "end": Vector2(210, -80), "width": 3.0})

func set_champion(id: StringName) -> void:
	if champion_id == id and _champ != null:
		return
	champion_id = id
	_update_champion()

func _update_champion() -> void:
	if _champ != null:
		_champ.queue_free()
		_champ = null

	_champ = Champion.new()
	_champ.name = "PreviewChamp"
	_champ.configure(champion_id, 1, true)
	_champ.collision_layer = 0
	_champ.collision_mask = 0
	_champ.position = Vector2(size.x * 0.5, size.y * 0.60)
	add_child(_champ)

func _process(delta: float) -> void:
	_t += delta
	_orb_angle += delta * 2.2
	if _champ != null:
		_champ.position = Vector2(size.x * 0.5, size.y * 0.60)
		_champ._anim_time += delta
		# Quay mặt theo hướng quả cầu năng lượng đang bay lượn
		var orb_dir := Vector2(cos(_orb_angle), sin(_orb_angle) * 0.5)
		_champ.aim_dir = orb_dir.normalized()
	queue_redraw()

func _draw() -> void:
	var col := GameData.champion_color(champion_id)
	var c := Vector2(size.x * 0.5, size.y * 0.60)

	# 1. Nền tối & Viền khung sàn đấu 2.5D
	var bg_rect := Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.04, 0.04, 0.06, 0.98))
	draw_rect(bg_rect, Color(0.18, 0.20, 0.26, 0.8), false, 2.0)

	# 2. Lưới gạch lát đá Isometric (Isometric Stone Tiles)
	_draw_isometric_grid(c)

	# 3. Các vết nứt dung nham phát sáng (Glowing Magma Cracks)
	_draw_lava_cracks(c, col)

	# 4. Vòng tròn ma pháp triệu hồi rực rỡ dưới chân tướng (Summoning Runic Seal)
	_draw_summoning_seal(c, col)

	# 5. Quả cầu kỹ năng năng lượng bay lượn xung quanh (Signature Floating Orb)
	_draw_floating_skill_orb(c, col)

	# 6. Radar Minimap ở góc trên trái
	_draw_minimap_widget()

	# 7. La bàn trang trí góc dưới phải
	_draw_compass_accent()

func _draw_isometric_grid(c: Vector2) -> void:
	var tile_w := 96.0
	var tile_h := 48.0
	var grid_x := 8
	var grid_y := 6

	for ix in range(-grid_x, grid_x + 1):
		for iy in range(-grid_y, grid_y + 1):
			var iso_x := (ix - iy) * (tile_w * 0.5)
			var iso_y := (ix + iy) * (tile_h * 0.5)
			var p := c + Vector2(iso_x, iso_y)
			if p.x < -tile_w or p.x > size.x + tile_w or p.y < -tile_h or p.y > size.y + tile_h:
				continue

			# Vẽ từng viên gạch kim cương isometric
			var pts := PackedVector2Array([
				p + Vector2(0, -tile_h * 0.5),
				p + Vector2(tile_w * 0.5, 0),
				p + Vector2(0, tile_h * 0.5),
				p + Vector2(-tile_w * 0.5, 0)
			])
			# Độ sáng xen kẽ để tạo bề mặt đá nổi khối
			var shade := 0.08 + (0.02 if (ix + iy) % 2 == 0 else 0.0)
			draw_colored_polygon(pts, Color(shade, shade + 0.01, shade + 0.02))
			# Đường chỉ gạch
			for k in range(4):
				draw_line(pts[k], pts[(k + 1) % 4], Color(0.13, 0.14, 0.18, 0.6), 1.0)

			# Hoa văn ngẫu nhiên hoặc ô thông gió kim loại
			if (ix + iy) % 5 == 0 and absi(ix) > 1:
				_draw_floor_grate(p, tile_w * 0.35, tile_h * 0.35)

func _draw_floor_grate(p: Vector2, w: float, h: float) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -h * 0.5),
		p + Vector2(w * 0.5, 0),
		p + Vector2(0, h * 0.5),
		p + Vector2(-w * 0.5, 0)
	])
	draw_colored_polygon(pts, Color(0.04, 0.04, 0.05, 0.8))
	for k in range(3):
		var t_step := float(k - 1) * 0.3
		draw_line(p + Vector2(-w * 0.3 + t_step * 10, -h * 0.2), p + Vector2(w * 0.3 + t_step * 10, h * 0.2), Color(0.2, 0.22, 0.28, 0.7), 1.0)

func _draw_lava_cracks(c: Vector2, col: Color) -> void:
	var pulse := 0.65 + 0.35 * sin(_t * 3.5)
	for crack in _lava_cracks:
		var s_vec: Vector2 = crack["start"]
		var e_vec: Vector2 = crack["end"]
		var p1: Vector2 = c + s_vec
		var p2: Vector2 = c + e_vec
		var w: float = float(crack["width"])
		# Quầng sáng
		draw_line(p1, p2, Color(col.r, col.g * 0.6, 0.1, 0.4 * pulse), w * 2.8)
		# Lõi sáng rực
		draw_line(p1, p2, Color(1.0, 0.7, 0.2, 0.85 * pulse), w)

func _draw_summoning_seal(c: Vector2, col: Color) -> void:
	var rx := 68.0
	var ry := 28.0

	# Quầng sáng nền
	var pulse := 0.22 + 0.08 * sin(_t * 3.0)
	_draw_ellipse_area(c, rx * 1.35, ry * 1.35, Color(col.r, col.g, col.b, pulse * 0.4))
	_draw_ellipse_area(c, rx, ry, Color(col.r, col.g, col.b, pulse * 0.7))

	# Vòng ngoài có răng cưa / ký tự cổ
	_draw_ellipse_border(c, rx, ry, Color(col.r, col.g, col.b, 0.85), 2.2)
	_draw_ellipse_border(c, rx * 0.82, ry * 0.82, Color(col.r, col.g, col.b, 0.5), 1.4)
	_draw_ellipse_border(c, rx * 0.45, ry * 0.45, Color(col.r, col.g, col.b, 0.75), 1.8)

	# Vòng quay các ký hiệu Rune
	var rot := _t * 0.8
	var runes := 12
	for i in range(runes):
		var a := rot + float(i) * TAU / float(runes)
		var p_inner := c + Vector2(cos(a) * rx * 0.48, sin(a) * ry * 0.48)
		var p_outer := c + Vector2(cos(a) * rx * 0.80, sin(a) * ry * 0.80)
		draw_line(p_inner, p_outer, Color(col.r, col.g, col.b, 0.65), 1.5, true)
		# Điểm sáng ở chóp
		var p_dot := c + Vector2(cos(a) * rx * 0.95, sin(a) * ry * 0.95)
		draw_circle(p_dot, 2.0, Color(col.r, col.g, col.b, 0.9))

	# Vòng sao bên trong
	var star_pts := 6
	var star_rot := -_t * 0.4
	for i in range(star_pts):
		var a1 := star_rot + float(i) * TAU / float(star_pts)
		var a2 := star_rot + float((i + 2) % star_pts) * TAU / float(star_pts)
		var p1 := c + Vector2(cos(a1) * rx * 0.45, sin(a1) * ry * 0.45)
		var p2 := c + Vector2(cos(a2) * rx * 0.45, sin(a2) * ry * 0.45)
		draw_line(p1, p2, Color(col.r, col.g, col.b, 0.5), 1.2, true)

func _draw_floating_skill_orb(c: Vector2, col: Color) -> void:
	var dist_x := 84.0
	var dist_y := 34.0
	var orb_center := c + Vector2(cos(_orb_angle) * dist_x, sin(_orb_angle) * dist_y - 28.0)

	# Vệt khói kéo đuôi
	for k in range(5):
		var trail_a := _orb_angle - float(k + 1) * 0.14
		var t_pos := c + Vector2(cos(trail_a) * dist_x, sin(trail_a) * dist_y - 28.0)
		var alpha := 0.6 * (1.0 - float(k) / 5.0)
		draw_circle(t_pos, 7.0 - float(k) * 1.1, Color(col.r, col.g, col.b, alpha))

	# Quả cầu năng lượng
	var flare := 1.0 + 0.15 * sin(_t * 8.0)
	draw_circle(orb_center, 14.0 * flare, Color(col.r, col.g, col.b, 0.25))
	draw_circle(orb_center, 8.5 * flare, Color(col.r, col.g, col.b, 0.7))
	draw_circle(orb_center, 4.5 * flare, Color(1, 1, 1, 0.95))

func _draw_minimap_widget() -> void:
	var m_pos := Vector2(16, 16)
	var m_size := Vector2(110, 75)
	# Nền radar
	draw_rect(Rect2(m_pos, m_size), Color(0.06, 0.07, 0.10, 0.88))
	draw_rect(Rect2(m_pos, m_size), Color(0.3, 0.35, 0.45, 0.7), false, 1.5)

	# Nhãn số hiệp / tỉ số
	draw_string(ThemeDB.fallback_font, m_pos + Vector2(8, 16), "1 / 0 / 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.6, 0.3))

	# Vùng sân & Điểm vị trí tướng
	var center_m := m_pos + m_size * 0.5 + Vector2(0, 5)
	draw_rect(Rect2(center_m - Vector2(38, 22), Vector2(76, 44)), Color(0.12, 0.14, 0.2, 0.5), false, 1.0)

	# Chấm tướng người chơi (xanh/cam) và quả cầu năng lượng
	draw_circle(center_m, 4.0, Color(0.35, 0.95, 0.55))
	draw_circle(center_m + Vector2(24, 2), 3.0, Color(1.0, 0.4, 0.2))

func _draw_compass_accent() -> void:
	var pos := Vector2(size.x - 30, size.y - 30)
	var pts := PackedVector2Array([
		pos + Vector2(0, -10),
		pos + Vector2(4, 0),
		pos + Vector2(0, 10),
		pos + Vector2(-4, 0)
	])
	draw_colored_polygon(pts, Color(0.5, 0.55, 0.65, 0.5))
	var pts_h := PackedVector2Array([
		pos + Vector2(-10, 0),
		pos + Vector2(0, 3),
		pos + Vector2(10, 0),
		pos + Vector2(0, -3)
	])
	draw_colored_polygon(pts_h, Color(0.5, 0.55, 0.65, 0.5))

func _draw_ellipse_area(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var segs := 32
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

func _draw_ellipse_border(c: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var segs := 32
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	for i in range(segs):
		draw_line(pts[i], pts[(i + 1) % segs], color, width, true)
