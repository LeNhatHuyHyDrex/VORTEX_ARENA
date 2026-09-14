class_name TouchControls
extends Control
## Điều khiển cảm ứng cho Android — bố cục theo tầm với của ngón tay cái.
##
## Nguyên tắc thiết kế:
##   1. Tay trái cầm mép trái, tay phải cầm mép phải. Cần trái lo di chuyển,
##      cần phải lo ngắm. Cả hai đều "động": xuất hiện đúng chỗ ngón tay chạm
##      xuống chứ không đóng khung cố định, nên người chơi không cần với.
##   2. Năm nút hành động (4 kỹ năng + đánh thường) xếp thành CUNG QUẠT quanh
##      góc dưới phải. Đánh thường to nhất và nằm ngoài cùng — vì nó bấm liên
##      tục, phải là nút dễ trúng nhất.
##   3. Mọi kích thước đều nhân với hệ số lấy từ cạnh ngắn màn hình, nên từ
##      điện thoại 5 inch tới tablet 12 inch đều dùng được một bố cục.
##
## Chỉ được tạo khi chạy trên thiết bị cảm ứng hoặc khi người dùng bật trong
## cài đặt, nên trên PC không chiếm chỗ.

## Kích thước thiết kế ở màn hình chuẩn 720p chiều ngang; thực tế nhân hệ số.
const STICK_RADIUS := 82.0
const KNOB_RADIUS := 34.0
const DEAD_ZONE := 0.16
const SKILL_RADIUS := 34.0
const ATTACK_RADIUS := 47.0
## Bán kính cung quạt đặt các nút kỹ năng quanh nút đánh thường.
const FAN_RADIUS := 132.0
## Cỡ nút được nới thêm một chút so với hình vẽ — ngón tay to hơn mắt nghĩ.
const TOUCH_PADDING := 1.28

var _move_touch := -1
var _aim_touch := -1
var _move_origin := Vector2.ZERO
var _aim_origin := Vector2.ZERO
var _move_vec := Vector2.ZERO
var _aim_vec := Vector2.ZERO

var _button_touch := {}          # touch_index -> slot (0..3 kỹ năng, 4 đánh thường)
var _pressed_mask := 0           # bit 0..3 kỹ năng vừa bấm
## Bit 0..3: kỹ năng vừa được NHẤC ngón trong khung hình này. Dùng để chốt chiêu.
var _released_mask := 0
## Lần nhấc ngón vừa rồi có rơi vào vùng huỷ không.
var _release_cancelled := false
## Vị trí nút lúc bấm xuống, làm gốc cho vector kéo. slot -> Vector2.
var _drag_origin := {}
var _attack_held := false
var _flash: Dictionary = {}      # slot -> thời gian còn lại của hiệu ứng bấm

## Vị trí nút đã tính, cache lại mỗi khi vẽ để xử lý chạm dùng chung một kết quả.
var _slots: Array[Vector2] = []
var _scale := 1.0
## Tâm vùng huỷ, chỉ hiện khi người chơi đang giữ một nút kỹ năng.
var _cancel_center := Vector2.ZERO
const CANCEL_RADIUS := 52.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	for slot in _flash.keys():
		var left: float = _flash[slot] - delta
		if left <= 0.0:
			_flash.erase(slot)
		else:
			_flash[slot] = left
	queue_redraw()

func move_vector() -> Vector2:
	return _move_vec

func aim_active() -> bool:
	return _aim_vec != Vector2.ZERO

func aim_direction() -> Vector2:
	return _aim_vec

## Đánh thường: trả về true khi ngón tay đang GIỮ nút, để bắn lặp lại theo
## nhịp hồi chiêu — cùng hành vi với giữ chuột trái trên PC.
func attack_held() -> bool:
	return _attack_held

## Trả về bitmask các nút kỹ năng vừa được bấm, rồi xoá cờ.
func consume_pressed_skills() -> int:
	var m := _pressed_mask
	_pressed_mask = 0
	return m

## Trả về bitmask các nút kỹ năng vừa được NHẤC ngón, rồi xoá cờ.
func consume_released_skills() -> int:
	var m := _released_mask
	_released_mask = 0
	return m

## Lần nhấc ngón vừa rồi có nằm trong vùng huỷ không. Tự xoá cờ sau khi đọc.
func release_was_cancel() -> bool:
	var c := _release_cancelled
	_release_cancelled = false
	return c

## Ô kỹ năng đang được giữ, -1 nếu không giữ ô nào.
func held_skill_slot() -> int:
	for idx in _button_touch.keys():
		var slot: int = _button_touch[idx]
		if slot != 4:
			return slot
	return -1

## Vector kéo của một ô kỹ năng, tính từ vị trí nút lúc bấm xuống.
##
## Đây là cách các game MOBA trên điện thoại làm: ngón tay che mất chỗ cần
## ngắm, nên thay vì trỏ vào đích, người chơi kéo theo hướng muốn bắn và độ dài
## kéo quyết định tầm với. Trả Vector2.ZERO nếu ô đó không đang được giữ.
func skill_drag_vector(slot: int) -> Vector2:
	for idx in _button_touch.keys():
		if int(_button_touch[idx]) != slot:
			continue
		var origin: Vector2 = _drag_origin.get(idx, Vector2.ZERO)
		var pos := _touch_position(idx)
		return pos - origin
	return Vector2.ZERO

## Vị trí hiện tại của một ngón đang chạm. Lưu lại trong lúc xử lý sự kiện.
var _touch_positions := {}

func _touch_position(index: int) -> Vector2:
	return _touch_positions.get(index, Vector2.ZERO)

# ------------------------------------------------------------------ bố cục

func _update_scale() -> void:
	# Cạnh ngắn quyết định cỡ nút: xoay ngang hay dọc đều giữ được tỉ lệ.
	_scale = clampf(minf(size.x, size.y) / 400.0, 0.72, 1.55)

## Năm vị trí nút: slot 0..3 là kỹ năng, slot 4 là đánh thường.
##
## Tâm cung đặt lùi vào trong so với góc dưới phải, để cả năm nút đều nằm
## trong vùng ngón tay cái với tới được khi cầm máy bằng hai tay.
func _compute_slots() -> void:
	_update_scale()
	var pad := 26.0 * _scale
	var anchor := Vector2(size.x - pad - ATTACK_RADIUS * _scale,
		size.y - pad - ATTACK_RADIUS * _scale)
	_slots = []
	# Góc tính theo toạ độ màn hình (y hướng xuống): 180° = trái, 270° = lên.
	var angles: Array[float] = [163.0, 201.0, 239.0, 277.0]
	for a in angles:
		var rad := deg_to_rad(a)
		_slots.append(anchor + Vector2(cos(rad), sin(rad)) * FAN_RADIUS * _scale)
	_slots.append(anchor)
	# Vùng huỷ nằm bên trái cụm nút — chỗ ngón cái với tới tự nhiên khi muốn
	# rút lại một chiêu đã lỡ bấm.
	_cancel_center = anchor + Vector2(-FAN_RADIUS * _scale * 1.45, -10.0 * _scale)

func _slot_at(pos: Vector2) -> int:
	# Vòng lặp ngược để nút vẽ sau (đánh thường) được ưu tiên khi hai nút dính nhau.
	for i in range(_slots.size() - 1, -1, -1):
		var r := (ATTACK_RADIUS if i == 4 else SKILL_RADIUS) * _scale * TOUCH_PADDING
		if pos.distance_to(_slots[i]) <= r:
			return i
	return -1

# ------------------------------------------------------------------ hình vẽ

func _draw() -> void:
	_compute_slots()
	if _slots.is_empty():
		return

	# Cần ngắm vẽ trước để nằm dưới các nút, tránh che mất chữ.
	if _aim_touch != -1:
		_draw_stick(_aim_origin, _aim_vec, Color(0.66, 0.33, 0.97, 0.16),
			Color(0.80, 0.58, 1.0, 0.52))
	if _move_touch != -1:
		_draw_stick(_move_origin, _move_vec, Color(1, 1, 1, 0.14),
			Color(1, 1, 1, 0.32))

	# Vòng mờ gợi ý vị trí cần khi chưa chạm — chỉ hiện vài giây đầu.
	if _move_touch == -1:
		_hint_ring(Vector2(size.x * 0.18, size.y * 0.72), Color(1, 1, 1, 0.10))
	if _aim_touch == -1:
		_hint_ring(Vector2(size.x * 0.72, size.y * 0.42),
			Color(0.66, 0.33, 0.97, 0.16))

	for i in range(4):
		_draw_skill_button(_slots[i], i)
	_draw_attack_button(_slots[4])

	# Vùng huỷ chỉ hiện khi đang giữ một nút kỹ năng, để không rối màn hình
	# trong lúc đánh nhau bình thường.
	var held := held_skill_slot()
	if held != -1:
		var dragging := skill_drag_vector(held).length() > 12.0
		_draw_cancel_zone(dragging)

## Vùng huỷ: kéo ngón vào đây rồi thả là bỏ chiêu.
##
## Tô đậm lên khi ngón đang ở trong vùng, vì lúc đó người chơi cần biết chắc
## rằng thả ra sẽ huỷ chứ không phải bắn.
func _draw_cancel_zone(active: bool) -> void:
	var r := CANCEL_RADIUS * _scale
	var col := Color(0.95, 0.35, 0.35)
	draw_circle(_cancel_center, r, Color(col.r, col.g, col.b, 0.30 if active else 0.14))
	draw_arc(_cancel_center, r, 0.0, TAU, 32,
		Color(col.r, col.g, col.b, 1.0 if active else 0.55), 3.0 * _scale, true)
	# Dấu X ở giữa.
	var k := r * 0.42
	var w := 3.0 * _scale
	draw_line(_cancel_center + Vector2(-k, -k), _cancel_center + Vector2(k, k),
		Color(1, 1, 1, 0.95 if active else 0.6), w, true)
	draw_line(_cancel_center + Vector2(k, -k), _cancel_center + Vector2(-k, k),
		Color(1, 1, 1, 0.95 if active else 0.6), w, true)
	draw_string(ThemeDB.fallback_font, _cancel_center + Vector2(-r, r + 16.0 * _scale),
		"HUỶ", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(12 * _scale),
		Color(1, 1, 1, 0.75 if active else 0.45))

func _hint_ring(center: Vector2, col: Color) -> void:
	draw_arc(center, STICK_RADIUS * _scale, 0.0, TAU, 36, col, 2.0 * _scale, true)

func _draw_stick(origin: Vector2, vec: Vector2, ring: Color, knob: Color) -> void:
	var r := STICK_RADIUS * _scale
	draw_arc(origin, r, 0.0, TAU, 40, ring, 3.0 * _scale, true)
	var knob_pos := origin + vec * (r - KNOB_RADIUS * _scale * 0.4)
	draw_circle(knob_pos, KNOB_RADIUS * _scale, knob)
	draw_circle(knob_pos, KNOB_RADIUS * _scale * 0.5, Color(1, 1, 1, 0.20))

func _skill_info(index: int) -> SkillBase:
	var game := _game()
	if game == null or game.local_champ == null:
		return null
	if index >= game.local_champ.skills.size():
		return null
	return game.local_champ.skills[index]

func _draw_skill_button(center: Vector2, index: int) -> void:
	var s := _skill_info(index)
	var col := Color(0.6, 0.6, 0.7)
	var label := "?"
	var ratio := 0.0
	var usable := true
	if s != null:
		col = s.icon_color
		label = s.key_label
		ratio = s.cooldown_ratio()
		usable = s.block_reason() == ""

	var r := SKILL_RADIUS * _scale
	var flash: float = _flash.get(index, 0.0)
	var grow := 1.0 + flash * 0.12

	draw_circle(center, r * grow, Color(col.r, col.g, col.b, 0.24 if usable else 0.10))
	draw_arc(center, r * grow, 0.0, TAU, 36,
		Color(col.r, col.g, col.b, 0.95 if usable else 0.35), 3.0 * _scale, true)

	# Vòng hồi chiêu quét ngược chiều kim đồng hồ: đầy dần khi chiêu sẵn sàng.
	if ratio > 0.0:
		draw_circle(center, r * grow - 3.0, Color(0, 0, 0, 0.45))
		draw_arc(center, r * grow - 6.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio), 28,
			Color(1, 1, 1, 0.55), 4.0 * _scale, true)

	draw_string(ThemeDB.fallback_font, center + Vector2(-r, 7.0 * _scale),
		label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(20 * _scale),
		Color(1, 1, 1, 0.95 if usable else 0.4))

func _draw_attack_button(center: Vector2) -> void:
	var game := _game()
	var col := Color(0.95, 0.55, 0.25)
	var label := "ĐÁNH"
	if game != null and game.local_champ != null and game.local_champ.basic_attack != null:
		col = game.local_champ.basic_attack.icon_color

	var r := ATTACK_RADIUS * _scale
	var flash: float = _flash.get(4, 0.0)
	var grow := 1.0 + flash * 0.10 + (0.03 if _attack_held else 0.0)

	draw_circle(center, r * grow, Color(col.r, col.g, col.b, 0.30))
	draw_arc(center, r * grow, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.95),
		3.5 * _scale, true)
	draw_arc(center, r * grow + 6.0 * _scale, 0.0, TAU, 40,
		Color(col.r, col.g, col.b, 0.20), 2.0 * _scale, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-r, 6.0 * _scale),
		label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(17 * _scale),
		Color(1, 1, 1, 0.95))

func _game() -> Game:
	var n: Node = get_parent()
	while n != null:
		if n is Game:
			return n
		n = n.get_parent()
	return null

# ------------------------------------------------------------------ xử lý chạm

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		# Cho phép thử nghiệm trên PC bằng chuột, và để bản Windows debug
		# so sánh được trực tiếp với cảm ứng thật.
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.position = mb.position
			down.pressed = true
			_handle_touch(down)
		else:
			var up := InputEventScreenTouch.new()
			up.index = 0
			up.position = mb.position
			up.pressed = false
			_handle_touch(up)
	elif event is InputEventMouseMotion:
		if _move_touch == 0 or _aim_touch == 0:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = (event as InputEventMouseMotion).position
			_handle_drag(drag)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	_touch_positions[event.index] = pos

	if event.pressed:
		# Nút hành động xét trước: nếu ngón tay chạm trúng nút thì đó là ra
		# chiêu, không phải cần ngắm — tránh vừa bấm skill vừa xoay hướng.
		var slot := _slot_at(pos)
		if slot != -1:
			_button_touch[event.index] = slot
			_flash[slot] = 0.18
			if slot == 4:
				_attack_held = true
			else:
				_pressed_mask |= 1 << slot
				# Ghi lại chỗ bấm xuống làm gốc cho vector kéo. Dùng vị trí nút
				# chứ không dùng vị trí ngón, để người chơi đặt ngón lệch một
				# chút vẫn kéo ra đúng hướng mong muốn.
				_drag_origin[event.index] = _slots[slot]
			return
		# Chia màn hình: nửa trái di chuyển, nửa phải ngắm.
		if pos.x < size.x * 0.5:
			if _move_touch == -1:
				_move_touch = event.index
				_move_origin = pos
				_move_vec = Vector2.ZERO
		else:
			if _aim_touch == -1:
				_aim_touch = event.index
				_aim_origin = pos
				_aim_vec = Vector2.ZERO
	else:
		var slot: int = _button_touch.get(event.index, -1)
		if slot != -1:
			_button_touch.erase(event.index)
			_drag_origin.erase(event.index)
			if slot == 4:
				_attack_held = false
			else:
				# Nhấc ngón = chốt chiêu. Nếu ngón đang nằm trong vùng huỷ thì
				# đánh dấu để tầng trên bỏ chiêu thay vì tung ra.
				_released_mask |= 1 << slot
				_release_cancelled = pos.distance_to(_cancel_center) <= CANCEL_RADIUS * _scale
		elif event.index == _move_touch:
			_move_touch = -1
			_move_vec = Vector2.ZERO
		elif event.index == _aim_touch:
			_aim_touch = -1
			_aim_vec = Vector2.ZERO
	_touch_positions.erase(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _slots.is_empty():
		_compute_slots()
	_touch_positions[event.index] = event.position
	if event.index == _move_touch:
		_move_vec = _clamp_vec((event.position - _move_origin) / (STICK_RADIUS * _scale))
	elif event.index == _aim_touch:
		_aim_vec = _clamp_vec((event.position - _aim_origin) / (STICK_RADIUS * _scale))
	# Kéo trên nút kỹ năng không cần xử lý gì thêm: `skill_drag_vector()` đọc
	# trực tiếp vị trí ngón từ `_touch_positions`, nên chỉ cần cập nhật vị trí.

func _clamp_vec(v: Vector2) -> Vector2:
	if v.length() < DEAD_ZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)
