class_name VFXLibrary
extends RefCounted
## Thư viện hiệu ứng hình ảnh 2.5D Isometric (VFX & Shaders) cho các trận chiến.

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
	var node := HitImpactNode.new()
	node.position = pos
	node.color = color
	node.strength = clampf(strength, 0.5, 1.6)
	parent.add_child(node)
	return node

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
	var node := FireEruptionNode.new()
	node.position = pos
	node.radius = radius
	parent.add_child(node)
	return node

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
