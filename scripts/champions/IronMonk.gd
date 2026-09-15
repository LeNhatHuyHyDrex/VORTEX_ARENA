extends RefCounted
## THIẾT QUYỀN SƯ — võ tăng thép, đi kiếm bằng nắm đấm và nhịp thở.
##
## Ý tưởng thiết kế: một chiến binh cận chiến "đánh nhịp" — mỗi 3 chiêu tung ra,
## nắm đấm kế tiếp hoá chí mạng. Nhờ vậy ông không spam chiêu vô nghĩa: muốn
## cú đấm to, phải xoay đủ bộ kỹ năng. Ông cũng là "điểm neo" của giao tranh:
## khiên Chung Vàng và cú hất của Thiên Chưởng Ấn giúp ông đứng vững giữa đám
## đông, còn Phong Bộ cho phép áp sát hoặc rút lui đúng nhịp.
##
## Chuỗi logic:
##   Q Phong Bộ lao vào tầm đấm
##   E Thiên Chưởng Ấn dán Vỡ Giáp + hất văng
##   đánh thường chí mạng (từ nội tại) thu hoạch
##   W Chung Vàng sống sót qua đợt burst
##   R Nhất Quyền Trấn Hồn dứt điểm, mạnh hơn khi mục tiêu đã Vỡ Giáp

func build_champion(c: Champion) -> void:
	c.display_name = "Thiết Quyền Sư"
	c.max_hp = 124.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 10.0
	c.move_speed = 262.0
	c.body_radius = 21.0
	c.accent = Color("f59e0b")
	c.skills.clear()
	for s in [WindStep.new(), GoldenBell.new(), HeavenPalm.new(), IronVerdict.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = IronFist.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [WindStep.new(), GoldenBell.new(), HeavenPalm.new(), IronVerdict.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return IronFist.new()


# ======================================================= ĐÁNH THƯỜNG — THIẾT QUYỀN
class IronFist extends SkillBase:
	const REACH := 96.0
	const HALF_ANGLE := 0.72
	const DAMAGE := 6.0
	const KNOCKBACK := 45.0
	const CRIT_MULT := 2.0

	func _init() -> void:
		id = &"iron_fist"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 100.0
		aoe_radius = 0.0
		display_name = "Thiết Quyền"
		description = "Đấm thẳng phía trước, hất nhẹ mục tiêu.\nNội tại Nhịp Quyền đủ 3 chiêu thì cú đấm này chí mạng."
		key_label = "LMB"
		cooldown = 0.45
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fbbf24")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		# Chí mạng đến từ nội tại: đủ 3 chiêu thì đòn kế tiếp gấp đôi.
		var crit := caster.has_status(GameData.ST_EMPOWER)
		if crit:
			caster.consume_status(GameData.ST_EMPOWER)
		Audio.play_at(&"slash_crit" if crit else &"clash", caster.global_position, -6.0, 1.1)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			var dmg := DAMAGE * (CRIT_MULT if crit else 1.0)
			if e.take_damage(dmg, caster.peer_id):
				e.apply_knockback(dir, KNOCKBACK * (1.8 if crit else 1.0))
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.14,
			"accent": Color("fbbf24"),
		})
		# Vệt chém liềm 2.5D — đòn đấm kim loại quét ngang trước mặt.
		VFXLibrary.slash_arc(caster.world.fx,
			caster.global_position + dir * REACH * 0.55,
			Color(1.0, 0.85, 0.35), signf(dir.x) if absf(dir.x) > 0.15 else 1.0)


# ========================================================= Q — PHONG BỘ
class WindStep extends SkillBase:
	const DASH_SPEED := 1100.0
	const DASH_TIME := 0.22
	const HIT_DAMAGE := 5.0
	const SLOW_TIME := 1.0

	func _init() -> void:
		id = &"wind_step"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 280.0
		preview_shape = SkillBase.PreviewShape.DASH
		aoe_radius = 0.0
		display_name = "Phong Bộ"
		description = "Trượt gió lao tới: xuyên qua địch, mỗi kẻ bị xuyên\nchậm 1 giây. Dùng để áp sát hoặc rút lui."
		key_label = "Q"
		cooldown = 5.5
		mana_cost = 14.0
		icon_color = Color("fcd34d")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_SPEED * DASH_TIME
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"blink", start, -5.0, 1.0)
		# Phong bộ: vòng gió vàng nhạt nở tại điểm đến.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.shock_ring(caster.world.fx, end, 46.0,
				Color(0.98, 0.9, 0.55, 0.5), 0.3)
		for e in enemies():
			var ab := end - start
			var len2 := ab.length_squared()
			var t := clampf((e.global_position - start).dot(ab) / maxf(len2, 0.001), 0.0, 1.0)
			if e.global_position.distance_to(start + ab * t) <= 40.0 + e.body_radius:
				e.take_damage(HIT_DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_SLOW, 1, SLOW_TIME, caster.peer_id)
		for i in range(3):
			var p := start.lerp(end, float(i + 1) / 3.0)
			caster.spawn_effect({
				"kind": &"dust",
				"position": p,
				"radius": 8.0,
				"life": 0.35,
				"accent": Color("fde68a"),
			})


# ========================================================= W — CHUNG VÀNG
class GoldenBell extends SkillBase:
	const SHIELD := 24.0
	const HASTE_TIME := 2.0

	func _init() -> void:
		id = &"golden_bell"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 70.0
		display_name = "Chung Vàng"
		description = "Két một quả chuông vàng bao quanh mình: 24 khiên\nvà Tăng Tốc 2 giây. Chiêu sống còn của võ tăng."
		key_label = "E"
		cooldown = 10.0
		mana_cost = 20.0
		icon_color = Color("f59e0b")

	func execute(_aim: Vector2) -> void:
		caster.add_shield(SHIELD)
		caster.add_status(GameData.ST_HASTE, 1, HASTE_TIME, caster.peer_id)
		Audio.play_at(&"shield", caster.global_position, -3.0, 0.9)
		# Chung vàng: lóe kim quang + vòng chuông ngân quanh người.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.cast_flash(caster.world.fx, caster.global_position, Color("f59e0b"))
			VFXLibrary.shock_ring(caster.world.fx, caster.global_position, 72.0,
				Color(0.95, 0.75, 0.3, 0.5), 0.4)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 72.0,
			"life": 0.45,
			"accent": Color("f59e0b"),
		})


# ========================================================= E — THIÊN CHƯỞNG ẤN
class HeavenPalm extends SkillBase:
	const REACH := 145.0
	const HALF_ANGLE := 1.05
	const DAMAGE := 14.0
	const KNOCKBACK := 135.0
	const BREAK_STACKS := 2
	const BREAK_TIME := 3.5

	func _init() -> void:
		id = &"heaven_palm"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 150.0
		aoe_radius = 60.0
		display_name = "Thiên Chưởng Ấn"
		description = "Đẩy lòng tráng định hất tung phía trước: 14 sát thương,\n2 Vỡ Giáp, hất văng mạnh. Mở màn giao tranh."
		key_label = "R"
		cooldown = 8.0
		mana_cost = 26.0
		icon_color = Color("d97706")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"hit_big", caster.global_position, -2.0, 0.8)
		# Thiên chưởng ấn: vòng sóng kim loại dội về phía trước.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.shock_ring(caster.world.fx,
				caster.global_position + dir * REACH * 0.5, 88.0,
				Color(0.95, 0.8, 0.4, 0.55), 0.32)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
			e.add_status(GameData.ST_BREAK, BREAK_STACKS, BREAK_TIME, caster.peer_id)
			e.apply_knockback(dir, KNOCKBACK)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position + dir * REACH * 0.55,
			"radius": 95.0,
			"life": 0.35,
			"accent": Color("f59e0b"),
		})


# ========================================================= R — NHẤT QUYỀN TRẤN HỒN
class IronVerdict extends SkillBase:
	const REACH := 160.0
	const HALF_ANGLE := 0.5
	const DAMAGE := 24.0
	const BONUS_VS_BREAK := 10.0
	const KNOCKBACK := 250.0

	func _init() -> void:
		id = &"iron_verdict"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 170.0
		aoe_radius = 0.0
		display_name = "Nhất Quyền Trấn Hồn"
		description = "Một cú đấm quyết định: 24 sát thương, hất văng rất mạnh.\nMục tiêu đang Vỡ Giáp nhận thêm 10 sát thương."
		key_label = "F"
		cooldown = 19.0
		mana_cost = 40.0
		icon_color = Color("b45309")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"execute", caster.global_position, 0.0, 1.0)
		# Nhất quyền trấn hồn (ULT): bụi đá tung + cầu kim quang nổ tier-ult.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.dust_impact(caster.world.fx,
				caster.global_position + dir * REACH * 0.55, 1.5)
			VFXLibrary.arcane_blast(caster.world.fx,
				caster.global_position + dir * REACH * 0.55, 105.0, Color("f59e0b"), 1)
		VFXLibrary.ult_shake(self, 7.0)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			var dmg := DAMAGE + (BONUS_VS_BREAK if e.has_status(GameData.ST_BREAK) else 0.0)
			if e.take_damage(dmg, caster.peer_id):
				e.apply_knockback(dir, KNOCKBACK)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position + dir * REACH * 0.6,
			"radius": 110.0,
			"life": 0.4,
			"accent": Color("fbbf24"),
		})


# ============================================================ NỘI TẠI — NHỊP QUYỀN
func build_passive():
	return FistRhythm.new()


## Nội tại NHỊP QUYỀN: cứ 3 chiêu kỹ năng được tung ra, nắm đấm kế tiếp chí mạng.
##
## Điểm hay của thiết kế này: nó ép võ tăng xoay đủ bộ chiêu thay vì spam một
## phím. Người chơi học được nhịp 3-1: ba chiêu setup, một cú đấm to thu hoạch.
class FistRhythm extends Passive:
	const NEEDED := 3

	var _count := 0

	func _init() -> void:
		display_name = "Nhịp Quyền"
		description = "Cứ 3 kỹ năng tung ra, đòn đánh thường kế tiếp thành chí mạng (gấp đôi)."

	func on_skill_cast(_skill: SkillBase) -> void:
		if owner_champ == null or not owner_champ.is_alive():
			return
		_count += 1
		if _count >= NEEDED:
			_count = 0
			owner_champ.add_status(GameData.ST_EMPOWER, 1, 6.0, owner_champ.peer_id)
			Audio.play_at(&"mark", owner_champ.global_position, -8.0, 1.3)

	func status_text() -> String:
		return "Nhịp Quyền · %d/%d" % [_count, NEEDED]
