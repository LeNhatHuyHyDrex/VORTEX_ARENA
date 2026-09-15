extends RefCounted
const VFXLibrary := preload("res://scripts/vfx/VFXLibrary.gd")
## SÁT THỦ BÓNG TỐI — tướng cận chiến, chuyên đánh dấu rồi kết liễu.
##
## Ý tưởng thiết kế: mọi sát thương lớn đều phụ thuộc vào stack Khóa Hồn do E
## tạo ra. Nhưng để dồn được stack thì phải áp sát, mà áp sát thì dễ ăn đòn.
## Người chơi phải tự cân giữa "dồn thêm một stack nữa" và "kết liễu ngay bây giờ".
##
## W không gây sát thương nhưng là mảnh ghép mở ra combo: nếu dịch chuyển tới
## mục tiêu ĐANG BỊ KHÓA HỒN thì đòn chém kế tiếp thành chí mạng. Tức là
## E -> W -> Q mạnh hơn hẳn Q -> W -> E dù dùng đúng bấy nhiêu chiêu.

func build_champion(c: Champion) -> void:
	c.display_name = "Sát Thủ Bóng Tối"
	c.max_hp = 105.0
	c.hp = c.max_hp
	c.max_mana = 90.0
	c.mana = c.max_mana
	c.mana_regen = 9.0
	c.move_speed = 272.0
	c.body_radius = 21.0
	c.accent = Color("a855f7")
	c.skills.clear()
	for s in [TwinSlash.new(), ShadowStep.new(), SoulMark.new(), DeathBlossom.new()]:
		s.bind(c)
		c.skills.append(s)
	# Đánh thường cận chiến: đâm nhanh, tầm rất ngắn nhưng không tốn năng lượng.
	c.basic_attack = DaggerStrike.new()
	c.basic_attack.bind(c)

## Trả về danh sách skill chưa gắn tướng, dùng cho menu chọn tướng.
func skill_preview() -> Array:
	return [TwinSlash.new(), ShadowStep.new(), SoulMark.new(), DeathBlossom.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return DaggerStrike.new()


# ======================================================= ĐÁNH THƯỜNG — ĐÂM NHANH
class DaggerStrike extends SkillBase:
	const REACH := 78.0
	const HALF_ANGLE := 0.80
	const DAMAGE := 5.0
	## Chém thường lên mục tiêu bị Khóa Hồn cũng được lợi, nhưng ít hơn hẳn Q —
	## để người chơi vẫn phải dùng đúng chiêu chứ không spam chuột trái.
	const MARK_BONUS := 3.0

	func _init() -> void:
		id = &"dagger_strike"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 80.0
		aoe_radius = 0.0
		display_name = "Đâm Nhanh"
		description = "Đâm nhanh tầm gần. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.38
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("c98f9c")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		Audio.play_at(&"slash", caster.global_position, -8.0, 1.25)
		for e in enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE):
			e.take_damage(DAMAGE, caster.peer_id)
			e.apply_knockback(e.global_position - caster.global_position, 70.0)
			if e.has_status(GameData.ST_MARK):
				e.take_damage(MARK_BONUS, caster.peer_id)
		caster.spawn_effect({
			"kind": &"slash",
			"position": caster.global_position,
			"direction": dir,
			"radius": REACH,
			"life": 0.16,
			"accent": Color("c98f9c"),
		})


# =============================================================== Q — CHÉM ĐÔI
class TwinSlash extends SkillBase:
	const REACH := 90.0
	const HALF_ANGLE := 0.95
	const BASE_DAMAGE := 13.0
	## Cộng thêm khi mục tiêu đang bị Khóa Hồn.
	const MARK_BONUS := 8.0
	## Hồi máu cho bản thân khi chém trúng mục tiêu bị Khóa Hồn.
	const MARK_LIFESTEAL := 6.0
	## Hệ số nhân khi đang có hiệu ứng Chí Mạng từ Ảnh Bộ.
	const CRIT_MULT := 1.8

	func _init() -> void:
		id = &"twin_slash"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 110.0
		aoe_radius = 0.0
		display_name = "Chém Đôi"
		description = "Chém hình quạt trước mặt.\nMục tiêu bị KHÓA HỒN nhận thêm sát thương và bạn hồi máu.\nNếu đang có Chí Mạng thì đòn này chí mạng."
		key_label = "Q"
		cooldown = 2.4
		mana_cost = 8.0
		icon_color = Color("b0405a")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var crit := caster.has_status(GameData.ST_EMPOWER)
		if crit:
			caster.consume_status(GameData.ST_EMPOWER)
		Audio.play_at(&"slash_crit" if crit else &"slash", caster.global_position)

		# Vệt chém bóng theo hướng quạt — lóe tím ngắn đúng góc vung dao.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.spell_seq(caster.world.fx, "fx10_blackExplosion",
				caster.global_position + dir * REACH * 0.45, 0.9,
				Color(0.85, 0.7, 1.0, 0.85), 32.0, rad_to_deg(dir.angle()), true)

		var hits := enemies_in_cone(caster.global_position, dir, REACH, HALF_ANGLE)
		for e in hits:
			var dmg := BASE_DAMAGE
			var marks: int = e.get_stacks(GameData.ST_MARK)
			if marks > 0:
				dmg += MARK_BONUS
				# Mỗi stack Khóa Hồn còn tăng thêm 6% sát thương nhận vào.
				dmg *= 1.0 + 0.06 * float(marks)
			if crit:
				dmg *= CRIT_MULT
			e.take_damage(dmg, caster.peer_id)
			e.apply_knockback(e.global_position - caster.global_position, 130.0)
			if marks > 0:
				caster.heal(MARK_LIFESTEAL)
			caster.spawn_effect({
				"kind": &"slash",
				"position": caster.global_position,
				"direction": dir,
				"radius": REACH,
				"life": 0.22,
				"accent": Color("f472b6") if crit else Color("b0405a"),
			})


# =============================================================== W — ẢNH BỘ
class ShadowStep extends SkillBase:
	const SEARCH_RANGE := 300.0
	## Khoảng cách đứng sau lưng mục tiêu sau khi dịch chuyển.
	const BEHIND_OFFSET := 58.0
	const DASH_SPEED := 1000.0
	const DASH_TIME := 0.15
	## Thời gian hiệu lực của Chí Mạng khi dịch chuyển tới mục tiêu bị Khóa Hồn.
	const EMPOWER_DURATION := 3.0

	## Cửa sổ để lướt lần thứ hai miễn phí.
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
		description = "Lướt tức thì theo hướng ngắm.\nBấm lần nữa trong 1.2s để lướt tiếp lần hai.\nNếu mục tiêu đang bị KHÓA HỒN: đòn Chém Đôi kế tiếp thành chí mạng."
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

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		# Mặc định lướt theo hướng ngắm. Chỉ khi có đối thủ trong tầm VÀ họ đang
		# bị Khóa Hồn thì mới nhảy ra sau lưng — vì lúc đó mới có Chí Mạng để ăn.
		# Không có điều kiện đó thì nhảy sau lưng chỉ làm mất phương hướng.
		var target := nearest_enemy_in_range(SEARCH_RANGE)
		var blink_behind := target != null and target.has_status(GameData.ST_MARK)

		var start_pos := caster.global_position
		if not blink_behind:
			var target_pos := start_pos + dir * (DASH_SPEED * DASH_TIME)
			if caster.world != null and "fx" in caster.world:
				VFXLibrary.shadow_dash_trail(caster.world.fx, start_pos, target_pos)
			caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
			Audio.play_at(&"blink", caster.global_position, -4.0)
		else:
			var behind := (target.global_position - caster.global_position)
			if behind.length_squared() < 0.01:
				behind = -aim
			var dest: Vector2 = target.global_position + behind.normalized() * BEHIND_OFFSET
			# Không dịch chuyển vào trong tường.
			if caster.world != null and caster.world.has_method("is_blocked_at"):
				if caster.world.is_blocked_at(dest, caster.body_radius + 2.0):
					dest = caster.global_position
			if caster.world != null and "fx" in caster.world:
				VFXLibrary.shadow_dash_trail(caster.world.fx, start_pos, dest)
			caster.global_position = dest
			caster.velocity = Vector2.ZERO
			# Sau khi dịch chuyển thì mặt hướng về mục tiêu.
			caster.aim_dir = (target.global_position - caster.global_position).normalized()
			Audio.play_at(&"teleport", caster.global_position)

		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 40.0,
			"life": 0.3,
			"accent": Color("a855f7"),
		})

		# Chí Mạng chỉ đến từ việc nhảy sau lưng mục tiêu bị Khóa Hồn.
		if blink_behind:
			caster.add_status(GameData.ST_EMPOWER, 1, EMPOWER_DURATION, caster.peer_id)

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


# ============================================================== E — KHÓA HỒN
class SoulMark extends SkillBase:
	func _init() -> void:
		id = &"soul_mark"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 560.0
		aoe_radius = 0.0
		display_name = "Khóa Hồn"
		description = "Ném phi tiêu gây sát thương và đánh dấu mục tiêu.\nMỗi stack Khóa Hồn khiến mục tiêu nhận thêm 6% sát thương từ bạn.\nTối đa 3 stack."
		key_label = "R"
		cooldown = 4.5
		mana_cost = 16.0
		icon_color = Color("a855f7")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"shadow_bolt",
			"direction": aim,
			"speed": 720.0,
			"damage": 7.0,
			"radius": 10.0,
			"life": 1.4,
			"power": 1.8,
			"status_id": GameData.ST_MARK,
			"status_stacks": 1,
			"status_duration": 10.0,
			"status_max_stacks": 3,
			"accent": Color("a855f7"),
		})
		Audio.play_at(&"shadow_bolt", caster.global_position)


# ============================================================== R — TỬ ẢNH
class DeathBlossom extends SkillBase:
	const RANGE := 195.0
	const BASE_DAMAGE := 30.0
	const DAMAGE_PER_STACK := 20.0
	## Dưới ngưỡng máu này thì bị kết liễu (nhân thêm sát thương).
	const EXECUTE_THRESHOLD := 0.35
	const EXECUTE_MULT := 2.5

	func _init() -> void:
		id = &"death_blossom"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 220.0
		display_name = "Tử Ảnh"
		description = "Kết liễu đối thủ trong tầm gần.\nSát thương = 30 + 20 mỗi stack Khóa Hồn, và tiêu thụ hết stack.\nMục tiêu dưới 35% máu chịu sát thương gấp 2.5 lần."
		key_label = "F"
		cooldown = 24.0
		mana_cost = 38.0
		icon_color = Color("7e22ce")

	func execute(_aim: Vector2) -> void:
		var target := nearest_enemy_in_range(RANGE)
		if target == null:
			# Không có ai trong tầm — đánh dấu mục tiêu gần nhất nếu có,
			# để người chơi không mất chiêu hoàn toàn mà vẫn thấy phản hồi.
			caster.spawn_effect({
				"kind": &"explosion",
				"position": caster.global_position,
				"radius": 50.0,
				"life": 0.3,
				"accent": Color("7e22ce"),
			})
			return

		var marks: int = target.consume_status(GameData.ST_MARK)
		Audio.play_at(&"execute", target.global_position)
		var dmg := BASE_DAMAGE + DAMAGE_PER_STACK * float(marks)
		dmg *= 1.0 + 0.06 * float(marks)
		var is_execute: bool = target.hp / maxf(target.max_hp, 1.0) < EXECUTE_THRESHOLD
		if is_execute:
			dmg *= EXECUTE_MULT

		target.take_damage(dmg, caster.peer_id)
		target.apply_knockback(target.global_position - caster.global_position, 200.0)
		if is_execute and target.is_alive():
			target.add_status(GameData.ST_SLOW, 1, 3.0, caster.peer_id)

		# Lớp pack ULT: khói đen tím bùng quanh mục tiêu + sóng kép. Bị xử lý
		# (execute) thì khói thêm một lớp sáng hơn, rộng hơn — nhìn là biết đòn
		# "chốt" đã ăn.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.shadow_burst(caster.world.fx, target.global_position,
				70.0 + 18.0 * float(marks), 1 if is_execute else 0)
			VFXLibrary.ult_shake(self, 6.0)

		caster.spawn_effect({
			"kind": &"explosion",
			"position": target.global_position,
			"radius": 46.0 + 16.0 * float(marks),
			"life": 0.45,
			"accent": Color("e9d5ff") if is_execute else Color("a855f7"),
		})


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
