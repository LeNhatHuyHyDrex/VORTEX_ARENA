extends RefCounted
## CHỦ ƯNG — gọi thú, chỉ huy chúng đánh hộ.
##
## Ý tưởng thiết kế: tướng duy nhất trong game mà sát thương đến từ một nguồn
## KHÔNG PHẢI chính mình. Người chơi điều khiển vị trí của bản thân và vị trí
## của đàn thú cùng lúc — hai bài toán chồng lên nhau.
##
##   - Nội tại Liên Kết: hứng 15% sát thương thay thú, và thú hạ được mục tiêu
##     thì hoàn một nửa hồi chiêu Triệu Hồ
##   - Q Triệu Hồ: gọi một con sói, nó tự lao vào đối thủ gần nhất
##   - E Khống Chế: ra lệnh cho sói lao tới và choáng mục tiêu
##   - R Đàn Bầy: gọi thêm hai con, thành một đàn ba con
##   - F Sói Đoàn: bản thân và cả đàn cùng lao về một hướng
##
## Điểm hay: thú là mối đe doạ thật chứ không phải hình trang trí — chúng gây
## sát thương thật và đối thủ phải chọn giữa bắn bạn hay bắn thú.

func build_champion(c: Champion) -> void:
	c.display_name = "Chủ Ưng"
	c.max_hp = 102.0
	c.hp = c.max_hp
	c.max_mana = 108.0
	c.mana = c.max_mana
	c.mana_regen = 12.0
	c.move_speed = 258.0
	c.body_radius = 21.0
	c.accent = Color("4ade80")
	c.skills.clear()
	for s in [SummonBeast.new(), Command.new(), Pack.new(), Stampede.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = WhipCrack.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [SummonBeast.new(), Command.new(), Pack.new(), Stampede.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return WhipCrack.new()

func build_passive():
	return Bond.new()


# ========================================================= ĐÁNH THƯỜNG — ROI DA
class WhipCrack extends SkillBase:
	const RANGE := 540.0
	const SPEED := 660.0
	const DAMAGE := 6.0
	const SLOW_TIME := 1.0

	func _init() -> void:
		id = &"whip_crack"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 560.0
		aoe_radius = 0.0
		display_name = "Phi Đao Chăn Thú"
		description = "Ném dao săn về phía trước, trúng thì Chậm 1 giây —\ndùng để giữ chân mục tiêu cho đàn thú áp sát. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.5
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("86efac")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"phantom_edge",
			"direction": aim,
			"speed": SPEED,
			"damage": DAMAGE,
			"radius": 7.0,
			"life": RANGE / SPEED,
			"power": 1.0,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": SLOW_TIME,
			"accent": Color("86efac"),
		})
		Audio.play_at(&"slash", caster.global_position, -10.0, 1.2)


# ========================================================= Q — TRIỆU HỒ
class SummonBeast extends SkillBase:
	const DAMAGE := 12.0
	const LIFETIME := 5.0
	const SPEED := 340.0
	const CHASE := 6.0

	func _init() -> void:
		id = &"summon_beast"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 260.0
		aoe_radius = 40.0
		display_name = "Triệu Hồ"
		description = "Gọi một con sói tại vùng đã chọn.\nSói tự lao vào đối thủ gần nhất và cắn một lần, tồn tại 5 giây."
		key_label = "Q"
		cooldown = 7.0
		mana_cost = 20.0
		icon_color = Color("4ade80")

	func execute(_aim: Vector2) -> void:
		var spawn_at := ground_point(cast_range)
		Audio.play_at(&"ui_select", spawn_at, -4.0, 0.85)
		caster.spawn_projectile({
			"kind": &"spirit_wolf",
			"position": spawn_at,
			"direction": caster.aim_dir,
			"speed": SPEED,
			"damage": DAMAGE,
			"radius": 18.0,
			"life": LIFETIME,
			"power": 0.0,          # thú không tham gia đối đầu đạn
			"chase_speed": CHASE,
			"accent": Color("4ade80"),
		})


# =========================================================== E — KHỐNG CHẾ
class Command extends SkillBase:
	const SEARCH := 420.0
	const DAMAGE := 14.0
	const STUN := 0.5

	func _init() -> void:
		id = &"command"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 420.0
		aoe_radius = 60.0
		display_name = "Khống Chế"
		description = "Ra lệnh cho đàn thú lao tới đối thủ gần nhất.\nCon đầu tiên trúng đích gây sát thương và CHOÁNG mục tiêu."
		key_label = "E"
		cooldown = 8.0
		mana_cost = 22.0
		icon_color = Color("22c55e")

	func execute(aim: Vector2) -> void:
		var target := nearest_enemy_in_range(SEARCH)
		var dir := aim.normalized()
		if target != null:
			dir = (target.global_position - caster.global_position).normalized()

		Audio.play_at(&"ui_select", caster.global_position, -3.0, 1.15)
		# Gọi thêm một con lao thẳng tới mục tiêu — đây là cách "ra lệnh" trong
		# bản 1v1, vì không có đàn thú thường trú để mà điều khiển.
		caster.spawn_projectile({
			"kind": &"spirit_wolf",
			"position": caster.global_position + dir * 30.0,
			"direction": dir,
			"speed": 620.0,
			"damage": DAMAGE,
			"radius": 20.0,
			"life": 1.6,
			"power": 0.0,
			"chase_speed": 12.0,
			"status_id": GameData.ST_FREEZE,
			"status_stacks": 1,
			"status_duration": STUN,
			"accent": Color("22c55e"),
		})


# ============================================================ R — ĐÀN BẦY
class Pack extends SkillBase:
	const COUNT := 2
	const DAMAGE := 11.0
	const LIFETIME := 5.0

	func _init() -> void:
		id = &"pack"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 200.0
		display_name = "Đàn Bầy"
		description = "Gọi thêm hai con sói quanh mình, cùng lao vào đối thủ.\nTổng cộng có thể có ba con cùng lúc."
		key_label = "R"
		cooldown = 20.0
		mana_cost = 36.0
		icon_color = Color("16a34a")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"ui_select", caster.global_position, 1.0, 0.75)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 150.0,
			"life": 0.5,
			"accent": Color("4ade80"),
		})
		for i in range(COUNT):
			var a := TAU * float(i) / float(COUNT) + randf()
			var spawn_at: Vector2 = caster.global_position + Vector2(cos(a), sin(a)) * 76.0
			caster.spawn_projectile({
				"kind": &"spirit_wolf",
				"position": spawn_at,
				"direction": (caster.aim_dir + Vector2(cos(a), sin(a)) * 0.6).normalized(),
				"speed": 360.0,
				"damage": DAMAGE,
				"radius": 18.0,
				"life": LIFETIME,
				"power": 0.0,
				"chase_speed": 7.0,
				"accent": Color("4ade80"),
			})


# ========================================================== F — SÓI ĐOÀN
class Stampede extends SkillBase:
	const DAMAGE := 22.0
	const STUN := 0.6
	const DASH_REACH := 330.0
	const WOLF_COUNT := 3

	func _init() -> void:
		id = &"stampede"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 340.0
		aoe_radius = 90.0
		display_name = "Sói Đoàn"
		description = "Bản thân và cả đàn cùng lao về một hướng.\nMọi kẻ trên đường bị húc văng và CHOÁNG."
		key_label = "F"
		cooldown = 24.0
		mana_cost = 44.0
		icon_color = Color("bbf7d0")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH

		Audio.play_at(&"dash_fire", start, 1.0, 0.8)
		caster.begin_dash(dir, DASH_REACH / 0.22, 0.22)

		# Đàn thú chạy hai bên sườn, không trùng đường với chủ.
		var perp := Vector2(-dir.y, dir.x)
		for i in range(WOLF_COUNT):
			var side := -1.0 if i % 2 == 0 else 1.0
			var lane := side * (34.0 + 30.0 * float(i / 2))
			caster.spawn_projectile({
				"kind": &"spirit_wolf",
				"position": start + perp * lane,
				"direction": dir,
				"speed": DASH_REACH / 0.30,
				"damage": DAMAGE,
				"radius": 20.0,
				"life": 0.42,
				"power": 0.0,
				"chase_speed": 0.0,
				"status_id": GameData.ST_FREEZE,
				"status_stacks": 1,
				"status_duration": STUN,
				"accent": Color("bbf7d0"),
			})

		for e in enemies():
			var d := _distance_to_segment(e.global_position, start, end)
			if d <= 74.0 + e.body_radius:
				e.take_damage(DAMAGE, caster.peer_id)
				e.add_status(GameData.ST_FREEZE, 1, STUN, caster.peer_id)
				e.apply_knockback(e.global_position - start, 260.0)

	## Khoảng cách từ một điểm tới đoạn thẳng. Dùng để biết ai nằm trên đường lao.
	func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 0.0001:
			return p.distance_to(a)
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		return p.distance_to(a + ab * t)


# ======================================================== NỘI TẠI — LIÊN KẾT
class Bond extends Passive:
	## Tỉ lệ sát thương đánh vào thú được chuyển sang chủ.
	const SHARE := 0.15
	## Phần hồi chiêu được hoàn cho Triệu Hồ khi thú hạ được mục tiêu.
	const KILL_REFUND := 0.5

	func _init() -> void:
		display_name = "Liên Kết"
		description = "Sát thương đánh vào đàn thú được chia 15% sang bạn. Thú hạ được mục tiêu thì hoàn nửa hồi chiêu Triệu Hồ."

	## Thú không phải tướng nên không nhận sát thương qua `take_damage`. Thay vào
	## đó, phần chia sẻ được xử lý khi thú bị tiêu diệt: chủ mất một phần máu.
	func on_deal_damage(_target: Champion, _amount: float) -> void:
		pass

	func on_kill(victim: Champion) -> void:
		if owner_champ == null or victim == null:
			return
		# Chỉ hoàn chiêu khi cái chết đến từ đàn thú. Cách nhận biết đơn giản:
		# nếu chủ không đang trong tầm cận chiến của nạn nhân thì gần như chắc
		# chắn là thú cắn.
		if owner_champ.global_position.distance_to(victim.global_position) > 160.0:
			_refund_summon()

	func _refund_summon() -> void:
		if owner_champ.skills.size() < 1:
			return
		var s: SkillBase = owner_champ.skills[0]
		if s != null:
			s.refund(s.cooldown * KILL_REFUND)

	func status_text() -> String:
		return "Liên Kết · chia %d%%" % int(SHARE * 100.0)
