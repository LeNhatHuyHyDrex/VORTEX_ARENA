extends RefCounted
## THẠCH VỆ BINH — tướng chống chịu, mạnh về việc chiếm địa hình.
##
## Ý tưởng thiết kế: đây là tướng duy nhất thay đổi được bản đồ giữa trận. Tường
## Đá không gây sát thương nhưng chặn đường, chặn cả đạn — nghĩa là nó vô hiệu
## hoá đòn tầm xa của đối thủ mà không cần đánh trúng ai.
##
## Ngoài ra Đá Lăn có sức mạnh đạn cao nhất game (4.5), nên trong mọi cuộc đối
## đầu đạn-đạn thì đá luôn thắng. Đổi lại nó bay chậm, đối thủ kịp né.
##
## Chuỗi logic:
##   E dán Vỡ Giáp lên kẻ đứng gần -> R giáng xuống thì chúng bị choáng
##   W dựng tường chặn đạn -> ung dung đi vào đè
##   Q đá lăn đè bẹp mọi đòn tầm xa đối phương

func build_champion(c: Champion) -> void:
	c.display_name = "Thạch Vệ Binh"
	c.max_hp = 125.0
	c.hp = c.max_hp
	c.max_mana = 90.0
	c.mana = c.max_mana
	c.mana_regen = 9.0
	c.move_speed = 228.0
	c.body_radius = 24.0
	c.accent = Color("a8a29e")
	c.skills.clear()
	for s in [BoulderRoll.new(), StoneWall.new(), StoneShield.new(), Earthquake.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = RockThrow.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [BoulderRoll.new(), StoneWall.new(), StoneShield.new(), Earthquake.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return RockThrow.new()


# ======================================================= ĐÁNH THƯỜNG — NÉM ĐÁ
class RockThrow extends SkillBase:
	func _init() -> void:
		id = &"rock_throw"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 620.0
		aoe_radius = 0.0
		display_name = "Ném Đá"
		description = "Ném một hòn đá. Bay chậm nhưng nặng, đè được đạn yếu hơn."
		key_label = "LMB"
		cooldown = 0.7
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("b8b2ac")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"boulder",
			"direction": aim,
			"speed": 540.0,
			"damage": 8.0,
			"radius": 9.0,
			"life": 1.5,
			"power": 1.6,
			"accent": Color("a8a29e"),
		})
		Audio.play_at(&"stone_throw", caster.global_position, -8.0, 1.25)


# ========================================================= Q — ĐÁ LĂN
class BoulderRoll extends SkillBase:
	## Sức mạnh đạn cao nhất game — thắng mọi cuộc đối đầu đạn-đạn.
	const POWER := 4.5

	func _init() -> void:
		id = &"boulder_roll"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 760.0
		aoe_radius = 0.0
		display_name = "Đá Lăn"
		description = "Lăn một tảng đá lớn, xuyên qua nhiều mục tiêu.\nSức mạnh đạn cao nhất game: đè bẹp mọi đòn tầm xa của đối thủ."
		key_label = "Q"
		cooldown = 6.0
		mana_cost = 20.0
		icon_color = Color("8a857e")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"boulder",
			"direction": aim,
			"speed": 360.0,
			"damage": 20.0,
			"radius": 20.0,
			"life": 2.4,
			"power": POWER,
			"pierce_left": 2,
			"accent": Color("a8a29e"),
		})
		Audio.play_at(&"stone_throw", caster.global_position, 2.0, 0.8)


# ========================================================= W — TƯỜNG ĐÁ
class StoneWall extends SkillBase:
	const PLACE_DISTANCE := 165.0
	const WALL_RADIUS := 56.0
	const LIFETIME := 6.0

	func _init() -> void:
		id = &"stone_wall"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 340.0
		aoe_radius = 56.0
		display_name = "Tường Đá"
		description = "Dựng một bức tường đá chắn trước mặt.\nChặn cả đường đi lẫn đường bay của đạn, tồn tại 6 giây."
		key_label = "E"
		cooldown = 12.0
		mana_cost = 26.0
		icon_color = Color("6b6660")

	## Số khối xếp thành một bức vách.
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


# ========================================================= E — KHIÊN ĐÁ
class StoneShield extends SkillBase:
	const SHIELD_AMOUNT := 45.0
	const RADIUS := 190.0
	const BREAK_TIME := 5.0

	func _init() -> void:
		id = &"stone_shield"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 190.0
		display_name = "Khiên Đá"
		description = "Bọc mình trong khiên đá hấp thụ sát thương.\nĐồng thời dán VỠ GIÁP lên đối thủ đứng gần."
		key_label = "R"
		cooldown = 10.0
		mana_cost = 18.0
		icon_color = Color("22d3ee")

	func execute(_aim: Vector2) -> void:
		caster.add_shield(SHIELD_AMOUNT)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.4,
			"accent": Color("22d3ee"),
		})
		for e in enemies_in_radius(caster.global_position, RADIUS):
			e.add_status(GameData.ST_BREAK, 1, BREAK_TIME, caster.peer_id)


# ========================================================= R — ĐỊA CHẤN
class Earthquake extends SkillBase:
	const RADIUS := 270.0
	const DAMAGE := 24.0
	const BREAK_BONUS := 14.0
	const STUN_TIME := 1.2

	func _init() -> void:
		id = &"earthquake"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 300.0
		display_name = "Địa Chấn"
		description = "Đập mạnh xuống đất, hất văng mọi kẻ quanh người.\nMục tiêu đang VỠ GIÁP chịu thêm sát thương và bị choáng."
		key_label = "F"
		cooldown = 27.0
		mana_cost = 40.0
		icon_color = Color("f97316")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"stone_wall", caster.global_position, 3.0, 0.7)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.55,
			"accent": Color("d6d3d1"),
		})
		# Sóng địa chấn bung bụi đá — vòng nâu xám nở tròn từ điểm đập.
		VFXLibrary.arcane_burst(caster.world.fx, caster.global_position,
			Color("a8a29e"), RADIUS * 0.85)
		for e in enemies_in_radius(caster.global_position, RADIUS):
			var broken: bool = e.has_status(GameData.ST_BREAK)
			var dmg := DAMAGE + (BREAK_BONUS if broken else 0.0)
			if broken:
				e.consume_status(GameData.ST_BREAK)
				e.add_status(GameData.ST_FREEZE, 1, STUN_TIME, caster.peer_id)
			e.take_damage(dmg, caster.peer_id)
			e.apply_knockback(e.global_position - caster.global_position, 320.0)
			caster.spawn_effect({
				"kind": &"explosion",
				"position": e.global_position,
				"radius": 55.0,
				"life": 0.32,
				"accent": Color("f97316"),
			})


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
