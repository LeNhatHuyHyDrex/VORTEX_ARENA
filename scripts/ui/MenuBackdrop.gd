class_name MenuBackdrop
extends Control
## Nền sân khấu cho menu ngoài: sàn đấu, hai bóng tướng đối mặt, và tàn lửa bay.
##
## Vì sao vẽ hẳn một nền thay vì để nền trơn: menu ngoài là thứ đầu tiên người
## chơi thấy, và một tấm nền có sàn đấu với hai tướng đối mặt nói được ngay
## "đây là game đối kháng 1v1" mà không cần một chữ giải thích nào.
##
## Toàn bộ vẽ bằng vector, không dùng file ảnh — cùng lý do như phần còn lại
## của game: đổi màu bằng một dòng code và không vướng bản quyền.

## Hai tướng đứng hai bên. Đổi hai dòng này là đổi bộ mặt của menu.
var left_champion: StringName = &"fire_mage"
var right_champion: StringName = &"frost_maiden"

var _t := 0.0
var _embers: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seed_embers()

func _seed_embers() -> void:
	_embers.clear()
	for i in range(46):
		_embers.append({
			"x": randf(),
			"y": randf(),
			"speed": randf_range(0.010, 0.040),
			"size": randf_range(1.0, 3.2),
			"phase": randf() * TAU,
			"warm": randf() > 0.45,
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_floor()
	# Hai tướng đứng ở khoảng 3/4 chiều cao: đủ thấp để trông như đang đứng trên
	# sàn, đủ cao để hàng nút ở dưới không che mất đầu.
	_draw_figure(left_champion, Vector2(size.x * 0.20, size.y * 0.72), 0.92, 1.0)
	_draw_figure(right_champion, Vector2(size.x * 0.80, size.y * 0.72), 0.92, -1.0)
	_draw_embers()
	_draw_bottom_fade()
	_draw_vignette()

## Tối dần về đáy màn hình, để hàng nút phía dưới luôn đọc được chữ bất kể
## tướng đứng sau là màu gì.
func _draw_bottom_fade() -> void:
	var steps := 22
	var h := size.y * 0.34
	for i in range(steps):
		var t := float(i) / float(steps)
		var y := size.y - h + h * t
		draw_rect(Rect2(0, y, size.x, h / float(steps) + 1.0),
			Color(0.02, 0.02, 0.04, 0.055 * (1.0 - t) + 0.02))

## Nền trời: hai quầng màu của hai tướng loang vào nhau trên nền tối.
func _draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("08080d"))
	var lc: Color = GameData.champion_color(left_champion)
	var rc: Color = GameData.champion_color(right_champion)
	var breathe := 0.5 + sin(_t * 0.5) * 0.06

	draw_circle(Vector2(size.x * 0.22, size.y * 0.62), size.x * 0.40,
		Color(lc.r, lc.g, lc.b, 0.055 * breathe + 0.02))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.62), size.x * 0.40,
		Color(rc.r, rc.g, rc.b, 0.055 * breathe + 0.02))

	# Vài vệt sáng chéo tạo không khí "đấu trường đêm".
	for i in range(4):
		var x := size.x * (0.12 + 0.25 * float(i))
		draw_line(Vector2(x, 0), Vector2(x - size.x * 0.10, size.y * 0.72),
			Color(1, 1, 1, 0.012), size.x * 0.06)

## Sàn đấu: bục gạch kim cương isometric — cùng ngôn ngữ 2.5D với sân thật.
func _draw_floor() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.72
	var rx := size.x * 0.44
	var ry := size.y * 0.17

	# Nền bục: ellipse tối.
	var pts := PackedVector2Array()
	var seg := 64
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	draw_colored_polygon(pts, Color("12111a"))

	# Lát gạch kim cương 2:1 xen kẽ sáng/tối — fake isometric thuần 2D.
	var tile_w := 128.0
	var tile_h := 64.0
	var light := Color(0.135, 0.13, 0.20, 1.0)
	var dark := Color(0.088, 0.084, 0.135, 1.0)
	for ix in range(-9, 10):
		for iy in range(-9, 10):
			var gx := cx + (ix - iy) * (tile_w * 0.5)
			var gy := cy + (ix + iy) * (tile_h * 0.5)
			# Chỉ vẽ viên nằm trong ellipse bục.
			var dx := (gx - cx) / rx
			var dy := (gy - cy) / ry
			if dx * dx + dy * dy > 0.94:
				continue
			var quad := PackedVector2Array([
				Vector2(gx, gy - tile_h * 0.5),
				Vector2(gx + tile_w * 0.5, gy),
				Vector2(gx, gy + tile_h * 0.5),
				Vector2(gx - tile_w * 0.5, gy),
			])
			draw_colored_polygon(quad, light if (ix + iy) % 2 == 0 else dark)
			draw_line(quad[0], quad[1], Color(1, 1, 1, 0.03), 1.0)
			draw_line(quad[1], quad[2], Color(1, 1, 1, 0.03), 1.0)

	# Viền sáng quanh sàn — cùng tông với viền sân đấu thật.
	for i in range(3):
		var grow := 1.0 + float(i) * 0.045
		var ring := PackedVector2Array()
		for k in range(seg):
			var a := TAU * float(k) / float(seg)
			ring.append(Vector2(cx + cos(a) * rx * grow, cy + sin(a) * ry * grow))
		ring.append(ring[0])
		for k in range(ring.size() - 1):
			draw_line(ring[k], ring[k + 1],
				Color(1.0, 0.45, 0.15, 0.10 - float(i) * 0.028), 2.0, true)

	# Đáy bệ: dải tối chạy dưới mép trước — bục có độ dày.
	var skirt := 14.0
	for i in range(4):
		var t := float(i) / 4.0
		var y := cy + ry + skirt * t
		var alpha := 0.5 * (1.0 - t) + 0.04
		draw_rect(Rect2(cx - rx, y, rx * 2.0, skirt / 4.0 + 1.0),
			Color(0.02, 0.02, 0.04, alpha))

	# Vòng tròn tâm sân.
	draw_arc(Vector2(cx, cy), rx * 0.16, 0.0, TAU, 48,
		Color(1, 0.6, 0.3, 0.10), 3.0, true)

## Một tướng đứng ở nền, vẽ theo kiểu bóng có viền sáng.
##
## Chi tiết bên trong bị lược bỏ hết — ở khoảng cách này mắt chỉ đọc được dáng
## và màu, nên giữ hình đơn giản sẽ sạch hơn là cố nhồi chi tiết.
func _draw_figure(id: StringName, feet: Vector2, scale: float, facing: float) -> void:
	var p: Dictionary = ChampionVisual.PALETTES.get(id, ChampionVisual.PALETTES[&"fire_mage"])
	var accent: Color = GameData.champion_color(id)
	var s := scale * (size.y / 620.0) * 1.35

	# Nhịp thở rất chậm để bóng không đứng im như tượng.
	var bob := sin(_t * 1.1 + facing) * 2.2 * s

	draw_set_transform(feet, 0.0, Vector2(s * facing, s))

	var body: Color = p["cloak"]
	var dark: Color = p["cloak_dark"]

	# Bóng đổ dưới chân
	_ellipse(Vector2(0, 2), 46.0, 13.0, Color(0, 0, 0, 0.45))

	# Chân
	_poly(PackedVector2Array([
		Vector2(-19, -46 + bob), Vector2(-5, -46 + bob),
		Vector2(-6, 2), Vector2(-22, 2),
	]), dark)
	_poly(PackedVector2Array([
		Vector2(5, -46 + bob), Vector2(19, -46 + bob),
		Vector2(22, 2), Vector2(6, 2),
	]), dark)

	# Thân
	_poly(PackedVector2Array([
		Vector2(-24, -124 + bob), Vector2(24, -124 + bob),
		Vector2(34, -40 + bob), Vector2(-34, -40 + bob),
	]), body)
	# Mảng sáng một bên hông
	_poly(PackedVector2Array([
		Vector2(6, -122 + bob), Vector2(24, -122 + bob),
		Vector2(32, -42 + bob), Vector2(12, -42 + bob),
	]), p["trim"])

	# Vai
	_poly(PackedVector2Array([
		Vector2(-24, -124 + bob), Vector2(-38, -114 + bob),
		Vector2(-32, -80 + bob), Vector2(-20, -86 + bob),
	]), dark)

	# Đầu
	var head := Vector2(0, -146 + bob)
	draw_circle(head, 26.0, body)
	# Mặt trong hốc
	_poly(PackedVector2Array([
		Vector2(-15, -150 + bob), Vector2(15, -150 + bob),
		Vector2(13, -132 + bob), Vector2(0, -126 + bob), Vector2(-13, -132 + bob),
	]), p["skin"])

	# Viền sáng phía ngoài — đây là thứ làm bóng tách khỏi nền.
	_rim(Vector2(0, 0), accent)

	# Vũ khí: một nét dài theo màu chủ đạo, đủ để nhận ra tướng nào.
	var weapon_len := 92.0
	if id == &"stone_guardian":
		weapon_len = 46.0
	elif id == &"shadow_assassin":
		weapon_len = 60.0
	draw_line(Vector2(30, -104 + bob), Vector2(30 + weapon_len * 0.45, -104 - weapon_len * 0.55),
		Color("2b2b33"), 7.0, true)
	draw_line(Vector2(30, -104 + bob), Vector2(30 + weapon_len * 0.45, -104 - weapon_len * 0.55),
		Color(accent.r, accent.g, accent.b, 0.85), 2.5, true)
	# Điểm sáng ở đầu vũ khí, nhấp nháy nhẹ.
	var tip := Vector2(30 + weapon_len * 0.45, -104 - weapon_len * 0.55 + bob)
	var pulse := 0.75 + sin(_t * 2.4) * 0.25
	draw_circle(tip, 12.0 * pulse, Color(accent.r, accent.g, accent.b, 0.30))
	draw_circle(tip, 6.0 * pulse, accent)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Viền sáng quanh bóng tướng: vẽ lại vài nét chính lệch ra ngoài một chút.
func _rim(_origin: Vector2, accent: Color) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.5)
	# Nét vai và sườn bên phải, nơi có nguồn sáng.
	draw_line(Vector2(34, -40), Vector2(24, -124), a, 3.0, true)
	draw_line(Vector2(24, -124), Vector2(38, -114), a, 3.0, true)
	draw_line(Vector2(34, -40), Vector2(22, 2), a, 2.5, true)

func _draw_embers() -> void:
	for e in _embers:
		var y := fmod(float(e["y"]) - _t * float(e["speed"]) + 1.0, 1.0)
		var sway := sin(_t * 0.6 + float(e["phase"])) * 0.014
		var px := (float(e["x"]) + sway) * size.x
		var py := y * size.y * 0.9
		var tw := 0.30 + sin(_t * 1.8 + float(e["phase"])) * 0.25
		var col := Color(1.0, 0.55, 0.18, tw * 0.55) if e["warm"] \
			else Color(0.72, 0.45, 1.0, tw * 0.42)
		draw_circle(Vector2(px, py), float(e["size"]), col)

## Tối bốn góc để mắt tập trung vào giữa màn hình, nơi đặt tiêu đề và nút.
func _draw_vignette() -> void:
	var steps := 26
	for i in range(steps):
		var t := float(i) / float(steps)
		var inset := -size.x * 0.20 * (1.0 - t)
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(0, 0, 0, 0.045), false, size.x * 0.030)

func _poly(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
