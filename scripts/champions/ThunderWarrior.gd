extends RefCounted
const VFXLibrary := preload("res://scripts/vfx/VFXLibrary.gd")
## LÔI ĐÌNH CHIẾN BINH — tướng sát thương lan, cơ động, nhưng phải "nạp" trước.
##
## Ý tưởng thiết kế: sét không tự mạnh. Muốn mạnh phải cắm TÍCH ĐIỆN lên mục
## tiêu trước, rồi mới giật. Tích Điện không gây sát thương gì cả — nó chỉ là
## điều kiện để các chiêu khác phát huy. Nghĩa là người chơi phải chủ động mở
## màn bằng W hoặc E, chứ không thể bấm Q liên tục.
##
## Chuỗi logic:
##   W lướt qua -> dính Tích Điện
##   Q bắn trúng mục tiêu đang Tích Điện -> sét LAN sang những kẻ đứng gần
##   E vừa cho bản thân Chí Mạng, vừa cắm Tích Điện quanh người
##   R giáng sét xuống một vùng; ai đang Tích Điện thì bị choáng

func build_champion(c: Champion) -> void:
	c.display_name = "Lôi Đình Chiến Binh"
	c.max_hp = 100.0
	c.hp = c.max_hp
	c.max_mana = 95.0
	c.mana = c.max_mana
	c.mana_regen = 10.0
	c.move_speed = 268.0
	c.body_radius = 21.0
	c.accent = Color("facc15")
	c.skills.clear()
	for s in [ThunderStrike.new(), LightningDash.new(), ChargeUp.new(), HeavensThunder.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = SparkShot.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [ThunderStrike.new(), LightningDash.new(), ChargeUp.new(), HeavensThunder.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return SparkShot.new()


# ======================================================= ĐÁNH THƯỜNG — TIA CHỚP
class SparkShot extends SkillBase:
	func _init() -> void:
		id = &"spark_shot"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 620.0
		aoe_radius = 0.0
		display_name = "Tia Chớp"
		description = "Bắn tia điện nhỏ. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.4
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("ffe066")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"thunder_bolt",
			"direction": aim,
			"speed": 760.0,
			"damage": 6.0,
			"radius": 7.0,
			"life": 1.05,
			"power": 0.9,
			"accent": Color("ffe066"),
		})
		Audio.play_at(&"chain", caster.global_position, -11.0, 1.4)


# ========================================================= Q — SÉT ĐÁNH
class ThunderStrike extends SkillBase:
	const CHAIN_RADIUS := 230.0
	const CHAIN_DAMAGE := 9.0
	## Chỉ lan khi mục tiêu đã bị cắm Tích Điện.
	const CHAIN_REQUIRES := GameData.ST_CHARGE

	func _init() -> void:
		id = &"thunder_strike"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 700.0
		aoe_radius = 0.0
		display_name = "Sét Đánh"
		description = "Phóng tia sét mạnh.\nNếu trúng mục tiêu ĐANG TÍCH ĐIỆN thì sét LAN sang những kẻ đứng gần."
		key_label = "Q"
		cooldown = 3.0
		mana_cost = 13.0
		icon_color = Color("facc15")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"thunder_strike",
			"direction": aim,
			"speed": 820.0,
			"damage": 12.0,
			"radius": 10.0,
			"life": 1.15,
			"power": 2.4,
			"accent": Color("facc15"),
			# Điều kiện lan được khai báo ngay trên đạn, để Projectile tự xử lý
			# lúc trúng đích thay vì phải viết riêng cho từng chiêu.
			"chain_radius": CHAIN_RADIUS,
			"chain_damage": CHAIN_DAMAGE,
			"chain_requires": CHAIN_REQUIRES,
			"chain_status": GameData.ST_CHARGE,
		})
		Audio.play_at(&"thunder", caster.global_position)


# ======================================================= W — LƯỚT SÉT
class LightningDash extends SkillBase:
	const DASH_SPEED := 1150.0
	const DASH_TIME := 0.16
	const DASH_REACH := 240.0
	const HIT_DAMAGE := 8.0
	const CHARGE_TIME := 5.0

	func _init() -> void:
		id = &"lightning_dash"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 280.0
		preview_shape = SkillBase.PreviewShape.DASH
		aoe_radius = 0.0
		display_name = "Lướt Sét"
		description = "Lướt nhanh theo hướng ngắm.\nMọi kẻ bị xuyên qua đều dính TÍCH ĐIỆN."
		key_label = "E"
		cooldown = 5.5
		mana_cost = 15.0
		icon_color = Color("fde047")

	## Thời gian choáng khi lướt xuyên qua một mục tiêu.
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
				caster.spawn_effect({
					"kind": &"explosion",
					"position": e.global_position,
					"radius": 42.0,
					"life": 0.25,
					"accent": Color("ffe066"),
				})

	func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 0.0001:
			return p.distance_to(a)
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		return p.distance_to(a + ab * t)


# ========================================================= E — NẠP ĐIỆN
class ChargeUp extends SkillBase:
	const RADIUS := 265.0
	const EMPOWER_TIME := 4.0
	const CHARGE_TIME := 6.0

	func _init() -> void:
		id = &"charge_up"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 260.0
		display_name = "Nạp Điện"
		description = "Bản thân nhận CHÍ MẠNG cho đòn kế tiếp.\nĐồng thời cắm TÍCH ĐIỆN lên mọi đối thủ quanh người."
		key_label = "R"
		cooldown = 9.0
		mana_cost = 20.0
		icon_color = Color("ffd24a")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"shield", caster.global_position, -2.0, 0.8)
		caster.add_status(GameData.ST_EMPOWER, 1, EMPOWER_TIME, caster.peer_id)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.4,
			"accent": Color("fde047"),
		})
		for e in enemies_in_radius(caster.global_position, RADIUS):
			e.add_status(GameData.ST_CHARGE, 1, CHARGE_TIME, caster.peer_id)


# ==================================================== R — THIÊN LÔI
class HeavensThunder extends SkillBase:
	const CAST_RANGE := 430.0
	const RADIUS := 155.0
	const DAMAGE := 34.0
	## Cắm thêm sát thương nếu mục tiêu đang Tích Điện, và làm choáng.
	const CHARGED_BONUS := 18.0
	const STUN_TIME := 0.8

	func _init() -> void:
		id = &"heavens_thunder"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 520.0
		aoe_radius = 155.0
		display_name = "Thiên Lôi"
		description = "Giáng sét xuống vị trí đang ngắm.\nMục tiêu ĐANG TÍCH ĐIỆN chịu thêm sát thương và bị choáng."
		key_label = "F"
		cooldown = 26.0
		mana_cost = 42.0
		icon_color = Color("f59e0b")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(CAST_RANGE, aim)
		Audio.play_at(&"thunder", center, 3.0)
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.lightning_strike(caster.world.fx, center)
			# Lớp nổ cầu sét + sóng kép — ultimate phải lớn hơn chiêu thường.
			VFXLibrary.lightning_burst(caster.world.fx, center, RADIUS, 1)
		VFXLibrary.ult_shake(self, 7.0)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": center,
			"radius": RADIUS,
			"life": 0.55,
			"accent": Color("fff3b0"),
		})
		for e in enemies_in_radius(center, RADIUS):
			var charged: bool = e.has_status(GameData.ST_CHARGE)
			var dmg := DAMAGE + (CHARGED_BONUS if charged else 0.0)
			if charged:
				e.consume_status(GameData.ST_CHARGE)
				e.add_status(GameData.ST_FREEZE, 1, STUN_TIME, caster.peer_id)
			e.take_damage(dmg, caster.peer_id)
			e.apply_knockback(e.global_position - center, 260.0)
			caster.spawn_effect({
				"kind": &"explosion",
				"position": e.global_position,
				"radius": 60.0,
				"life": 0.35,
				"accent": Color("facc15"),
			})


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
