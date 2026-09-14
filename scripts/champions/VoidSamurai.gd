extends RefCounted
## KIẾM THÁNH — khách kiếm hư không, chớp nhoáng như một nhát rút kiếm.
##
## Ý tưởng thiết kế: sát thủ kỹ thuật với nguồn sức mạnh là SÁT Ý — mỗi chiêu
## kỹ năng tung ra cộng dồn sát thương (tối đa +35%), còn đòn đánh thường sẽ
## "thu hoạch" toàn bộ Sát Ý đang có. Nhờ vậy lối chơi đúng là một vũ điệu:
## tích ý bằng chiêu, xả ý bằng đòn thường, xoay vòng không ngừng. Bộ chiêu
## cho hắn đủ công cụ để vào-ra: Nhất Đao Lưu cho chí mạng, Hư Không Bước để
## lao xuyên người đánh dấu, Vạn Kiếm Mộ nhốt cả vùng đất.
##
## Chuỗi logic:
##   Q Nghịch Phong Trảm tích Sát Ý
##   đánh thường xả Sát Ý
##   W Nhất Đao Lưu → Chí Mạng cho đòn kế tiếp
##   E Hư Không Bước lao xuyên + đánh dấu
##   R Vạn Kiếm Mộ nhốt địch trong mưa kiếm

func build_champion(c: Champion) -> void:
	c.display_name = "Kiếm Thánh"
	c.max_hp = 96.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 10.0
	c.move_speed = 276.0
	c.body_radius = 18.0
	c.accent = Color("818cf8")
	c.skills.clear()
	for s in [SwiftSlash.new(), IaiDraw.new(), VoidStep.new(), BladeStorm.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = QuickDraw.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [SwiftSlash.new(), IaiDraw.new(), VoidStep.new(), BladeStorm.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return QuickDraw.new()


# ======================================================= ĐÁNH THƯỜNG — TỐC KIẾM
class QuickDraw extends SkillBase:
	const REACH := 114.0
	const HALF_ANGLE := 0.62
	const DAMAGE := 6.0

	func _init() -> void:
		id = &"quick_draw"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 118.0
		aoe_radius = 0.0
		display_name = "Tốc Kiếm"
		description = "Rút kiếm chớp nhoáng phía trước.\nĐòn này tiêu thụ toàn bộ Sát Ý đang có (nội tại)."
		key_label = "LMB"
		cooldown = 0.4
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("a5b4fc")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash", caster.global_position, -7.0, 1.25)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.13,
			"accent": Color("a5b4fc"),
		})
		# Vệt chém katana tím hư không — nhanh và sắc hơn đòn rìu.
		VFXLibrary.slash_arc(caster.world.fx,
			caster.global_position + dir * REACH * 0.55,
			Color(0.65, 0.55, 1.0), signf(dir.x) if absf(dir.x) > 0.15 else 1.0)


# ========================================================= Q — NGHỊCH PHONG TRẢM
class SwiftSlash extends SkillBase:
	const REACH := 165.0
	const HALF_ANGLE := 0.5
	const DAMAGE := 12.0

	func _init() -> void:
		id = &"swift_slash"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 175.0
		aoe_radius = 0.0
		display_name = "Nghịch Phong Trảm"
		description = "Một đường kiếm chém ngược gió: 12 sát thương\nvà cộng 1 lớp Sát Ý (nội tại)."
		key_label = "Q"
		cooldown = 3.5
		mana_cost = 12.0
		icon_color = Color("818cf8")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash", caster.global_position, -5.0, 1.1)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.16,
			"accent": Color("6366f1"),
		})


# ========================================================= W — NHẤT ĐAO LƯU
class IaiDraw extends SkillBase:
	const REACH := 250.0
	const HALF_ANGLE := 0.34
	const DAMAGE := 16.0
	const EMPOWER_TIME := 4.0

	func _init() -> void:
		id = &"iai_draw"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 260.0
		aoe_radius = 0.0
		display_name = "Nhất Đao Lưu"
		description = "Rút kiếm chém một đường dài 250px: 16 sát thương,\nvà đòn đánh thường KẾ TIẾP thành chí mạng."
		key_label = "E"
		cooldown = 8.0
		mana_cost = 22.0
		icon_color = Color("6366f1")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash_crit", caster.global_position, -4.0, 1.0)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
		caster.add_status(GameData.ST_EMPOWER, 1, EMPOWER_TIME, caster.peer_id)
		# Vệt chém dài đặc trưng của nhất đao lưu.
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.22,
			"accent": Color("c7d2fe"),
		})


# ========================================================= E — HƯ KHÔNG BƯỚC
class VoidStep extends SkillBase:
	const DASH_SPEED := 1150.0
	const DASH_TIME := 0.22
	const HIT_DAMAGE := 10.0
	const MARK_STACKS := 2
	const MARK_TIME := 4.0

	func _init() -> void:
		id = &"void_step"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 290.0
		aoe_radius = 0.0
		display_name = "Hư Không Bước"
		description = "Lao xuyên thân địch qua hư không: 10 sát thương\n+ 2 Khóa Hồn mỗi kẻ bị xuyên qua."
		key_label = "R"
		cooldown = 6.5
		mana_cost = 18.0
		icon_color = Color("4f46e5")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_SPEED * DASH_TIME
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"teleport", start, -4.0, 1.1)
		for e in enemies():
			var ab := end - start
			var len2 := ab.length_squared()
			var t := clampf((e.global_position - start).dot(ab) / maxf(len2, 0.001), 0.0, 1.0)
			if e.global_position.distance_to(start + ab * t) <= 40.0 + e.body_radius:
				e.take_damage(HIT_DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_MARK, MARK_STACKS, MARK_TIME, caster.peer_id)
		for i in range(4):
			var p := start.lerp(end, float(i + 1) / 4.0)
			caster.spawn_effect({
				"kind": &"dust",
				"position": p,
				"radius": 8.0,
				"life": 0.35,
				"accent": Color("4f46e5"),
			})


# ========================================================= R — VẠN KIẾM MỘ
class BladeStorm extends SkillBase:
	const CAST_RANGE := 420.0
	const RADIUS := 155.0
	const TICK_DAMAGE := 6.0
	const TICK_INTERVAL := 0.4
	const LIFE := 2.8

	func _init() -> void:
		id = &"blade_storm"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 430.0
		aoe_radius = RADIUS
		display_name = "Vạn Kiếm Mộ"
		description = "Triệu hồi mưa kiếm xoay tròn tại điểm chọn: múc 6\nsát thương mỗi 0.4 giây trong 2.8 giây."
		key_label = "F"
		cooldown = 26.0
		mana_cost = 45.0
		icon_color = Color("3730a3")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(CAST_RANGE, aim)
		Audio.play_at(&"void_collapse", center, -2.0, 0.9)
		caster.spawn_projectile({
			"kind": &"blade_storm_zone",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TICK_DAMAGE,
			"tick_interval": TICK_INTERVAL,
			"radius": RADIUS,
			"life": LIFE,
			"accent": Color("818cf8"),
		})


# ============================================================ NỘI TẠI — SÁT Ý
func build_passive():
	return KillingIntent.new()


## Nội tại SÁT Ý: kỹ năng cộng dồn, đánh thường tiêu thụ.
##
## Mỗi chiêu +7% sát thương, tối đa 5 lớp (+35%). Đòn đánh thường trúng thì
## xả hết. Đây là "động cơ xoay vòng" của cả bộ kỹ năng: chiêu nuôi đòn thường,
## đòn thường nuôi chí mạng từ W, W lại nuôi tiếp chuỗi.
class KillingIntent extends Passive:
	const PER_STACK := 0.07
	const MAX_STACKS := 5

	var _stacks := 0

	func _init() -> void:
		display_name = "Sát Ý"
		description = "Mỗi kỹ năng cộng 1 Sát Ý (+7% sát thương, tối đa 5).\nĐánh thường trúng sẽ tiêu thụ toàn bộ Sát Ý."

	func on_skill_cast(_skill: SkillBase) -> void:
		if owner_champ == null:
			return
		_stacks = mini(_stacks + 1, MAX_STACKS)

	func outgoing_multiplier(_target: Champion) -> float:
		return 1.0 + PER_STACK * _stacks

	func on_basic_hit(_target: Champion) -> void:
		_stacks = 0

	func status_text() -> String:
		return "Sát Ý · %d/%d" % [_stacks, MAX_STACKS]
