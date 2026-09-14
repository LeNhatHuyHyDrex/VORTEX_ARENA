class_name VFXLibrary
extends RefCounted
## Thư viện hiệu ứng hình ảnh 2.5D Isometric (VFX & Shaders) cho các trận chiến.

# ------------------------------------------------------------------- Sprite Kenney
## Sprite Kenney Particle Pack (CC0) — dùng khi có, rơi về vector khi không.
## Mỗi sprite chỉ nạp một lần rồi cache static; khi build không đóng gói
## kèm sprite, ta tự vẽ vector như trước nên game không vỡ.
const _K_PATH := "res://assets/vfx/kenney_particles/"
const _K_SPARK := _K_PATH + "spark_05.png"
const _K_LIGHT := _K_PATH + "light_01.png"
const _K_FLAME := _K_PATH + "flame_05.png"
const _K_CIRCLE := _K_PATH + "circle_03.png"
const _K_MUZZLE := _K_PATH + "muzzle_05_rotated.png"
const _K_TRACE := _K_PATH + "trace_05_rotated.png"
static var _kenney_loaded := false
static var k_spark: Texture2D
static var k_light: Texture2D
static var k_flame: Texture2D
static var k_circle: Texture2D
static var k_muzzle: Texture2D
static var k_trace: Texture2D

static func _load_kenney() -> void:
	if _kenney_loaded:
		return
	_kenney_loaded = true
	if ResourceLoader.exists(_K_SPARK):
		k_spark = load(_K_SPARK)
	if ResourceLoader.exists(_K_LIGHT):
		k_light = load(_K_LIGHT)
	if ResourceLoader.exists(_K_FLAME):
		k_flame = load(_K_FLAME)
	if ResourceLoader.exists(_K_CIRCLE):
		k_circle = load(_K_CIRCLE)
	if ResourceLoader.exists(_K_MUZZLE):
		k_muzzle = load(_K_MUZZLE)
	if ResourceLoader.exists(_K_TRACE):
		k_trace = load(_K_TRACE)

# ------------------------------------------------- Spell FX (2D Spell Effects)
## Pack "2D Spell Effects" (pompi, CC0) đã dựng thành spritesheet nằm ở
## res://assets/vfx/spell_fx/. manifest.json khai báo số frame/lưới của từng
## hiệu ứng. Có pack thì phát chuỗi frame thật; thiếu pack thì caller rơi về
## bộ vẽ vector cũ — thêm/xoá art không bao giờ làm vỡ game.
const _FX_DIR := "res://assets/vfx/spell_fx/"
static var _fx_manifest: Dictionary = {}
static var _fx_manifest_loaded := false
static var _fx_sheet_cache: Dictionary = {}

static func _load_fx_manifest() -> void:
	if _fx_manifest_loaded:
		return
	_fx_manifest_loaded = true
	var path := _FX_DIR + "manifest.json"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_fx_manifest = parsed

## Phát một chuỗi frame của pack spell FX tại vị trí pos.
## tint cho phép tái dùng MỘT hiệu ứng cho NHIỀU nguyên tố khác nhau
## (vd. blackExplosion: tím cho Sát Thủ, xanh lá cho Độc Linh Sư).
static func spell_seq(parent: Node, fx_name: String, pos: Vector2,
		scale_px: float = 1.0, tint: Color = Color.WHITE, fps: float = 24.0,
		rot_deg: float = 0.0, additive: bool = false, flip_h: bool = false,
		loop: bool = false) -> Node2D:
	if parent == null:
		return null
	_load_fx_manifest()
	if not _fx_manifest.has(fx_name):
		return null
	var cache_key := _FX_DIR + fx_name + ".png"
	var tex: Texture2D = _fx_sheet_cache.get(cache_key)
	if tex == null:
		if not ResourceLoader.exists(cache_key):
			return null
		tex = load(cache_key)
		_fx_sheet_cache[cache_key] = tex
	var seq := SpriteSeq.from_manifest(_fx_manifest[fx_name], tex)
	seq.fps = fps
	seq.loop = loop
	seq.tint = tint
	seq.pixel_scale = scale_px
	seq.rotation_deg = rot_deg
	seq.additive = additive
	seq.flip_h = flip_h
	seq.position = pos
	# z_index cao để luôn nổi trên sàn nhưng dưới UI.
	seq.z_index = 20
	parent.add_child(seq)
	return seq

# ------------------------------------------------------- VFX nhiều lớp / nguyên tố
## Tất cả hàm dưới đây là COMPOSITE: ghép nhiều lớp (frame pack + vòng sáng
## vector + hạt + vệt) thay vì một particle duy nhất, đúng tinh thần
## "VFX phải được thiết kế theo hero + skill". Tham số tier 0=skill thường,
## 1=ultimate — ultimate luôn to hơn, nhiều lớp hơn.

## LỚP DÙNG CHUNG: vòng sóng xung kích nở ra rồi tan (vector, rẻ, mượt).
static func shock_ring(parent: Node, pos: Vector2, radius: float,
		color: Color, duration: float = 0.35) -> void:
	if parent == null:
		return
	var ring := ShockRingNode.new()
	ring.position = pos
	ring.radius = radius
	ring.color = color
	ring.duration = duration
	parent.add_child(ring)

## LỚP DÙNG CHUNG: lóe sáng tại điểm niệm chiêu (cast flash) — rất ngắn.
static func cast_flash(parent: Node, pos: Vector2, color: Color) -> void:
	spell_seq(parent, "fx7_energyBall", pos, 0.55, Color(color.r, color.g, color.b, 0.85), 30.0, 0.0, true)
	shock_ring(parent, pos, 26.0, Color(color.r, color.g, color.b, 0.55), 0.22)

## HỎA — nổ cầu lửa: chuỗi nổ của pack + vòng sóng + khói đen.
## tier 1 (ultimate) thêm sóng thứ hai to hơn và khói dày hơn.
static func fire_blast(parent: Node, pos: Vector2, radius: float, tier: int = 0) -> void:
	if parent == null:
		return
	var s := radius / 80.0
	spell_seq(parent, "fx3_fireBall", pos, s * 1.6, Color.WHITE, 26.0)
	spell_seq(parent, "fx5_fire_scissors", pos, s * 1.1, Color(1, 0.85, 0.6, 0.9), 30.0, 0.0, true)
	shock_ring(parent, pos, radius * 0.9, Color(1.0, 0.55, 0.2, 0.6), 0.32)
	if tier >= 1:
		shock_ring(parent, pos, radius * 1.35, Color(1.0, 0.35, 0.1, 0.45), 0.5)
		spell_seq(parent, "fx10_blackExplosion", pos + Vector2(0, 6), s * 0.9,
			Color(0.35, 0.3, 0.3, 0.5), 20.0)

## HỎA — dấu vòng lửa trên đất (Tường Lửa / vùng cháy).
static func fire_ground(parent: Node, pos: Vector2, radius: float) -> void:
	if parent == null:
		return
	spell_seq(parent, "fx4_sign_of_fire", pos, radius / 70.0, Color(1, 0.9, 0.75, 0.95), 22.0, 0.0, false, false, false)
	spell_seq(parent, "fx6_eaterFire", pos, radius / 110.0, Color(1, 0.6, 0.25, 0.8), 22.0, 0.0, true)

## HỎA — vệt chém lửa theo hướng (Lướt Lửa / đòn cận chiến nóng).
static func fire_slash(parent: Node, pos: Vector2, angle_deg: float, scale_px: float = 1.0) -> void:
	spell_seq(parent, "fx2_swordFire", pos, scale_px, Color.WHITE, 34.0, angle_deg, true)

## BĂNG — nở băng: chuỗi xanh của pack nhuộm cyan + tinh thể vector lạnh.
static func ice_bloom(parent: Node, pos: Vector2, radius: float, tier: int = 0) -> void:
	if parent == null:
		return
	var cyan := Color(0.62, 0.9, 1.0)
	spell_seq(parent, "fx1_blue_topEffect", pos, radius / 95.0, cyan, 24.0)
	shock_ring(parent, pos, radius * 0.8, Color(0.65, 0.92, 1.0, 0.5), 0.4)
	if tier >= 1:
		# Bão tuyết: mưa đất của pack nhuộm trắng lạnh, rơi đều quanh vùng.
		spell_seq(parent, "fx9_rainOnGround", pos, radius / 120.0,
			Color(0.85, 0.95, 1.0, 0.7), 18.0, 0.0, false, false, false)
		shock_ring(parent, pos, radius * 1.2, Color(0.8, 0.95, 1.0, 0.35), 0.6)

## BÓNG — bùng khói đen tím (Sát Thủ Bóng Tối / nổ bóng).
static func shadow_burst(parent: Node, pos: Vector2, radius: float, tier: int = 0) -> void:
	if parent == null:
		return
	var purple := Color(0.72, 0.5, 1.0)
	spell_seq(parent, "fx10_blackExplosion", pos, radius / 90.0, Color(1, 1, 1, 0.92), 26.0)
	shock_ring(parent, pos, radius * 0.75, Color(purple.r, purple.g, purple.b, 0.55), 0.3)
	if tier >= 1:
		spell_seq(parent, "fx10_blackExplosion", pos + Vector2(0, -8), radius / 130.0,
			Color(0.85, 0.75, 1.0, 0.55), 20.0)
		shock_ring(parent, pos, radius * 1.15, Color(purple.r, purple.g, purple.b, 0.35), 0.55)

## LÔI — cầu sét nổ: chuỗi lightning ball + vòm sóng vàng trắng.
static func lightning_burst(parent: Node, pos: Vector2, radius: float, tier: int = 0) -> void:
	if parent == null:
		return
	spell_seq(parent, "fx8_lighteningBall", pos, radius / 85.0, Color.WHITE, 26.0)
	shock_ring(parent, pos, radius * 0.85, Color(1.0, 0.92, 0.5, 0.6), 0.3)
	if tier >= 1:
		shock_ring(parent, pos, radius * 1.3, Color(1.0, 0.85, 0.3, 0.4), 0.55)

## ĐỘC — bùng khói độc xanh lá (tái dùng blackExplosion nhuộm xanh) + bọt.
static func poison_burst(parent: Node, pos: Vector2, radius: float, tier: int = 0) -> void:
	if parent == null:
		return
	spell_seq(parent, "fx10_blackExplosion", pos, radius / 90.0,
		Color(0.65, 1.0, 0.45, 0.9), 24.0)
	shock_ring(parent, pos, radius * 0.8, Color(0.55, 0.9, 0.35, 0.5), 0.35)
	if tier >= 1:
		spell_seq(parent, "fx9_rainOnGround", pos, radius / 130.0,
			Color(0.5, 0.85, 0.4, 0.6), 18.0, 0.0, false, false, false)

## ĐỘC — vũng độc loang trên đất (vùng DoT).
static func poison_puddle(parent: Node, pos: Vector2, radius: float) -> void:
	spell_seq(parent, "fx9_rainOnGround", pos, radius / 110.0,
		Color(0.55, 0.9, 0.4, 0.75), 16.0, 0.0, false, false, false)

## ARCANE — quả cầu năng lượng (Arcane Weaver / Mirage / TimeWeaver...).
static func arcane_blast(parent: Node, pos: Vector2, radius: float, tint: Color,
		tier: int = 0) -> void:
	if parent == null:
		return
	spell_seq(parent, "fx7_energyBall", pos, radius / 90.0, tint, 26.0)
	shock_ring(parent, pos, radius * 0.8, Color(tint.r, tint.g, tint.b, 0.55), 0.35)
	if tier >= 1:
		shock_ring(parent, pos, radius * 1.25, Color(tint.r, tint.g, tint.b, 0.35), 0.55)

## VA CHẠM CẬN CHIẾN — bụi đất + tia lửa, dùng chung cho mọi đòn đánh thường.
static func dust_impact(parent: Node, pos: Vector2, scale_px: float = 1.0) -> void:
	if parent == null:
		return
	spell_seq(parent, "fx8_explosionOfDust", pos, scale_px, Color(1, 1, 1, 0.85), 30.0)

## RUNG MÀN HÌNH cho ultimate — gọi từ skill, tìm Game qua scene hiện tại.
## Game tự giới hạn theo Settings.screen_shake nên không cần kiểm tra ở đây.
static func ult_shake(from_node: Node, strength: float = 7.0) -> void:
	if from_node == null or from_node.get_tree() == null:
		return
	var scene := from_node.get_tree().current_scene
	if scene != null and scene.has_method("add_shake"):
		scene.add_shake(strength)


# ------------------------------------------------------------------- Trụ Băng 3D
static func ice_spikes(parent: Node, pos: Vector2, radius: float = 65.0) -> Node2D:
	if parent == null:
		return null
	var node := IceSpikesNode.new()
	node.position = pos
	node.radius = radius
	parent.add_child(node)
	return node

class IceSpikesNode extends Node2D:
	var radius: float = 65.0
	var life: float = 1.4
	var max_life: float = 1.4
	var _spikes: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 4
		# Tạo các cột tinh thể băng nhọn 3D
		var count := 9
		for i in range(count):
			var a := float(i) * TAU / float(count) + randf_range(-0.3, 0.3)
			var dist := randf_range(radius * 0.2, radius * 0.9)
			var base := Vector2(cos(a) * dist, sin(a) * dist * 0.5)
			var h := randf_range(35.0, 75.0)
			var w := randf_range(12.0, 24.0)
			_spikes.append({
				"base": base,
				"h": h,
				"w": w,
				"slant": randf_range(-8.0, 8.0),
				"delay": randf_range(0.0, 0.12)
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed := max_life - life
		var fade := clampf(life / 0.4, 0.0, 1.0) if life < 0.4 else 1.0

		# Vòng ấn chú băng dưới sàn (Runic Frost Circle)
		var seal_col := Color(0.3, 0.8, 1.0, 0.45 * fade)
		_draw_ellipse(Vector2.ZERO, radius, radius * 0.5, seal_col)
		_draw_ellipse_rim(Vector2.ZERO, radius, radius * 0.5, Color(0.6, 0.9, 1.0, 0.8 * fade), 2.0)

		# Vẽ các tinh thể băng mọc nhô lên từ sàn
		for sp in _spikes:
			var delay: float = float(sp["delay"])
			if elapsed < delay:
				continue
			var grow_t := clampf((elapsed - delay) / 0.18, 0.0, 1.0)
			var grow_ease := 1.0 - pow(1.0 - grow_t, 3.0) # Cubic out
			var b: Vector2 = sp["base"]
			var cur_h: float = float(sp["h"]) * grow_ease
			var half_w: float = float(sp["w"]) * 0.5
			var slant: float = float(sp["slant"])
			var tip: Vector2 = b + Vector2(slant, -cur_h)

			# Mặt trái (sáng hơn)
			var pts_left := PackedVector2Array([
				tip,
				b + Vector2(-half_w, 0),
				b + Vector2(0, 4)
			])
			draw_colored_polygon(pts_left, Color(0.7, 0.92, 1.0, 0.88 * fade))

			# Mặt phải (sẫm màu hơn tạo bóng 3D)
			var pts_right := PackedVector2Array([
				tip,
				b + Vector2(0, 4),
				b + Vector2(half_w, 0)
			])
			draw_colored_polygon(pts_right, Color(0.35, 0.65, 0.95, 0.88 * fade))

			# Viền phát sáng lân tinh của cạnh pha lê
			draw_line(b + Vector2(-half_w, 0), tip, Color(1, 1, 1, 0.9 * fade), 1.5)
			draw_line(b + Vector2(half_w, 0), tip, Color(0.8, 0.95, 1, 0.7 * fade), 1.2)
			draw_line(b + Vector2(0, 4), tip, Color(1, 1, 1, 0.95 * fade), 1.6)

	func _draw_ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(24):
			var a := TAU * float(i) / 24.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, color)

	func _draw_ellipse_rim(c: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in range(24):
			var a := TAU * float(i) / 24.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		for i in range(24):
			draw_line(pts[i], pts[(i + 1) % 24], color, width, true)


# ---------------------------------------------------------------- Sấm Sét Giáng Trần
static func lightning_strike(parent: Node, target_pos: Vector2) -> Node2D:
	if parent == null:
		return null
	var node := LightningStrikeNode.new()
	node.position = target_pos
	parent.add_child(node)
	return node

class LightningStrikeNode extends Node2D:
	var life: float = 0.45
	var max_life: float = 0.45
	var _segments: Array[Vector2] = []
	var _cracks: Array[PackedVector2Array] = []

	func _ready() -> void:
		z_index = 6
		# Dựng tia sét ngoằn ngoèo từ đỉnh màn hình xuống (khoảng -550px Y)
		var start := Vector2(randf_range(-60, 60), -600)
		var cur := start
		_segments.append(cur)
		var steps := 14
		for i in range(steps):
			var t := float(i + 1) / float(steps)
			var ideal := start.lerp(Vector2.ZERO, t)
			if i == steps - 1:
				cur = Vector2.ZERO
			else:
				cur = ideal + Vector2(randf_range(-35, 35), randf_range(-12, 12))
			_segments.append(cur)

		# Các rãnh vỡ mặt sàn do sét đánh
		for i in range(5):
			var a := float(i) * TAU / 5.0 + randf_range(-0.2, 0.2)
			var len_c := randf_range(25.0, 50.0)
			var p1 := Vector2.ZERO
			var p2 := Vector2(cos(a) * len_c, sin(a) * len_c * 0.5)
			_cracks.append(PackedVector2Array([p1, p2]))

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var jitter := Vector2(randf_range(-2, 2), 0)

		# 1. Rãnh nứt sàn phát sáng màu xanh lôi điện
		for crack in _cracks:
			draw_line(crack[0], crack[1], Color(0.3, 0.7, 1.0, 0.6 * alpha), 3.0)
			draw_line(crack[0], crack[1], Color(1, 1, 1, 0.9 * alpha), 1.2)

		# 2. Quầng sáng sét lan tỏa
		draw_circle(Vector2.ZERO, 35.0 * alpha, Color(0.25, 0.7, 1.0, 0.4 * alpha))

		# 3. Thân tia sét
		for i in range(_segments.size() - 1):
			var p1 := _segments[i] + jitter
			var p2 := _segments[i + 1] + jitter
			# Vầng sáng ngoài
			draw_line(p1, p2, Color(0.2, 0.6, 1.0, 0.5 * alpha), 8.0)
			draw_line(p1, p2, Color(0.5, 0.85, 1.0, 0.8 * alpha), 4.5)
			# Lõi sét trắng chói
			draw_line(p1, p2, Color(1, 1, 1, 1.0 * alpha), 2.2)


# ------------------------------------------------------------ Va Chạm Đòn Trúng
## Tia lửa + vòng sóng xung kích tại điểm trúng đòn — dùng chung cho MỌI nguồn
## sát thương (kỹ năng + đánh thường) qua Game.spawn_damage_number.
static func hit_impact(parent: Node, pos: Vector2, color: Color,
		strength: float = 1.0) -> Node2D:
	if parent == null:
		return null
	_load_kenney()
	# Ưu tiên sprite Kenney Particle Pack nếu có — trông "thật" hơn vẽ vector.
	if k_light != null and k_spark != null and randf() < 0.65:
		var node := SpriteHitImpactNode.new()
		node.position = pos
		node.color = color
		node.strength = clampf(strength, 0.5, 1.6)
		parent.add_child(node)
		return node
	# Fallback vector khi chưa import sprite hoặc 35% xác suất để đỡ đơn điệu.
	var vnode := HitImpactNode.new()
	vnode.position = pos
	vnode.color = color
	vnode.strength = clampf(strength, 0.5, 1.6)
	parent.add_child(vnode)
	return vnode

class HitImpactNode extends Node2D:
	var color := Color(1.0, 0.8, 0.4)
	var strength := 1.0
	var life := 0.32
	var max_life := 0.32
	var _sparks: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 8
		# 6-10 tia lửa văng theo hướng ngẫu nhiên, xa gần khác nhau.
		var count := 6 + randi() % 5
		for i in range(count):
			var a := randf() * TAU
			_sparks.append({
				"dir": Vector2(cos(a), sin(a) * 0.55),  # dẹt y → cảm giác sàn iso
				"speed": randf_range(120.0, 260.0) * strength,
				"len": randf_range(6.0, 13.0),
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life        # 0→1
		var fade := 1.0 - t

		# 1. Vòng sóng xung kích nở ra trên "sàn" (ellipse dẹt — đúng phối cảnh iso).
		var ring_r := 10.0 + 42.0 * (1.0 - pow(1.0 - t, 2.0)) * strength
		var ring_col := Color(color.r, color.g, color.b, 0.55 * fade)
		var pts := PackedVector2Array()
		for i in range(20):
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a) * ring_r, sin(a) * ring_r * 0.5))
		for i in range(20):
			draw_line(pts[i], pts[(i + 1) % 20], ring_col, 2.5, true)

		# 2. Chớp lõi trắng giữa điểm trúng.
		draw_circle(Vector2.ZERO, (5.0 + 3.0 * strength) * (1.0 - t * 0.6),
			Color(1, 1, 1, 0.85 * fade))

		# 3. Tia lửa văng — đuôi mờ dần theo vận tốc.
		for sp in _sparks:
			var d: Vector2 = sp["dir"]
			var sp2 := clampf(t * 1.6, 0.0, 1.0)
			var travel: float = float(sp["speed"]) * pow(sp2, 1.4) * 0.12
			var p1: Vector2 = d * travel
			var p2: Vector2 = d * travel * (1.0 + float(sp["len"]) / 20.0)
			var s_col := Color(color.r, color.g, color.b, 0.9 * fade)
			draw_line(p1, p2, s_col, 2.0)
			# Hạt đầu tia lửa — chấm sáng nhỏ.
			draw_circle(p2, 1.6, Color(1, 1, 1, 0.8 * fade))

# ------------------------------------------------------------------- Cột Lửa
## Cột lửa phun lên từ sàn cho vùng cháy (Tường Lửa, Diêm Vực...).
static func fire_eruption(parent: Node, pos: Vector2, radius: float = 46.0) -> Node2D:
	if parent == null:
		return null
	_load_kenney()
	var node := FireEruptionNode.new()
	node.position = pos
	node.radius = radius
	parent.add_child(node)
	return node


class SpriteHitImpactNode extends Node2D:
	## Đòn trúng dùng sprite Kenney: chớp sáng + vòng xung kích + tia lửa xoay.
	## Đây là phiên bản "thật" hơn HitImpactNode vector — chỉ bật khi có sprite.
	## Tự nhận dạng theme theo màu sắc đòn đánh (điện/băng/độc/bóng/lửa).
	var color := Color.WHITE
	var strength := 1.0
	var life := 0.34
	var max_life := 0.34
	var _particles: Array[Dictionary] = []
	# Theme: lightning nếu blue/cyan đậm, frost nếu lạnh cyan-lam, poison nếu
	# xanh lục, shadow nếu tím, fire là phần còn lại.
	var theme := ""

	func _ready() -> void:
		z_index = 8
		# Tự phân loại theme từ màu đòn đánh nếu caller không truyền.
		if theme == "":
			if color.b >= 0.7 and color.b >= color.r * 1.1 and color.g >= 0.45:
				if color.r < 0.45 and color.g > 0.6:
					theme = "frost"
				else:
					theme = "lightning"
			elif color.g >= 0.5 and color.r < 0.5 and color.b < 0.5:
				theme = "poison"
			elif color.r >= 0.4 and color.b >= 0.5 and color.g < 0.4:
				theme = "shadow"
			else:
				theme = "fire"
		for i in range(8):
			_particles.append({
				"dir": Vector2.RIGHT.rotated(randf() * TAU) * Vector2(1.0, 0.55),
				"speed": randf_range(180.0, 320.0) * strength,
				"rot_speed": randf_range(-12.0, 12.0),
				"rot": randf() * TAU,
				"scale": randf_range(0.7, 1.2) * strength,
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life
		var fade := 1.0 - t
		var light_tex := VFXLibrary.k_light
		var spark_tex := VFXLibrary.k_spark
		# 1. Chớp sáng trung tâm (light sprite thu nhỏ).
		if light_tex != null:
			var burst := 22.0 * (1.0 - t * 0.55) * strength
			var col := Color(1.0, 1.0, 1.0, 0.9 * fade)
			draw_texture_rect(light_tex,
				Rect2(-Vector2(burst, burst), Vector2(burst * 2.0, burst * 2.0)),
				false, col)
		# 2. Vòng xung kích ellipse iso (vẫn vector, nhẹ và chuẩn phối cảnh).
		var ring := 10.0 + 42.0 * (1.0 - pow(1.0 - t, 2.0)) * strength
		var pts := PackedVector2Array()
		for i in range(20):
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a) * ring, sin(a) * ring * 0.5))
		for i in range(20):
			draw_line(pts[i], pts[(i + 1) % 20],
				Color(color.r, color.g, color.b, 0.55 * fade), 2.5, true)
		# 3. Tia lửa bay ra — sprite spark có xoay để có cảm giác chuyển động 3D.
		if spark_tex != null:
			for p in _particles:
				var d: Vector2 = p["dir"]
				var travel: float = float(p["speed"]) * pow(t, 1.4) * 0.18
				var pos: Vector2 = d * travel
				var s: float = float(p["scale"]) * (1.0 - t * 0.3) * 24.0
				var rot: float = float(p["rot"]) + float(p["rot_speed"]) * t
				draw_set_transform(pos, rot, Vector2.ONE)
				draw_texture_rect(spark_tex,
					Rect2(-Vector2(s, s), Vector2(s * 2.0, s * 2.0)),
					false, Color(color.r, color.g, color.b, 0.95 * fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 4. Lớp nhấn theo theme — phân biệt "đây là hero nào" khi nhìn VFX.
		match theme:
			"lightning":
				# Tia chớp điện ngoằn ngoèo xuất phát từ tâm, hồi quy ngẫu nhiên mỗi
				# khung (jitter) → cảm giác tia chớp thật, không phải nét vẽ tĩnh.
				for i in range(3):
					var a := randf() * TAU
					var l := 30.0 + randf() * 26.0
					var pts2 := PackedVector2Array()
					var segs := 5
					for k in range(segs + 1):
						var tt := float(k) / float(segs)
						var dist := l * tt
						var jag := Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
						pts2.append(Vector2(cos(a), sin(a) * 0.5) * dist + jag)
					for k in range(segs):
						draw_line(pts2[k], pts2[k + 1],
							Color(1.0, 1.0, 1.0, 0.85 * fade), 2.0)
			"frost":
				# Vòng trắng đông đá mở rộng — sprite circle Kenney tô xanh nhạt.
				if VFXLibrary.k_circle != null:
					var cr := 36.0 * (0.5 + 0.5 * t) * strength
					draw_texture_rect(VFXLibrary.k_circle,
						Rect2(-Vector2(cr, cr), Vector2(cr * 2.0, cr * 2.0)),
						false, Color(0.75, 0.92, 1.0, 0.55 * fade))
			"poison":
				if VFXLibrary.k_circle != null:
					var cr := 38.0 * (0.4 + 0.6 * t) * strength
					draw_texture_rect(VFXLibrary.k_circle,
						Rect2(-Vector2(cr, cr), Vector2(cr * 2.0, cr * 2.0)),
						false, Color(0.4, 1.0, 0.45, 0.55 * fade))
			"shadow":
				if VFXLibrary.k_circle != null:
					var cr := 32.0 * (0.5 + 0.5 * t) * strength
					draw_texture_rect(VFXLibrary.k_circle,
						Rect2(-Vector2(cr, cr), Vector2(cr * 2.0, cr * 2.0)),
						false, Color(0.4, 0.15, 0.55, 0.55 * fade))

class FireEruptionNode extends Node2D:
	var radius := 46.0
	var life := 0.7
	var max_life := 0.7
	var _tongues: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 7
		for i in range(7):
			_tongues.append({
				"ox": randf_range(-radius * 0.7, radius * 0.7),
				"h": randf_range(60.0, 105.0),
				"w": randf_range(10.0, 18.0),
				"delay": randf_range(0.0, 0.10),
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed := max_life - life
		var fade := clampf(life / 0.25, 0.0, 1.0)
		var grow := clampf(elapsed / 0.12, 0.0, 1.0)

		# Vệt cháy dưới sàn.
		var pts := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * radius * 0.8, sin(a) * radius * 0.4))
		draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.28 * fade))

		# Lớp sprite flame Kenney (nếu đã import) — chớp sáng lửa lớn ngay tâm,
		# giúp hiệu ứng có "chất" hơn là chỉ vector đơn thuần.
		if VFXLibrary.k_flame != null:
			var fl := VFXLibrary.k_flame
			var flame_size := radius * 2.0 * grow
			draw_texture_rect(fl,
				Rect2(Vector2(-flame_size * 0.5, -flame_size * 0.5),
					Vector2(flame_size, flame_size)),
				false, Color(1.0, 1.0, 1.0, 0.65 * fade))

		# Các lưỡi lửa: thân cam + lõi vàng, nhấp nháy theo thời gian.
		for tg in _tongues:
			if elapsed < tg["delay"]:
				continue
			var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.03 + tg["ox"])
			var h: float = tg["h"] * grow * flick
			var w: float = tg["w"]
			var x: float = tg["ox"]
			var base := Vector2(x, 0)
			var tip := Vector2(x + randf_range(-4, 4), -h)
			# Thân lửa (tam giác cam đỏ).
			draw_colored_polygon(PackedVector2Array([
				tip,
				base + Vector2(-w, 0),
				base + Vector2(w, 0),
			]), Color(1.0, 0.42, 0.12, 0.85 * fade))
			# Lõi vàng sáng hơn, hẹp hơn.
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(0, h * 0.15),
				base + Vector2(-w * 0.45, 0),
				base + Vector2(w * 0.45, 0),
			]), Color(1.0, 0.85, 0.3, 0.95 * fade))
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(0, h * 0.15),
				base + Vector2(-w * 0.45, 0),
				base + Vector2(w * 0.45, 0),
			]), Color(1.0, 0.85, 0.3, 0.95 * fade))

# ------------------------------------------------------------- Nổ Phép Thuật
## Bùng nổ tinh thể phép thuật — mảnh vỡ bay + vòng ấn chú nở ra.
## Dùng cho các chiêu kích nổ (Sụp Đổ của Arcane Weaver, nổ stack...).
static func arcane_burst(parent: Node, pos: Vector2, color: Color,
		radius: float = 80.0) -> Node2D:
	if parent == null:
		return null
	var node := ArcaneBurstNode.new()
	node.position = pos
	node.color = color
	node.radius = radius
	parent.add_child(node)
	return node

class ArcaneBurstNode extends Node2D:
	var color := Color(0.55, 0.4, 1.0)
	var radius := 80.0
	var life := 0.6
	var max_life := 0.6
	var _shards: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 6
		for i in range(8):
			var a := TAU * float(i) / 8.0 + randf_range(-0.2, 0.2)
			_shards.append({
				"dir": Vector2(cos(a), sin(a) * 0.5),
				"dist": radius * randf_range(0.45, 0.95),
				"size": randf_range(5.0, 10.0),
			})

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life
		var fade := 1.0 - t

		# Vòng ấn chú nở ra + xoay — cảm giác ma thuật lan tỏa trên sàn.
		var rot := t * 1.8
		for ring_v: float in [0.45, 0.7, 1.0]:
			var r: float = radius * ring_v * (0.3 + 0.7 * (1.0 - pow(1.0 - t, 2.0)))
			var pts := PackedVector2Array()
			for i in range(24):
				var a := TAU * float(i) / 24.0 + rot * (1.0 if ring_v != 0.7 else -1.0)
				pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
			for i in range(24):
				draw_line(pts[i], pts[(i + 1) % 24],
					Color(color.r, color.g, color.b, 0.6 * fade), 2.0, true)

		# Quầng giữa.
		draw_circle(Vector2.ZERO, radius * 0.22 * (1.0 - t * 0.5),
			Color(color.r, color.g, color.b, 0.5 * fade))
		draw_circle(Vector2.ZERO, radius * 0.10,
			Color(1, 1, 1, 0.9 * fade))

		# Mảnh tinh thể bay ra (kim cương nhỏ xoay).
		for sd in _shards:
			var p: Vector2 = sd["dir"] * sd["dist"] * (1.0 - pow(1.0 - t, 2.2))
			var s: float = sd["size"] * fade
			var diamond := PackedVector2Array([
				p + Vector2(0, -s), p + Vector2(s * 0.6, 0),
				p + Vector2(0, s), p + Vector2(-s * 0.6, 0),
			])
			draw_colored_polygon(diamond, Color(color.r, color.g, color.b, 0.9 * fade))
			draw_line(diamond[0], diamond[2], Color(1, 1, 1, 0.7 * fade), 1.0)

# ------------------------------------------------------------- Vệt Chém Cận Chiến
## Vệt chém hình liềm khi đánh thường cận chiến trúng mục tiêu.
static func slash_arc(parent: Node, pos: Vector2, color: Color,
		facing := 1.0) -> Node2D:
	if parent == null:
		return null
	var node := SlashArcNode.new()
	node.position = pos
	node.color = color
	node.facing = facing
	parent.add_child(node)
	return node

class SlashArcNode extends Node2D:
	var color := Color(1, 1, 1)
	var facing := 1.0
	var life := 0.18
	var max_life := 0.18

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var t := 1.0 - life / max_life        # 0→1 theo đời
		var fade := 1.0 - t
		# Vệt chém quét ngang: cung liềm nở ra rồi mờ đi trong ~0.18s.
		var sweep := TAU * 0.55 * t * facing
		var r_out := 34.0
		var r_in := 22.0
		var blade := PackedVector2Array()
		var steps := 14
		for i in range(steps + 1):
			var a := -TAU * 0.28 * facing + sweep * float(i) / float(steps)
			blade.append(Vector2(cos(a) * r_out, sin(a) * r_out * 0.7 - 22.0))
		for i in range(steps + 1):
			var j := steps - i
			var a := -TAU * 0.28 * facing + sweep * float(j) / float(steps)
			blade.append(Vector2(cos(a) * r_in, sin(a) * r_in * 0.7 - 22.0))
		draw_colored_polygon(blade,
			Color(color.r, color.g, color.b, 0.75 * fade))
		# Cạnh lưỡi sáng trắng.
		for i in range(steps):
			draw_line(blade[i], blade[i + 1], Color(1, 1, 1, 0.9 * fade), 1.5)

# ------------------------------------------------------------- Tàn Ảnh Lướt Sát Thủ
static func shadow_dash_trail(parent: Node, start_pos: Vector2, end_pos: Vector2) -> Node2D:
	if parent == null:
		return null
	var node := ShadowDashTrailNode.new()
	node.start_pos = start_pos
	node.end_pos = end_pos
	parent.add_child(node)
	return node

class ShadowDashTrailNode extends Node2D:
	var start_pos := Vector2.ZERO
	var end_pos := Vector2.ZERO
	var life: float = 0.55
	var max_life: float = 0.55

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var count := 4
		for i in range(count):
			var t := float(i + 1) / float(count + 1)
			var pos := start_pos.lerp(end_pos, t)
			var ghost_alpha := alpha * (1.0 - t * 0.4)

			# Bóng đen khói hư không
			draw_circle(pos + Vector2(0, -20), 16.0, Color(0.12, 0.04, 0.20, 0.5 * ghost_alpha))
			draw_circle(pos + Vector2(0, -20), 10.0, Color(0.35, 0.12, 0.55, 0.6 * ghost_alpha))

			# Vệt dao sáng xanh dạ quang lướt qua
			var offset_knife := Vector2(randf_range(-12, 12), randf_range(-25, -15))
			draw_line(pos + offset_knife, pos + offset_knife + (end_pos - start_pos).normalized() * 16.0,
				Color(0.2, 0.95, 0.85, 0.85 * ghost_alpha), 2.0)

class ShockRingNode extends Node2D:
	## Vòng sóng xung kích: một vành nở ra rồi tan — lớp VFX rẻ tiền nhưng
	## cực kỳ hiệu quả để "đo" tầm của đòn đánh bằng mắt.
	var radius := 60.0
	var color := Color.WHITE
	var duration := 0.35
	var _t := 0.0

	func _ready() -> void:
		z_index = 18

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / duration, 0.0, 1.0)
		var r := radius * (0.25 + 0.75 * ease_out(k))
		var a := (1.0 - k) * color.a
		var pts := PackedVector2Array()
		var segs := 40
		for i in range(segs):
			var ang := TAU * float(i) / float(segs)
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.62))
		draw_colored_polygon(pts, Color(0, 0, 0, 0))
		for i in range(segs):
			draw_line(pts[i], pts[(i + 1) % segs], Color(color.r, color.g, color.b, a), 3.0 * (1.0 - k) + 1.0, true)
		# Vòng sáng thứ hai mảnh hơn, trễ pha — tạo cảm giác "sóng kép".
		var r2 := r * 0.7
		var pts2 := PackedVector2Array()
		for i in range(segs):
			var ang := TAU * float(i) / float(segs)
			pts2.append(Vector2(cos(ang) * r2, sin(ang) * r2 * 0.62))
		for i in range(segs):
			draw_line(pts2[i], pts2[(i + 1) % segs], Color(1, 1, 1, a * 0.5), 1.6, true)

	func ease_out(t: float) -> float:
		return 1.0 - pow(1.0 - t, 3.0)
