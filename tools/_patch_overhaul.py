"""Đại cải năm chiêu chủ lực của năm tướng gốc.

Mục tiêu: mỗi tướng có thêm một chiêu để "phô diễn" — tức là chiêu mà người
chơi giỏi dùng được tốt hơn hẳn người mới, chứ không chỉ là bấm là ăn.

  1. Hỏa Pháp Sư  — Lướt Tung Lửa: lướt vẽ cung lửa hai bên, không còn là vệt
                    lửa thẳng đơn điệu
  2. Sát Thủ      — Ảnh Bộ: từ SELF thành INSTANT lướt theo hướng, có cửa sổ
                    1.2 giây để lướt lần thứ hai (chuỗi 2 lần)
  3. Băng Sương Nữ — Trượt Băng: thêm tường băng chặn đạn tại chỗ vừa rời đi
  4. Lôi Đình     — Lướt Lôi Đình: để lại vết sét tại chỗ cũ, xuyên qua ai thì
                    choáng người đó
  5. Thạch Vệ Binh — Vách Đá: từ một khối tròn thành cả bức tường ba khối dài

Chạy: python tools/_patch_overhaul.py
"""
import pathlib
import sys

EDITS = [
    # ---------------------------------------------------------- Hỏa Pháp Sư
    (
        "FireMage.gd",
        '''		# Vệt lửa dọc đường lướt — biến đường lướt thành công cụ kiểm soát khu vực.
		for i in range(5):
			var t := float(i) / 4.0
			caster.spawn_projectile({
				"kind": &"firewall",
				"position": start.lerp(end, t),
				"speed": 0.0,
				"is_zone": true,
				"tick_damage": 4.0,
				"tick_interval": 0.4,
				"radius": 34.0,
				"life": 1.6,
				"accent": Color("ff7a2f"),
			})
''',
        '''		# Vệt lửa dọc đường lướt — biến đường lướt thành công cụ kiểm soát khu vực.
		for i in range(5):
			var t := float(i) / 4.0
			caster.spawn_projectile({
				"kind": &"firewall",
				"position": start.lerp(end, t),
				"speed": 0.0,
				"is_zone": true,
				"tick_damage": 4.0,
				"tick_interval": 0.4,
				"radius": 34.0,
				"life": 1.6,
				"accent": Color("ff7a2f"),
			})

		# Cung lửa hai bên: đây là phần biến chiêu lướt thành chiêu tấn công.
		# Không lướt thẳng rồi để lại một vệt — mà quét một hình quạt về hai
		# phía, nên người chơi giỏi có thể lướt XUYÊN QUA đối thủ và đốt cả hai
		# bên sườn cùng lúc. Ai chỉ bấm lướt để chạy thì không bao giờ thấy phần
		# này hoạt động.
		var perp := Vector2(-dir.y, dir.x)
		for side in [-1.0, 1.0]:
			for i in range(3):
				var t := 0.30 + 0.30 * float(i)
				var pos: Vector2 = start.lerp(end, t) + perp * (side * (46.0 + 26.0 * float(i)))
				caster.spawn_projectile({
					"kind": &"firewall",
					"position": pos,
					"speed": 0.0,
					"is_zone": true,
					"tick_damage": 5.0,
					"tick_interval": 0.4,
					"radius": 38.0,
					"life": 2.2,
					"accent": Color("ffa347"),
				})
''',
    ),
    # ------------------------------------------------------------ Sát Thủ
    (
        "ShadowAssassin.gd",
        '''	func _init() -> void:
		id = &"shadow_step"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Ảnh Bộ"
		description = "Dịch chuyển tới sau lưng đối thủ gần nhất.\\nNếu mục tiêu đang bị KHÓA HỒN: đòn Chém Đôi kế tiếp thành chí mạng.\\nKhông có mục tiêu thì lướt theo hướng ngắm."
		key_label = "E"
		cooldown = 5.5
		mana_cost = 14.0
		icon_color = Color("7c3aed")
''',
        '''	## Cửa sổ để lướt lần thứ hai miễn phí.
	const CHAIN_WINDOW := 1.2
	## Số lần lướt trong một chuỗi.
	const CHAIN_CHARGES := 2

	## Đồng hồ cửa sổ chuỗi. Khi hết mà chưa lướt tiếp thì vào hồi chiêu đầy.
	var _window := 0.0
	var _charges := CHAIN_CHARGES

	func _init() -> void:
		id = &"shadow_step"
		# INSTANT: bấm là lướt luôn, không có bước xác nhận. Chiêu này phải phản
		# xạ nhanh — thêm một cú bấm nữa là mất hết ý nghĩa né đòn.
		cast_type = SkillBase.CastType.INSTANT
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Ảnh Bộ"
		description = "Lướt tức thì theo hướng ngắm.\\nBấm lần nữa trong 1.2s để lướt tiếp lần hai.\\nNếu mục tiêu đang bị KHÓA HỒN: đòn Chém Đôi kế tiếp thành chí mạng."
		key_label = "E"
		cooldown = 5.0
		mana_cost = 14.0
		icon_color = Color("7c3aed")

	## Hết cửa sổ chuỗi mà chưa dùng lần hai thì khoá chiêu lại như bình thường.
	func tick(delta: float) -> void:
		if _window > 0.0:
			_window -= delta
			if _window <= 0.0:
				_charges = CHAIN_CHARGES
		super.tick(delta)

	func status_text() -> String:
		return ""
''',
    ),
    (
        "ShadowAssassin.gd",
        '''	func execute(aim: Vector2) -> void:
		var target := nearest_enemy_in_range(SEARCH_RANGE)
		if target == null:
			caster.begin_dash(aim.normalized(), DASH_SPEED, DASH_TIME)
			Audio.play_at(&"blink", caster.global_position, -4.0)
			return

		var behind := (target.global_position - caster.global_position)
		if behind.length_squared() < 0.01:
			behind = -aim
		var dest: Vector2 = target.global_position + behind.normalized() * BEHIND_OFFSET

		# Không dịch chuyển vào trong tường.
		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(dest, caster.body_radius + 2.0):
				dest = caster.global_position

		caster.global_position = dest
		caster.velocity = Vector2.ZERO
		# Sau khi dịch chuyển thì mặt hướng về mục tiêu.
		caster.aim_dir = (target.global_position - caster.global_position).normalized()
		Audio.play_at(&"teleport", caster.global_position)
''',
        '''	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		# Mặc định lướt theo hướng ngắm. Chỉ khi có đối thủ trong tầm VÀ họ đang
		# bị Khóa Hồn thì mới nhảy ra sau lưng — vì lúc đó mới có Chí Mạng để ăn.
		# Nếu không có điều kiện đó thì nhảy sau lưng chỉ làm mất phương hướng.
		var target := nearest_enemy_in_range(SEARCH_RANGE)
		var blink_behind := target != null and target.has_status(GameData.ST_MARK)

		if not blink_behind:
			caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
			Audio.play_at(&"blink", caster.global_position, -4.0)
			_cast_chain()
			return

		var behind := (target.global_position - caster.global_position)
		if behind.length_squared() < 0.01:
			behind = -aim
		var dest: Vector2 = target.global_position + behind.normalized() * BEHIND_OFFSET

		# Không dịch chuyển vào trong tường.
		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(dest, caster.body_radius + 2.0):
				dest = caster.global_position

		caster.global_position = dest
		caster.velocity = Vector2.ZERO
		# Sau khi dịch chuyển thì mặt hướng về mục tiêu.
		caster.aim_dir = (target.global_position - caster.global_position).normalized()
		Audio.play_at(&"teleport", caster.global_position)
		_cast_chain()

	## Mở cửa sổ lướt lần hai, hoặc đóng lại nếu đã dùng hết chuỗi.
	##
	## `try_cast` đã đặt hồi chiêu đầy trước khi gọi `execute`, nên ở đây chỉ
	## việc xoá nó đi khi vẫn còn lượt trong chuỗi.
	func _cast_chain() -> void:
		if _charges > 1:
			_charges -= 1
			_window = CHAIN_WINDOW
			cooldown_left = 0.0
		else:
			_charges = CHAIN_CHARGES
			_window = 0.0
''',
    ),
    # -------------------------------------------------------- Băng Sương Nữ
    (
        "FrostMaiden.gd",
        '''	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"ice_shard", start, -6.0, 0.7)
''',
        '''	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"ice_shard", start, -6.0, 0.7)

		# Tường băng dựng lại ngay chỗ vừa rời đi, vuông góc với hướng lướt.
		#
		# Đây là phần nâng cấp chính: Trượt Băng từ chỗ chỉ là "chạy trốn để lại
		# vệt chậm" thành chiêu có hai công dụng. Lướt ra xa thì có tường chắn
		# đạn phía sau; lướt xuyên qua đối thủ thì dựng tường ngay trước mặt họ.
		# Cùng một cú bấm, hai cách dùng — tuỳ hướng người chơi chọn.
		var perp := Vector2(-dir.y, dir.x)
		for i in range(3):
			var offset := (float(i) - 1.0) * 62.0
			caster.spawn_projectile({
				"kind": &"ice_wall",
				"position": start + perp * offset,
				"direction": perp,
				"speed": 0.0,
				"is_zone": true,
				"blocks_movement": true,
				"tick_damage": 2.0,
				"tick_interval": 0.6,
				"status_id": GameData.ST_SLOW,
				"status_stacks": 1,
				"status_duration": 1.5,
				"radius": 40.0,
				"life": 4.0,
				"accent": Color("bdf0ff"),
			})
''',
    ),
    # ---------------------------------------------------------- Lôi Đình
    (
        "ThunderWarrior.gd",
        '''	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"blink", start, -2.0, 0.9)

		for e in enemies():
			var d := _distance_to_segment(e.global_position, start, end)
			if d <= 40.0 + e.body_radius:
				e.take_damage(HIT_DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_CHARGE, 1, CHARGE_TIME, caster.peer_id)
''',
        '''	## Thời gian choáng khi lướt xuyên qua một mục tiêu.
	const STUN_TIME := 0.4
	## Sát thương của vết sét để lại tại chỗ xuất phát.
	const TRAIL_DAMAGE := 9.0

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"blink", start, -2.0, 0.9)

		# Vết sét tại chỗ vừa rời đi. Người chơi giỏi dùng nó để chặn đường
		# truy đuổi: lướt ra xa, kẻ bám theo chạy vào vết sét và bị choáng.
		caster.spawn_projectile({
			"kind": &"thunder_zone",
			"position": start,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TRAIL_DAMAGE,
			"tick_interval": 0.45,
			"status_id": GameData.ST_CHARGE,
			"status_stacks": 1,
			"status_duration": 4.0,
			"radius": 62.0,
			"life": 2.4,
			"accent": Color("fde047"),
		})
		Audio.play_at(&"thunder", start, -3.0, 1.4)

		for e in enemies():
			var d := _distance_to_segment(e.global_position, start, end)
			if d <= 40.0 + e.body_radius:
				e.take_damage(HIT_DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_CHARGE, 1, CHARGE_TIME, caster.peer_id)
				# Lướt XUYÊN QUA thì mới choáng. Đây là phần thưởng cho việc
				# chọn đúng hướng lướt thay vì lướt để chạy.
				e.add_status(GameData.ST_FREEZE, 1, STUN_TIME, caster.peer_id)
				caster.spawn_effect({
					"kind": &"explosion",
					"position": e.global_position,
					"radius": 50.0,
					"life": 0.3,
					"accent": Color("fff3b0"),
				})
''',
    ),
    # ------------------------------------------------------- Thạch Vệ Binh
    (
        "StoneGuardian.gd",
        '''	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(PLACE_DISTANCE, aim)
		# Không dựng tường vào trong vật cản sẵn có.
		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(center, WALL_RADIUS):
				center = caster.global_position + aim.normalized() * (PLACE_DISTANCE * 0.5)

		caster.spawn_projectile({
			"kind": &"stone_wall",
			"position": center,
			"direction": aim.normalized(),
			"speed": 0.0,
			"is_zone": true,
			"blocks_movement": true,
			"tick_damage": 0.0,
			"radius": WALL_RADIUS,
			"life": LIFETIME,
			"accent": Color("8a857e"),
		})
		Audio.play_at(&"stone_wall", center)
''',
        '''	## Số khối xếp thành một bức vách.
	const SEGMENTS := 3
	## Khoảng cách giữa tâm hai khối liền nhau.
	const SEGMENT_GAP := 58.0

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(PLACE_DISTANCE, aim)
		# Vách dựng vuông góc với hướng ngắm, nên nó chắn đúng đường đối thủ
		# muốn đi qua. Bản cũ dựng một khối tròn nên đối thủ chỉ cần đi vòng.
		var facing := (center - caster.global_position)
		if facing.length_squared() < 1.0:
			facing = aim
		var perp := Vector2(-facing.y, facing.x).normalized()

		var placed := 0
		for i in range(SEGMENTS):
			var offset := (float(i) - float(SEGMENTS - 1) * 0.5) * SEGMENT_GAP
			var pos: Vector2 = center + perp * offset
			# Bỏ qua khối nào rơi vào vật cản sẵn có, thay vì đẩy cả vách đi chỗ
			# khác — giữ được hình dạng vách như người chơi đã chọn.
			if caster.world != null and caster.world.has_method("is_blocked_at"):
				if caster.world.is_blocked_at(pos, WALL_RADIUS * 0.8):
					continue
			placed += 1
			caster.spawn_projectile({
				"kind": &"stone_wall",
				"position": pos,
				"direction": perp,
				"speed": 0.0,
				"is_zone": true,
				"blocks_movement": true,
				"tick_damage": 0.0,
				"radius": WALL_RADIUS * 0.86,
				"life": LIFETIME,
				"accent": Color("8a857e"),
			})
		if placed > 0:
			Audio.play_at(&"stone_wall", center)
''',
    ),
]


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "champions"
    failures = 0
    for filename, old, new in EDITS:
        path = root / filename
        if not path.exists():
            print("KHÔNG THẤY FILE:", filename)
            failures += 1
            continue
        text = path.read_text(encoding="utf-8")
        if new.strip()[:60] in text:
            print("đã áp rồi, bỏ qua:", filename)
            continue
        if old not in text:
            print("KHÔNG KHỚP ĐOẠN CẦN SỬA:", filename)
            failures += 1
            continue
        path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="")
        print("đã đại cải:", filename)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
