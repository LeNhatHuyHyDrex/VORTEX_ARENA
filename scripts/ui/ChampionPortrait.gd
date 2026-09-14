class_name ChampionPortrait
extends Control
## Ảnh đại diện tướng, vẽ bằng vector — dùng ở menu chọn tướng và khung mô tả.
##
## Tại sao lại vẽ thay vì dùng file ảnh:
##   - Không cần chuẩn bị tài nguyên, thêm tướng mới là có icon ngay.
##   - Một nguồn màu duy nhất (ChampionVisual.PALETTES) nên icon trong menu
##     luôn khớp với nhân vật thật ngoài sân đấu.
##   - Phóng to thu nhỏ không vỡ, không cần nhiều bản độ phân giải cho
##     Windows lẫn Android.
##
## Thiết kế trong một hộp vuông 100 đơn vị, gốc toạ độ đặt ở đáy trung tâm,
## trục y âm hướng lên. Khi vẽ chỉ việc nhân với hệ số s = cạnh ngắn nhất/100.

signal pressed(id: StringName)

var champion_id: StringName = &"fire_mage"
var selected := false
var bot_selected := false
var hovered := false
var compact := false     # thu nhỏ: bỏ khung tên, chỉ còn hình

## Nhịp hoạt ảnh, chạy liên tục để icon "thở" chứ không đứng im.
var _t := 0.0

## Màu chủ đạo của từng tướng, lấy từ bảng màu chung với nhân vật ngoài sân.
func accent() -> Color:
	return GameData.champion_color(champion_id)

func palette() -> Dictionary:
	return ChampionVisual.PALETTES.get(champion_id, ChampionVisual.PALETTES[&"fire_mage"])

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered = true)
	mouse_exited.connect(func() -> void: hovered = false)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(champion_id)
			accept_event()

func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	var col := accent()
	var p := palette()

	_draw_frame(col)
	# Gốc toạ độ: đáy trung tâm, trục y âm hướng lên.
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.99), 0.0, Vector2(s, s))

	_draw_glow(col)
	_draw_ground(col)
	_draw_weapon_behind(p, col)
	_draw_shoulders(p)
	_draw_head(p)
	_draw_headgear(p, col)
	_draw_face(p)
	_draw_motifs(col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not compact:
		_draw_nameplate(col)

# ------------------------------------------------------------------ các phần

func _draw_frame(col: Color) -> void:
	var sb := StyleBoxFlat.new()
	var a := 1.0 if selected else (0.85 if hovered else 0.55)
	sb.bg_color = Color(0.055, 0.055, 0.075, 0.96)
	if bot_selected:
		sb.border_color = Color(1.0, 0.45, 0.25, 0.9)
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(col.r, col.g, col.b, a)
		sb.set_border_width_all(3 if selected else 2)
	sb.set_corner_radius_all(12)
	sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

func _draw_glow(col: Color) -> void:
	var pulse := 0.16 + sin(_t * 1.9) * 0.05
	draw_circle(Vector2(0, -46), 40.0, Color(col.r, col.g, col.b, pulse * 0.55))
	draw_circle(Vector2(0, -46), 27.0, Color(col.r, col.g, col.b, pulse))

## Bệ đá isometric dưới chân: tấm nền hình thoi + viền phát sáng màu tướng.
##
## Đây là chi tiết tạo chiều sâu 2.5D cho thẻ tướng — nhân vật không còn
## "dán" phẳng vào nền đen mà đứng trên một tấm đá nổi, khớp với phong cách
## sàn đấu isometric của ảnh tham chiếu.
func _draw_ground(col: Color) -> void:
	# Thân bệ: hình thoi dẹt (mặt trên) + mép dày (cạnh bệ) tạo khối.
	_poly_pts(PackedVector2Array([
		Vector2(-44, -2), Vector2(0, -13), Vector2(44, -2), Vector2(0, 9),
	]), Color(0.10, 0.11, 0.15, 0.95))
	_poly_pts(PackedVector2Array([
		Vector2(-44, -2), Vector2(0, 9), Vector2(0, 15), Vector2(-44, 4),
	]), Color(0.05, 0.06, 0.09, 0.95))
	_poly_pts(PackedVector2Array([
		Vector2(44, -2), Vector2(0, 9), Vector2(0, 15), Vector2(44, 4),
	]), Color(0.07, 0.08, 0.12, 0.95))
	# Viền rune phát sáng nhịp theo thở, màu chủ đạo của tướng.
	var pulse := 0.30 + sin(_t * 1.9) * 0.12
	_line(Vector2(-44, -2), Vector2(0, -13), Color(col.r, col.g, col.b, pulse), 1.6)
	_line(Vector2(0, -13), Vector2(44, -2), Color(col.r, col.g, col.b, pulse), 1.6)
	_line(Vector2(-44, -2), Vector2(0, 9), Color(col.r, col.g, col.b, pulse * 0.6), 1.2)
	_line(Vector2(44, -2), Vector2(0, 9), Color(col.r, col.g, col.b, pulse * 0.6), 1.2)

## Vũ khí vẽ sau lưng để không che mặt.
func _draw_weapon_behind(p: Dictionary, col: Color) -> void:
	match champion_id:
		&"fire_mage":
			_line(Vector2(-24, -6), Vector2(-30, -74), Color("2b2b33"), 4.0)
			_line(Vector2(-24, -6), Vector2(-30, -74), Color("5a5a68"), 1.4)
			var flare := 1.0 + sin(_t * 7.0) * 0.12
			draw_circle(Vector2(-30, -76), 8.0 * flare, Color(col.r, col.g, col.b, 0.28))
			draw_circle(Vector2(-30, -76), 5.2 * flare, Color("ff8c3a"))
			draw_circle(Vector2(-30, -76), 2.8 * flare, Color("ffd24a"))
		&"shadow_assassin":
			var offs: Array[float] = [-1.0, 1.0]
			for k in offs:
				_line(Vector2(22 + k * 6, -8), Vector2(34 + k * 14, -66), Color("8f3350"), 3.4)
				_line(Vector2(22 + k * 6, -8), Vector2(34 + k * 14, -66),
					Color(1, 0.75, 0.8, 0.45), 1.2)
		&"frost_maiden":
			_line(Vector2(-25, -4), Vector2(-31, -72), Color("bfe9ff"), 3.0)
			_poly_pts(PackedVector2Array([
				Vector2(-31, -84), Vector2(-35, -70), Vector2(-31, -62), Vector2(-27, -70),
			]), Color("93e5ff"))
		&"thunder_warrior":
			_line(Vector2(-26, -4), Vector2(-32, -78), Color("8a7a3a"), 3.6)
			_poly_pts(PackedVector2Array([
				Vector2(-32, -88), Vector2(-36, -66), Vector2(-28, -66),
			]), Color("cbd5e1"))
		&"stone_guardian":
			# Đá lơ lửng quanh người thay cho vũ khí.
			for i in range(3):
				var a := _t * 0.7 + float(i) * TAU / 3.0
				var rp := Vector2(cos(a) * 30.0, -44.0 + sin(a) * 13.0)
				_poly_pts(PackedVector2Array([
					rp + Vector2(-6, -2), rp + Vector2(-2, -7),
					rp + Vector2(6, -4), rp + Vector2(7, 3), rp + Vector2(-1, 7),
				]), Color("78716c"))
		&"arcane_weaver":
			# Trượng tinh thể tím sau lưng.
			_line(Vector2(-25, -4), Vector2(-31, -74), Color("3a2a5e"), 3.6)
			_poly_pts(PackedVector2Array([
				Vector2(-31, -82), Vector2(-36, -72), Vector2(-31, -64), Vector2(-26, -72),
			]), Color("8b5cf6"))
			draw_circle(Vector2(-31, -72), 2.4, Color("e9d5ff"))
		&"mirage":
			# Song đoản đao cyan chéo sau lưng.
			for k in [-1.0, 1.0]:
				_line(Vector2(24 * k, -6), Vector2(36 * k, -70), Color("1d5a66"), 3.0)
				_line(Vector2(24 * k, -6), Vector2(36 * k, -70),
					Color(0.55, 0.95, 1.0, 0.5), 1.0)
		&"marksman":
			# Súng trường dài tựa vai.
			_line(Vector2(-26, -8), Vector2(30, -66), Color("2b2b33"), 4.2)
			_line(Vector2(-26, -8), Vector2(30, -66), Color("6b7280"), 1.4)
			draw_circle(Vector2(30, -66), 3.0, Color("facc15"))
		&"seraph":
			# Chuỗi hạt sáng + bình hương nhỏ sau lưng.
			draw_arc(Vector2(0, -66), 22.0, PI * 1.05, PI * 1.95, 14,
				Color(0.99, 0.92, 0.55, 0.5), 1.8, true)
			draw_circle(Vector2(-24, -58), 4.0, Color("fde68a"))
			draw_circle(Vector2(-24, -58), 1.8, Color(1, 1, 1, 0.9))
		&"artificer":
			# Cờ lê lớn + mối hàn sáng.
			_line(Vector2(24, -6), Vector2(34, -68), Color("6b4630"), 4.4)
			_line(Vector2(34, -68), Vector2(30, -80), Color("9a8f86"), 3.2)
			var spark := 0.6 + sin(_t * 8.0) * 0.4
			draw_circle(Vector2(32, -74), 3.2 * spark, Color(0.98, 0.6, 0.25, 0.8))
		&"tamer":
			# Roi da cuộn treo hông.
			draw_arc(Vector2(26, -34), 16.0, -PI * 0.4, PI * 0.7, 12,
				Color("8a6a4a"), 2.6, true)
			_line(Vector2(26, -18), Vector2(32, -6), Color("6b4f35"), 2.4)
		&"time_weaver":
			# Đồng hồ cát hồng lơ lửng sau vai.
			var fl := sin(_t * 2.2) * 2.2
			_poly_pts(PackedVector2Array([
				Vector2(-28, -64 + fl), Vector2(-20, -64 + fl),
				Vector2(-27, -46 + fl), Vector2(-21, -46 + fl),
			]), Color("7a3a52"))
			draw_circle(Vector2(-24, -55 + fl), 1.8, Color("fb7185"))
		&"blood_lord":
			# Song vuốt cong đỏ thẫm sau lưng.
			for k in [-1.0, 1.0]:
				draw_arc(Vector2(26 * k, -40), 15.0, -PI * 0.75, PI * 0.1, 10,
					Color("6b1f2a"), 3.2, true)
				draw_arc(Vector2(26 * k, -40), 15.0, -PI * 0.75, PI * 0.1, 10,
					Color(0.94, 0.27, 0.27, 0.45), 1.2, true)
		&"iron_monk":
			# Xích vàng + chuỗi hạt quyền sau lưng.
			draw_arc(Vector2(0, -64), 20.0, PI * 1.1, PI * 1.9, 12,
				Color("8a6a2c"), 2.4, true)
			for i in range(5):
				var ba := PI * 1.1 + float(i) * PI * 0.8 / 4.0
				draw_circle(Vector2(cos(ba) * 20.0, -64 + sin(ba) * 20.0), 2.0,
					Color("fde68a", 0.9))
		&"berserker":
			# Đại rìu tựa vai, lưỡi sáng thép.
			_line(Vector2(-26, -4), Vector2(32, -72), Color("4a3428"), 5.0)
			_poly_pts(PackedVector2Array([
				Vector2(32, -72), Vector2(44, -80), Vector2(40, -64),
			]), Color("cbd5e1"))
			_line(Vector2(34, -72), Vector2(42, -70), Color(1, 0.75, 0.8, 0.6), 1.4)
		&"void_samurai":
			# Katana trong vỏ đen chéo sau lưng.
			_line(Vector2(-28, -6), Vector2(34, -70), Color("151a2e"), 4.6)
			_line(Vector2(-28, -6), Vector2(34, -70), Color("2c3a66"), 1.6)
			draw_circle(Vector2(34, -70), 2.6, Color("818cf8"))
		&"plague_alchemist":
			# Ba lô bình độc + ống khói bọt xanh.
			_poly_pts(PackedVector2Array([
				Vector2(-32, -56), Vector2(-18, -56), Vector2(-16, -24), Vector2(-30, -24),
			]), Color("44521f"))
			for i in range(3):
				var bp := fmod(_t * 0.7 + float(i) * 0.33, 1.0)
				draw_circle(Vector2(-24 + sin(_t * 3.0 + i) * 4.0, -58 - bp * 18.0),
					(1.0 - bp) * 2.6 + 0.8, Color(0.64, 0.8, 0.2, (1.0 - bp) * 0.7))

func _draw_shoulders(p: Dictionary) -> void:
	var cloak: Color = p["cloak"]
	var trim: Color = p["trim"]
	_poly_pts(PackedVector2Array([
		Vector2(-32, 4), Vector2(32, 4), Vector2(20, -30), Vector2(-20, -30),
	]), cloak)
	# Mảng sáng bên vai phải tạo khối.
	_poly_pts(PackedVector2Array([
		Vector2(6, -29), Vector2(20, -29), Vector2(30, 3), Vector2(14, 3),
	]), trim)
	# Cổ
	_poly_pts(PackedVector2Array([
		Vector2(-6, -34), Vector2(6, -34), Vector2(6, -26), Vector2(-6, -26),
	]), p["cloak_dark"])

	if champion_id == &"stone_guardian":
		# Vai giáp dày, khác biệt rõ so với áo choàng.
		_poly_pts(PackedVector2Array([
			Vector2(-34, -12), Vector2(-20, -34), Vector2(-8, -30), Vector2(-14, -8),
		]), Color("6b6560"))
		_poly_pts(PackedVector2Array([
			Vector2(34, -12), Vector2(20, -34), Vector2(8, -30), Vector2(14, -8),
		]), Color("6b6560"))

func _draw_head(p: Dictionary) -> void:
	var skin: Color = p["skin"]
	draw_circle(Vector2(0, -50), 16.5, skin)
	# Mảng tối nửa đầu bên trái cho có độ khối.
	_poly_pts(PackedVector2Array([
		Vector2(0, -67), Vector2(-16, -54), Vector2(-14, -40), Vector2(0, -34),
	]), Color(skin.r * 0.82, skin.g * 0.82, skin.b * 0.82))

func _draw_headgear(p: Dictionary, col: Color) -> void:
	var cloak: Color = p["cloak"]
	var dark: Color = p["cloak_dark"]
	match champion_id:
		&"fire_mage":
			# Mũ trùm nhọn, hở mặt.
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(19, -50), Vector2(13, -76), Vector2(0, -86),
				Vector2(-13, -76),
			]), cloak)
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(-9, -50), Vector2(-6, -74), Vector2(-13, -70),
			]), dark)
		&"shadow_assassin":
			# Mũ trùm kín + khăn che miệng.
			_poly_pts(PackedVector2Array([
				Vector2(-19, -48), Vector2(19, -48), Vector2(14, -74), Vector2(0, -84),
				Vector2(-14, -74),
			]), cloak)
			_poly_pts(PackedVector2Array([
				Vector2(-15, -40), Vector2(15, -40), Vector2(13, -28), Vector2(-13, -28),
			]), dark)
		&"frost_maiden":
			# Tóc dài hai bên + vương miện băng ba nhọn.
			_poly_pts(PackedVector2Array([
				Vector2(-20, -52), Vector2(-26, -18), Vector2(-14, -20), Vector2(-12, -46),
			]), Color("dff3ff"))
			_poly_pts(PackedVector2Array([
				Vector2(20, -52), Vector2(26, -18), Vector2(14, -20), Vector2(12, -46),
			]), Color("dff3ff"))
			_poly_pts(PackedVector2Array([
				Vector2(-17, -58), Vector2(17, -58), Vector2(13, -70), Vector2(-13, -70),
			]), Color("bfe9ff"))
			for i in range(3):
				var x := -12.0 + float(i) * 12.0
				var h := 16.0 if i == 1 else 10.0
				_poly_pts(PackedVector2Array([
					Vector2(x - 4, -68), Vector2(x + 4, -68), Vector2(x, -68 - h),
				]), Color("93e5ff"))
		&"thunder_warrior":
			# Mũ sừng: vành kim loại + hai sừng cong.
			_poly_pts(PackedVector2Array([
				Vector2(-18, -56), Vector2(18, -56), Vector2(16, -70), Vector2(-16, -70),
			]), Color("8a7a3a"))
			_poly_pts(PackedVector2Array([
				Vector2(-18, -56), Vector2(18, -56), Vector2(18, -60), Vector2(-18, -60),
			]), Color("facc15"))
			for k in [-1.0, 1.0]:
				draw_arc(Vector2(k * 24, -62), 13.0, PI * 0.55 if k < 0.0 else PI * -0.05,
					PI * 1.05 if k < 0.0 else PI * 0.45, 10, Color("e8d9a8"), 4.0, true)
		&"stone_guardian":
			# Mũ trụ khối, khe nhìn hẹp.
			_poly_pts(PackedVector2Array([
				Vector2(-18, -44), Vector2(18, -44), Vector2(16, -72), Vector2(-16, -72),
			]), Color("57534e"))
			_poly_pts(PackedVector2Array([
				Vector2(-16, -72), Vector2(16, -72), Vector2(14, -78), Vector2(-14, -78),
			]), Color("a8a29e"))
		&"arcane_weaver":
			# Mũ trùm sâu, không lộ tóc, cộng vòng mảnh vỡ lơ lửng trên đầu.
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(19, -50), Vector2(15, -78), Vector2(0, -88),
				Vector2(-15, -78),
			]), cloak)
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(-8, -50), Vector2(-5, -76), Vector2(-14, -72),
			]), dark)
			# Ba mảnh kết tinh xoay quanh đỉnh đầu.
			for i in range(3):
				var a := _t * 1.1 + float(i) * TAU / 3.0
				var rp := Vector2(cos(a) * 24.0, -80.0 + sin(a) * 7.0)
				_poly_pts(PackedVector2Array([
					rp + Vector2(0, -6), rp + Vector2(4, 0),
					rp + Vector2(0, 6), rp + Vector2(-4, 0),
				]), Color(0.66, 0.55, 0.98, 0.9))
		&"mirage":
			# Mũ trùm trơn, không trang trí — điểm nhấn nằm ở mắt.
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(19, -50), Vector2(14, -76), Vector2(0, -84),
				Vector2(-14, -76),
			]), cloak)
			_poly_pts(PackedVector2Array([
				Vector2(-19, -50), Vector2(-7, -50), Vector2(-4, -74), Vector2(-14, -70),
			]), dark)
		&"marksman":
			# Mũ vành rộng + kính một mắt.
			_poly_pts(PackedVector2Array([
				Vector2(-30, -60), Vector2(30, -60), Vector2(30, -66), Vector2(-30, -66),
			]), Color("5a4a1c"))
			_poly_pts(PackedVector2Array([
				Vector2(-16, -60), Vector2(16, -60), Vector2(14, -74), Vector2(-14, -74),
			]), Color("6b5a24"))
			draw_circle(Vector2(7, -52), 5.0, Color("0b0b10"))
			draw_circle(Vector2(7, -52), 3.4, Color(0.98, 0.85, 0.35, 0.8))
		&"seraph":
			# Vòng hào quang lơ lửng trên đầu.
			draw_arc(Vector2(0, -74), 17.0, 0.0, TAU, 28,
				Color(0.99, 0.92, 0.55, 0.9), 3.0, true)
			draw_arc(Vector2(0, -74), 21.0, _t * 1.2, _t * 1.2 + 2.4, 16,
				Color(1, 1, 1, 0.7), 2.0, true)
			_poly_pts(PackedVector2Array([
				Vector2(-15, -52), Vector2(15, -52), Vector2(13, -64), Vector2(-13, -64),
			]), Color("fef3c7"))
		&"artificer":
			# Kính bảo hộ hai mắt tròn + mũ da.
			_poly_pts(PackedVector2Array([
				Vector2(-19, -56), Vector2(19, -56), Vector2(16, -70), Vector2(-16, -70),
			]), Color("4a3524"))
			for k in [-6.5, 6.5]:
				draw_circle(Vector2(k, -50), 5.2, Color("2b2b33"))
				draw_circle(Vector2(k, -50), 3.6, Color(0.98, 0.6, 0.25, 0.85))
		&"tamer":
			# Mũ lông thú + hai tai sói nhô lên.
			_poly_pts(PackedVector2Array([
				Vector2(-20, -52), Vector2(20, -52), Vector2(17, -68), Vector2(-17, -68),
			]), Color("3a5c34"))
			for k in [-11.0, 11.0]:
				_poly_pts(PackedVector2Array([
					Vector2(k - 6, -66), Vector2(k + 6, -66), Vector2(k, -84),
				]), Color("4a7040"))
			_poly_pts(PackedVector2Array([
				Vector2(-20, -52), Vector2(20, -52), Vector2(22, -44), Vector2(-22, -44),
			]), Color("6b8a5e"))

func _draw_face(p: Dictionary) -> void:
	var eye := Color("1b1a22")
	match champion_id:
		&"shadow_assassin":
			# Chỉ lộ đôi mắt sáng — phần dưới mặt đã bị khăn che.
			draw_circle(Vector2(-6, -50), 2.4, Color("c4b5fd"))
			draw_circle(Vector2(6, -50), 2.4, Color("c4b5fd"))
		&"stone_guardian":
			# Khe nhìn sáng lên như mắt đèn.
			_poly_pts(PackedVector2Array([
				Vector2(-11, -56), Vector2(11, -56), Vector2(11, -51), Vector2(-11, -51),
			]), Color("0b0b10"))
			draw_circle(Vector2(-5, -53.5), 1.8, Color("fde68a"))
			draw_circle(Vector2(5, -53.5), 1.8, Color("fde68a"))
		&"arcane_weaver":
			# Hốc mắt tối với hai điểm sáng tím — không thấy tròng mắt.
			_poly_pts(PackedVector2Array([
				Vector2(-14, -54), Vector2(14, -54), Vector2(12, -45), Vector2(-12, -45),
			]), Color("100b1e"))
			var glow := 0.75 + sin(_t * 3.0) * 0.25
			draw_circle(Vector2(-6, -50), 2.6, Color(0.72, 0.55, 1.0, glow))
			draw_circle(Vector2(6, -50), 2.6, Color(0.72, 0.55, 1.0, glow))
		&"mirage":
			# Hai vệt mắt cyan, không có tròng — nhìn như bóng.
			var g := 0.7 + sin(_t * 5.0) * 0.3
			draw_line(Vector2(-11, -52), Vector2(-3, -51), Color(0.55, 0.95, 1.0, g), 2.6, true)
			draw_line(Vector2(3, -51), Vector2(11, -52), Color(0.55, 0.95, 1.0, g), 2.6, true)
		&"marksman":
			draw_line(Vector2(-9, -52), Vector2(-3.5, -51), Color("1b1a22"), 2.0)
			draw_line(Vector2(3.5, -51), Vector2(9, -52), Color("1b1a22"), 2.0)
		&"seraph":
			# Mắt nhắm hiền, miệng cười nhẹ.
			draw_arc(Vector2(-6, -52), 3.4, PI * 1.15, PI * 1.85, 10, Color("1b1a22"), 1.6, true)
			draw_arc(Vector2(6, -52), 3.4, PI * 1.15, PI * 1.85, 10, Color("1b1a22"), 1.6, true)
			draw_arc(Vector2(0, -44), 4.5, PI * 0.15, PI * 0.85, 10, Color(0.55, 0.4, 0.35), 1.6, true)
		&"artificer":
			draw_line(Vector2(-9, -52), Vector2(-3.5, -51), Color("1b1a22"), 2.0)
			draw_line(Vector2(3.5, -51), Vector2(9, -52), Color("1b1a22"), 2.0)
		&"tamer":
			draw_line(Vector2(-9, -52), Vector2(-3.5, -51), Color("1b1a22"), 2.0)
			draw_line(Vector2(3.5, -51), Vector2(9, -52), Color("1b1a22"), 2.0)
			# Vết sơn chiến trên má.
			draw_line(Vector2(-12, -46), Vector2(-4, -44), Color(0.35, 0.7, 0.4, 0.8), 2.0, true)
		_:
			draw_line(Vector2(-9, -52), Vector2(-3.5, -51), eye, 2.0)
			draw_line(Vector2(3.5, -51), Vector2(9, -52), eye, 2.0)
			# Viên ngạc trên trán: điểm nhận diện theo màu tướng.
			draw_circle(Vector2(0, -59), 3.0, p["accent"])
			draw_circle(Vector2(0, -59), 1.4, Color(1, 1, 1, 0.85))

## Họa tiết bay quanh người — thứ làm icon có "chất" của từng tướng.
func _draw_motifs(col: Color) -> void:
	match champion_id:
		&"fire_mage":
			for i in range(5):
				var ph := fmod(_t * 1.1 + float(i) * 0.37, 1.0)
				var fx := 22.0 + sin(ph * 7.0 + float(i)) * 7.0
				var fy := -10.0 - ph * 62.0
				var r := (1.0 - ph) * 3.4 + 0.8
				draw_circle(Vector2(fx, fy), r,
					Color(1.0, 0.55 + ph * 0.3, 0.15, (1.0 - ph) * 0.9))
		&"shadow_assassin":
			for i in range(4):
				var a := _t * 1.4 + float(i) * TAU / 4.0
				var rp := Vector2(cos(a) * 34.0, -48.0 + sin(a) * 15.0)
				draw_circle(rp, 3.2 - float(i) * 0.4, Color(0.66, 0.33, 0.97, 0.55))
		&"frost_maiden":
			for i in range(6):
				var a := _t * 0.5 + float(i) * TAU / 6.0
				var rp := Vector2(cos(a) * 36.0, -50.0 + sin(a) * 14.0)
				var sz := 3.4 + sin(_t * 3.0 + float(i)) * 0.8
				_poly_pts(PackedVector2Array([
					rp + Vector2(0, -sz * 1.8), rp + Vector2(sz, 0),
					rp + Vector2(0, sz * 1.8), rp + Vector2(-sz, 0),
				]), Color(0.74, 0.93, 1.0, 0.75))
		&"thunder_warrior":
			# Tia sét chạy quanh, nhấp nháy theo nhịp không đều.
			var bolt_on := sin(_t * 9.0) > 0.55
			if bolt_on:
				var pts := PackedVector2Array([
					Vector2(24, -78), Vector2(31, -66), Vector2(26, -62), Vector2(33, -50),
				])
				for i in range(pts.size() - 1):
					draw_line(pts[i], pts[i + 1], Color("ffe066"), 2.6)
			for i in range(3):
				var a := _t * 2.2 + float(i) * TAU / 3.0
				draw_circle(Vector2(cos(a) * 33.0, -46.0 + sin(a) * 12.0), 2.0,
					Color(1.0, 0.92, 0.4, 0.7))
		&"stone_guardian":
			for i in range(3):
				var a := _t * 0.35 + float(i) * TAU / 3.0 + 1.2
				var rp := Vector2(cos(a) * 33.0, -14.0 + sin(a) * 6.0)
				draw_circle(rp, 2.6, Color(0.66, 0.64, 0.62, 0.6))
		&"arcane_weaver":
			# Tinh thể nhỏ bay lên rồi tan, quanh hai bên vai.
			for i in range(6):
				var ph := fmod(_t * 0.55 + float(i) * 0.167, 1.0)
				var side := -1.0 if i % 2 == 0 else 1.0
				var fx := side * (26.0 + sin(ph * 6.0 + float(i)) * 8.0)
				var fy := -8.0 - ph * 66.0
				var sz := (1.0 - ph) * 3.0 + 0.9
				_poly_pts(PackedVector2Array([
					Vector2(fx, fy - sz * 1.7), Vector2(fx + sz, fy),
					Vector2(fx, fy + sz * 1.7), Vector2(fx - sz, fy),
				]), Color(0.72, 0.60, 1.0, (1.0 - ph) * 0.85))
		&"mirage":
			# Ba vệt bóng mờ lướt quanh người.
			for i in range(3):
				var a := _t * 1.5 + float(i) * TAU / 3.0
				var rp := Vector2(cos(a) * 32.0, -46.0 + sin(a) * 13.0)
				draw_circle(rp, 3.0, Color(0.13, 0.83, 0.93, 0.5))
		&"marksman":
			# Vỏ đạn vàng rơi xuống quanh người.
			for i in range(4):
				var ph := fmod(_t * 0.8 + float(i) * 0.25, 1.0)
				var rp := Vector2(-26.0 + float(i) * 15.0, -40.0 + ph * 44.0)
				draw_line(rp, rp + Vector2(0, 5), Color(0.98, 0.8, 0.3, (1.0 - ph) * 0.8), 2.0, true)
		&"seraph":
			# Lông vũ trắng bay lên.
			for i in range(5):
				var ph := fmod(_t * 0.45 + float(i) * 0.2, 1.0)
				var rp := Vector2(sin(ph * 5.0 + float(i)) * 30.0, 6.0 - ph * 70.0)
				_poly_pts(PackedVector2Array([
					rp + Vector2(0, -4), rp + Vector2(3, 0),
					rp + Vector2(0, 4), rp + Vector2(-3, 0),
				]), Color(1, 0.98, 0.9, (1.0 - ph) * 0.75))
		&"artificer":
			# Tia lửa hàn bắn ra hai bên.
			for i in range(6):
				var ph := fmod(_t * 1.4 + float(i) * 0.167, 1.0)
				var side := -1.0 if i % 2 == 0 else 1.0
				var rp := Vector2(side * (20.0 + ph * 22.0), -20.0 - ph * 24.0)
				draw_circle(rp, (1.0 - ph) * 2.6 + 0.6,
					Color(1.0, 0.6 + ph * 0.3, 0.15, (1.0 - ph) * 0.9))
		&"tamer":
			# Dấu chân thú mờ hiện quanh người.
			for i in range(3):
				var a := _t * 0.8 + float(i) * TAU / 3.0
				var rp := Vector2(cos(a) * 33.0, -16.0 + sin(a) * 8.0)
				draw_circle(rp, 3.2, Color(0.29, 0.87, 0.5, 0.55))
				draw_circle(rp + Vector2(0, -5), 1.6, Color(0.29, 0.87, 0.5, 0.45))

## Băng tên phía dưới icon (bỏ qua khi ở chế độ thu nhỏ).
func _draw_nameplate(col: Color) -> void:
	var name := GameData.champion_display_name(champion_id)
	var font := ThemeDB.fallback_font
	var plate_h := 26.0
	var y := size.y - plate_h - 6.0
	draw_rect(Rect2(0.0, y, size.x, plate_h + 6.0), Color(0.04, 0.04, 0.06, 0.82))
	# Chọn cỡ chữ lớn nhất có thể mà vẫn nằm gọn trong card.
	var fs := 13
	var max_w := size.x - 6.0
	var text_w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if text_w > max_w:
		fs = 12
		text_w = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if text_w > max_w:
		fs = 11
		text_w = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := (size.x - text_w) * 0.5
	draw_string(font, Vector2(tx, y + 18.0), name, HORIZONTAL_ALIGNMENT_LEFT,
		-1, fs, Color(1, 1, 1, 0.96 if selected else 0.7))

# ------------------------------------------------------------------ tiện ích

func _poly_pts(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width, true)
