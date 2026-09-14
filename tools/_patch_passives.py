"""Gắn nội tại cho sáu tướng hiện có.

Mỗi tướng nhận thêm hai thứ ở cuối file:
  1. `build_passive()` — hàm mà `Champion.configure()` gọi để lấy nội tại
  2. một lớp con của `Passive` — phần hành vi thật

Cách làm này giữ nguyên nguyên tắc của project: mọi thứ thuộc về một tướng nằm
trong đúng một file, không rải ra nhiều nơi.

Chạy: python tools/_patch_passives.py
"""
import pathlib
import sys

PASSIVES = {
    "FireMage.gd": '''

# ============================================================ NỘI TẠI — THIÊU ĐỐT
func build_passive():
	return EmberFeed.new()


## Nội tại THIÊU ĐỐT: cứ 2 đòn đánh thường thì cộng thêm 1 stack Bỏng lên mục
## tiêu gần nhất, và mục tiêu đang Bỏng chịu thêm 8% sát thương từ Hỏa Pháp Sư.
##
## Vì sao gắn vào đánh thường: chiêu Q đã cộng Bỏng rồi, nên nội tại phải thưởng
## cho việc dùng đánh thường — nếu không thì người chơi chỉ bấm Q rồi đứng chờ
## hồi chiêu, và cả bộ chiêu còn lại thành vô nghĩa.
class EmberFeed extends Passive:
	const HITS_PER_STACK := 2
	const BURN_BONUS := 0.08

	var _hits := 0

	func _init() -> void:
		display_name = "Thiêu Đốt"
		description = "Mỗi 2 đòn đánh thường cộng 1 stack Bỏng. Mục tiêu đang Bỏng chịu thêm 8% sát thương từ bạn."

	func on_basic_cast() -> void:
		if owner_champ == null:
			return
		_hits += 1
		if _hits < HITS_PER_STACK:
			return
		_hits = 0
		var e := owner_champ.nearest_enemy(620.0)
		if e != null:
			e.add_status(GameData.ST_BURN, 1, 5.0, owner_champ.peer_id)

	func outgoing_multiplier(target: Champion) -> float:
		if target != null and target.has_status(GameData.ST_BURN):
			return 1.0 + BURN_BONUS
		return 1.0

	func status_text() -> String:
		return "Thiêu Đốt · %d/%d" % [_hits, HITS_PER_STACK]
''',

    "ShadowAssassin.gd": '''

# ============================================================ NỘI TẠI — ĐÒN CHUẨN
func build_passive():
	return PreciseStrike.new()


## Nội tại ĐÒN CHUẨN: mỗi stack Khóa Hồn trên mục tiêu cộng thêm 4% sát thương,
## và đánh trúng mục tiêu bị Khóa Hồn thì hoàn 1 giây hồi chiêu đánh thường.
##
## Nhờ vậy đánh thường không còn là "để lấp thời gian chờ" — nó là cách giữ nhịp
## ra đòn trong lúc chờ Khóa Hồn hồi.
class PreciseStrike extends Passive:
	const REFUND := 1.0
	const MARK_BONUS := 0.04

	func _init() -> void:
		display_name = "Đòn Chuẩn"
		description = "Mỗi stack Khóa Hồn trên mục tiêu: +4% sát thương. Đánh trúng mục tiêu bị Khóa Hồn thì hoàn 1s hồi chiêu đánh thường."

	func outgoing_multiplier(target: Champion) -> float:
		if target == null:
			return 1.0
		var marks: int = target.get_stacks(GameData.ST_MARK)
		if marks <= 0:
			return 1.0
		return 1.0 + MARK_BONUS * float(marks)

	func on_deal_damage(target: Champion, _amount: float) -> void:
		if owner_champ == null or target == null:
			return
		if not target.has_status(GameData.ST_MARK):
			return
		if owner_champ.basic_attack != null:
			owner_champ.basic_attack.refund(REFUND)
''',

    "FrostMaiden.gd": '''

# ============================================================ NỘI TẠI — BĂNG GIÁP
func build_passive():
	return FrostArmor.new()


## Nội tại BĂNG GIÁP: bị đánh thì có 25% cơ hội đóng băng kẻ tấn công 0.45 giây.
##
## Có thời gian chờ 3 giây, và đây là con số quan trọng: không có nó thì chỉ cần
## đối thủ bắn liên tục là bị khoá cứng vĩnh viễn — nội tại sẽ biến từ "thưởng
## cho việc chịu đòn" thành "không thể chơi được".
class FrostArmor extends Passive:
	const CHANCE := 0.25
	const FREEZE_TIME := 0.45
	const COOLDOWN := 3.0

	var _cd := 0.0

	func _init() -> void:
		display_name = "Băng Giáp"
		description = "Bị đánh: 25% cơ hội đóng băng kẻ tấn công 0.45s. Hồi 3s."

	func tick(delta: float) -> void:
		_cd = maxf(0.0, _cd - delta)

	func on_damage_taken(_amount: float, source_peer: int) -> void:
		if _cd > 0.0 or owner_champ == null or source_peer == 0:
			return
		if randf() > CHANCE:
			return
		var src := _find(source_peer)
		if src == null or not src.is_alive():
			return
		_cd = COOLDOWN
		src.add_status(GameData.ST_FREEZE, 1, FREEZE_TIME, owner_champ.peer_id)
		owner_champ.spawn_effect({
			"kind": &"explosion",
			"position": owner_champ.global_position,
			"radius": 70.0,
			"life": 0.32,
			"accent": Color("bdf0ff"),
		})
		Audio.play_at(&"freeze", owner_champ.global_position, -6.0)

	func _find(pid: int) -> Champion:
		if owner_champ == null or owner_champ.world == null:
			return null
		for c in owner_champ.world.champions_list():
			if c.peer_id == pid:
				return c
		return null

	func status_text() -> String:
		return "Băng Giáp · sẵn sàng" if _cd <= 0.0 else "Băng Giáp · %.1fs" % _cd
''',

    "ThunderWarrior.gd": '''

# ============================================================ NỘI TẠI — SẠC KÉP
func build_passive():
	return DoubleCharge.new()


## Nội tại SẠC KÉP: cứ 3 kỹ năng thì lần thứ 3 bắn kèm một tia sét phụ theo
## hướng đang ngắm, và tia đó cũng gắn Tích Điện.
##
## Vì sao đếm kỹ năng chứ không đếm đánh thường: cả bộ chiêu của Lôi Đình xoay
## quanh Tích Điện, nên phần thưởng phải nằm ở việc dùng chiêu liên tục để giữ
## dòng Tích Điện chảy — chứ không phải ở việc giữ chuột trái.
class DoubleCharge extends Passive:
	const EVERY := 3
	const BOLT_DAMAGE := 13.0

	var _count := 0

	func _init() -> void:
		display_name = "Sạc Kép"
		description = "Cứ 3 kỹ năng thì lần thứ 3 bắn kèm một tia sét phụ gắn Tích Điện."

	func on_skill_cast(_skill: SkillBase) -> void:
		if owner_champ == null:
			return
		_count += 1
		if _count < EVERY:
			return
		_count = 0
		owner_champ.spawn_projectile({
			"kind": &"thunder_bolt",
			"direction": owner_champ.aim_dir,
			"speed": 800.0,
			"damage": BOLT_DAMAGE,
			"radius": 10.0,
			"life": 0.9,
			"power": 1.4,
			"status_id": GameData.ST_CHARGE,
			"status_stacks": 1,
			"status_duration": 4.0,
			"accent": Color("ffe066"),
		})
		Audio.play_at(&"thunder", owner_champ.global_position, -4.0, 1.25)

	func status_text() -> String:
		return "Sạc Kép · %d/%d" % [_count, EVERY]
''',

    "StoneGuardian.gd": '''

# ============================================================ NỘI TẠI — VỎ BỌC
func build_passive():
	return StoneShell.new()


## Nội tại VỎ BỌC: đứng yên liên tục 1.5 giây thì giảm 25% sát thương phải chịu.
##
## Đây là nội tại có đánh đổi rõ nhất trong bộ: muốn chắc thì phải đứng im, mà
## đứng im thì dễ ăn chiêu chọn vùng. Người chơi phải tự cân giữa hai thứ.
class StoneShell extends Passive:
	const STILL_TIME := 1.5
	const REDUCTION := 0.25
	## Ngưỡng vận tốc coi là "đang đứng yên". Để 12 px/s vì tướng vẫn bị trôi
	## nhẹ khi vừa dừng bấm phím.
	const MOVE_EPSILON := 12.0

	var _still := 0.0

	func _init() -> void:
		display_name = "Vỏ Bọc"
		description = "Đứng yên 1.5s liên tục: giảm 25% sát thương phải chịu."

	func tick(delta: float) -> void:
		if owner_champ == null:
			return
		if owner_champ.velocity.length() < MOVE_EPSILON:
			_still += delta
		else:
			_still = 0.0

	func incoming_multiplier(_source_peer: int) -> float:
		if _still >= STILL_TIME:
			return 1.0 - REDUCTION
		return 1.0

	func status_text() -> String:
		if _still >= STILL_TIME:
			return "Vỏ Bọc · đang giảm 25%"
		return "Vỏ Bọc · %.1fs" % maxf(0.0, STILL_TIME - _still)
''',

    "ArcaneWeaver.gd": '''

# ======================================================== NỘI TẠI — KHÔNG GIAN VẶN
func build_passive():
	return WarpedSpace.new()


## Nội tại KHÔNG GIAN VẶN: mọi vùng ảnh hưởng rộng thêm 20%.
##
## Hệ số được nhân ở `Arena.spawn_projectile` chứ không sửa từng chiêu, nên nó
## áp cho cả 25 chiêu hiện có mà không phải đụng vào file tướng nào.
class WarpedSpace extends Passive:
	const AREA_BONUS := 0.2

	func _init() -> void:
		display_name = "Không Gian Vặn"
		description = "Mọi vùng ảnh hưởng của bạn rộng thêm 20%."

	func area_multiplier() -> float:
		return 1.0 + AREA_BONUS
''',
}


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "champions"
    for filename, block in PASSIVES.items():
        path = root / filename
        if not path.exists():
            print("KHÔNG THẤY:", filename)
            continue
        text = path.read_text(encoding="utf-8")
        if "build_passive" in text:
            print("đã có nội tại, bỏ qua:", filename)
            continue
        path.write_text(text.rstrip("\n") + "\n" + block, encoding="utf-8", newline="")
        print("đã gắn nội tại:", filename)
    return 0


if __name__ == "__main__":
    sys.exit(main())
