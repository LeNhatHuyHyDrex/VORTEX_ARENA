class_name CastIndicator
extends Node2D
## Vẽ vùng phạm vi của chiêu đang chờ xác nhận.
##
## Node này nằm trong KHÔNG GIAN THẾ GIỚI. Vòng tầm phải bám đúng sân đấu,
## nên nếu vẽ theo toạ độ màn hình thì zoom hay rung camera là lệch ngay.

var game: Game = null

## Màu chỉ báo: cyan sáng, đọc rõ trên mọi nền.
const TINT := Color("00e5ff")
const TINT_INVALID := Color("ff4757")

var _t := 0.0
const SEGMENTS := 72
const DASHES := 30

func _ready() -> void:
	z_index = 6
	# Vẽ TRÊN cả tướng và đạn để không bao giờ bị che khuất.
	z_as_relative = false
	set_process(true)

## QUAN TRỌNG: `visible` phải được điều khiển TRỰC TIẾP ở đây, trước khi gọi
## queue_redraw(). Godot bỏ qua _draw() của canvas item đang ẩn, nên nếu để
## _draw() tự bật visible (bản cũ) thì sau lần huỷ chiêu đầu tiên node bị ẩn
## mãi mãi — đúng lỗi "bấm chiêu mà không thấy vòng phạm vi".
func _process(delta: float) -> void:
	_t += delta
	var showing := game != null and game.armed_slot != -1
	visible = showing
	if showing:
		queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var skill: SkillBase = game.armed_skill()
	if skill == null or game.local_champ == null:
		return

	var origin: Vector2 = game.local_champ.global_position
	var valid: bool = game.armed_valid
	var col := TINT if valid else TINT_INVALID
	var pulse := 0.75 + sin(_t * 5.5) * 0.25

	# --- Vòng tầm: NỀN CỰC MỎNG để không che cảnh, viền nét đứt mảnh hơn ---
	if skill.cast_range > 1.0:
		draw_circle(origin, skill.cast_range, Color(col.r, col.g, col.b, 0.07))
		_dashed_circle(origin, skill.cast_range, Color(col.r, col.g, col.b, 0.72 * pulse),
			2.8, DASHES)
		# Vòng ngoài mảnh, nhấp nháy
		draw_arc(origin, skill.cast_range + 5.0, 0.0, TAU, SEGMENTS,
			Color(col.r, col.g, col.b, 0.28 * pulse), 1.6, true)
		# Ticks canh hướng tại 8 hướng chính — giúp ước lượng khoảng cách.
		for i in range(8):
			var a := TAU * float(i) / 8.0
			draw_line(origin + Vector2(cos(a), sin(a)) * (skill.cast_range - 12.0),
				origin + Vector2(cos(a), sin(a)) * skill.cast_range,
				Color(1, 1, 1, 0.35 * pulse), 2.2, true)

	# --- Vòng quanh chân tướng: biết đang niệm chiêu ---
	draw_arc(origin, 30.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.98), 3.6, true)
	var sweep := _t * 2.6
	draw_arc(origin, 38.0, sweep, sweep + 1.8, 18, Color(1, 1, 1, 0.9), 2.8, true)

	# Điểm sẽ thật sự trúng (đã kẹp tầm)
	var point: Vector2 = game.armed_point
	if skill.uses_range():
		var delta_v := point - origin
		if delta_v.length() > skill.cast_range:
			point = origin + delta_v.normalized() * skill.cast_range

	if skill.cast_type == SkillBase.CastType.GROUND:
		_draw_ground_preview(origin, point, skill, col)
	else:
		_draw_direction_preview(origin, point, skill, col)

	# --- Bảng trạng thái ngay tại điểm trỏ: nói RÕ màu xanh/đỏ nghĩa là gì ---
	# Xanh lam = điểm đặt hợp lệ, bấm chuột trái là chiêu ra đúng chỗ.
	# Đỏ = con trỏ nằm ngoài tầm, bấm thì điểm đặt bị KẸP VỀ MÉP tầm.
	var label := "XÁC NHẬN — bấm để ra chiêu" if valid else "NGOÀI TẦM — sẽ kẹp về mép"
	var font := ThemeDB.fallback_font
	var fsize := 13
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var lp := point + Vector2(-text_w * 0.5, -aoe_label_offset(skill) - 14.0)
	var pad := Vector2(9.0, 5.0)
	var bg := Rect2(lp - pad, Vector2(text_w + pad.x * 2.0, fsize + pad.y * 2.0))
	# Viền + nền bảng, tối để chữ nổi trên mọi địa hình.
	draw_rect(bg, Color(0.03, 0.05, 0.09, 0.82))
	draw_rect(bg, Color(col.r, col.g, col.b, 0.75), false, 1.4)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(1, 1, 1, 0.95) if valid else Color(1.0, 0.62, 0.62, 0.98))

## Khoảng cách từ điểm trỏ lên mép trên của vùng preview, để bảng chữ không
## đè lên vùng nổ/hình quạt.
func aoe_label_offset(skill: SkillBase) -> float:
	match skill.preview_shape:
		SkillBase.PreviewShape.RECT:
			return maxf(skill.preview_rect_size.x, skill.preview_rect_size.y) * 0.5
		SkillBase.PreviewShape.DASH:
			return skill.aoe_radius if skill.aoe_radius > 1.0 else 30.0
		_:
			return skill.aoe_radius if skill.aoe_radius > 1.0 else 46.0

func _draw_ground_preview(origin: Vector2, point: Vector2, skill: SkillBase,
		col: Color) -> void:
	var aoe: float = skill.aoe_radius if skill.aoe_radius > 1.0 else 46.0
	var pulse := 0.75 + sin(_t * 5.5) * 0.25

	# Vùng nổ: nền mờ dày + viền sáng + vòng nhấp nháy
	draw_circle(point, aoe, Color(col.r, col.g, col.b, 0.35))
	draw_arc(point, aoe, 0.0, TAU, SEGMENTS, Color(col.r, col.g, col.b, 1.0), 3.6, true)
	draw_arc(point, aoe * (0.55 + sin(_t * 4.2) * 0.08), 0.0, TAU, SEGMENTS,
		Color(1, 1, 1, 0.55 * pulse), 2.2, true)

	# Bốn vạch canh tâm
	var k := aoe * 0.26
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for d in dirs:
		var perp := Vector2(-d.y, d.x)
		draw_line(point + d * (aoe - k) - perp * k * 0.5,
			point + d * (aoe - k) + perp * k * 0.5, Color(1, 1, 1, 0.95), 2.6, true)

	# Tâm vùng nổ: chữ thập sáng + chấm trung tâm
	draw_circle(point, 4.0, Color(1, 1, 1, 1.0))
	draw_line(point + Vector2(-aoe * 0.18, 0), point + Vector2(aoe * 0.18, 0),
		Color(1, 1, 1, 0.75), 2.0, true)
	draw_line(point + Vector2(0, -aoe * 0.18), point + Vector2(0, aoe * 0.18),
		Color(1, 1, 1, 0.75), 2.0, true)

	# Đường nối từ tướng tới điểm đặt — mảnh, chỉ để dẫn mắt
	draw_line(origin, point, Color(col.r, col.g, col.b, 0.38), 2.0, true)

	# Mũi tên ở điểm đặt chỉ hướng từ tướng
	var dir := (point - origin).normalized()
	var tip := point - dir * 10.0
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip + dir * 14.0,
		tip - dir * 6.0 + perp * 7.0,
		tip - dir * 6.0 - perp * 7.0,
	]), Color(1, 1, 1, 0.9))

func _draw_direction_preview(origin: Vector2, point: Vector2, skill: SkillBase,
		col: Color) -> void:
	var dir := (point - origin)
	if dir.length_squared() < 1.0:
		dir = game.local_champ.aim_dir
	dir = dir.normalized()

	var reach: float = maxf(skill.cast_range, 60.0)
	var base := dir.angle()
	var half := 0.28

	# Hình quạt: gradient TỎI từ tướng ra xa — đủ nhận ra hướng, không che địa hình
	var steps := 14
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a0 := 0.13 * (1.0 - t0)
		var a1 := 0.13 * (1.0 - t1)
		var r0 := reach * t0
		var r1 := reach * t1
		var quad := PackedVector2Array([
			origin + Vector2(cos(base - half), sin(base - half)) * r0,
			origin + Vector2(cos(base + half), sin(base + half)) * r0,
			origin + Vector2(cos(base + half), sin(base + half)) * r1,
			origin + Vector2(cos(base - half), sin(base - half)) * r1,
		])
		draw_colored_polygon(quad, Color(col.r, col.g, col.b, (a0 + a1) * 0.5))

	# Hai mép hình quạt
	var sides: Array[float] = [-1.0, 1.0]
	for s in sides:
		draw_line(origin,
			origin + Vector2(cos(base + half * s), sin(base + half * s)) * reach,
			Color(col.r, col.g, col.b, 0.5), 1.8, true)

	# Cung tròn ở đầu tầm
	draw_arc(origin, reach, base - half, base + half, 28,
		Color(col.r, col.g, col.b, 0.7), 2.2, true)

	# Mũi tên ở đầu hướng
	var tip := origin + dir * reach
	var left := tip + dir.rotated(2.5) * 20.0
	var right := tip + dir.rotated(-2.5) * 20.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]),
		Color(col.r, col.g, col.b, 1.0))

## Xem trước chiêu LƯỚT: dải hành trình + các mũi tên chỉ chiều lướt + vòng
## "điểm hạ cánh" nơi thân tướng sẽ đứng. Với loại GROUND (Dịch Chuyển) đích là
## điểm đã kẹp tầm; với loại DIRECTION đích = hướng ngắm * tầm.
func _draw_dash_preview(origin: Vector2, point: Vector2, skill: SkillBase,
		col: Color) -> void:
	var pulse := 0.75 + sin(_t * 5.5) * 0.25
	var to_point := point - origin
	var dir := to_point.normalized() if to_point.length_squared() > 1.0 \
		else game.local_champ.aim_dir.normalized()
	var dest: Vector2
	if skill.cast_type == SkillBase.CastType.GROUND:
		dest = point
	else:
		if skill.preview_dash_back:
			dir = -dir
		dest = origin + dir * skill.cast_range

	var reach := origin.distance_to(dest)
	if reach > 24.0:
		# Dải hành trình: nền mờ + vệt giữa sáng hơn, xoay theo hướng lướt.
		var corridor_w := skill.aoe_radius if skill.aoe_radius > 1.0 else 34.0
		draw_set_transform(origin, dir.angle(), Vector2.ONE)
		draw_rect(Rect2(0.0, -corridor_w * 0.5, reach, corridor_w),
			Color(col.r, col.g, col.b, 0.13))
		draw_rect(Rect2(0.0, -3.0, reach, 6.0), Color(col.r, col.g, col.b, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Ba mũi tên dọc đường: đọc ngay chiều di chuyển.
		var perp := Vector2(-dir.y, dir.x)
		for f: float in [0.35, 0.6, 0.85]:
			var p := origin + dir * (reach * f)
			draw_colored_polygon(PackedVector2Array([
				p + dir * 7.0,
				p - dir * 5.0 + perp * 8.0,
				p - dir * 5.0 - perp * 8.0,
			]), Color(1, 1, 1, 0.6))

	# Điểm hạ cánh: vùng sát thương (nếu có) + vòng chân thân tướng.
	var land: float = skill.aoe_radius if skill.aoe_radius > 1.0 else 30.0
	draw_circle(dest, land, Color(col.r, col.g, col.b, 0.30))
	draw_arc(dest, land, 0.0, TAU, SEGMENTS, Color(col.r, col.g, col.b, 1.0), 3.4, true)
	draw_arc(dest, land * (0.55 + sin(_t * 4.2) * 0.08), 0.0, TAU, SEGMENTS,
		Color(1, 1, 1, 0.5 * pulse), 2.0, true)
	draw_arc(dest, 26.0, 0.0, TAU, 30, Color(1, 1, 1, 0.85), 2.4, true)
	draw_circle(dest, 4.0, Color(1, 1, 1, 1.0))

## Xem trước chiêu TƯỜNG: hình chữ nhật đặt tại điểm chọn, DÀI vuông góc hướng
## ngắm, mỏng dọc hướng ngắm. Vạch chia khối + mép sáng phía người niệm.
func _draw_rect_preview(origin: Vector2, point: Vector2, skill: SkillBase,
		col: Color) -> void:
	var size := skill.preview_rect_size
	var to_point := point - origin
	var aim := to_point.normalized() if to_point.length_squared() > 1.0 \
		else game.local_champ.aim_dir.normalized()

	# Xoay theo hướng ngắm: trục X cục bộ = dọc hướng ngắm (bề dày),
	# trục Y cục bộ = vuông góc (chiều dài tường).
	var half_len := size.x * 0.5
	var half_thick := size.y * 0.5
	draw_set_transform(point, aim.angle(), Vector2.ONE)
	var body := Rect2(-half_thick, -half_len, size.y, size.x)
	draw_rect(body, Color(col.r, col.g, col.b, 0.32))
	draw_rect(body, Color(col.r, col.g, col.b, 0.95), false, 3.0)
	# Vạch chia khối tường — gợi ý tường dựng từ nhiều khối liền nhau.
	for i in range(1, 4):
		var gy := -half_len + size.x * float(i) / 4.0
		draw_line(Vector2(-half_thick, gy), Vector2(half_thick, gy),
			Color(1, 1, 1, 0.4), 1.6, true)
	# Mép phía người niệm: vạch trắng dày hơn — biết ngay mặt "sau" của tường.
	draw_line(Vector2(-half_thick, -half_len), Vector2(-half_thick, half_len),
		Color(1, 1, 1, 0.75), 2.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Nét nối từ tướng tới tâm tường, mảnh chỉ để dẫn mắt.
	draw_line(origin, point, Color(col.r, col.g, col.b, 0.38), 2.0, true)

func _dashed_circle(center: Vector2, radius: float, color: Color,
		width: float, dashes: int) -> void:
	var step := TAU / float(dashes)
	var on := step * 0.55
	for i in range(dashes):
		var a := float(i) * step + _t * 0.35
		draw_arc(center, radius, a, a + on, 6, color, width, true)
