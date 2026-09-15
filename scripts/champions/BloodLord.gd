extends RefCounted
## HUYẾT BÁ — đấu sĩ hút máu, cận chiến là môi trường sống của hắn.
##
## Ý tưởng thiết kế: mọi nguồn sát thương của Huyết Bá đều hoàn lại máu — nội
## tại hút 10%, Q hút 40%, lướt và vùng R hồi trực tiếp. Nhờ vậy hắn KHÔNG sợ
## đổi máu: càng đứng gần càng lâu, càng lợi. Bù lại hắn thiếu chiêu khống chế
## cứng và di chuyển chậm hơn sát thủ, nên đối thủ biết giữ khoảng cách thì
## hắn đói.
##
## Chuỗi logic:
##   W Đàn Dơi lao xuyên người -> vừa damage vừa hồi
##   đánh thường giữ chân mục tiêu ở cự ly vuốt
##   Q Huyết Tiễn bắn từ xa để hồi máu khi không áp sát nổi
##   E Trường Sinh sống sót qua đợt burst
##   R Dòng Máu nhốt địch trong vùng hút -> hắn hồi, đối thủ cạn

func build_champion(c: Champion) -> void:
	c.display_name = "Huyết Bá"
	c.max_hp = 112.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 10.0
	c.move_speed = 256.0
	c.body_radius = 21.0
	c.accent = Color("dc2626")
	c.skills.clear()
	for s in [BloodBolt.new(), BatSwarm.new(), Longevity.new(), BloodPool.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = BloodClaws.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [BloodBolt.new(), BatSwarm.new(), Longevity.new(), BloodPool.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return BloodClaws.new()


# ======================================================= ĐÁNH THƯỜNG — VUỐT MÁU
class BloodClaws extends SkillBase:
	const REACH := 92.0
	const HALF_ANGLE := 0.75
	const DAMAGE := 5.5
	## Mỗi kẻ trúng đòn hoàn lại chút máu — đánh thường cũng nuôi được.
	const HEAL_PER_HIT := 1.0

	func _init() -> void:
		id = &"blood_claws"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 96.0
		aoe_radius = 0.0
		display_name = "Vuốt Máu"
		description = "Cào về phía trước, mỗi kẻ trúng hồi bạn 1 máu."
		key_label = "LMB"
		cooldown = 0.42
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("f87171")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash", caster.global_position, -8.0, 0.8)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			if e.take_damage(DAMAGE, caster.peer_id):
				caster.heal(HEAL_PER_HIT)
			e.apply_knockback(e.global_position - caster.global_position, 50.0)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.16,
			"accent": Color("ef4444"),
		})
		# Vệt vuốt đỏ — cú cào móng máu quét qua mục tiêu.
		VFXLibrary.slash_arc(caster.world.fx,
			caster.global_position + dir * REACH * 0.55,
			Color(1.0, 0.3, 0.3), signf(dir.x) if absf(dir.x) > 0.15 else 1.0)


# ========================================================= Q — HUYẾT TIẾN
class BloodBolt extends SkillBase:
	const LIFESTEAL := 0.4

	func _init() -> void:
		id = &"blood_bolt"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 500.0
		aoe_radius = 0.0
		display_name = "Huyết Tiễn"
		description = "Phóng mũi máu mạnh, hút 40% sát thương gây ra làm máu."
		key_label = "Q"
		cooldown = 3.0
		mana_cost = 12.0
		icon_color = Color("ef4444")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"phantom_edge",
			"direction": aim,
			"speed": 700.0,
			"damage": 12.0,
			"radius": 9.0,
			"life": 1.15,
			"power": 1.5,
			"lifesteal": LIFESTEAL,
			"accent": Color("ef4444"),
		})
		Audio.play_at(&"void_bolt", caster.global_position, -9.0, 0.7)
		# Lóe huyết sắc tại tay phóng — viên đạn máu cần khởi đầu đỏ thẫm.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.cast_flash(caster.world.fx,
				caster.global_position + aim.normalized() * 24.0, Color("ef4444"))


# ========================================================= W — ĐÀN DƠI
class BatSwarm extends SkillBase:
	const DASH_SPEED := 1050.0
	const DASH_TIME := 0.2
	const DASH_REACH := 250.0
	const HIT_DAMAGE := 8.0
	const SLOW_TIME := 1.5
	## Hồi máu mỗi kẻ bị xuyên qua — cơ chế sống còn của chiêu này.
	const HEAL_PER_ENEMY := 3.0

	func _init() -> void:
		id = &"bat_swarm"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 280.0
		aoe_radius = 0.0
		display_name = "Đàn Dơi"
		description = "Hoá đàn dơi lướt xuyên người: 8 sát thương + Chậm,\nvà hồi 3 máu MỖI kẻ bị xuyên qua."
		key_label = "E"
		cooldown = 5.0
		mana_cost = 15.0
		icon_color = Color("f87171")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"blink", start, -4.0, 1.2)
		# Đàn dơi: vệt khói đỏ dọc đường lướt + vòng huyết tại điểm đến.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.spell_seq(caster.world.fx, "fx10_blackExplosion",
				start.lerp(end, 0.5), 1.0, Color(0.7, 0.2, 0.25, 0.6), 20.0,
				rad_to_deg(dir.angle()), true)
			VFXLibrary.shock_ring(caster.world.fx, end, 52.0,
				Color(0.85, 0.3, 0.3, 0.5), 0.3)
		var healed := 0
		for e in enemies():
			var ab := end - start
			var len2 := ab.length_squared()
			var t := clampf((e.global_position - start).dot(ab) / maxf(len2, 0.001), 0.0, 1.0)
			var d: float = e.global_position.distance_to(start + ab * t)
			if d <= 44.0 + e.body_radius:
				e.take_damage(HIT_DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_SLOW, 1, SLOW_TIME, caster.peer_id)
				healed += 1
				caster.spawn_effect({
					"kind": &"explosion",
					"position": e.global_position,
					"radius": 46.0,
					"life": 0.3,
					"accent": Color("ef4444"),
				})
		if healed > 0:
			caster.heal(HEAL_PER_ENEMY * healed)
		# Vệt dơi tan dọc đường lướt.
		for i in range(4):
			var p := start.lerp(end, float(i + 1) / 4.0)
			caster.spawn_effect({
				"kind": &"dust",
				"position": p,
				"radius": 9.0,
				"life": 0.4,
				"accent": Color("7f1d1d"),
			})


# ========================================================= E — TRƯỜNG SINH
class Longevity extends SkillBase:
	const SHIELD := 24.0
	const HEAL := 10.0

	func _init() -> void:
		id = &"longevity"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 90.0
		display_name = "Trường Sinh"
		description = "Nhận 24 khiên và hồi 10 máu.\nChiêu sống sót để đổi tiếp máu ở giây kế tiếp."
		key_label = "R"
		cooldown = 11.0
		mana_cost = 22.0
		icon_color = Color("b91c1c")

	func execute(_aim: Vector2) -> void:
		caster.add_shield(SHIELD)
		caster.heal(HEAL)
		Audio.play_at(&"shield", caster.global_position, -4.0, 0.7)
		# Trường sinh: huyết quang dịu nở quanh người khi hồi máu.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.cast_flash(caster.world.fx, caster.global_position, Color("f87171"))
			VFXLibrary.shock_ring(caster.world.fx, caster.global_position, 78.0,
				Color(0.95, 0.45, 0.45, 0.45), 0.4)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 90.0,
			"life": 0.45,
			"accent": Color("b91c1c"),
		})


# ========================================================= R — DÒNG MÁU
class BloodPool extends SkillBase:
	const CAST_RANGE := 460.0
	const RADIUS := 150.0
	const TICK_DAMAGE := 7.0
	const TICK_INTERVAL := 0.55
	const LIFESTEAL := 0.7
	const PULL := 55.0

	func _init() -> void:
		id = &"blood_pool"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 480.0
		aoe_radius = 150.0
		display_name = "Dòng Máu"
		description = "Mở vùng máu hút địch vào giữa: rút máu theo nhịp,\nmọi sát thương vùng gây ra hoàn 70% về bạn."
		key_label = "F"
		cooldown = 24.0
		mana_cost = 40.0
		icon_color = Color("7f1d1d")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(CAST_RANGE, aim)
		Audio.play_at(&"void_bolt", center, 0.0, 0.6)
		caster.spawn_projectile({
			"kind": &"black_hole",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TICK_DAMAGE,
			"tick_interval": TICK_INTERVAL,
			"lifesteal": LIFESTEAL,
			"pull_strength": PULL,
			"radius": RADIUS,
			"life": 3.6,
			"accent": Color("dc2626"),
		})
		# Dòng Máu (ULT): quả cầu huyết nổ tier-ultimate + nền đất đỏ thẫm.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.arcane_blast(caster.world.fx, center, RADIUS,
				Color(0.85, 0.2, 0.25), 1)
			VFXLibrary.spell_seq(caster.world.fx, "fx9_rainOnGround", center,
				RADIUS / 110.0, Color(0.8, 0.25, 0.3, 0.55), 16.0, 0.0, false, false, false)
		VFXLibrary.ult_shake(self, 6.5)


# ============================================================ NỘI TẠI — HẤP HUYẾT
func build_passive():
	return BloodDrinker.new()


## Nội tại HẤP HUYẾT: mọi sát thương gây ra đều hoàn lại 10% thành máu.
##
## Hút ở mức 10% là đủ để cận chiến thắng được đường đổi máu, nhưng không đủ
## để bắn từ xa vô hại — muốn hồi máu phải dám lao vào nhận đòn.
class BloodDrinker extends Passive:
	const LIFESTEAL := 0.10

	func _init() -> void:
		display_name = "Hấp Huyết"
		description = "Mọi sát thương gây ra hoàn lại 10% thành máu của bạn."

	func on_deal_damage(target: Champion, amount: float) -> void:
		if owner_champ == null or not owner_champ.is_alive():
			return
		if amount < 1.0:
			return
		owner_champ.heal(amount * LIFESTEAL)

	func status_text() -> String:
		return "Hấp Huyết"
