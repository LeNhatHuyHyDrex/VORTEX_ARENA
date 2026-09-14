class_name ModeCard
extends Control
## Thẻ chọn chế độ chơi, vẽ bằng vector.
##
## Dùng Control tự vẽ thay vì Button vì cần icon minh hoạ + hai dòng chữ có
## cỡ khác nhau + hiệu ứng hover mượt — ghép bằng node con thì rườm rà mà
## vẫn không ra được viền bo theo màu riêng từng thẻ.

signal pressed()

enum Icon { BOT, ANTENNA, SETTINGS, LANDSCAPE }

var title := ""
var subtitle := ""
var tint: Color = Color("ff7a2f")
var icon: Icon = Icon.BOT
## >= 0: vẽ hình thu nhỏ của bản đồ (GameData.MapType) thay vì icon.
var map_preview := -1

var _hover := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
			accept_event()

func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var lift := 1.0 if _hover else 0.0

	# Thẻ đúc nổi: viền đáy dày (vát 3D) + shadow trượt xuống + bo góc lớn hơn.
	# Hover: thẻ "nâng lên" — shadow sâu hơn, nền sáng hơn, viền đậm hơn.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * (0.20 + lift * 0.10), tint.g * (0.20 + lift * 0.10),
		tint.b * (0.20 + lift * 0.10), 1.0)
	sb.border_color = Color(tint.r, tint.g, tint.b, 1.0 if _hover else 0.62)
	sb.set_border_width_all(2 if _hover else 1)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.shadow_color = Color(0, 0, 0, 0.5 + lift * 0.15)
	sb.shadow_size = 4.0 + lift * 5.0
	sb.shadow_offset = Vector2(0, 3 + lift * 2)
	sb.draw(get_canvas_item(), r)

	# Bóng kính nửa trên thẻ — ánh sáng rọi từ trên, cùng hướng với mọi panel.
	var pts := PackedVector2Array()
	var gr := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.42))
	var g_r := 9.0
	for s in range(7):
		var a: float = PI + (PI * 0.5) * float(s) / 6.0
		pts.append(Vector2(gr.position.x + g_r, gr.position.y + g_r)
			+ Vector2(cos(a), sin(a)) * g_r)
	for s in range(7):
		var a: float = PI * 1.5 + (PI * 0.5) * float(s) / 6.0
		pts.append(Vector2(gr.end.x - g_r, gr.position.y + g_r)
			+ Vector2(cos(a), sin(a)) * g_r)
	pts.append(Vector2(gr.end.x, gr.end.y))
	pts.append(Vector2(gr.position.x, gr.end.y))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.05 + lift * 0.03))

	if _hover:
		# Viền sáng mờ chạy dọc mép trái, gợi ý "thẻ này đang được trỏ".
		var glow := Color(tint.r, tint.g, tint.b, 0.35 + sin(_t * 6.0) * 0.12)
		draw_rect(Rect2(2, 2, 4, size.y - 4), glow)

	var font := ThemeDB.fallback_font
	if map_preview >= 0:
		# Thẻ bản đồ: hình thu nhỏ sân đấu bên trái, chữ đẩy sang phải.
		var pv_w := 168.0
		var pv_h := minf(size.y - 16.0, 96.0)
		var pv_rect := Rect2(Vector2(10.0, (size.y - pv_h) * 0.5), Vector2(pv_w, pv_h))
		_draw_map_preview(pv_rect)
		var tx := pv_rect.end.x + 16.0
		draw_string(font, Vector2(tx, size.y * 0.5 - 6.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, int(size.x - tx - 12), 17,
			Color(1, 1, 1, 0.98))
		draw_string(font, Vector2(tx, size.y * 0.5 + 16.0), subtitle,
			HORIZONTAL_ALIGNMENT_LEFT, int(size.x - tx - 12), 12,
			Color(1, 1, 1, 0.55))
		return

	var icon_cx := 40.0
	var icon_cy := size.y * 0.5
	_draw_icon(Vector2(icon_cx, icon_cy))

	var tx2 := 76.0
	draw_string(font, Vector2(tx2, size.y * 0.5 - 4.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, int(size.x - tx2 - 12), 18,
		Color(1, 1, 1, 0.98))
	draw_string(font, Vector2(tx2, size.y * 0.5 + 18.0), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, int(size.x - tx2 - 12), 13,
		Color(1, 1, 1, 0.55))

## Hình thu nhỏ bản đồ: tái hiện đúng bố cục và màu sắc của sân đấu thật.
##
## Người chơi nhìn một cái là biết bản đồ đó trông thế nào: vật cản, vết nứt
## magma, lớp băng, vòng bão — đúng vị trí tỉ lệ với trong game.
func _draw_map_preview(r: Rect2) -> void:
	var ground: Color
	var inner: Color
	match map_preview:
		GameData.MapType.LAVA_RIFT:
			ground = Color("1a0f0f")
			inner = Color("261a1a")
		GameData.MapType.FROZEN_LAKE:
			ground = Color("0f141a")
			inner = Color("141d26")
		GameData.MapType.STORM_EYE:
			ground = Color("120f1a")
			inner = Color("1a1626")
		_:
			ground = Color("100f16")
			inner = Color("1b1a26")

	# Khung sáng quanh preview.
	draw_rect(r, Color(tint.r, tint.g, tint.b, 0.35), false, 1.5)
	# Nền hai lớp như sân thật.
	draw_rect(r, ground)
	draw_rect(r.grow(-3.0), inner)

	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.5
	var s := Vector2(r.size.x / 1750.0, r.size.y / 1180.0)

	# Vật cản: các khối theo đúng bố cục đối xứng của từng bản đồ.
	for bdef in _pv_layout(map_preview):
		var br := _pv_block(bdef, r)
		draw_rect(br, Color(0, 0, 0, 0.35))
		draw_rect(br, Color(1, 1, 1, 0.16), false, 1.0)

	# Đường chia giữa + vòng tâm — đúng như sân thật.
	draw_line(Vector2(cx, r.position.y + 8.0), Vector2(cx, r.end.y - 8.0),
		Color(1, 1, 1, 0.10), 1.0)
	draw_arc(Vector2(cx, cy), r.size.x * 0.11, 0.0, TAU, 32,
		Color(1, 0.6, 0.3, 0.22), 2.0, true)

	# Chi tiết đặc trưng từng bản đồ.
	match map_preview:
		GameData.MapType.LAVA_RIFT:
			# Vết nứt magma đỏ rực, nhấp nháy nhẹ.
			var pulse := 0.6 + 0.4 * sin(_t * 3.0)
			for i in range(4):
				var ang := 0.35 + i * 1.5
				var px := cx + cos(ang) * r.size.x * (0.12 + 0.07 * (i % 2))
				var py := cy + sin(ang) * r.size.y * (0.15 + 0.1 * (i % 2))
				var pw := r.size.x * 0.14
				var ph := 3.5
				var cr := Rect2(px - pw * 0.5, py, pw, ph)
				draw_rect(cr, Color(1.0, 0.25, 0.08, 0.55 * pulse))
		GameData.MapType.FROZEN_LAKE:
			# Lớp băng xanh mờ phủ sân + vài vết nứt.
			draw_rect(r.grow(-3.0), Color(0.55, 0.85, 1.0, 0.06))
			for i in range(5):
				var a := 0.8 + i * 1.1
				var x1 := cx + cos(a) * r.size.x * 0.3
				var y1 := cy + sin(a) * r.size.y * 0.3
				draw_line(Vector2(x1, y1), Vector2(x1 + 9.0, y1 - 6.0),
					Color(0.75, 0.95, 1.0, 0.35), 1.0)
		GameData.MapType.STORM_EYE:
			# Vòng bão tím + vành cảnh báo đỏ ngoài.
			var rr := r.size.y * 0.38
			draw_arc(Vector2(cx, cy), rr, 0.0, TAU, 48,
				Color(0.6, 0.85, 1.0, 0.5), 1.8, true)
			var warn := 0.35 + 0.25 * sin(_t * 4.0)
			draw_arc(Vector2(cx, cy), rr + 5.0, 0.0, TAU, 48,
				Color(1.0, 0.2, 0.2, warn), 1.2, true)
			# Tia sét nhỏ.
			for i in range(3):
				var a := _t * 0.7 + i * TAU / 3.0
				var p := Vector2(cx + cos(a) * (rr + 10.0), cy + sin(a) * (rr + 10.0))
				draw_line(p, p + Vector2(3.0, -5.0), Color(1, 0.95, 0.5, 0.8), 1.2)
		_:
			# Cổ điển: mấy mảng sáng tinh tế cho sân đỡ trơn.
			draw_circle(Vector2(cx - r.size.x * 0.25, cy - r.size.y * 0.2),
				r.size.x * 0.05, Color(1.0, 0.85, 0.7, 0.06))
			draw_circle(Vector2(cx + r.size.x * 0.2, cy + r.size.y * 0.15),
				r.size.x * 0.04, Color(1.0, 0.85, 0.7, 0.05))

## Bố cục vật cản thu nhỏ (toạ độ sân thật, chia đôi rồi scale theo r).
func _pv_layout(mt: int) -> Array:
	match mt:
		GameData.MapType.FROZEN_LAKE:
			return [
				[-260.0, -180.0, 70.0, 70.0], [190.0, -180.0, 70.0, 70.0],
				[-260.0, 110.0, 70.0, 70.0], [190.0, 110.0, 70.0, 70.0],
				[-50.0, -300.0, 100.0, 60.0], [-50.0, 240.0, 100.0, 60.0],
			]
		GameData.MapType.STORM_EYE:
			return [
				[-420.0, -260.0, 100.0, 100.0], [320.0, -260.0, 100.0, 100.0],
				[-420.0, 160.0, 100.0, 100.0], [320.0, 160.0, 100.0, 100.0],
			]
		_:
			return [
				[-470.0, -300.0, 120.0, 120.0], [350.0, -300.0, 120.0, 120.0],
				[-470.0, 180.0, 120.0, 120.0], [350.0, 180.0, 120.0, 120.0],
				[-70.0, -450.0, 140.0, 90.0], [-70.0, 360.0, 140.0, 90.0],
			]

## Chuyển toạ độ sân thật sang toạ độ trong hình thu nhỏ.
func _pv_block(d: Array, r: Rect2) -> Rect2:
	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.5
	var s := Vector2(r.size.x / 1750.0, r.size.y / 1180.0)
	return Rect2(cx + float(d[0]) * s.x, cy + float(d[1]) * s.y,
		float(d[2]) * s.x, float(d[3]) * s.y)

func _draw_icon(c: Vector2) -> void:
	match icon:
		Icon.BOT:
			# Đầu robot: hộp + hai mắt + ăng-ten.
			draw_rect(Rect2(c + Vector2(-13, -13), Vector2(26, 22)), Color(1, 1, 1, 0.14))
			draw_rect(Rect2(c + Vector2(-13, -13), Vector2(26, 22)), tint, false, 2.0)
			draw_circle(c + Vector2(-5, -3), 2.6, tint)
			draw_circle(c + Vector2(5, -3), 2.6, tint)
			draw_line(c + Vector2(0, -13), c + Vector2(0, -20), tint, 2.0)
			draw_circle(c + Vector2(0, -21), 2.4, tint)
		Icon.ANTENNA:
			# Trạm phát: cột + hai sóng lan ra.
			draw_line(c + Vector2(0, 14), c + Vector2(0, -14), tint, 2.6)
			draw_circle(c + Vector2(0, -16), 3.0, tint)
			for i in range(3):
				var rr := 6.0 + float(i) * 5.0
				var a := 0.75 - float(i) * 0.22
				draw_arc(c + Vector2(0, -16), rr, -PI * 0.75, -PI * 0.25, 12,
					Color(tint.r, tint.g, tint.b, a), 2.0, true)
				draw_arc(c + Vector2(0, -16), rr, PI * 0.25, PI * 0.75, 12,
					Color(tint.r, tint.g, tint.b, a), 2.0, true)
		Icon.SETTINGS:
			# Bánh răng: vành tròn + răng cưa.
			draw_circle(c, 11.0, Color(1, 1, 1, 0.12))
			draw_arc(c, 11.0, 0.0, TAU, 20, tint, 2.4, true)
			draw_circle(c, 4.2, tint)
			for i in range(6):
				var a := TAU * float(i) / 6.0 + _t * 0.4
				var p1 := c + Vector2(cos(a) * 12.0, sin(a) * 12.0)
				var p2 := c + Vector2(cos(a) * 16.0, sin(a) * 16.0)
				draw_line(p1, p2, tint, 3.0)
		Icon.LANDSCAPE:
			# Phong cảnh: mặt đất + ngọn núi + mặt trờ.
			var ground_y := c.y + 10.0
			draw_line(c + Vector2(-18, ground_y), c + Vector2(18, ground_y), tint, 2.2)
			var peak := c + Vector2(0, ground_y - 14.0)
			var left := c + Vector2(-12, ground_y)
			var right := c + Vector2(12, ground_y)
			draw_line(left, peak, tint, 2.0)
			draw_line(peak, right, tint, 2.0)
			draw_circle(c + Vector2(10, ground_y - 18.0), 4.5, Color(tint.r, tint.g, tint.b, 0.35))
			draw_circle(c + Vector2(10, ground_y - 18.0), 2.2, tint)
