class_name ChampionPedestal
extends Control
## Bệ đá trưng bày tướng 2.5D Isometric với vòng rune nguyên tố xoay tròn.

var champion_id: StringName = &"fire_mage"
var _champ: Champion = null
var _t: float = 0.0
var _pedestal_texture: Texture2D = null

## Bảng hạt phát sáng lơ lửng quanh bệ
var _particles: Array[Dictionary] = []
const MAX_PARTICLES := 24

func _ready() -> void:
	custom_minimum_size = Vector2(240, 290)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_init_particles()
	_pedestal_texture = ArtLibrary.ui_texture("pedestal")
	_update_champion()

func _init_particles() -> void:
	_particles.clear()
	for i in range(MAX_PARTICLES):
		_particles.append({
			"pos": Vector2(randf_range(-60, 60), randf_range(-10, 40)),
			"vel": Vector2(randf_range(-8, 8), randf_range(-30, -65)),
			"life": randf_range(0.2, 1.0),
			"max_life": randf_range(0.8, 1.8),
			"size": randf_range(2.0, 4.5)
		})

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
	_champ.name = "PedestalChamp"
	_champ.configure(champion_id, 1, true)
	# Tắt va chạm vật lý để không tương tác với bất kỳ gì trong UI
	_champ.collision_layer = 0
	_champ.collision_mask = 0
	_champ.position = Vector2(size.x * 0.5, size.y * 0.72)
	add_child(_champ)

func _process(delta: float) -> void:
	_t += delta
	if _champ != null:
		_champ.position = Vector2(size.x * 0.5, size.y * 0.72)
		_champ._anim_time += delta
		# Hướng nhìn xéo nhẹ sang trái theo phong cách chọn tướng 2.5D
		_champ.aim_dir = Vector2(-0.8, 0.4).normalized()

	# Cập nhật hạt bụi nguyên tố
	for p in _particles:
		p["life"] = float(p["life"]) - delta
		var pos_v: Vector2 = p["pos"]
		var vel_v: Vector2 = p["vel"]
		p["pos"] = pos_v + vel_v * delta
		if float(p["life"]) <= 0.0:
			p["life"] = p["max_life"]
			p["pos"] = Vector2(randf_range(-70, 70), randf_range(5, 30))
			p["vel"] = Vector2(randf_range(-10, 10), randf_range(-35, -75))

	queue_redraw()

func _draw() -> void:
	var col := GameData.champion_color(champion_id)
	var center := Vector2(size.x * 0.5, size.y * 0.74)

	# 1. Quầng sáng hắt từ dưới chân bệ đá
	var pulse := 0.25 + 0.08 * sin(_t * 2.5)
	_draw_ellipse(center + Vector2(0, 15), 110, 36, Color(col.r, col.g, col.b, pulse * 0.5))
	_draw_ellipse(center + Vector2(0, 15), 85, 26, Color(col.r, col.g, col.b, pulse))

	# 3. Tầng đáy bệ đá (Dark Stone Base)
	_draw_cylinder(center + Vector2(0, 24), 92, 32, 16, Color(0.12, 0.11, 0.15), Color(0.08, 0.07, 0.10))

	# 4. Tầng thân bệ đá chạm khắc hoa văn (Carved Middle Tier)
	_draw_cylinder(center + Vector2(0, 10), 80, 27, 14, Color(0.18, 0.17, 0.22), Color(0.13, 0.12, 0.16))

	# Các rãnh ma thuật trên thân bệ
	var rim_pts := 16
	for i in range(rim_pts):
		var a := _t * 0.5 + float(i) * TAU / float(rim_pts)
		var x := cos(a) * 78.0
		var y := sin(a) * 26.0
		if sin(a) > 0.1: # Chỉ vẽ mặt trước
			var rune_alpha := 0.4 + 0.4 * sin(_t * 4.0 + float(i))
			draw_line(center + Vector2(x, 10 + y), center + Vector2(x, 22 + y), Color(col.r, col.g, col.b, rune_alpha), 2.0)

	# 4. Mặt bệ đá trên cùng (Top Platform)
	_draw_ellipse(center, 74, 25, Color(0.24, 0.23, 0.28))
	_draw_ellipse_rim(center, 74, 25, Color(col.r, col.g, col.b, 0.8), 2.2)

	# 5. Vòng tròn ma pháp xoay trên mặt bệ (Rotating Runic Magic Disc)
	var rot := _t * 0.6
	_draw_rune_circle(center, 62, 21, rot, col)

	# 6. Huy hiệu nguyên tố phía trước bệ đá (Front Medallion Crest)
	_draw_front_crest(center + Vector2(0, 28), col)

	# 7. Lớp art PNG tùy chọn phủ lên thân bệ đã vẽ vector.
	# Ảnh được giới hạn trong vùng bệ để không che champion preview.
	if _pedestal_texture != null:
		var tex_size := _pedestal_texture.get_size()
		if tex_size.x > 1.0 and tex_size.y > 1.0:
			var target := Vector2(184.0, 86.0)
			var tex_scale := minf(target.x / tex_size.x, target.y / tex_size.y)
			var draw_size := tex_size * tex_scale
			var tex_rect := Rect2(center + Vector2(-draw_size.x * 0.5, 10.0 - draw_size.y * 0.5), draw_size)
			draw_texture_rect(_pedestal_texture, tex_rect, false, Color(1, 1, 1, 0.9))

	# 8. Hạt năng lượng nguyên tố bay lơ lửng
	for p in _particles:
		var life_f: float = float(p["life"])
		var max_life_f: float = float(p["max_life"])
		var alpha: float = clampf(life_f / max_life_f, 0.0, 1.0)
		var p_offset: Vector2 = p["pos"]
		var ppos: Vector2 = center + p_offset
		var p_size: float = float(p["size"])
		draw_circle(ppos, p_size * (0.6 + 0.4 * alpha), Color(col.r, col.g, col.b, alpha * 0.75))

func _draw_ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var segs := 36
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

func _draw_ellipse_rim(c: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var segs := 36
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	for i in range(segs):
		draw_line(pts[i], pts[(i + 1) % segs], color, width, true)

func _draw_cylinder(c: Vector2, rx: float, ry: float, height: float, top_col: Color, side_col: Color) -> void:
	var segs := 32
	var side_pts := PackedVector2Array()
	# Nửa dưới của ellipse trước
	for i in range(segs / 2 + 1):
		var a := PI * float(i) / float(segs / 2)
		side_pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	# Kéo xuống
	for i in range(segs / 2, -1, -1):
		var a := PI * float(i) / float(segs / 2)
		side_pts.append(c + Vector2(cos(a) * rx, sin(a) * ry + height))
	draw_colored_polygon(side_pts, side_col)
	_draw_ellipse(c, rx, ry, top_col)

func _draw_rune_circle(c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	_draw_ellipse_rim(c, rx * 0.85, ry * 0.85, Color(col.r, col.g, col.b, 0.45), 1.4)
	# Các vạch rune quay
	var runes := 8
	for i in range(runes):
		var a := rot + float(i) * TAU / float(runes)
		var p1 := c + Vector2(cos(a) * rx * 0.45, sin(a) * ry * 0.45)
		var p2 := c + Vector2(cos(a) * rx * 0.85, sin(a) * ry * 0.85)
		draw_line(p1, p2, Color(col.r, col.g, col.b, 0.65), 1.5, true)

func _draw_front_crest(c: Vector2, col: Color) -> void:
	# Khung huy hiệu tròn
	_draw_ellipse(c, 16, 12, Color(0.08, 0.08, 0.12))
	_draw_ellipse_rim(c, 16, 12, Color(col.r, col.g, col.b, 0.9), 1.8)
	# Biểu tượng năng lượng
	draw_circle(c, 5.0, Color(col.r, col.g, col.b, 0.9))
