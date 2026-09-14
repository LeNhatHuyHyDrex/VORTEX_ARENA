class_name StatusEffect
extends RefCounted
## Một trạng thái gắn lên tướng (Bỏng, Khóa Hồn, Chậm...).
##
## Đây là mảnh ghép then chốt của hệ thống combo: skill này TẠO stack, skill kia
## TIÊU THỤ stack. Nhờ vậy thứ tự ra chiêu mới quan trọng, và người chơi tự tìm
## ra combo chứ không phải bấm theo một dãy cố định.

var id: StringName
var stacks: int = 0
var max_stacks: int = 10
var duration: float = 0.0      # thời gian làm mới mỗi khi thêm stack
var time_left: float = 0.0
var source_peer: int = 0       # ai gây ra, để tính công trạng khi hạ gục

func _init(p_id: StringName, p_duration: float, p_max_stacks: int = 10) -> void:
	id = p_id
	duration = p_duration
	max_stacks = p_max_stacks
	time_left = p_duration

## Thêm stack và làm mới đồng hồ đếm ngược. Trả về số stack thực sự được thêm.
func add(p_stacks: int, p_source: int = 0) -> int:
	var before := stacks
	stacks = mini(stacks + p_stacks, max_stacks)
	time_left = duration
	source_peer = p_source
	return stacks - before

## Đếm ngược. Trả về true khi đã hết hạn (cần xoá khỏi tướng).
func tick(delta: float) -> bool:
	time_left -= delta
	if time_left <= 0.0:
		stacks = 0
		return true
	return false

func ratio() -> float:
	return 0.0 if duration <= 0.0 else clampf(time_left / duration, 0.0, 1.0)
