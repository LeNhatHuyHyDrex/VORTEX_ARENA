extends RefCounted
## LUYỆN THUẬT SƯ — đặt bẫy, dựng máy, kiểm soát khu vực.
##
## Ý tưởng thiết kế: tướng duy nhất trong game chơi bằng cách CHUẨN BỊ TRƯỚC.
## Mọi tướng khác phản ứng theo đối thủ; Luyện Thuật Sư thì sửa đổi sân đấu rồi
## bắt đối thủ phải đánh trong cái sân đã bị sửa đó.
##
##   - Nội tại Chế Tạo: cứ 8 giây tự đặt một quả mìn sau lưng
##   - Q Mìn Nổ: đặt mìn, nổ khi đối thủ đi qua
##   - R Bẫy Laser: hàng rào chắn ngang, đi qua là mất máu
##   - F Pháo Cố Định: dựng trụ pháo tự động bắn trong 5 giây
##
## Người chơi giỏi sẽ dồn đối thủ vào một góc đã rải mìn từ trước. Người mới sẽ
## rải mìn ngẫu nhiên rồi tự đi vào.

func build_champion(c: Champion) -> void:
	c.display_name = "Luyện Thuật Sư"
	c.max_hp = 100.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 11.0
	c.move_speed = 246.0
	c.body_radius = 22.0
	c.accent = Color("fb923c")
	c.skills.clear()
	for s in [LayMine.new(), ArcWelder.new(), LaserFence.new(), AutoCannon.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = HammerSwing.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [LayMine.new(), ArcWelder.new(), LaserFence.new(), AutoCannon.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return HammerSwing.new()

func build_passive():
	return Fabricate.new()


# ======================================================= ĐÁNH THƯỜNG — BÚA CƠ KHÍ
class HammerSwing extends SkillBase:
	const RANGE := 500.0
	const SPEED := 700.0
	const DAMAGE := 6.5

	func _init() -> void:
		id = &"hammer_swing"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 520.0
		aoe_radius = 0.0
		display_name = "Tia Điện Cơ Khí"
		description = "Bắn một tia điện từ búa cơ khí, tầm xa.\nKhông tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.55
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fdba74")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"spark_shot",
			"direction": aim,
			"speed": SPEED,
			"damage": DAMAGE,
			"radius": 7.0,
			"life": RANGE / SPEED,
			"power": 1.0,
			"accent": Color("fcd34d"),
		})
		Audio.play_at(&"chain", caster.global_position, -12.0, 1.5)


# ============================================================= Q — MÌN NỔ
class LayMine extends SkillBase:
	const RADIUS := 78.0
	const DAMAGE := 26.0
	const ARM_TIME := 0.6
	const LIFETIME := 14.0

	func _init() -> void:
		id = &"lay_mine"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 380.0
		aoe_radius = RADIUS
		display_name = "Mìn Nổ"
		description = "Đặt một quả mìn tại vùng đã chọn.\nMìn nổ khi đối thủ bước vào, gây sát thương và đẩy lùi. Tồn tại 14 giây."
		key_label = "Q"
		cooldown = 6.0
		mana_cost = 16.0
		icon_color = Color("fb923c")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"ui_click", center, -8.0, 0.8)
		caster.spawn_projectile({
			"kind": &"mine",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": DAMAGE,
			"tick_interval": 99.0,     # chỉ nổ một lần
			"radius": RADIUS,
			"life": LIFETIME,
			"accent": Color("fb923c"),
		})


# =========================================================== E — SÚNG ĐIỆN
class ArcWelder extends SkillBase:
	const DAMAGE := 7.0
	const SHOTS := 3

	func _init() -> void:
		id = &"arc_welder"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 560.0
		aoe_radius = 0.0
		display_name = "Súng Điện"
		description = "Bắn ba tia điện liên tiếp theo hình quạt.\nCàng nhiều tia trúng một mục tiêu thì càng đau."
		key_label = "E"
		cooldown = 5.0
		mana_cost = 18.0
		icon_color = Color("fdba74")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"spark_shot", caster.global_position, -6.0, 1.2)
		# Ba tia xoè nhẹ, nên ở tầm gần cả ba cùng trúng — đó là phần thưởng cho
		# việc áp sát, đổi lại phải chịu rủi ro ở gần.
		var spreads: Array[float] = [-0.16, 0.0, 0.16]
		for sp in spreads:
			caster.spawn_projectile({
				"kind": &"arc_bolt",
				"direction": dir.rotated(sp),
				"speed": 880.0,
				"damage": DAMAGE,
				"radius": 8.0,
				"life": 0.75,
				"power": 1.2,
				"accent": Color("fed7aa"),
			})


# ========================================================== R — BẪY LASER
class LaserFence extends SkillBase:
	const RADIUS := 46.0
	const DAMAGE := 4.0
	const LIFETIME := 7.0
	const SEGMENTS := 5
	const GAP := 54.0

	func _init() -> void:
		id = &"laser_fence"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 400.0
		aoe_radius = RADIUS
		display_name = "Bẫy Laser"
		description = "Dựng một hàng rào laser vuông góc với hướng ngắm.\nĐối thủ đi qua chịu sát thương liên tục và bị làm chậm."
		key_label = "R"
		cooldown = 15.0
		mana_cost = 30.0
		icon_color = Color("f87171")

	func execute(aim: Vector2) -> void:
		var center := ground_point(cast_range)
		var facing := center - caster.global_position
		if facing.length_squared() < 1.0:
			facing = aim
		var perp := Vector2(-facing.y, facing.x).normalized()

		Audio.play_at(&"ui_select", center, -2.0, 0.9)
		for i in range(SEGMENTS):
			var offset := (float(i) - float(SEGMENTS - 1) * 0.5) * GAP
			caster.spawn_projectile({
				"kind": &"laser_fence",
				"position": center + perp * offset,
				"direction": perp,
				"speed": 0.0,
				"is_zone": true,
				"tick_damage": DAMAGE,
				"tick_interval": 0.35,
				"status_id": GameData.ST_SLOW,
				"status_stacks": 1,
				"status_duration": 0.8,
				"radius": RADIUS,
				"life": LIFETIME,
				"accent": Color("fca5a5"),
			})


# ======================================================= F — PHÁO CỐ ĐỊNH
class AutoCannon extends SkillBase:
	const RADIUS := 110.0
	const DAMAGE := 8.0
	const LIFETIME := 5.0
	const TICK := 0.45

	func _init() -> void:
		id = &"auto_cannon"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 420.0
		aoe_radius = RADIUS
		display_name = "Pháo Cố Định"
		description = "Dựng một trụ pháo tự động bắn mọi đối thủ trong tầm, trong 5 giây.\nĐứng gần trụ thì nó bắn nhanh hơn."
		key_label = "F"
		cooldown = 26.0
		mana_cost = 42.0
		icon_color = Color("fdba74")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"stone_wall", center, -2.0, 1.2)
		caster.spawn_projectile({
			"kind": &"autocannon",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": DAMAGE,
			"tick_interval": TICK,
			"radius": RADIUS,
			"life": LIFETIME,
			"accent": Color("fdba74"),
		})
		caster.spawn_effect({
			"kind": &"explosion",
			"position": center,
			"radius": 80.0,
			"life": 0.4,
			"accent": Color("fed7aa"),
		})


# ======================================================= NỘI TẠI — CHẾ TẠO
class Fabricate extends Passive:
	const INTERVAL := 8.0
	const MINE_DAMAGE := 18.0
	const MINE_RADIUS := 70.0
	const MINE_LIFE := 12.0

	var _timer := 0.0

	func _init() -> void:
		display_name = "Chế Tạo"
		description = "Mỗi 8 giây tự đặt một quả mìn nhỏ ngay sau lưng. Không tốn năng lượng, không tốn hồi chiêu."

	func tick(delta: float) -> void:
		if owner_champ == null or not owner_champ.is_alive():
			return
		_timer += delta
		if _timer < INTERVAL:
			return
		_timer = 0.0
		# Đặt ngay sau lưng, không phải dưới chân — nếu đặt dưới chân thì chính
		# người chơi sẽ kích hoạt mìn của mình khi lùi lại.
		var back := -owner_champ.aim_dir
		var pos: Vector2 = owner_champ.global_position + back * 62.0
		if owner_champ.world != null and owner_champ.world.has_method("is_blocked_at"):
			if owner_champ.world.is_blocked_at(pos, 24.0):
				pos = owner_champ.global_position + back * 34.0
		owner_champ.spawn_projectile({
			"kind": &"mine",
			"position": pos,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": MINE_DAMAGE,
			"tick_interval": 99.0,
			"radius": MINE_RADIUS,
			"life": MINE_LIFE,
			"accent": Color("fdba74"),
		})

	func status_text() -> String:
		return "Chế Tạo · %.1fs" % maxf(0.0, INTERVAL - _timer)
