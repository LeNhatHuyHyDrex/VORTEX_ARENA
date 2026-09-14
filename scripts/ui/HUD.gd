class_name HUD
extends Control
## Giao diện trong trận: thanh máu/năng lượng, dải kỹ năng bo góc, chip trạng
## thái, minimap, bảng điều khiển phòng luyện tập, và chỉ báo mức zoom.
##
## Vẽ toàn bộ bằng `_draw()` để kiểm soát hoàn toàn bố cục và giữ mọi thứ trong
## một chỗ, thay vì rải hàng chục node con. Đổi lại, phần bấm chuột phải tự
## tính vùng — xem `_practice_rects`.

var game: Game = null

const MARGIN := 26.0
const PANEL_W := 380.0
const HP_H := 22.0
const MANA_H := 11.0
const ICON := 64.0
const ICON_GAP := 12.0
## Bo góc ô kỹ năng. Đây là con số quyết định "chất" của dải kỹ năng — bo ít quá
## thì vẫn ra hình vuông, bo nhiều quá thì thành viên thuốc và mất chỗ viết chữ.
const ICON_RADIUS := 18.0

const MINIMAP_SIZE := Vector2(186.0, 126.0)
const MINIMAP_MARGIN := 22.0

## Vùng bấm của từng mục trong bảng luyện tập, tính lại mỗi lần vẽ.
var _practice_rects: Array[Rect2] = []
var _practice_buttons: Array[Rect2] = []
## Vùng bấm của nút tạm dừng ở góc trên phải.
var _pause_rect := Rect2()
var _skill_slot_texture: Texture2D = null

## Hiệu ứng flash màn hình khi bị đánh — độ sáng (0-1) và hướng màu.
var _damage_flash := 0.0
var _shield_flash := 0.0

## Bộ đếm combo: số đòn trúng liên tiếp vào đối thủ.
var _combo_count := 0
var _combo_timer := 0.0
const COMBO_DECAY := 3.0  # giây không trúng thì reset
const COMBO_MAX_DISPLAY := 99

## Thanh máu mượt: giá trị hiển thị lerp dần về giá trị thực.
var _display_hp := 0.0
var _display_enemy_hp := 0.0
const HP_LERP_SPEED := 6.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PASS chứ không IGNORE: bảng luyện tập cần nhận cú bấm, nhưng phần còn lại
	# của HUD thì phải để sự kiện đi qua cho game xử lý.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_skill_slot_texture = ArtLibrary.ui_texture("skill_slot")

func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	_shield_flash = maxf(0.0, _shield_flash - delta * 5.0)
	if _combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_count = 0
	# Lerp thanh máu về giá trị thực.
	if game.local_champ != null:
		_display_hp = lerpf(_display_hp, game.local_champ.hp, HP_LERP_SPEED * delta)
	if game.enemy_champ != null:
		_display_enemy_hp = lerpf(_display_enemy_hp, game.enemy_champ.hp, HP_LERP_SPEED * delta)
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	_draw_player_panel(game.local_champ, Vector2(MARGIN, MARGIN), false)
	_draw_player_panel(game.enemy_champ, Vector2(size.x - MARGIN - PANEL_W, MARGIN), true)
	_draw_score()
	_draw_map_name()
	_draw_minimap()
	_draw_pause_button()
	_draw_zoom_meter()
	_draw_skill_bar()
	_draw_armed_skill_panel()
	_draw_center_message()
	_draw_combo()
	_draw_match_timer()
	_draw_hints()
	if game.is_practice():
		_draw_practice_panel()
	_draw_damage_flash()

## Vignette đỏ/trắng khi bị đánh — làm đòn trúng "đau" hơn hẳn.
func _draw_damage_flash() -> void:
	if _damage_flash <= 0.001 and _shield_flash <= 0.001:
		return
	var w := size.x
	var h := size.y
	if _damage_flash > 0.001:
		_round_rect(Rect2(0, 0, w, h), 0.0, Color(0.95, 0.15, 0.08, _damage_flash * 0.32))
	if _shield_flash > 0.001:
		_round_rect(Rect2(0, 0, w, h), 0.0, Color(0.2, 0.85, 0.95, _shield_flash * 0.25))

## Kích hoạt flash khi tướng bị đánh. Nối với signal `damaged` của tướng.
func _on_local_damaged(amount: float, _source: int) -> void:
	if amount <= 0.0:
		return
	_damage_flash = clampf(amount / 22.0, 0.22, 0.9)

func _on_local_shield_broken() -> void:
	_shield_flash = 0.7

## Được gọi từ Game khi đối thủ nhận sát thương từ ngườ chơi.
func register_hit() -> void:
	_combo_count = mini(_combo_count + 1, COMBO_MAX_DISPLAY)
	_combo_timer = COMBO_DECAY

func get_combo() -> int:
	return _combo_count

func _draw_combo() -> void:
	if _combo_count < 2:
		return
	var txt := "%dx COMBO" % _combo_count
	var sz := 22 if _combo_count < 5 else 26
	var col := Color(1, 0.92, 0.65, 0.9) if _combo_count < 5 else Color(1, 0.55, 0.25, 0.95)
	# Hiệu ứng nhấp nháy nhẹ khi combo cao.
	if _combo_count >= 8:
		var pulse := 0.9 + sin(Time.get_ticks_msec() * 0.01) * 0.1
		col.a *= pulse
	var y := size.y * 0.58
	draw_string(ThemeDB.fallback_font, Vector2(0, y), txt,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, col)

func _draw_match_timer() -> void:
	if game.is_practice():
		return
	var t := game._match_timer
	var mins := int(t) / 60
	var secs := int(t) % 60
	var txt := "%02d:%02d" % [mins, secs]
	var y := size.y - MARGIN - 12.0
	draw_string(ThemeDB.fallback_font, Vector2(0, y), txt,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.4))

# ------------------------------------------------------------ nút tạm dừng

## Nút pause ở góc trên phải.
##
## Trên điện thoại không có phím ESC nên đây là đường duy nhất để ra khỏi trận.
## Trên PC nó vẫn hữu ích vì bấm được bằng chuột mà không phải nhớ phím.
func _draw_pause_button() -> void:
	var s := 38.0
	# Đặt ngay dưới bảng máu đối thủ (panel cao 120px), ngang hàng với minimap
	# ở bên trái. Không đặt ở góc trên cùng vì chỗ đó đã là bảng máu đối thủ.
	_pause_rect = Rect2(size.x - MARGIN - s, MARGIN + 120.0, s, s)
	var hovered := _pause_rect.has_point(get_local_mouse_position())

	_round_rect(_pause_rect, 9.0, Color(0, 0, 0, 0.5 if hovered else 0.34))
	_round_rect(_pause_rect, 9.0,
		Color(1, 1, 1, 0.55 if hovered else 0.28), false, 1.5)

	# Hai vạch dọc = biểu tượng tạm dừng, vẽ bằng hai hình chữ nhật bo góc.
	var c := _pause_rect.get_center()
	var bar_w := 4.5
	var bar_h := 15.0
	_round_rect(Rect2(c.x - 7.0 - bar_w * 0.5, c.y - bar_h * 0.5, bar_w, bar_h),
		1.6, Color(1, 1, 1, 0.9 if hovered else 0.7))
	_round_rect(Rect2(c.x + 7.0 - bar_w * 0.5, c.y - bar_h * 0.5, bar_w, bar_h),
		1.6, Color(1, 1, 1, 0.9 if hovered else 0.7))

# ------------------------------------------------------------------ thanh máu

func _draw_player_panel(c: Champion, origin: Vector2, mirrored: bool) -> void:
	if c == null:
		return
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT

	var crest_s := 48.0
	var gap := 8.0
	var bar_w := PANEL_W - crest_s - gap
	var crest_pos := Vector2(origin.x, origin.y + 12) if not mirrored else Vector2(origin.x + PANEL_W - crest_s, origin.y + 12)
	var bar_origin_x := origin.x + crest_s + gap if not mirrored else origin.x

	# Nền panel kính tối: "tấm khiên" nâng cả cụm huy hiệu + thanh máu khỏi nền
	# sân — đúng chất HUD dark-fantasy (panel sâu, viền mảnh, bóng kính nửa trên).
	var panel := Rect2(origin.x - 8.0, origin.y - 8.0, PANEL_W + 16.0, 120.0)
	_round_rect(panel, 14.0, Color(0.03, 0.04, 0.07, 0.78))
	_glossy_top(Rect2(panel.position + Vector2(2.0, 2.0),
		Vector2(panel.size.x - 4.0, panel.size.y * 0.42)), 12.0,
		Color(0.12, 0.14, 0.20, 0.30))
	_round_rect(panel, 14.0, Color(1, 1, 1, 0.10), false, 1.2)
	# Nét accent màu nguyên tố chạy trên đỉnh panel — nhận diện phe/tướng ngay.
	_round_rect(Rect2(panel.position.x + 10.0, panel.position.y - 1.0,
		panel.size.x - 20.0, 3.0), 2.0,
		Color(c.accent.r, c.accent.g, c.accent.b, 0.65))

	# Vẽ huy hiệu đại diện tướng chuẩn 2.5D Isometric
	_draw_avatar_crest(c, crest_pos)

	# Bóng chữ tên tướng: chữ nổi trên mọi nền, kể cả khi chạy qua vùng sáng.
	draw_string(ThemeDB.fallback_font, Vector2(bar_origin_x, origin.y + 17), c.display_name,
		align, bar_w, 18, Color(0, 0, 0, 0.55))
	draw_string(ThemeDB.fallback_font, Vector2(bar_origin_x, origin.y + 16), c.display_name,
		align, bar_w, 18, Color(0.95, 0.95, 0.98))

	# Thanh máu: dùng giá trị hiển thị đã lerp để nhìn mượt.
	var display_hp := c.hp
	if c == game.local_champ:
		if absf(_display_hp - c.hp) < 0.01:
			_display_hp = c.hp
		display_hp = _display_hp
	elif c == game.enemy_champ:
		if absf(_display_enemy_hp - c.hp) < 0.01:
			_display_enemy_hp = c.hp
		display_hp = _display_enemy_hp
	var hp_rect := Rect2(bar_origin_x, origin.y + 24, bar_w, HP_H)
	_bar(hp_rect, display_hp / maxf(c.max_hp, 1.0), Color("d94a4a"), Color("f07a6a"), mirrored)
	draw_string(ThemeDB.fallback_font, Vector2(bar_origin_x + 8, origin.y + 24 + HP_H - 6),
		"%d / %d" % [int(ceil(c.hp)), int(c.max_hp)], HORIZONTAL_ALIGNMENT_LEFT,
		bar_w - 16, 13, Color(1, 1, 1, 0.95))

	# Khiên: một lớp mỏng phủ lên phần máu, cho thấy còn bao nhiêu khiên.
	if c.shield > 0.0:
		var ratio := clampf(c.shield / maxf(c.max_hp, 1.0), 0.0, 1.0)
		var w := bar_w * ratio
		var sx := bar_origin_x if not mirrored else bar_origin_x + bar_w - w
		draw_rect(Rect2(sx, origin.y + 24, w, HP_H), Color(0.13, 0.83, 0.93, 0.45))

	# Thanh năng lượng
	var mana_rect := Rect2(bar_origin_x, origin.y + 24 + HP_H + 4, bar_w * 0.82, MANA_H)
	_bar(mana_rect, c.mana / maxf(c.max_mana, 1.0), Color("2f7fd9"), Color("5fc8f0"), mirrored)

	# Biểu tượng năng lượng nguyên tố
	var pips_origin := Vector2(bar_origin_x + 6, origin.y + 24 + HP_H + MANA_H + 11) if not mirrored else Vector2(bar_origin_x + bar_w - 6, origin.y + 24 + HP_H + MANA_H + 11)
	_draw_elemental_pips(c, pips_origin, mirrored)

	_draw_status_chips(c, Vector2(bar_origin_x, origin.y + 24 + HP_H + MANA_H + 20), mirrored)

	# Nội tại: chỉ hiện cho tướng của MÌNH, và chỉ khi nó có trạng thái động cần
	# theo dõi (Thiêu Đốt đếm đòn, Vỏ Bọc đếm giây). Nội tại thụ động thuần thì
	# không cần chiếm chỗ trên màn hình.
	if not mirrored and c.passive != null:
		var txt := c.passive.status_text()
		if txt != "":
			var y := origin.y + 24 + HP_H + MANA_H + 46
			draw_string(ThemeDB.fallback_font, Vector2(bar_origin_x, y), txt,
				HORIZONTAL_ALIGNMENT_LEFT, bar_w, 12, Color(0.78, 0.92, 1.0, 0.8))

	# Bất tử (phòng luyện tập): ghi rõ để không tưởng nhầm là mình đang giỏi.
	if c.invincible:
		var label := "BẤT TỬ"
		var w := 64.0
		var x := origin.x if not mirrored else origin.x + PANEL_W - w
		var r := Rect2(x, origin.y - 20, w, 17)
		_round_rect(r, 4.0, Color(0.98, 0.75, 0.14, 0.22))
		_round_rect(r, 4.0, Color(0.98, 0.75, 0.14, 0.9), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + 13),
			label, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(0.99, 0.85, 0.35))

func _draw_avatar_crest(c: Champion, pos: Vector2) -> void:
	var s := 48.0
	var r := Rect2(pos, Vector2(s, s))
	var col := c.accent
	# Bóng đổ lệch xuống: tách huy hiệu khỏi panel phía sau, cảm giác nổi 2.5D.
	_round_rect(Rect2(pos + Vector2(0, 3), Vector2(s, s)), 8.0, Color(0, 0, 0, 0.5))
	# Nền tối kim loại + bóng kính nửa trên (ánh sáng rọi từ trên xuống).
	_round_rect(r, 8.0, Color(0.07, 0.07, 0.11, 0.97))
	_glossy_top(Rect2(pos + Vector2(2, 2), Vector2(s - 4, s * 0.42)), 6.0,
		Color(0.16, 0.18, 0.26, 0.55))
	# Khung viền nguyên tố
	_round_rect(r, 8.0, Color(col.r, col.g, col.b, 0.85), false, 2.0)
	# Góc trang trí kim loại: cặp trên SÁNG, cặp dưới mờ — vát ánh sáng nhất quán.
	draw_line(pos + Vector2(2, 6), pos + Vector2(6, 2), Color(1, 1, 1, 0.85), 1.5)
	draw_line(pos + Vector2(s - 2, 6), pos + Vector2(s - 6, 2), Color(1, 1, 1, 0.85), 1.5)
	draw_line(pos + Vector2(2, s - 6), pos + Vector2(6, s - 2), Color(1, 1, 1, 0.25), 1.2)
	draw_line(pos + Vector2(s - 2, s - 6), pos + Vector2(s - 6, s - 2), Color(1, 1, 1, 0.25), 1.2)

	# Biểu tượng năng lượng: quầng phát nhịp quanh hạt lõi sáng.
	var icon_c := pos + Vector2(s * 0.5, s * 0.5)
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
	draw_circle(icon_c, 14.0, Color(col.r, col.g, col.b, 0.25 * pulse))
	draw_circle(icon_c, 9.0, Color(col.r, col.g, col.b, 0.75))
	draw_circle(icon_c, 4.0, Color(1, 1, 1, 0.95))

func _draw_elemental_pips(c: Champion, pos: Vector2, mirrored: bool) -> void:
	var col := c.accent
	var pips := 4
	for i in range(pips):
		var px := pos.x + (float(i) * 14.0 if not mirrored else -float(i) * 14.0)
		var p_center := Vector2(px, pos.y)
		var diamond := PackedVector2Array([
			p_center + Vector2(0, -4.0),
			p_center + Vector2(4.0, 0),
			p_center + Vector2(0, 4.0),
			p_center + Vector2(-4.0, 0)
		])
		draw_colored_polygon(diamond, Color(col.r, col.g, col.b, 0.75))
		for k in range(4):
			draw_line(diamond[k], diamond[(k + 1) % 4], Color(1, 1, 1, 0.85), 1.0)

## Thanh có nền tối, phần đầy đổ từ trái sang (hoặc phải sang nếu mirrored).
## Bản premium dark-fantasy: khung rãnh lõm vào panel, bóng kính nửa trên,
## vạch chia 20% kiểu MOBA và cạnh tiến phát sáng — thanh đọc như thanh kim
## loại đúc có năng lượng chảy bên trong, thay vì một dải màu phẳng.
func _bar(rect: Rect2, ratio: float, dark: Color, light: Color, mirrored: bool) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	# Khung rãnh: nền đậm hơn panel + nét vát sáng quanh mép = cảm giác lõm vào.
	_round_rect(rect.grow(2.0), 6.0, Color(0, 0, 0, 0.55))
	_round_rect(rect.grow(2.0), 6.0, Color(1, 1, 1, 0.10), false, 1.0)
	_round_rect(rect, 4.0, Color(0.05, 0.05, 0.08, 0.92))
	var w := rect.size.x * ratio
	var fill := Rect2(rect.position, Vector2(w, rect.size.y))
	if mirrored:
		fill.position.x = rect.end.x - w
	if w > 1.0:
		_round_rect(fill, 4.0, dark)
		_glossy_top(fill, 4.0, Color(light.r, light.g, light.b, 0.55))
		# Cạnh tiến của phần đầy: nét trắng mảnh như năng lượng đang đẩy tới.
		var edge_x := fill.end.x if not mirrored else fill.position.x
		draw_line(Vector2(edge_x, rect.position.y + 2.0), Vector2(edge_x, rect.end.y - 2.0),
			Color(1, 1, 1, 0.5), 2.0)
	# Vạch chia mỗi 20% — đọc nhanh "còn bao nhiêu máu" không cần nhìn số.
	for k in range(1, 5):
		var tx := rect.position.x + rect.size.x * (float(k) / 5.0)
		draw_line(Vector2(tx, rect.position.y + 2.0), Vector2(tx, rect.end.y - 2.0),
			Color(0, 0, 0, 0.32), 1.0)
	_round_rect(rect, 4.0, Color(1, 1, 1, 0.16), false, 1.2)

func _draw_status_chips(c: Champion, origin: Vector2, mirrored: bool) -> void:
	var x := origin.x
	if mirrored:
		x = origin.x + PANEL_W
	var y := origin.y
	for id in GameData.STATUS_NAMES.keys():
		var stacks: int = c.get_stacks(id)
		if stacks <= 0:
			continue
		var label := "%s x%d" % [GameData.STATUS_NAMES[id], stacks]
		var col: Color = GameData.STATUS_COLORS.get(id, Color.WHITE)
		var w := 26.0 + float(label.length()) * 8.2
		var rect := Rect2(x if not mirrored else x - w, y, w, 22.0)
		_round_rect(rect, 11.0, Color(col.r, col.g, col.b, 0.22))
		_round_rect(rect, 11.0, Color(col.r, col.g, col.b, 0.85), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 8, rect.position.y + 16),
			label, HORIZONTAL_ALIGNMENT_LEFT, w - 12, 14, col)
		if mirrored:
			x -= w + 6.0
		else:
			x += w + 6.0

# ------------------------------------------------------------------- tỉ số

func _draw_score() -> void:
	if game.is_practice():
		draw_string(ThemeDB.fallback_font, Vector2(0, MARGIN + 26), "PHÒNG LUYỆN TẬP",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.6, 0.85, 1.0, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(0, MARGIN + 46),
			"Nhấn Tab để mở bảng điều khiển", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
			Color(1, 1, 1, 0.42))
		return

	var txt := "%d  —  %d" % [int(game.scores.get(1, 0)), int(game.scores.get(2, 0))]
	draw_string(ThemeDB.fallback_font, Vector2(0, MARGIN + 30), txt,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(0.95, 0.95, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(0, MARGIN + 50),
		"Chạm %d ván để thắng" % Game.ROUNDS_TO_WIN,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 1, 1, 0.45))

func _draw_map_name() -> void:
	if game.arena == null:
		return
	var info: Dictionary = GameData.MAP_INFO.get(game.arena.map_type, {})
	var name_ := str(info.get("name", ""))
	if name_ == "":
		return
	var col: Color = info.get("color", Color.WHITE)
	# Đặt ở góc trên giữa, dưới tỉ số (nếu không phải practice) hoặc ngay dưới margin.
	var y := MARGIN + 68.0 if not game.is_practice() else MARGIN + 56.0
	# Một nền mờ nhỏ để chữ nổi trên mọi nền.
	var tw := 220.0
	var tx := (size.x - tw) * 0.5
	var tr := Rect2(tx, y - 14, tw, 22)
	_round_rect(tr, 6.0, Color(0, 0, 0, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(0, y), name_,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(col.r, col.g, col.b, 0.85))

# ------------------------------------------------------------------ minimap

## Bản đồ nhỏ ở góc trên trái, dưới thanh máu của mình.
##
## Vì sao đặt ở đây chứ không phải góc dưới: hai góc dưới đã thuộc về ngón tay
## cái (cần di chuyển bên trái, cụm kỹ năng bên phải). Góc trên trái là chỗ duy
## nhất không ai chạm tới trong lúc đánh nhau.
func _draw_minimap() -> void:
	if game.arena == null:
		return
	var b: Rect2 = game.arena.bounds
	var origin := Vector2(MINIMAP_MARGIN, MARGIN + 120.0)
	var mm := Rect2(origin, MINIMAP_SIZE)

	_round_rect(mm, 8.0, Color(0.03, 0.03, 0.05, 0.72))
	_round_rect(mm, 8.0, Color(1, 1, 1, 0.16), false, 1.5)

	# Quy đổi từ toạ độ sân sang toạ độ minimap.
	var inner := mm.grow(-5.0)
	var sx := inner.size.x / maxf(b.size.x, 1.0)
	var sy := inner.size.y / maxf(b.size.y, 1.0)
	var to_map := func(world: Vector2) -> Vector2:
		return Vector2(
			inner.position.x + (world.x - b.position.x) * sx,
			inner.position.y + (world.y - b.position.y) * sy)

	# Vật cản
	for o in game.arena.obstacles:
		var p1: Vector2 = to_map.call(o.position)
		var p2: Vector2 = to_map.call(o.end)
		draw_rect(Rect2(p1, p2 - p1), Color(1, 1, 1, 0.14))

	# Tường do kỹ năng tạo (Tường Đá) — vẽ mờ hơn vì nó sẽ biến mất.
	for proj in game.arena.projectiles:
		if is_instance_valid(proj) and proj.blocks_movement and not proj.is_dead():
			var p: Vector2 = to_map.call(proj.position)
			draw_circle(p, 3.0, Color(0.62, 0.58, 0.55, 0.7))

	# Khung nhìn của camera, cho biết đang nhìn vào vùng nào của sân.
	if game.camera != null:
		var half := size * 0.5 / game.camera.zoom
		var cam: Vector2 = game.camera.global_position
		var c1: Vector2 = to_map.call(cam - half)
		var c2: Vector2 = to_map.call(cam + half)
		draw_rect(Rect2(c1, c2 - c1), Color(1, 1, 1, 0.22), false, 1.0)

	# Vùng an toàn Mắt Bão (nếu đang chơi map đó).
	if game.arena.map_type == GameData.MapType.STORM_EYE:
		var sc: Vector2 = to_map.call(game.arena.storm_center)
		var sr := game.arena.storm_radius * sx
		if sr > 2.0:
			draw_arc(sc, sr, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.25), 1.5, true)

	# Đạn đang bay — chấm nhỏ mờ.
	for proj in game.arena.projectiles:
		if is_instance_valid(proj) and not proj.is_dead() and not proj.is_zone \
				and not proj.get_meta("visual_only", false) and proj.speed > 0.0:
			var p: Vector2 = to_map.call(proj.position)
			draw_circle(p, 1.6, Color(proj.accent.r, proj.accent.g, proj.accent.b, 0.55))

	# Tướng. Mình là chấm xanh, đối thủ là chấm đỏ.
	if game.local_champ != null:
		var lp: Vector2 = to_map.call(game.local_champ.global_position)
		_draw_minimap_dot(lp, Color("38bdf8"), game.local_champ.is_alive())
		if game.local_champ.is_alive():
			_draw_minimap_dir(lp, game.local_champ.aim_dir)
	if game.enemy_champ != null:
		var ep: Vector2 = to_map.call(game.enemy_champ.global_position)
		_draw_minimap_dot(ep, Color("ef4444"), game.enemy_champ.is_alive())
		if game.enemy_champ.is_alive():
			_draw_minimap_dir(ep, game.enemy_champ.aim_dir)

func _draw_minimap_dot(pos: Vector2, col: Color, alive: bool) -> void:
	var c := col if alive else Color(0.4, 0.4, 0.45, 0.6)
	draw_circle(pos, 5.0, Color(0, 0, 0, 0.6))
	draw_circle(pos, 4.0, c)
	draw_circle(pos, 1.6, Color(1, 1, 1, 0.85))

## Mũi tên chỉ hướng ngắm trên minimap.
func _draw_minimap_dir(pos: Vector2, dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return
	var tip := pos + dir.normalized() * 6.0
	var perp := Vector2(-dir.y, dir.x).normalized() * 2.2
	draw_colored_polygon(PackedVector2Array([
		tip, pos + perp, pos - perp,
	]), Color(1, 1, 1, 0.65))

# --------------------------------------------------------------- chỉ báo zoom

## Thước zoom ở mép phải. Chỉ là chỉ báo, không bấm được — người chơi cuộn
## chuột hoặc bấm phím +/- để đổi.
func _draw_zoom_meter() -> void:
	var levels := Game.ZOOM_LEVELS.size()
	var h := 14.0
	var gap := 4.0
	var total := float(levels) * h + float(levels - 1) * gap
	var x := size.x - 30.0
	var y := (size.y - total) * 0.5
	var idx := clampi(game.zoom_index, 0, levels - 1)

	for i in range(levels):
		var r := Rect2(x, y + float(i) * (h + gap), 12.0, h)
		var on := i <= idx
		_round_rect(r, 3.0, Color(1, 1, 1, 0.28 if on else 0.10))
		if i == idx:
			_round_rect(r, 3.0, Color("ff9f5a"), false, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(x - 62, y - 10),
		"ZOOM", HORIZONTAL_ALIGNMENT_LEFT, 56, 11, Color(1, 1, 1, 0.4))

# -------------------------------------------------------------- dải kỹ năng

func _draw_skill_bar() -> void:
	var c := game.local_champ
	if c == null:
		return
	# Trên thiết bị cảm ứng, nút bấm đã nằm ở góc dưới phải rồi. Vẽ thêm dải kỹ
	# năng ở giữa là lặp thông tin và chiếm mất chỗ nhìn — nên bỏ hẳn.
	if game.touch != null:
		return
	var labels := InputSetup.skill_key_labels()
	# 4 kỹ năng + 1 ô đánh thường (nằm ngoài cùng, to hơn một chút).
	var atk_w := ICON * 1.1
	var total := ICON * 4.0 + ICON_GAP * 4.0 + atk_w
	var start_x := (size.x - total) * 0.5
	# Chừa thêm một khoảng dưới đáy để dòng tên chiêu không dính mép màn hình.
	var y := size.y - ICON - MARGIN - 16.0
	# Khay đỡ dải kỹ năng: tấm kính tối nằm dưới mọi ô — dải chiêu trông như
	# được gắn INTO khung kim loại thay vì trôi lơ lửng trên nền sân.
	var tray := Rect2(start_x - 16.0, y - 12.0, total + 32.0, ICON + 36.0)
	_round_rect(tray, 24.0, Color(0.03, 0.04, 0.07, 0.72))
	_glossy_top(tray, 24.0, Color(0.12, 0.14, 0.20, 0.25))
	_round_rect(tray, 24.0, Color(1, 1, 1, 0.10), false, 1.2)
	for i in range(c.skills.size()):
		var pos := Vector2(start_x + float(i) * (ICON + ICON_GAP), y)
		var s: SkillBase = c.skills[i]
		var key: String = _shorten(labels[i] if i < labels.size() else s.key_label)
		# Ô đang chờ chọn vùng được viền sáng để biết đang "lên đạn" chiêu nào.
		# Làn nhãn của mỗi ô = bước cách giữa hai ô trừ 4px hít, để nhãn dài
		# nhất cũng không chạm vào nhãn của ô bên cạnh.
		_draw_skill_icon(s, pos, ICON, key, true, game.armed_slot == i,
				ICON + ICON_GAP - 4.0)
	if c.basic_attack != null:
		var bx := start_x + 4.0 * (ICON + ICON_GAP)
		var raw := labels[4] if labels.size() > 4 else "LMB"
		var atk: String = "LMB" if raw.begins_with("Chuột") else _shorten(raw)
		# Ô đánh thường là ô cuối nên nhãn được phép tràn thêm về bên phải.
		_draw_skill_icon(c.basic_attack, Vector2(bx, y), atk_w, atk, false, false,
				atk_w + 14.0)

## Vẽ một ô kỹ năng.
##
## Khác bản cũ ở ba điểm: bo góc thay vì hình vuông, lớp phủ hồi chiêu quét theo
## hình quạt thay vì phủ dọc, và có quầng sáng khi ô đang chờ chọn vùng.
func _draw_skill_icon(s: SkillBase, pos: Vector2, w: float, key_label: String,
		is_skill: bool, armed: bool, name_max_w: float = 0.0) -> void:
	var rect := Rect2(pos, Vector2(w, ICON))
	var col := s.icon_color
	var reason := s.block_reason()
	var ready := reason == ""
	var cd := s.cooldown_ratio()

	# Nền slot raster tùy chọn; nếu thiếu ảnh thì vẫn giữ style vector hiện tại.
	if _skill_slot_texture != null:
		draw_texture_rect(_skill_slot_texture, rect, false, Color(1, 1, 1, 0.88 if ready else 0.62))
	else:
		_round_rect(rect, ICON_RADIUS, Color(0.06, 0.06, 0.09, 0.92))
	_round_rect(rect, ICON_RADIUS, Color(col.r, col.g, col.b, 0.20 if ready else 0.08))
	# Vát ánh sáng: bóng kính nửa trên + nét đổ tối sát đáy — ô đọc như viên
	# kim loại đúc lõm vào khay, ánh sáng rọi từ trên xuống.
	_glossy_top(rect.grow(-2.0), ICON_RADIUS - 2.0, Color(1, 1, 1, 0.07))
	draw_line(Vector2(rect.position.x + 6.0, rect.end.y - 2.5),
		Vector2(rect.end.x - 6.0, rect.end.y - 2.5), Color(0, 0, 0, 0.30), 2.0)
	# Quầng màu quanh ô khi sẵn sàng — chiêu "sống" thì ô cũng phát sáng.
	if ready:
		_round_rect(rect.grow(3.0), ICON_RADIUS + 3.0,
			Color(col.r, col.g, col.b, 0.16), false, 3.0)

	# Biểu tượng: một hình đơn giản đại diện cho loại chiêu, để ô không chỉ có chữ.
	_draw_skill_glyph(rect.get_center(), w * 0.30, col, s.cast_type, ready)

	# Nhãn phím, đặt ở đáy ô.
	draw_string(ThemeDB.fallback_font, Vector2(pos.x, pos.y + ICON - 9),
		key_label, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(1, 1, 1, 0.95 if ready else 0.5))

	# Tên chiêu bên dưới ô. Giới hạn theo "làn nhãn" truyền vào (bề rộng thật
	# giữa hai tâm ô) rồi đo bằng font thật để cắt kèm "…" — nhãn dài kiểu
	# "Đại Nổ Dịch Bệnh" không còn đè lên nhãn ô kế bên. Tên đầy đủ vẫn hiện
	# trong panel tên + mô tả khi lên đạn chiêu, nên không mất thông tin.
	var name_text := "Đánh thường" if not is_skill else s.display_name
	if name_max_w <= 0.0:
		name_max_w = w + 22.0
	name_text = _fit_label(name_text, name_max_w, 11)
	draw_string(ThemeDB.fallback_font,
		Vector2(pos.x - (name_max_w - w) * 0.5, pos.y + ICON + 15),
		name_text, HORIZONTAL_ALIGNMENT_CENTER, name_max_w, 11, Color(1, 1, 1, 0.7))

	# Lớp phủ hồi chiêu: hình quạt tối quét ngược chiều kim đồng hồ, thu dần khi
	# chiêu sẵn sàng. Dễ đọc hơn hẳn kiểu phủ dọc vì mắt bám vào góc quét.
	if cd > 0.001:
		_pie_overlay(rect, cd, Color(0, 0, 0, 0.68))
		if s.cooldown_left > 0.15:
			draw_string(ThemeDB.fallback_font, Vector2(pos.x, pos.y + ICON * 0.58),
				"%.1f" % s.cooldown_left, HORIZONTAL_ALIGNMENT_CENTER, w, 18,
				Color(1, 1, 1, 0.9))

	# Viền: đổi màu theo trạng thái và theo việc ô có đang chờ chọn vùng không.
	var border := Color(col.r, col.g, col.b, 0.95 if ready else 0.35)
	var width := 2.0
	if reason == "Thiếu năng lượng":
		border = Color(0.45, 0.6, 0.9, 0.85)
	if armed:
		# Ô đang chờ: viền trắng đậm + quầng sáng nhấp nháy quanh ô.
		border = Color(1, 1, 1, 0.95)
		width = 3.0
		var pulse := 0.35 + sin(Time.get_ticks_msec() * 0.006) * 0.18
		_round_rect(rect.grow(4.0), ICON_RADIUS + 4.0,
			Color(1, 1, 1, pulse * 0.35), false, 2.0)
	_round_rect(rect, ICON_RADIUS, border, false, width)

## Bảng mô tả chiêu đang "lên đạn": tên + mô tả + cách xác nhận/huỷ.
##
## Bám theo ảnh tham khảo (bảng kỹ năng trong trận): khi người chơi bấm Q/E/R/F,
## họ cần NGAY LẬP TỨC nhớ lại chiêu đó làm gì mà không phải đoán từ hình thu nhỏ.
## Chỉ hiện khi đang armed — lúc khác nhường không gian cho cảnh đấu.
func _draw_armed_skill_panel() -> void:
	if game.touch != null or game.armed_slot == -1:
		return
	var s := game.armed_skill()
	if s == null:
		return

	var font := ThemeDB.fallback_font
	var w := 480.0
	var x := (size.x - w) * 0.5
	var lines: Array = s.description.split("\n")
	var h := 34.0 + float(lines.size()) * 17.0 + 22.0
	# Đặt trên dải kỹ năng (icons nằm ở size.y - ICON - MARGIN - 16).
	var bar_y := size.y - ICON - MARGIN - 16.0
	var y := bar_y - h - 22.0
	var rect := Rect2(x, y, w, h)

	# Nền tối + viền màu chiêu.
	_round_rect(rect, 10.0, Color(0.04, 0.05, 0.09, 0.88))
	_round_rect(rect, 10.0, Color(s.icon_color.r, s.icon_color.g, s.icon_color.b, 0.9),
		false, 1.6)

	# Tên chiêu + nhãn phím.
	var key_hint := "Q/E/R/F"
	draw_string(font, Vector2(x + 14, y + 22), s.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, s.icon_color)
	var key_w := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(x + w - key_w - 14, y + 21), key_hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

	# Mô tả: từng dòng trong description (đã viết gọn 1-2 dòng).
	var ty := y + 42.0
	for line in lines:
		draw_string(font, Vector2(x + 14, ty), str(line),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.78))
		ty += 17.0

	# Dòng hướng dẫn xác nhận/huỷ.
	var guide := "CHUỘT TRÁI: tung chiêu   ·   CHUỘT PHẢI: huỷ"
	draw_string(font, Vector2(x + 14, y + h - 8.0), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 1, 1, 0.5) if game.armed_valid else Color(1.0, 0.6, 0.5, 0.75))

## Biểu tượng nhỏ bên trong ô, gợi ý loại chiêu.
##
## Không vẽ hình riêng cho từng chiêu vì như vậy phải làm 25 hình; thay vào đó
## dùng bốn hình theo LOẠI chiêu, cộng màu của chiêu. Người chơi học được ngay
## "ô có hình tròn = chiêu chọn vùng", "ô có mũi tên = chiêu bắn thẳng".
func _draw_skill_glyph(center: Vector2, r: float, col: Color,
		cast_type: int, ready: bool) -> void:
	var c := Color(col.r, col.g, col.b, 0.95 if ready else 0.4)
	var cy := center.y - 6.0
	var mid := Vector2(center.x, cy)
	match cast_type:
		SkillBase.CastType.GROUND:
			# Vòng tròn có tâm: chiêu đặt xuống đất.
			draw_arc(mid, r, 0.0, TAU, 24, c, 2.2, true)
			draw_circle(mid, r * 0.28, c)
		SkillBase.CastType.SELF:
			# Vòng tròn đồng tâm: chiêu toả quanh người.
			draw_arc(mid, r, 0.0, TAU, 24, c, 2.2, true)
			draw_arc(mid, r * 0.5, 0.0, TAU, 18, c, 2.2, true)
		SkillBase.CastType.INSTANT:
			# Tia chớp: bấm là ra ngay.
			draw_colored_polygon(PackedVector2Array([
				Vector2(center.x - r * 0.3, cy - r),
				Vector2(center.x + r * 0.5, cy - r * 0.15),
				Vector2(center.x + r * 0.1, cy - r * 0.15),
				Vector2(center.x + r * 0.4, cy + r),
				Vector2(center.x - r * 0.5, cy + r * 0.1),
				Vector2(center.x - r * 0.1, cy + r * 0.1),
			]), c)
		_:
			# Mũi tên: chiêu bắn/lướt theo hướng.
			draw_colored_polygon(PackedVector2Array([
				Vector2(center.x + r, cy),
				Vector2(center.x - r * 0.6, cy - r * 0.8),
				Vector2(center.x - r * 0.2, cy),
				Vector2(center.x - r * 0.6, cy + r * 0.8),
			]), c)

## Phủ một hình quạt tối lên ô, biểu diễn hồi chiêu còn lại.
##
## `ratio` = 1 nghĩa là vừa dùng xong (phủ gần kín), 0 là sẵn sàng.
func _pie_overlay(rect: Rect2, ratio: float, color: Color) -> void:
	var center := rect.get_center()
	# Bán kính phải phủ hết cả bốn góc của hình chữ nhật, không chỉ cạnh.
	var r := maxf(rect.size.x, rect.size.y)
	var start := -PI * 0.5
	var end := start + TAU * clampf(ratio, 0.0, 1.0)
	var pts := PackedVector2Array([center])
	var steps := maxi(6, int(48.0 * clampf(ratio, 0.02, 1.0)))
	for i in range(steps + 1):
		var a := start + (end - start) * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)

func _shorten(text: String) -> String:
	# Phiên bản ngắn của nhãn phím để vừa ô ICON hẹp. Lấy nguyên nếu ≤4 ký tự,
	# dài hơn thì giữ 4 ký tự đầu — tránh tràn viền khi người chơi đặt nhãn
	# dài kiểu "Chuột trái".
	if text.length() <= 4:
		return text
	return text.substr(0, 4)

## Cắt nhãn kèm dấu "…" để vừa đúng chiều rộng cho phép, đo bằng font thật thay
## vì đếm ký tự. Nhãn chiêu dài kiểu "Đại Nổ Dịch Bệnh" không còn tràn sang ô
## bên cạnh và đè lên nhãn "Đánh thường". Thông tin đầy đủ vẫn nằm trong panel
## tên + mô tả khi lên đạn chiêu, nên cắt nhãn dưới icon không mất dữ liệu.
func _fit_label(text: String, max_w: float, font_size: int) -> String:
	if text.is_empty():
		return text
	var font := ThemeDB.fallback_font
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
		return text
	var fitted := text
	while fitted.length() > 1:
		fitted = fitted.substr(0, fitted.length() - 1)
		var candidate := fitted + "…"
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
			return candidate
	return fitted

# ------------------------------------------------------------- thông báo giữa

func _draw_center_message() -> void:
	if game.is_practice():
		# Phòng luyện tập không có đếm ngược hay thắng thua, chỉ có thông báo
		# ngắn khi người chơi bấm nút trong bảng điều khiển.
		if game.status_message != "" and game.status_message != "Phòng luyện tập":
			_draw_center_text(game.status_message, Color(1, 0.9, 0.6, 0.85), 26)
		return

	match game.phase:
		Game.Phase.COUNTDOWN:
			var n := int(ceil(game.phase_timer))
			var scale_t := 1.0 - fmod(game.phase_timer, 1.0)
			var sz := 96 + int(scale_t * 22.0)
			# Dải kính tối ngang giữa màn — số đếm ngược "nổi" lên khỏi sân đấu.
			var band := Rect2(0, size.y * 0.28, size.x, size.y * 0.26)
			_round_rect(band, 0.0, Color(0, 0, 0, 0.42))
			_glossy_top(Rect2(band.position, Vector2(band.size.x, band.size.y * 0.5)), 0.0,
				Color(0.1, 0.12, 0.18, 0.25))
			# Plaque "VÁN X": nền tối + hai nét accent vàng hai bên chữ.
			var round_txt := "VÁN %d" % game.current_round
			var rt_w := ThemeDB.fallback_font.get_string_size(round_txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			var rc := Vector2(size.x * 0.5, size.y * 0.32)
			_round_rect(Rect2(rc.x - rt_w * 0.5 - 46.0, rc.y - 24.0, rt_w + 92.0, 40.0),
				8.0, Color(0.05, 0.05, 0.09, 0.85))
			_round_rect(Rect2(rc.x - rt_w * 0.5 - 46.0, rc.y - 24.0, rt_w + 92.0, 40.0),
				8.0, Color(1, 0.85, 0.5, 0.4), false, 1.2)
			draw_string(ThemeDB.fallback_font, Vector2(rc.x, rc.y),
				round_txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.75))
			# Vòng hào quang thu nhỏ theo nhịp — mỗi giây "thump" một cái.
			var num_c := Vector2(size.x * 0.5, size.y * 0.42)
			var ring_r := 62.0 + scale_t * 30.0
			var ring_col := Color(1, 0.85, 0.5, 0.28 * scale_t)
			draw_circle(num_c, ring_r, ring_col)
			draw_circle(num_c, ring_r * 0.72, Color(1, 0.85, 0.5, 0.16 * scale_t))
			# Bóng chữ dưới số cho số nổi trên mọi nền (vẽ TRƯỚC số chính).
			draw_string(ThemeDB.fallback_font, Vector2(3, size.y * 0.42 + 3),
				"%d" % maxi(n, 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, sz,
				Color(0, 0, 0, 0.35))
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42),
				"%d" % maxi(n, 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, sz,
				Color(1, 0.85, 0.5, 0.95))
		Game.Phase.FIGHT:
			if game.phase_timer < 0.8:
				var a := 1.0 - game.phase_timer / 0.8
				# "ĐÁNH!" bật to dần rồi mờ — thêm bóng để chữ nặng hơn cú mở màn.
				var pop := 1.0 + game.phase_timer * 0.25
				var fsz := int(72.0 * pop)
				draw_string(ThemeDB.fallback_font, Vector2(4, size.y * 0.42 + 4),
					"ĐÁNH!", HORIZONTAL_ALIGNMENT_CENTER, size.x, fsz,
					Color(0, 0, 0, 0.5 * a))
				draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42),
					"ĐÁNH!", HORIZONTAL_ALIGNMENT_CENTER, size.x, fsz,
					Color(1, 0.5, 0.2, a))
		Game.Phase.WAITING:
			_draw_center_text("Đang chờ đối thủ...", Color(1, 1, 1, 0.8), 34)
			_draw_center_text("IP máy bạn: %s" % GameData.get_local_ip(),
				Color(0.6, 0.9, 1.0, 0.8), 20, 46.0)
		Game.Phase.ROUND_END:
			# Thông báo thắng/thua ván: bóng đậm + nhịp vàng nhẹ cho cảm giác ăn mừng.
			var re_beat := 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.005)
			draw_string(ThemeDB.fallback_font, Vector2(4, size.y * 0.42 + 4),
				game.status_message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40,
				Color(0, 0, 0, 0.55))
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42),
				game.status_message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40,
				Color(1.0, 0.9, 0.6, 0.95 * re_beat))
		Game.Phase.MATCH_END:
			var winner_col := Color(1, 0.85, 0.4)
			if game.match_winner == 1 and game.local_champ != null:
				winner_col = game.local_champ.accent
			elif game.match_winner == 2 and game.enemy_champ != null:
				winner_col = game.enemy_champ.accent
			var beat := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.004)
			var wc := Color(winner_col.r, winner_col.g, winner_col.b, 0.95 * beat)
			# Làm tối dần toàn màn để banner thắng nổi bật như một khoảnh khắc.
			_round_rect(Rect2(0, 0, size.x, size.y), 0.0, Color(0, 0, 0, 0.5))
			# Banner kính tối giữa màn — cùng ngôn ngữ panel với bảng máu.
			var bw := 460.0
			var by := size.y * 0.42 - 118.0
			var banner := Rect2((size.x - bw) * 0.5, by, bw, 236.0)
			_round_rect(banner, 16.0, Color(0.04, 0.05, 0.09, 0.92))
			_glossy_top(banner, 16.0, Color(0.12, 0.14, 0.2, 0.3))
			_round_rect(banner, 16.0, Color(1, 1, 1, 0.1), false, 1.2)
			# Nét accent màu tướng thắng chạy trên đỉnh banner.
			_round_rect(Rect2(banner.position.x + 24.0, banner.position.y - 1.0,
				banner.size.x - 48.0, 3.0), 2.0,
				Color(winner_col.r, winner_col.g, winner_col.b, 0.75))
			# Chữ có bóng đậm — đọc rõ trên mọi nền.
			draw_string(ThemeDB.fallback_font,
				Vector2(3, size.y * 0.42 - 58.0 + 3), "KẾT THÚC",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(0, 0, 0, 0.55))
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42 - 58.0),
				"KẾT THÚC", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(1, 1, 1, 0.6))
			draw_string(ThemeDB.fallback_font,
				Vector2(3, size.y * 0.42 - 14.0 + 3), game.status_message,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, Color(0, 0, 0, 0.55))
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42 - 14.0),
				game.status_message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, wc)
			# Thống kê sau trận trong thẻ kính con — ba số, ba dòng gọn.
			var stats := "Sát thương: %.0f  ·  Combo cao nhất: %d  ·  Thắng %d/%d ván" % [
				game.stats_damage_dealt, game.stats_max_combo,
				game.stats_rounds_won, game.current_round]
			var card := Rect2(banner.position.x + 36.0, size.y * 0.42 + 24.0,
				banner.size.x - 72.0, 40.0)
			_round_rect(card, 8.0, Color(1, 1, 1, 0.06))
			_round_rect(card, 8.0, Color(1, 1, 1, 0.14), false, 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(0, card.position.y + 27.0),
				stats, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.78))
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42 + 96.0),
				"Nhấn ESC để về menu", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18,
				Color(1, 1, 1, 0.55))

func _draw_center_text(txt: String, col: Color, sz: int, dy: float = 0.0) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.42 + dy), txt,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, col)

# ------------------------------------------------------------- gợi ý combo

func _draw_hints() -> void:
	# Nhắc combo ngay trên màn hình — đây là cách dạy người chơi hệ thống
	# tương tác giữa các skill mà không cần màn hướng dẫn riêng.
	var c := game.local_champ
	if c == null:
		return

	# Khi đang chờ chọn vùng: trên PC đã có bảng mô tả chiêu (bên trên dải kỹ
	# năng) nói đủ tên + mô tả + cách xác nhận, nên bỏ dòng cũ để không chồng chữ.
	# Trên cảm ứng không vẽ bảng đó — giữ dòng hướng dẫn kéo-thả.
	if game.armed_slot != -1:
		if game.touch == null:
			return
		var how := "Kéo để chọn hướng rồi thả ra  ·  Kéo vào ô X để huỷ"
		var extra := ""
		var s := game.armed_skill()
		if s != null and s.uses_range() and not game.armed_valid:
			extra = "   (ngoài tầm — sẽ đặt ở mép tầm)"
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - ICON - MARGIN - 36),
			"%s%s" % [how, extra], HORIZONTAL_ALIGNMENT_CENTER, size.x, 14,
			Color(1, 0.85, 0.5, 0.95) if game.armed_valid else Color(1, 0.55, 0.45, 0.95))
		return

	# Rút gọn còn câu đầu tiên để khỏi tràn màn hình — phần đầy đủ đã có ở menu.
	var full := String(GameData.COMBO_HINTS.get(c.champion_id, ""))
	var hint := full
	if full.contains("."):
		hint = full.split(".")[0] + "."
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - ICON - MARGIN - 34), hint,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 1, 1, 0.4))

# ------------------------------------------------------- bảng phòng luyện tập

## Bảng bật/tắt của phòng luyện tập.
##
## Đây là thứ biến phòng luyện tập thành chỗ thử combo thật sự: tắt hồi chiêu để
## thử một chuỗi liên tục, bật bất tử để không phải chạy lại từ đầu mỗi lần sai,
## và bật hình nộm để đo sát thương mà không bị đánh trả.
func _draw_practice_panel() -> void:
	_practice_rects.clear()
	_practice_buttons.clear()
	if not game.practice_panel_open:
		return

	var items: Array = game.practice_items()
	var row_h := 38.0
	var panel_w := 430.0
	var panel_h := 56.0 + float(items.size()) * row_h + 66.0
	var px := (size.x - panel_w) * 0.5
	var py := (size.y - panel_h) * 0.5 - 30.0

	var panel := Rect2(px, py, panel_w, panel_h)
	_round_rect(panel, 14.0, Color(0.05, 0.05, 0.08, 0.94))
	_round_rect(panel, 14.0, Color(0.45, 0.7, 1.0, 0.55), false, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(px, py + 30), "BẢNG ĐIỀU KHIỂN",
		HORIZONTAL_ALIGNMENT_CENTER, panel_w, 19, Color(0.7, 0.9, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(px, py + 48),
		"Bấm để bật/tắt  ·  Tab để đóng", HORIZONTAL_ALIGNMENT_CENTER, panel_w, 12,
		Color(1, 1, 1, 0.45))

	var y := py + 62.0
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var rect := Rect2(px + 18.0, y, panel_w - 36.0, row_h - 6.0)
		_practice_rects.append(rect)
		var on: bool = item["on"]

		_round_rect(rect, 8.0, Color(1, 1, 1, 0.10 if on else 0.04))
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 14, rect.position.y + 22),
			str(item["label"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 100, 15,
			Color(1, 1, 1, 0.9 if on else 0.55))

		# Viên bật/tắt bên phải.
		var sw := Rect2(rect.end.x - 66.0, rect.position.y + 7.0, 52.0, 18.0)
		_round_rect(sw, 9.0, Color(0.2, 0.75, 0.45, 0.85) if on else Color(0.3, 0.3, 0.36, 0.9))
		var knob_x := sw.end.x - 10.0 if on else sw.position.x + 10.0
		draw_circle(Vector2(knob_x, sw.get_center().y), 7.0, Color(1, 1, 1, 0.92))
		y += row_h

	# Hai nút hành động.
	var by := py + panel_h - 52.0
	var bw := (panel_w - 54.0) * 0.5
	var b1 := Rect2(px + 18.0, by, bw, 36.0)
	var b2 := Rect2(px + 36.0 + bw, by, bw, 36.0)
	_practice_buttons = [b1, b2]
	_round_rect(b1, 8.0, Color(0.35, 0.6, 0.95, 0.28))
	_round_rect(b1, 8.0, Color(0.45, 0.7, 1.0, 0.7), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(b1.position.x, b1.position.y + 24),
		"Hồi đầy máu", HORIZONTAL_ALIGNMENT_CENTER, b1.size.x, 14, Color(0.85, 0.95, 1.0))
	_round_rect(b2, 8.0, Color(0.95, 0.5, 0.3, 0.28))
	_round_rect(b2, 8.0, Color(1.0, 0.65, 0.4, 0.7), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(b2.position.x, b2.position.y + 24),
		"Đặt lại", HORIZONTAL_ALIGNMENT_CENTER, b2.size.x, 14, Color(1.0, 0.9, 0.8))

# ------------------------------------------------------------- bấm bảng luyện tập

func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	# Nút tạm dừng luôn bấm được, kể cả khi đang chơi bình thường.
	if _pause_rect.has_point(mb.position):
		game.toggle_pause()
		accept_event()
		return

	# Phần còn lại chỉ liên quan tới bảng luyện tập.
	if not game.is_practice() or not game.practice_panel_open:
		return

	for i in range(_practice_rects.size()):
		if _practice_rects[i].has_point(mb.position):
			game.practice_click(i)
			accept_event()
			return
	if _practice_buttons.size() >= 2:
		if _practice_buttons[0].has_point(mb.position):
			game.practice_heal_all()
			accept_event()
			return
		if _practice_buttons[1].has_point(mb.position):
			game.practice_reset()
			accept_event()
			return

# ------------------------------------------------------------------ tiện ích

## Lớp bóng kính nửa trên của một panel/ô: chỉ bo HAI góc trên, góc dưới để
## vuông — nhìn như một tấm kính úp xuống, chuẩn chất UI "đúc nổi" 2.5D.
## Godot không có gradient primitive nên dùng lớp màu bán trong suốt này.
func _glossy_top(rect: Rect2, radius: float, color: Color) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	# Cung góc trên-trái (từ hướng trái quay lên hướng trên).
	for s in range(7):
		var a: float = PI + (PI * 0.5) * float(s) / 6.0
		pts.append(Vector2(rect.position.x + r, rect.position.y + r)
			+ Vector2(cos(a), sin(a)) * r)
	# Cung góc trên-phải (từ hướng trên quay sang hướng phải).
	for s in range(7):
		var a: float = PI * 1.5 + (PI * 0.5) * float(s) / 6.0
		pts.append(Vector2(rect.end.x - r, rect.position.y + r)
			+ Vector2(cos(a), sin(a)) * r)
	# Đóng đa giác bằng hai góc dưới vuông.
	pts.append(Vector2(rect.end.x, rect.end.y))
	pts.append(Vector2(rect.position.x, rect.end.y))
	draw_colored_polygon(pts, color)

## Vẽ hình chữ nhật bo góc. Godot không có primitive này nên tự dựng polygon.
func _round_rect(rect: Rect2, radius: float, color: Color,
		filled: bool = true, width: float = 1.0) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.5:
		if filled:
			draw_rect(rect, color)
		else:
			draw_rect(rect, color, false, width)
		return

	var pts := PackedVector2Array()
	var corners := [
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
	]
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	for i in range(4):
		for s in range(7):
			var a: float = starts[i] + (PI * 0.5) * float(s) / 6.0
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * r)

	if filled:
		draw_colored_polygon(pts, color)
		return
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], color, width, true)
