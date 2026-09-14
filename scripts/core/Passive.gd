class_name Passive
extends RefCounted
## Lớp cơ sở cho nội tại của tướng.
##
## Nội tại là thứ khiến hai tướng dùng chung một bộ luật vẫn chơi khác hẳn nhau.
## Mỗi tướng có đúng MỘT nội tại, và không tướng nào trùng tướng nào.
##
## Cách hoạt động: `Champion` gọi các hàm hook này vào đúng thời điểm trong vòng
## tick. Lớp con chỉ cần ghi đè những hook nó quan tâm — mặc định tất cả đều
## không làm gì.
##
## Vì sao dùng hook thay vì để nội tại tự bám vào signal: signal của Champion
## phát ra cho tầng hiển thị (HUD, hiệu ứng), còn nội tại là một phần của LUẬT
## CHƠI. Trộn hai thứ đó vào nhau thì rất khó biết cái gì chạy trên máy chủ và
## cái gì chỉ để vẽ. Hook gọi thẳng trong `step()` nên chỉ chạy ở nơi mô phỏng.

## Tướng sở hữu nội tại này.
var owner_champ: Champion = null
## Tên hiển thị ở HUD và menu chọn tướng.
var display_name := "Nội tại"
## Mô tả một dòng, hiện ở menu chọn tướng.
var description := ""

func setup(c: Champion) -> void:
	owner_champ = c

# ------------------------------------------------------------------ hook

## Chạy mỗi tick mô phỏng. Dùng cho nội tại có đồng hồ đếm riêng.
func tick(_delta: float) -> void:
	pass

## Sắp gây sát thương. Trả về hệ số nhân cho lượng sát thương đó.
##
## Ví dụ: Tâm Điểm của Xạ Thủ trả 1.5 khi đã sạc đầy.
func outgoing_multiplier(_target: Champion) -> float:
	return 1.0

## Sắp nhận sát thương. Trả về hệ số nhân.
##
## Ví dụ: Vỏ Bọc của Thạch Vệ Binh trả 0.75 khi đang đứng yên.
func incoming_multiplier(_source_peer: int) -> float:
	return 1.0

## Hệ số nhân bán kính cho mọi vùng/đạn của tướng này.
##
## Ví dụ: Không Gian Vặn của Hư Không Pháp Sư trả 1.2.
func area_multiplier() -> float:
	return 1.0

## Vừa GÂY sát thương lên một mục tiêu.
##
## Khác `on_basic_hit`: hook này chạy cho mọi nguồn sát thương, kể cả đạn và
## vùng đất. Dùng khi nội tại cần biết "tôi vừa đánh trúng ai" mà không quan
## tâm bằng cách gì.
func on_deal_damage(_target: Champion, _amount: float) -> void:
	pass

## Vừa gây sát thương bằng ĐÁNH THƯỜNG lên một mục tiêu.
func on_basic_hit(_target: Champion) -> void:
	pass

## Vừa BẤM đánh thường (chưa chắc đã trúng ai).
##
## Cần hook riêng vì đánh thường là hành động lặp liên tục, không đi qua
## `on_skill_cast`. Nội tại kiểu "cứ 2 đòn thường thì..." dùng hook này.
func on_basic_cast() -> void:
	pass

## Vừa NHẬN sát thương từ một đối thủ.
##
## Khác `incoming_multiplier`: hook này chạy SAU khi máu đã trừ, dùng cho nội
## tại cần phản ứng với việc bị đánh (ví dụ Băng Giáp đóng băng kẻ tấn công).
func on_damage_taken(_amount: float, _source_peer: int) -> void:
	pass

## Vừa tung một kỹ năng (không tính đánh thường).
func on_skill_cast(_skill: SkillBase) -> void:
	pass

## Vừa hồi máu. Trả về lượng máu thực sự được hồi (đã qua biến đổi của nội tại).
func on_heal(amount: float) -> float:
	return amount

## Vừa hạ gục một đối thủ.
func on_kill(_victim: Champion) -> void:
	pass

## Mô tả ngắn để hiện ở HUD, ví dụ "Bóng Theo · 2.4s".
## Trả chuỗi rỗng nếu nội tại không có trạng thái động cần hiện.
func status_text() -> String:
	return ""
