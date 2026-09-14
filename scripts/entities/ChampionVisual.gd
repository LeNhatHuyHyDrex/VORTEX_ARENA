class_name ChampionVisual
extends Node2D
## Vẽ tướng bằng vector (không dùng file ảnh).
##
## Lý do chọn cách này thay vì tải sprite rời:
##   - Style trong ảnh tham chiếu là mảng màu phẳng, viền cứng -> vector khớp hơn.
##   - Không vướng bản quyền, không phụ thuộc file ngoài.
##   - Đổi màu/tỉ lệ bằng một dòng code, không cần mở phần mềm vẽ.
##
## Góc nhìn: từ trên xuống hơi xéo. Nhân vật vẽ theo kiểu 3/4 (thấy được mặt
## và thân trước), chân đặt tại gốc toạ độ, có bóng đổ dưới chân.

var champion: Champion = null

## Hệ số phóng to toàn bộ hình vẽ. Nhân vật được thiết kế ở tỉ lệ nhỏ (~58px
## cao) rồi phóng lên cho vừa mắt trên màn hình 720p trở lên. Đổi một số ở đây
## là đổi được cỡ tướng, không phải sửa từng toạ độ.
const DRAW_SCALE := 1.75

## Bảng màu theo từng tướng. Thêm tướng mới thì thêm một entry ở đây.
const PALETTES := {
	&"fire_mage": {
		"cloak": Color("26242e"),
		"cloak_dark": Color("1a1822"),
		"trim": Color("3a3646"),
		"skin": Color("d9a066"),
		"accent": Color("ff7a2f"),
		"metal": Color("8a8f9c"),
	},
	&"shadow_assassin": {
		"cloak": Color("241d33"),
		"cloak_dark": Color("171122"),
		"trim": Color("3d3054"),
		"skin": Color("c98f63"),
		"accent": Color("a855f7"),
		"metal": Color("b0405a"),
	},
	&"frost_maiden": {
		"cloak": Color("dff3ff"),
		"cloak_dark": Color("a8cfe6"),
		"trim": Color("7dd3fc"),
		"skin": Color("f0d3c0"),
		"accent": Color("38bdf8"),
		"metal": Color("bfe9ff"),
	},
	&"thunder_warrior": {
		"cloak": Color("3b3410"),
		"cloak_dark": Color("292408"),
		"trim": Color("facc15"),
		"skin": Color("d9a066"),
		"accent": Color("ffe066"),
		"metal": Color("cbd5e1"),
	},
	&"stone_guardian": {
		"cloak": Color("57534e"),
		"cloak_dark": Color("3f3b37"),
		"trim": Color("a8a29e"),
		"skin": Color("c4a484"),
		"accent": Color("d6d3d1"),
		"metal": Color("78716c"),
	},
	&"arcane_weaver": {
		"cloak": Color("2e2347"),
		"cloak_dark": Color("1d1630"),
		"trim": Color("4c3a72"),
		"skin": Color("d3a983"),
		"accent": Color("a78bfa"),
		"metal": Color("c4b5fd"),
	},
	&"mirage": {
		"cloak": Color("123840"),
		"cloak_dark": Color("0a2429"),
		"trim": Color("1d5a66"),
		"skin": Color("c9a17c"),
		"accent": Color("22d3ee"),
		"metal": Color("a5f3fc"),
	},
	&"marksman": {
		"cloak": Color("4a3c14"),
		"cloak_dark": Color("32280c"),
		"trim": Color("7a6420"),
		"skin": Color("d9a066"),
		"accent": Color("facc15"),
		"metal": Color("cbd5e1"),
	},
	&"seraph": {
		"cloak": Color("4a4030"),
		"cloak_dark": Color("332c20"),
		"trim": Color("fef3c7"),
		"skin": Color("f0d3c0"),
		"accent": Color("fde68a"),
		"metal": Color("fffbeb"),
	},
	&"artificer": {
		"cloak": Color("3d2a1c"),
		"cloak_dark": Color("291c12"),
		"trim": Color("6b4630"),
		"skin": Color("c4a484"),
		"accent": Color("fb923c"),
		"metal": Color("9a8f86"),
	},
	&"tamer": {
		"cloak": Color("22331f"),
		"cloak_dark": Color("162213"),
		"trim": Color("3a5c34"),
		"skin": Color("c98f63"),
		"accent": Color("4ade80"),
		"metal": Color("bbf7d0"),
	},
	&"time_weaver": {
		"cloak": Color("3b1c2a"),
		"cloak_dark": Color("2a121c"),
		"trim": Color("7a3a52"),
		"skin": Color("d9a98a"),
		"accent": Color("fb7185"),
		"metal": Color("fcd9e0"),
	},
	&"blood_lord": {
		"cloak": Color("3a1418"),
		"cloak_dark": Color("24090d"),
		"trim": Color("6b1f2a"),
		"skin": Color("cf9d8a"),
		"accent": Color("ef4444"),
		"metal": Color("f8b4b4"),
	},
	&"iron_monk": {
		"cloak": Color("4a3a1c"),
		"cloak_dark": Color("302610"),
		"trim": Color("8a6a2c"),
		"skin": Color("e0b088"),
		"accent": Color("fbbf24"),
		"metal": Color("fde68a"),
	},
	&"berserker": {
		"cloak": Color("4a1c26"),
		"cloak_dark": Color("30101a"),
		"trim": Color("7a2c3a"),
		"skin": Color("d9a066"),
		"accent": Color("f43f5e"),
		"metal": Color("cbd5e1"),
	},
	&"void_samurai": {
		"cloak": Color("1c2440"),
		"cloak_dark": Color("121733"),
		"trim": Color("2c3a66"),
		"skin": Color("e0b088"),
		"accent": Color("818cf8"),
		"metal": Color("c7d2fe"),
	},
	&"plague_alchemist": {
		"cloak": Color("2a3318"),
		"cloak_dark": Color("1a2210"),
		"trim": Color("44521f"),
		"skin": Color("d9b98a"),
		"accent": Color("84cc16"),
		"metal": Color("d9f99d"),
	},
}

func _ready() -> void:
	champion = get_parent() as Champion
	z_index = 1

func _process(_delta: float) -> void:
	queue_redraw()

func _palette() -> Dictionary:
	return PALETTES.get(champion.champion_id, PALETTES[&"fire_mage"])

func _draw() -> void:
	if champion == null:
		return
	# Áp hệ số phóng to một lần cho toàn bộ phần vẽ bên dưới.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(DRAW_SCALE, DRAW_SCALE))
	var p := _palette()
	var t := champion.anim_time()
	var alive := champion.is_alive()

	# Nhịp thở khi đứng yên + nhún khi chạy.
	var speed_ratio := clampf(champion.velocity.length() / maxf(champion.move_speed, 1.0), 0.0, 1.0)
	var bob := sin(t * 3.2) * 1.1 + sin(t * 12.0) * 1.8 * speed_ratio

	if not alive:
		_draw_dead(p)
		return

	# Hướng nhìn: lật ngang theo trục x của hướng ngắm.
	var flip := 1.0 if champion.aim_dir.x >= 0.0 else -1.0

	_draw_ground_platform()
	_draw_team_ring()
	_draw_shadow(p)
	_draw_aim_indicator(p, flip)
	_draw_cape(p, flip, t, speed_ratio)
	_draw_legs(p, flip, speed_ratio, t)
	_draw_body(p, flip, bob)
	_draw_head(p, flip, bob, t)
	_draw_weapon(p, flip, bob)
	# Cú vung khi ra chiêu: quét cung sáng theo hướng chiêu vừa tung.
	_draw_cast_swing(p, flip)
	# Viền sáng vẽ sau cùng, đè lên mọi mảng màu, để bóng tách khỏi nền sân tối.
	_draw_rim_light(p, flip, bob)
	_draw_status_vfx(p, t)
	_draw_hit_flash()

# ------------------------------------------------------------------ các phần

## Bệ đá isometric dưới chân: mặt thoi + cạnh dày + viền rune màu phe.
##
## Nâng cảm giác 2.5D trong trận: tướng đứng trên tấm đá nổi thay vì trôi trên
## mặt sàn phẳng. Viền rune màu phe (xanh/đỏ) lồng vào trong vòng hitbox để
## không thêm chi tiết gây nhiễu vào gameplay.
func _draw_ground_platform() -> void:
	var col := Color(0.35, 0.95, 0.55) if champion.is_local else Color(1.0, 0.35, 0.3)
	var t := champion.anim_time()
	# Mặt trên hình thoi.
	_poly(PackedVector2Array([
		Vector2(-27, 3), Vector2(0, -8), Vector2(27, 3), Vector2(0, 13),
	]), Color(0.09, 0.10, 0.14, 0.88))
	# Cạnh trước hai bên tạo độ dày.
	_poly(PackedVector2Array([
		Vector2(-27, 3), Vector2(0, 13), Vector2(0, 17), Vector2(-27, 7),
	]), Color(0.05, 0.06, 0.09, 0.9))
	_poly(PackedVector2Array([
		Vector2(27, 3), Vector2(0, 13), Vector2(0, 17), Vector2(27, 7),
	]), Color(0.07, 0.08, 0.11, 0.9))
	# Viền rune phát sáng nhịp chậm, cùng màu phe.
	var pulse := 0.22 + 0.10 * sin(t * 2.6)
	draw_line(Vector2(-27, 3), Vector2(0, -8),
		Color(col.r, col.g, col.b, pulse), 1.1, true)
	draw_line(Vector2(0, -8), Vector2(27, 3),
		Color(col.r, col.g, col.b, pulse), 1.1, true)

## Vòng chân màu phe: biết ngay tướng nào là MÌNH trong một cái nhìn.
##
## Trong game 1v1 nhiều hiệu ứng nổ tung, người chơi hay mất dấu vị trí của
## mình. Vòng xanh dưới chân tướng mình + vòng đỏ dưới chân đối thủ giải
## quyết vấn đề đó mà không cần đụng vào HUD.
##
## Đồng thời đây cũng là "CHÂN DỰNG hitbox": tâm va chạm nằm ở chân nhân vật,
## nên vòng này càng rõ thì người chơi càng hiểu "đòn trúng khi chạm vòng".
func _draw_team_ring() -> void:
	var col := Color(0.35, 0.95, 0.55) if champion.is_local else Color(1.0, 0.35, 0.3)
	var pulse := 0.45 + 0.15 * sin(champion.anim_time() * 3.0)
	_ellipse(Vector2(0, 3), 23.0, 9.5, Color(col.r, col.g, col.b, 0.38))
	# Vòng ellipse không có sẵn → vẽ bằng các đoạn nối liền.
	var pts := PackedVector2Array()
	var segs := 28
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(0, 3) + Vector2(cos(a) * 23.0, sin(a) * 9.5))
	for i in range(segs):
		var c := Color(col.r, col.g, col.b, pulse)
		draw_line(pts[i], pts[(i + 1) % segs], c, 2.6, true)

## Bóng đổ dưới chân: ba lớp ellipse chồng nhau, mờ dần ra ngoài.
##
## Một hình ellipse đặc trông như miếng dán. Ba lớp lồng nhau cho ra độ mờ giảm
## dần theo bán kính, đủ để bóng "mềm" mà không cần shader.
func _draw_shadow(p: Dictionary) -> void:
	var layers: Array[float] = [1.0, 1.55, 2.15]
	var alphas: Array[float] = [0.30, 0.13, 0.06]
	for i in range(layers.size()):
		_ellipse(Vector2(0, 3), 15.0 * layers[i], 6.0 * layers[i],
			Color(0, 0, 0, alphas[i]))

## Áo choàng sau lưng, bay nhẹ theo nhịp thở và theo tốc độ chạy.
##
## Đây là chi tiết làm nhân vật "sống" hơn hẳn: một mảng vải chuyển động chậm
## hơn cơ thể một nhịp, nên mắt đọc ra ngay là có gió và có quán tính.
func _draw_cape(p: Dictionary, flip: float, t: float, speed_ratio: float) -> void:
	var sway := sin(t * 2.4) * 2.2 + sin(t * 7.0) * 1.1 * speed_ratio
	# Gió thổi ngược hướng nhìn, nên vải kéo về phía sau lưng.
	var wind := -7.0 - speed_ratio * 6.0
	var dark: Color = p["cloak_dark"]
	_poly(PackedVector2Array([
		Vector2(-10 * flip, -38),
		Vector2(11 * flip, -38),
		Vector2((13 + wind) * flip, -6 + sway * 0.4),
		Vector2((2 + wind * 1.3) * flip, 6 + sway),
		Vector2((-9 + wind) * flip, -2 + sway * 0.7),
	]), Color(dark.r, dark.g, dark.b, 0.92))

## Viền sáng một bên thân — nguồn sáng giả định ở phía trên bên phải.
##
## Vì sao cần: sân đấu có nền tối và nhân vật cũng tối, nên nếu không có viền
## sáng thì bóng nhân vật nhoè vào nền khi đứng gần vật cản.
func _draw_rim_light(p: Dictionary, flip: float, bob: float) -> void:
	var accent: Color = p["accent"]
	var rim := Color(accent.r, accent.g, accent.b, 0.55)
	var y := bob
	# Sườn phải thân
	draw_line(Vector2(13 * flip, -6 + y), Vector2(9 * flip, -36 + y), rim, 1.6, true)
	# Vai
	draw_line(Vector2(9 * flip, -36 + y), Vector2(14 * flip, -32 + y), rim, 1.6, true)
	# Đỉnh đầu
	draw_arc(Vector2(0, -46 + y), 11.0, -PI * 0.75, -PI * 0.15, 10, rim, 1.6, true)
	# Mép ngoài chân
	draw_line(Vector2(7 * flip, -14 + y), Vector2(8 * flip, 0 + y), rim, 1.3, true)

func _draw_aim_indicator(p: Dictionary, flip: float) -> void:
	# Cung mờ dưới chân cho biết hướng đang ngắm — quan trọng khi chơi cảm ứng.
	var dir := champion.aim_dir
	var base := dir.angle()
	var accent: Color = p["accent"]
	draw_arc(Vector2.ZERO, 24.0, base - 0.45, base + 0.45, 14,
		Color(accent.r, accent.g, accent.b, 0.35), 2.0, true)

func _draw_legs(p: Dictionary, flip: float, speed_ratio: float, t: float) -> void:
	var dark: Color = p["cloak_dark"]
	var swing := sin(t * 11.0) * 4.0 * speed_ratio
	# Chân trái
	_poly(PackedVector2Array([
		Vector2(-7 * flip, -14), Vector2(-2 * flip, -14),
		Vector2(-2 * flip + swing * flip, 1), Vector2(-8 * flip + swing * flip, 1),
	]), dark)
	# Chân phải
	_poly(PackedVector2Array([
		Vector2(2 * flip, -14), Vector2(7 * flip, -14),
		Vector2(8 * flip - swing * flip, 1), Vector2(2 * flip - swing * flip, 1),
	]), dark)

func _draw_body(p: Dictionary, flip: float, bob: float) -> void:
	var cloak: Color = p["cloak"]
	var trim: Color = p["trim"]
	var y := bob

	# Áo choàng ngoài — hình thang rộng dần xuống dưới.
	_poly(PackedVector2Array([
		Vector2(-9 * flip, -36 + y), Vector2(9 * flip, -36 + y),
		Vector2(13 * flip, -6 + y), Vector2(-13 * flip, -6 + y),
	]), cloak)

	# Mảng sáng bên hông tạo khối.
	_poly(PackedVector2Array([
		Vector2(3 * flip, -35 + y), Vector2(9 * flip, -35 + y),
		Vector2(12 * flip, -8 + y), Vector2(5 * flip, -8 + y),
	]), trim)

	# Đai lưng
	draw_line(Vector2(-11 * flip, -16 + y), Vector2(11 * flip, -16 + y), p["cloak_dark"], 3.0)

	# Vai / tay áo
	_poly(PackedVector2Array([
		Vector2(-9 * flip, -36 + y), Vector2(-14 * flip, -32 + y),
		Vector2(-12 * flip, -22 + y), Vector2(-8 * flip, -24 + y),
	]), p["cloak_dark"])

func _draw_head(p: Dictionary, flip: float, bob: float, t: float) -> void:
	var y := bob
	var head := Vector2(0, -46 + y)
	var skin: Color = p["skin"]

	# Mũ trùm
	draw_circle(head, 11.0, p["cloak"])
	_poly(PackedVector2Array([
		Vector2(-11 * flip, -46 + y), Vector2(11 * flip, -46 + y),
		Vector2(6 * flip, -58 + y), Vector2(-6 * flip, -58 + y),
	]), p["cloak"])

	# Khuôn mặt trong hốc mũ
	_poly(PackedVector2Array([
		Vector2(-6.5 * flip, -47 + y), Vector2(6.5 * flip, -47 + y),
		Vector2(6 * flip, -39 + y), Vector2(0, -36.5 + y), Vector2(-6 * flip, -39 + y),
	]), skin)

	# Mắt
	var eye_col := Color("1b1a22")
	draw_line(Vector2(1.5 * flip, -44.5 + y), Vector2(4.5 * flip, -44.0 + y), eye_col, 1.6)
	draw_line(Vector2(-4.5 * flip, -44.0 + y), Vector2(-1.5 * flip, -44.5 + y), eye_col, 1.6)

	# Điểm nhấn màu chủ đạo trên ngực (viên ngọc ở ảnh gốc).
	var gem := Vector2(0, -30 + y)
	draw_circle(gem, 3.2, p["accent"])
	draw_circle(gem, 1.5, Color(1, 1, 1, 0.85))

func _draw_weapon(p: Dictionary, flip: float, bob: float) -> void:
	var dir := champion.aim_dir
	var shoulder := Vector2(6 * flip, -32 + bob)
	var hand := shoulder + dir * 12.0

	if champion.champion_id == &"shadow_assassin":
		_draw_blades(p, shoulder, dir, bob)
		return
	if champion.champion_id == &"frost_maiden":
		_draw_frost_staff(p, shoulder, dir)
		return
	if champion.champion_id == &"thunder_warrior":
		_draw_spear(p, shoulder, dir)
		return
	if champion.champion_id == &"stone_guardian":
		_draw_gauntlet(p, shoulder, dir)
		return
	if champion.champion_id == &"arcane_weaver":
		_draw_void_orb(p, shoulder, dir)
		return
	if champion.champion_id == &"mirage":
		_draw_twin_fangs(p, shoulder, dir)
		return
	if champion.champion_id == &"marksman":
		_draw_rifle(p, shoulder, dir)
		return
	if champion.champion_id == &"seraph":
		_draw_censer(p, shoulder, dir)
		return
	if champion.champion_id == &"artificer":
		_draw_wrench_arm(p, shoulder, dir)
		return
	if champion.champion_id == &"tamer":
		_draw_whip(p, shoulder, dir)
		return
	if champion.champion_id == &"time_weaver":
		_draw_clock_orb(p, shoulder, dir)
		return
	if champion.champion_id == &"blood_lord":
		_draw_blood_claws(p, shoulder, dir)
		return
	if champion.champion_id == &"iron_monk":
		_draw_iron_fists(p, shoulder, dir)
		return
	if champion.champion_id == &"berserker":
		_draw_greataxe(p, shoulder, dir)
		return
	if champion.champion_id == &"void_samurai":
		_draw_katana(p, shoulder, dir)
		return
	if champion.champion_id == &"plague_alchemist":
		_draw_flask(p, shoulder, dir)
		return

	# Trượng pháp sư — đâm tới khi niệm.
	var prog := champion.cast_anim_progress()
	var thrust := sin(clampf(prog, 0.0, 1.0) * PI) * 9.0
	var tip := hand + dir * (22.0 + thrust)
	draw_line(shoulder, tip, Color("2b2b33"), 3.0)
	draw_line(shoulder, tip, Color("4a4a55"), 1.0)
	# Quả cầu lửa ở đầu trượng, nhấp nháy nhẹ — bùng to khi ra chiêu.
	var flicker := 0.85 + sin(champion.anim_time() * 9.0) * 0.15 + prog * 0.7
	var accent: Color = p["accent"]
	draw_circle(tip, 7.0 * flicker, Color(accent.r, accent.g, accent.b, 0.25))
	draw_circle(tip, 4.6 * flicker, Color("ff8c3a"))
	draw_circle(tip, 2.6 * flicker, Color("ffd24a"))

func _draw_blades(p: Dictionary, shoulder: Vector2, dir: Vector2, bob: float) -> void:
	var metal: Color = p["metal"]
	var accent: Color = p["accent"]
	# Hai lưỡi chéo nhau, mở theo hướng ngắm.
	var perp := Vector2(-dir.y, dir.x)
	var front := shoulder + dir * 13.0
	# Khai báo kiểu tường minh cho mảng: nếu để mảng suông, biến s trong vòng
	# lặp bị coi là Variant và Godot không suy được kiểu của base/tip.
	var offsets: Array[float] = [-1.0, 1.0]
	for s in offsets:
		var base: Vector2 = front + perp * (5.0 * s)
		var tip: Vector2 = base + dir * 20.0 + perp * (2.0 * s)
		draw_line(base, tip, metal, 3.0)
		draw_line(base, tip, Color(1, 0.75, 0.8, 0.5), 1.0)
	draw_circle(shoulder, 3.0, accent)

## Trượng băng: cán mảnh + tinh thể lục lăng ở đầu, tỏa hơi lạnh.
func _draw_frost_staff(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var tip := shoulder + dir * 24.0
	draw_line(shoulder, tip, Color("bfe9ff"), 2.4)
	draw_line(shoulder, tip, Color(1, 1, 1, 0.5), 0.8)
	var perp := Vector2(-dir.y, dir.x)
	_poly(PackedVector2Array([
		tip + dir * 7.0, tip + perp * 4.2, tip - perp * 4.2,
		tip - dir * 6.0, tip - perp * 4.2 - dir * 1.0,
	]), Color("93e5ff"))
	draw_circle(tip, 2.0, Color(1, 1, 1, 0.9))

## Giáo sét: cán dài, mũi nhọn, tia lửa nhỏ chạy dọc thân giáo.
## Khi đâm: giáo phóng tới trước rồi rút về.
func _draw_spear(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var prog := champion.cast_anim_progress()
	var lunge := sin(clampf(prog, 0.0, 1.0) * PI) * 8.0
	var base := shoulder - dir * lunge * 0.4
	var tip := base + dir * (30.0 + lunge)
	draw_line(base, tip, Color("8a7a3a"), 3.0)
	_poly(PackedVector2Array([
		tip, tip + dir * 8.0,
		tip + Vector2(-dir.y, dir.x) * 3.2,
	]), p["metal"])
	var spark := fmod(champion.anim_time() * 6.0, 1.0)
	var at := base.lerp(tip, spark)
	draw_circle(at, 2.2, Color(1.0, 0.92, 0.4, 0.9))
	draw_circle(tip, 3.0, Color("ffe066"))
	# Chớp điện quanh mũi giáo khi vừa đâm.
	if prog > 0.3:
		draw_circle(tip, 7.0 * prog, Color(1.0, 0.95, 0.5, prog * 0.5))

## Song Ảnh: hai lưỡi ngắn cong, vẽ như hai vệt sáng.
func _draw_twin_fangs(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	# Mảng phải khai báo kiểu: `for s in [-1.0, 1.0]` làm `s` thành Variant, và
	# mọi phép tính với nó cũng thành Variant nên `:=` không suy được kiểu.
	var sides: Array[float] = [-1.0, 1.0]
	for s in sides:
		var base := shoulder + perp * (4.0 * s)
		var tip := base + dir * 18.0 + perp * (3.0 * s)
		draw_line(base, tip, Color("a5f3fc"), 2.6, true)
		draw_line(base, tip, Color(1, 1, 1, 0.5), 1.0, true)
	draw_circle(shoulder, 2.6, p["accent"])

## Súng trường: nòng dài, có ống ngắm nhỏ ở trên.
## Khi bắn: giật nòng về sau + chớp lửa đầu nòng.
func _draw_rifle(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var prog := champion.cast_anim_progress()
	var recoil := prog * 5.0
	var tip := shoulder + dir * (30.0 - recoil)
	var stock := shoulder - dir * recoil
	var perp := Vector2(-dir.y, dir.x)
	draw_line(stock, tip, Color("2b2b33"), 4.0, true)
	draw_line(stock, tip, Color("6b7280"), 1.6, true)
	# Ống ngắm
	var scope := shoulder + dir * 14.0 + perp * 4.0
	draw_line(scope - perp * 3.0, scope + perp * 3.0, Color("cbd5e1"), 2.2, true)
	# Đầu nòng sáng lên
	draw_circle(tip, 2.6, p["accent"])
	# Chớp lửa đầu nòng khi vừa bắn.
	if prog > 0.2:
		var flash := Color(1.0, 0.85, 0.4, prog * 0.9)
		draw_circle(tip + dir * 3.0, 5.0 * prog, flash)
		draw_circle(tip + dir * 6.0, 3.2 * prog, Color(1, 1, 1, prog))

## Bình hương: quả cầu sáng treo trên dây xích, đung đưa theo nhịp.
func _draw_censer(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var hand := shoulder + dir * 10.0
	var t := champion.anim_time()
	var sway := Vector2(sin(t * 1.6) * 4.0, 12.0 + cos(t * 1.6) * 2.0)
	var orb := hand + sway
	draw_line(hand, orb, Color("8a7a5a"), 1.6, true)
	draw_circle(orb, 7.0, Color(0.99, 0.92, 0.6, 0.28))
	draw_circle(orb, 4.2, Color("fde68a"))
	draw_circle(orb, 1.8, Color(1, 1, 1, 0.9))

## Cánh tay máy: kìm sắt + tia lửa nhỏ khi đang hoạt động.
func _draw_wrench_arm(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var hand := shoulder + dir * 13.0
	var perp := Vector2(-dir.y, dir.x)
	draw_line(hand, hand + dir * 11.0, p["metal"], 4.0, true)
	var jaws: Array[float] = [-1.0, 1.0]
	for s in jaws:
		draw_line(hand + dir * 11.0, hand + dir * 15.0 + perp * (4.0 * s),
			p["metal"], 3.0, true)
	draw_circle(hand, 3.0, p["accent"])

## Roi da: sợi dây dài uốn lượn, đầu roi có mấu.
##
## Khi vừa ra đòn, roi VUNG thật: nếp gợn chạy dọc sợi dây, đầu roi quất tới
## hết tầm rồi co lại — đây là hoạt ảnh người chơi thấy rõ nhất ở Champion Ưng.
func _draw_whip(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var t := champion.anim_time()
	var prog := champion.cast_anim_progress()
	# Chiều dài roi: nghỉ ~34px, vung thì duỗi thẳng tới 58px rồi co lại.
	var reach := lerpf(34.0, 58.0, sin(clampf(prog, 0.0, 1.0) * PI))
	# Cú vung làm biên độ sóng lớn rồi tắt dần.
	var wave_amp := 5.0 + prog * 9.0
	var pts := PackedVector2Array()
	for i in range(7):
		var f := float(i) / 6.0
		var wave := sin(t * 5.0 + f * 4.0) * wave_amp * f
		# Gợn sóng dập theo chiều vung: đỉnh sóng di chuyển ra ngoài.
		pts.append(shoulder + dir * (f * reach) + Vector2(-dir.y, dir.x) * wave)
	for i in range(pts.size() - 1):
		# Sợi roi dày hơn khi đang vung.
		draw_line(pts[i], pts[i + 1], Color("8a6a4a"), 2.2 + prog * 1.6, true)
	draw_circle(pts[pts.size() - 1], 2.6 + prog * 1.6, p["accent"])
	# Chớp "tách" ở đầu roi lúc vung — điểm roi chạm mục tiêu.
	if prog > 0.15:
		var tip := pts[pts.size() - 1]
		draw_circle(tip, 6.5 * prog, Color(0.98, 1.0, 0.9, 0.55 * prog))
		draw_circle(tip, 3.0 * prog, Color(1, 1, 1, 0.9 * prog))

## Quả cầu hư không: không cầm vũ khí, chỉ có một khối năng lượng lơ lửng
## trên lòng bàn tay, nhấp nháy và tự xoay.
func _draw_void_orb(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var palm := shoulder + dir * 12.0
	var t := champion.anim_time()
	var float_y := sin(t * 2.6) * 2.2
	var orb := palm + Vector2(0, -9.0 + float_y)

	draw_circle(orb, 11.0, Color(0.55, 0.36, 0.98, 0.22))
	draw_circle(orb, 7.0, Color("8b5cf6"))
	draw_circle(orb, 3.2, Color(1, 1, 1, 0.9))
	# Vành xoay quanh quả cầu.
	var a := t * 3.4
	draw_arc(orb, 10.0, a, a + 2.0, 14, Color(0.78, 0.71, 1.0, 0.75), 1.8, true)
	draw_arc(orb, 10.0, a + PI, a + PI + 2.0, 14, Color(0.78, 0.71, 1.0, 0.55), 1.8, true)
	# Bàn tay đỡ bên dưới.
	draw_circle(palm, 4.0, p["skin"])

## Găng đá: không có vũ khí dài, chỉ là nắm đấm to + đá lơ lửng cạnh người.
func _draw_gauntlet(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var hand := shoulder + dir * 10.0
	_poly(PackedVector2Array([
		hand + Vector2(-6, -5), hand + Vector2(6, -5),
		hand + Vector2(7, 5), hand + Vector2(-7, 5),
	]), p["metal"])
	draw_circle(hand, 4.0, Color("a8a29e"))
	var orbit := champion.anim_time() * 1.6
	var rock := shoulder + Vector2(cos(orbit) * 15.0, sin(orbit) * 7.0 - 6.0)
	_poly(PackedVector2Array([
		rock + Vector2(-5, -1), rock + Vector2(-2, -5),
		rock + Vector2(4, -4), rock + Vector2(5, 2), rock + Vector2(-1, 5),
	]), Color("78716c"))

## Cú vung khi ra chiêu — phản hồi hình ảnh tức thời cho MỌI đòn.
##
## Vì sao cần: người chơi bấm phím mà nhân vật không nhúc nhích thì cảm giác
## "chiêu đã ra" không tồn tại. Một cung sáng quét ngang theo hướng chiêu,
## mờ dần trong 0.3 giây, là đủ để mọi đòn đều "có trọng lượng".
func _draw_cast_swing(p: Dictionary, flip: float) -> void:
	var prog := champion.cast_anim_progress()
	if prog <= 0.01:
		return
	var dir := champion.cast_anim_dir()
	var base := dir.angle()
	var accent: Color = p["accent"]
	var a := prog * prog * 0.85
	# Cung quét: rộng 1.9 radian, quét từ mép này sang mép kia theo tiến độ.
	var sweep := 1.9
	var start := base - sweep * 0.5
	var sweep_now := sweep * (1.0 - prog)
	# Vệt sáng chính
	draw_arc(Vector2(0, -18), 30.0, start, start + sweep_now + 0.35, 16,
		Color(accent.r, accent.g, accent.b, a), 4.5, true)
	draw_arc(Vector2(0, -18), 30.0, start, start + sweep_now + 0.35, 16,
		Color(1, 1, 1, a * 0.65), 1.8, true)
	# Vệt mờ phía sau, gợi chuyển động
	draw_arc(Vector2(0, -18), 24.0, start, start + sweep_now, 12,
		Color(accent.r, accent.g, accent.b, a * 0.4), 2.4, true)
	# Chớp sáng ở đầu vệt — điểm "chạm" của cú đánh.
	var tip_a := start + sweep_now + 0.35
	var tip := Vector2(0, -18) + Vector2(cos(tip_a), sin(tip_a)) * 30.0
	draw_circle(tip, 3.6 * prog, Color(1, 1, 1, a))
	# Hơi lệch theo hướng nhìn cho khớp với dáng người.
	_ellipse(Vector2(flip * 2.0, -18), 26.0, 15.0, Color(accent.r, accent.g, accent.b, a * 0.12))

## Đồng hồ cát lơ lửng của Thời Sư: khung vàng + cát hồng rơi + kim quay ngược.
func _draw_clock_orb(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var t := champion.anim_time()
	var prog := champion.cast_anim_progress()
	var palm := shoulder + dir * 12.0
	var float_y := sin(t * 2.2) * 2.4
	var center := palm + Vector2(0, -10.0 + float_y)
	var accent: Color = p["accent"]
	var glow := Color(accent.r, accent.g, accent.b, 0.20)

	# Quầng năng lượng.
	draw_circle(center, 12.0 + prog * 4.0, glow)
	# Mặt đồng hồ: vòng ngoài sáng + 12 vạch khắc.
	draw_arc(center, 9.0, 0.0, TAU, 32, p["metal"], 2.2, true)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var r0 := 7.4 if i % 3 != 0 else 6.6
		draw_line(center + Vector2(cos(a), sin(a)) * r0,
			center + Vector2(cos(a), sin(a)) * 8.4,
			Color(1, 1, 1, 0.55 if i % 3 == 0 else 0.3), 1.0, true)
	# Hai kim quay NGƯỢC chiều — chi tiết đặc trưng của thời gian bị bẻ cong.
	var minute := -t * 2.6
	var hour := -t * 0.9 + 2.0
	draw_line(center, center + Vector2(cos(minute), sin(minute)) * 7.6,
		Color(1, 0.95, 0.92, 0.9), 1.6, true)
	draw_line(center, center + Vector2(cos(hour), sin(hour)) * 4.8,
		Color(accent.r, accent.g, accent.b, 0.95), 1.9, true)
	# Hạt cát hồng rơi từ nửa trên xuống nửa dưới.
	for i in range(3):
		var ph := fposmod(t * 0.8 + float(i) / 3.0, 1.0)
		var sy := lerpf(-6.0, 5.0, ph)
		draw_circle(center + Vector2(sin(t * 3.0 + i) * 1.2, sy),
			1.1, Color(accent.r, accent.g, accent.b, 0.8 * (1.0 - ph * 0.4)))
	# Chớp sáng khi ra chiêu.
	if prog > 0.1:
		draw_circle(center, 14.0 * prog, Color(1, 0.9, 0.85, prog * 0.5))
	# Bàn tay đỡ bên dưới.
	draw_circle(palm, 4.0, p["skin"])

## Vuốt máu của Huyết Bá: hai khúc vuốt cong đỏ thẫm, nhỏ giọt khi vừa vung.
func _draw_blood_claws(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var accent: Color = p["accent"]
	var perp := Vector2(-dir.y, dir.x)
	var prog := champion.cast_anim_progress()
	var sides: Array[float] = [-1.0, 1.0]
	for s in sides:
		var base := shoulder + dir * 10.0 + perp * (5.0 * s)
		# Khúc cong: ba đoạn nối tạo dáng vuốt cong vào giữa.
		var m1 := base + dir * 8.0 + perp * (7.0 * s)
		var m2 := base + dir * 16.0 + perp * (2.0 * s)
		var tip := base + dir * 24.0 - perp * (1.0 * s)
		draw_line(base, m1, p["metal"], 2.8, true)
		draw_line(m1, m2, Color(accent.r, accent.g, accent.b, 0.95), 2.4, true)
		draw_line(m2, tip, Color(accent.r, accent.g, accent.b, 0.8), 1.8, true)
	# Giọt máu rơi ở đầu vuốt khi vừa cào.
	if prog > 0.25:
		var drop := shoulder + dir * 30.0
		draw_circle(drop, 2.4 * prog, Color(0.94, 0.27, 0.27, 0.85 * prog))
		draw_circle(drop + Vector2(0, 5.0 * (1.0 - prog)), 1.6, Color(0.94, 0.27, 0.27, 0.6 * prog))

## Song quyền cứng của Thiết Quyền Sư: hai găng kim loại hộp, đấm vươn ra khi ra chiêu.
func _draw_iron_fists(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var prog := champion.cast_anim_progress()
	var punch := sin(clampf(prog, 0.0, 1.0) * PI) * 7.0
	var perp := Vector2(-dir.y, dir.x)
	var sides: Array[float] = [-1.0, 1.0]
	for s in sides:
		var off := 6.0 * s
		# Tay đấm chính vươn xa hơn tay giữ thế.
		var reach := 14.0 + punch + (2.0 * s if s > 0.0 else 0.0)
		var fist := shoulder + dir * reach + perp * off
		_poly(PackedVector2Array([
			fist + Vector2(-4, -4), fist + Vector2(4, -4),
			fist + Vector2(5, 4), fist + Vector2(-5, 4),
		]), p["metal"])
		draw_circle(fist, 2.0, p["accent"])
	# Sợi buộc tay vàng nhạt quanh cổ tay.
	draw_line(shoulder + perp * 4.0, shoulder - perp * 4.0, p["accent"], 1.6, true)

## Đại rìu của Cuồng Chiến: cán dài, lưỡi rìu rộng, sáng lên khi vung.
func _draw_greataxe(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var prog := champion.cast_anim_progress()
	var lunge := sin(clampf(prog, 0.0, 1.0) * PI) * 8.0
	var base := shoulder - dir * 2.0
	var shaft_tip := base + dir * (30.0 + lunge)
	draw_line(base, shaft_tip, Color("4a3428"), 3.4, true)
	# Lưỡi rìu: mảng tam giác lệch một bên cán.
	var perp := Vector2(-dir.y, dir.x)
	var blade_base := shaft_tip - dir * 6.0
	_poly(PackedVector2Array([
		blade_base + perp * 3.0,
		blade_base + perp * 12.0 + dir * 3.0,
		shaft_tip + perp * 8.0 + dir * 6.0,
		shaft_tip + dir * 9.0,
		shaft_tip - perp * 1.0 + dir * 5.0,
	]), p["metal"])
	# Sáng lưỡi khi vung — cảm giác "rìu sắc".
	if prog > 0.2:
		draw_line(blade_base + perp * 8.0, shaft_tip + perp * 6.0 + dir * 8.0,
			Color(1, 0.75, 0.8, prog * 0.8), 2.0, true)

## Katana của Kiếm Thánh: cán ngắn + vỏ đen, lưỡi mảnh sáng bạc.
func _draw_katana(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var prog := champion.cast_anim_progress()
	# Kiếm rút ra khi vừa ra chiêu, về lại vỏ khi xong.
	var drawn := sin(clampf(prog, 0.0, 1.0) * PI)
	var blade_len := lerpf(6.0, 34.0, drawn)
	var perp := Vector2(-dir.y, dir.x)
	var grip := shoulder + perp * 6.0
	var tip := grip + dir * blade_len
	# Vỏ kiếm (khi chưa rút).
	if drawn < 0.35:
		draw_line(grip, grip + dir * 16.0, Color("151a2e"), 3.0, true)
	# Lưỡi: thân mảnh + lằn gọt trắng.
	draw_line(grip, tip, p["metal"], 2.6, true)
	if drawn > 0.15:
		draw_line(grip + perp * 0.8, tip + perp * 0.8, Color(1, 1, 1, 0.7 * drawn), 1.0, true)
	# Tsuba (chắn tay) nhỏ.
	draw_circle(grip, 2.4, p["accent"])

## Bình độc của Độc Sư: bình cổ cong, chất lỏng xanh sủi bọt.
func _draw_flask(p: Dictionary, shoulder: Vector2, dir: Vector2) -> void:
	var hand := shoulder + dir * 11.0
	var t := champion.anim_time()
	var prog := champion.cast_anim_progress()
	var bob := sin(t * 2.8) * 1.6
	var flask := hand + Vector2(0, -8.0 + bob)
	# Thân bình thuỷ tinh.
	draw_circle(flask, 7.0, Color(0.85, 0.95, 0.75, 0.22))
	draw_arc(flask, 7.0, 0.0, TAU, 20, p["metal"], 1.6, true)
	# Cổ bình + nút.
	draw_line(flask + Vector2(-2.5, -6.5), flask + Vector2(-2.5, -11.0), p["metal"], 2.2, true)
	draw_line(flask + Vector2(2.5, -6.5), flask + Vector2(2.5, -11.0), p["metal"], 2.2, true)
	draw_line(flask + Vector2(-3.5, -11.5), flask + Vector2(3.5, -11.5), Color("6b4630"), 3.0, true)
	# Chất lỏng độc bên trong, dâng cao khi niệm.
	var fill := 0.55 + prog * 0.3
	_ellipse(flask + Vector2(0, 7.0 * (1.0 - fill)), 5.4, 2.2, p["accent"])
	# Bọt sủi.
	for i in range(3):
		var ph := fposmod(t * 1.2 + float(i) / 3.0, 1.0)
		draw_circle(flask + Vector2(sin(t * 4.0 + i * 2.0) * 3.0, 6.0 - ph * 9.0),
			1.0 + (1.0 - ph), Color(1, 1, 1, 0.5 * (1.0 - ph)))
	draw_circle(hand, 3.4, p["skin"])

func _draw_status_vfx(p: Dictionary, t: float) -> void:
	# Bỏng: ngọn lửa nhỏ bay lên, số lượng tăng theo stack.
	var burn := champion.get_stacks(GameData.ST_BURN)
	if burn > 0:
		var n := mini(burn, 6)
		for i in range(n):
			var phase := t * 4.0 + float(i) * 1.7
			var rise := fmod(phase, 1.0)
			var fx := sin(phase * 2.3) * 9.0
			var fy := -30.0 - rise * 34.0
			var size := (1.0 - rise) * 4.2 + 1.2
			var col := Color(1.0, 0.55 + rise * 0.25, 0.15, (1.0 - rise) * 0.85)
			draw_circle(Vector2(fx, fy), size, col)

	# Khóa Hồn: vòng xoáy tím quanh chân.
	if champion.has_status(GameData.ST_MARK):
		var pulse := 0.6 + sin(t * 6.0) * 0.25
		draw_arc(Vector2(0, 2), 21.0, 0.0, TAU, 28,
			Color(0.66, 0.33, 0.97, pulse * 0.8), 2.2, true)
		draw_arc(Vector2(0, 2), 25.0, t * 1.5, t * 1.5 + 2.0, 12,
			Color(0.85, 0.6, 1.0, pulse), 2.6, true)

	# Chậm: vòng xanh lam mờ.
	if champion.has_status(GameData.ST_SLOW):
		draw_arc(Vector2(0, 2), 19.0, 0.0, TAU, 24,
			Color(0.22, 0.74, 0.97, 0.5), 2.0, true)

	# Khiên: lớp sáng mờ quanh thân.
	if champion.has_status(GameData.ST_SHIELD):
		var sp := 0.5 + sin(t * 4.0) * 0.15
		draw_arc(Vector2(0, -22), 18.0, 0.0, TAU, 32,
			Color(0.22, 0.93, 0.97, sp * 0.45), 2.4, true)

	# Chí Mạng (empower): tia sáng nhấp nháy quanh viên ngọc.
	if champion.has_status(GameData.ST_EMPOWER):
		var ep := 0.6 + sin(t * 8.0) * 0.3
		draw_circle(Vector2(0, -30), 6.0, Color(1.0, 0.92, 0.35, ep * 0.35))
		for i in range(4):
			var a := TAU * float(i) / 4.0 + t * 2.0
			var p1 := Vector2(cos(a), sin(a)) * 5.0 + Vector2(0, -30)
			var p2 := Vector2(cos(a), sin(a)) * 9.0 + Vector2(0, -30)
			draw_line(p1, p2, Color(1.0, 0.92, 0.35, ep * 0.7), 1.6, true)

	# Tăng Tốc: vệt mờ phía sau khi chạy.
	if champion.has_status(GameData.ST_HASTE):
		var speed_r := clampf(champion.velocity.length() / maxf(champion.move_speed, 1.0), 0.0, 1.0)
		if speed_r > 0.2:
			var dir := -champion.velocity.normalized()
			for i in range(3):
				var f := float(i + 1) / 3.0
				var pp := dir * (8.0 + f * 14.0) + Vector2(sin(t * 10.0 + i) * 3.0, 0)
				draw_circle(pp, (1.0 - f) * 3.5,
					Color(0.55, 1.0, 0.65, (1.0 - f) * 0.35 * speed_r))

	# Nhiễm Độc: bọt khí xanh lục sủi quanh người, số lượng theo stack.
	var poison := champion.get_stacks(GameData.ST_POISON)
	if poison > 0:
		var n := mini(poison, 6)
		for i in range(n):
			var phase := t * 3.2 + float(i) * 1.9
			var rise := fmod(phase, 1.0)
			var fx := sin(phase * 2.7) * 10.0
			var fy := -22.0 - rise * 30.0
			var size := (1.0 - rise) * 3.6 + 1.0
			var col := Color(0.64, 0.8, 0.2, (1.0 - rise) * 0.8)
			draw_circle(Vector2(fx, fy), size, col)
		# Vòng chân xanh mờ báo hiệu đang nhiễm độc.
		draw_arc(Vector2(0, 2), 20.0, 0.0, TAU, 26,
			Color(0.64, 0.8, 0.2, 0.35), 1.8, true)

## Phản hồi trúng đòn: che phủ CẢ NGƯỜI chứ không chỉ lồng ngực.
##
## Vì sao: tâm va chạm nằm ở chân, người vẽ cao trên đó. Nếu flash chỉ chấm ở
## ngực thì người chơi nhìn thấy "chạm chân" nhưng không thấy "trúng người" —
## chính là cảm giác hitbox khó hiểu. Ba lớp: chấm sáng thân + vòng rung dưới
## chân + cột sáng mảnh dọc người, all cùng tắt trong ~0.25s.
func _draw_hit_flash() -> void:
	var f := champion.flash_amount()
	if f <= 0.01:
		return
	# Thân người cháy sáng trắng.
	draw_circle(Vector2(0, -28), 24.0, Color(1, 1, 1, f * 0.38))
	draw_circle(Vector2(0, -44), 14.0, Color(1, 1, 1, f * 0.28))
	# Vòng rung tại chân trùng với vòng hitbox — nối liền "trúng" với "vòng chân".
	var ring := 0.75 + (1.0 - f) * 0.45
	_ellipse(Vector2(0, 3), 23.0 * ring, 9.5 * ring, Color(1, 1, 1, f * 0.30))
	# Cột sáng mảnh dọc thân: điểm chạm "dâng" dọc theo người.
	draw_line(Vector2(0, -2), Vector2(0, -58), Color(1, 1, 1, f * 0.30), 3.0)

func _draw_dead(p: Dictionary) -> void:
	# Xác nằm sấp: vẽ mảng tối dẹt, mờ dần.
	var col: Color = p["cloak_dark"]
	col.a = 0.55
	_ellipse(Vector2(0, 4), 17.0, 8.0, col)
	col.a = 0.35
	_ellipse(Vector2(0, 2), 22.0, 10.0, col)

# ------------------------------------------------------------------ tiện ích

func _poly(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

## Godot không có draw_ellipse, nên dựng ellipse từ polygon nhiều cạnh.
func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
