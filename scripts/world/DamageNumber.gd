class_name DamageNumber
extends Node2D
## Con số sát thương bay lên rồi mờ dần.
##
## Vì sao cần: hệ thống combo dựa trên việc dồn stack rồi kích nổ, mà stack thì
## không nhìn thấy được. Không có con số thì người chơi không biết đòn kích nổ
## của mình ăn 40 hay 120 sát thương — tức là không học được gì từ việc thử.
##
## Vẽ bằng `_draw()` cho đồng bộ với phần còn lại của game (không dùng Label).

## Tổng thời gian sống. Ngắn quá thì không kịp đọc, dài quá thì rối màn hình.
const LIFETIME := 0.85
## Độ cao bay lên trong suốt vòng đời.
const RISE := 46.0

var amount := 0.0
var color := Color.WHITE
## Sát thương lớn thì chữ to hơn — mắt tự nhiên chú ý tới đòn nặng.
var big := false
## Chữ nhỏ hơn nữa, dùng cho sát thương theo nhịp (vùng lửa, vệt băng).
var small := false

var _t := 0.0

func setup(value: float, tint: Color, is_big: bool = false, is_small: bool = false) -> void:
	amount = value
	color = tint
	big = is_big
	small = is_small
	z_index = 20

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_t / LIFETIME, 0.0, 1.0)
	# Bay lên nhanh lúc đầu rồi chậm dần — giống vật bị ném lên.
	var rise := RISE * (1.0 - pow(1.0 - t, 2.2))
	# Mờ dần ở 40% cuối để số cũ không tranh chỗ với số mới.
	var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4

	var size := 15
	if big:
		size = 24
	elif small:
		size = 11

	# Nhấp một cái ngay khi xuất hiện để đòn nặng có cảm giác "nặng".
	var pop := 1.0 + maxf(0.0, 0.25 - t) * 1.6
	size = int(float(size) * pop)

	var text := str(int(round(amount)))
	if amount < 1.0:
		text = "%d" % int(ceil(amount))

	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, -rise)

	# Viền tối phía sau để số đọc được trên mọi nền sân.
	draw_string(font, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, alpha * 0.65))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(color.r, color.g, color.b, alpha))
