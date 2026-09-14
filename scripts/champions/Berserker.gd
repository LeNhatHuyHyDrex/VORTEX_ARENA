extends RefCounted
## CUỒNG CHIẾN — phái cuồng chiến, càng yếu máu càng điên.
##
## Ý tưởng thiết kế: toàn bộ sức mạnh của phái này nằm ở thanh máu của chính
## mình. Nội tại Tử Chiến tăng tới +45% sát thương khi cạn máu, nên hắn chủ
## động ĐỔI MÁU — không phải để chạy, mà là chiến thuật. Bộ kỹ năng vì vậy là
## bộ "nhảy vào giữa đám đông": Bước Nhảy nhảy qua đầu kẻ địch, Chiến Hào khoác
## khiên hét toáng quanh mình, Xoáy Rìu xoay tròn càn quét, Phán Quyết chặt
## xuống những kẻ đã lộ ra sơ hở.
##
## Chuỗi logic:
##   Q Bước Nhảy nhảy vào giữa đám đông, đập vỡ mặt đất
##   E Xoáy Rìu càn quét quanh người
##   W Chiến Hào giữ mạng khi đang đứng giữa bầy địch
##   máu càng cạn nội tại càng mạnh — đánh thường gào rú
##   R Phán Quyết chặt nốt mục tiêu còn ít máu

func build_champion(c: Champion) -> void:
	c.display_name = "Cuồng Chiến"
	c.max_hp = 132.0
	c.hp = c.max_hp
	c.max_mana = 90.0
	c.mana = c.max_mana
	c.mana_regen = 9.0
	c.move_speed = 252.0
	c.body_radius = 22.0
	c.accent = Color("f97316")
	c.skills.clear()
	for s in [LeapSlam.new(), WarCry.new(), SpinAxe.new(), Execution.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = AxeCleave.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [LeapSlam.new(), WarCry.new(), SpinAxe.new(), Execution.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return AxeCleave.new()


# ======================================================= ĐÁNH THƯỜNG — RÌU CHÉM
class AxeCleave extends SkillBase:
	const REACH := 104.0
	const HALF_ANGLE := 0.78
	const DAMAGE := 6.5

	func _init() -> void:
		id = &"axe_cleave"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 108.0
		aoe_radius = 0.0
		display_name = "Rìu Chém"
		description = "Vung rìu chém hình quạt phía trước.\nCàng cạn máu, vung rìu càng đau (nội tại Tử Chiến)."
		key_label = "LMB"
		cooldown = 0.48
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fb923c")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash", caster.global_position, -7.0, 0.7)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.15,
			"accent": Color("f97316"),
		})
		# Vệt chém rìu lớn — quét rộng và nặng hơn đòn tay thường.
		VFXLibrary.slash_arc(caster.world.fx,
			caster.global_position + dir * REACH * 0.6,
			Color(1.0, 0.55, 0.15), signf(dir.x) if absf(dir.x) > 0.15 else 1.0)


# ========================================================= Q — BƯỚC NHẢY CHÉM
class LeapSlam extends SkillBase:
	const DASH_SPEED := 850.0
	const DASH_TIME := 0.32
	const LANDING_RADIUS := 88.0
	const LANDING_DAMAGE := 12.0
	const SLOW_TIME := 1.2

	func _init() -> void:
		id = &"leap_slam"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 300.0
		aoe_radius = 88.0
		display_name = "Bước Nhảy Chém"
		description = "Nhảy vọt tới nơi chỉ định rồi đập rìu xuống đất:\n12 sát thương vùng + Chậm 1.2 giây. Cầu nối cận chiến."
		key_label = "Q"
		cooldown = 7.0
		mana_cost = 18.0
		icon_color = Color("fdba74")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_SPEED * DASH_TIME
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"dash_fire", start, -4.0, 0.9)
		# Sát thương tính theo ĐIỂM TIẾP ĐẤT, không tính theo đường bay —
		# đúng nghĩa "nhảy tới nơi rồi đập xuống".
		var landed := false
		for e in enemies_in_radius(end, LANDING_RADIUS):
			e.take_damage(LANDING_DAMAGE, caster.peer_id)
			e.add_status(GameData.ST_SLOW, 1, SLOW_TIME, caster.peer_id)
			landed = true
		Audio.play_at(&"hit_big", end, -2.0 if landed else -8.0, 0.8)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": end,
			"radius": LANDING_RADIUS,
			"life": 0.4,
			"accent": Color("f97316"),
		})
		for i in range(3):
			var p := start.lerp(end, float(i + 1) / 3.0) + Vector2(0, 8.0)
			caster.spawn_effect({
				"kind": &"dust",
				"position": p,
				"radius": 10.0,
				"life": 0.4,
				"accent": Color("7c2d12"),
			})


# ========================================================= W — CHIẾN HÀO
class WarCry extends SkillBase:
	const SHIELD := 18.0
	const HASTE_TIME := 2.5
	const FEAR_RADIUS := 140.0
	const SLOW_TIME := 1.5

	func _init() -> void:
		id = &"war_cry"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = FEAR_RADIUS
		display_name = "Chiến Hào"
		description = "Gào lên một tiếng: 18 khiên + Tăng Tốc 2.5 giây,\nđịch quanh mình bị Chậm 1.5 giây."
		key_label = "E"
		cooldown = 12.0
		mana_cost = 22.0
		icon_color = Color("ea580c")

	func execute(_aim: Vector2) -> void:
		caster.add_shield(SHIELD)
		caster.add_status(GameData.ST_HASTE, 1, HASTE_TIME, caster.peer_id)
		Audio.play_at(&"clash", caster.global_position, 0.0, 0.7)
		for e in enemies_in_radius(caster.global_position, FEAR_RADIUS):
			e.add_status(GameData.ST_SLOW, 1, SLOW_TIME, caster.peer_id)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": FEAR_RADIUS,
			"life": 0.5,
			"accent": Color("ea580c"),
		})


# ========================================================= E — XOÁY RÌU
class SpinAxe extends SkillBase:
	const RADIUS := 128.0
	const DAMAGE := 13.0
	const KNOCKBACK := 95.0

	func _init() -> void:
		id = &"spin_axe"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = RADIUS
		display_name = "Xoáy Rìu"
		description = "Xoay tròn rìu quanh người: 13 sát thương vùng,\nhất nhẹ mọi kẻ đang bám lấy mình."
		key_label = "R"
		cooldown = 7.0
		mana_cost = 24.0
		icon_color = Color("c2410c")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"slash", caster.global_position, -3.0, 0.9)
		for e in enemies_in_radius(caster.global_position, RADIUS):
			e.take_damage(DAMAGE, caster.peer_id)
			e.apply_knockback(e.global_position - caster.global_position, KNOCKBACK)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.35,
			"accent": Color("f97316"),
		})


# ========================================================= R — PHÁN QUYẾT
class Execution extends SkillBase:
	const REACH := 175.0
	const HALF_ANGLE := 0.55
	const BASE_DAMAGE := 14.0
	const MAX_BONUS := 30.0

	func _init() -> void:
		id = &"berserk_execution"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 185.0
		aoe_radius = 0.0
		display_name = "Phán Quyết"
		description = "Chặt một nhát dứt khoát: 14 sát thương, cộng thêm\ntới 30 theo MÁU ĐÃ MẤT của mục tiêu. Đòn kết liễu."
		key_label = "F"
		cooldown = 22.0
		mana_cost = 38.0
		icon_color = Color("9a3412")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"execute", caster.global_position, 0.0, 1.0)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			var missing := 1.0 - clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
			e.take_damage(BASE_DAMAGE + MAX_BONUS * missing, caster.peer_id)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.2,
			"accent": Color("dc2626"),
		})
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position + dir * REACH * 0.5,
			"radius": 90.0,
			"life": 0.35,
			"accent": Color("f97316"),
		})


# ============================================================ NỘI TẠI — TỬ CHIẾN
func build_passive():
	return DeathRage.new()


## Nội tại TỬ CHIẾN: sát thương tăng dần khi máu cạn, tối đa +45%.
##
## Vì sao +45% chứ không phải gấp đôi: con số này đủ để làm đối thủ hối hận khi
## bỏ mặc hắn ở 20% máu, nhưng chưa đủ để hắn bất tử khi đứng giữa đám
## đông — muốn ăn trọn nội tại vẫn phải dựa vào Chiến Hào và Xoáy Rìu để sống.
class DeathRage extends Passive:
	const MAX_BONUS := 0.45

	func _init() -> void:
		display_name = "Tử Chiến"
		description = "Máu càng cạn, sát thương càng cao — tối đa +45% khi gần chết."

	func outgoing_multiplier(_target: Champion) -> float:
		if owner_champ == null or not owner_champ.is_alive():
			return 1.0
		var hp_ratio := clampf(owner_champ.hp / maxf(owner_champ.max_hp, 1.0), 0.0, 1.0)
		return 1.0 + MAX_BONUS * (1.0 - hp_ratio)

	func status_text() -> String:
		if owner_champ == null:
			return ""
		var bonus := int(round((outgoing_multiplier(null) - 1.0) * 100.0))
		return "Tử Chiến · +%d%%" % bonus
