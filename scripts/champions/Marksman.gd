extends RefCounted
## XẠ THỦ — bắn xa, chuyên gia giữ khoảng cách.
##
## Ý tưởng thiết kế: tướng này thưởng cho việc ĐỨNG YÊN. Mọi tướng khác trong
## game đều muốn di chuyển liên tục; Xạ Thủ thì phải chọn giữa "chạy để sống" và
## "đứng để bắn đau". Đó là một áp lực hoàn toàn khác, và nó khiến người chơi
## phải đọc tình huống thay vì phản xạ.
##
##   - Nội tại Tâm Điểm: đứng yên thì sạc, tối đa +50% sát thương đánh thường
##   - E Bước Lùi Súng: lướt NGƯỢC hướng ngắm — vừa thoát thân vừa giữ được
##     hướng bắn về phía đối thủ
##   - R Ống Nhòm: đổi khả năng di chuyển lấy tầm bắn và sát thương gấp đôi

func build_champion(c: Champion) -> void:
	c.display_name = "Xạ Thủ"
	c.max_hp = 88.0
	c.hp = c.max_hp
	c.max_mana = 105.0
	c.mana = c.max_mana
	c.mana_regen = 12.0
	c.move_speed = 248.0
	c.body_radius = 20.0
	c.accent = Color("facc15")
	c.skills.clear()
	for s in [PiercingShot.new(), GunStep.new(), Scope.new(), FinalShot.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = Snipe.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [PiercingShot.new(), GunStep.new(), Scope.new(), FinalShot.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return Snipe.new()

func build_passive():
	return Focus.new()


# ========================================================== ĐÁNH THƯỜNG — ĐẠN TIỄU
class Snipe extends SkillBase:
	func _init() -> void:
		id = &"snipe"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 700.0
		aoe_radius = 0.0
		display_name = "Đạn Tiễu"
		description = "Bắn một viên đạn nhanh và xa. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.3
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fde047")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"snipe_round",
			"direction": aim,
			"speed": 940.0,
			"damage": 5.5,
			"radius": 7.0,
			"life": 1.3,
			"power": 1.05,
			"accent": Color("fde047"),
		})
		Audio.play_at(&"spark_shot", caster.global_position, -10.0, 1.3)


# ========================================================== Q — XUYÊN THẤU
class PiercingShot extends SkillBase:
	const DAMAGE := 17.0
	const PIERCE := 3

	func _init() -> void:
		id = &"piercing_shot"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 780.0
		aoe_radius = 0.0
		display_name = "Xuyên Thấu"
		description = "Bắn viên đạn lớn xuyên qua tối đa 3 mục tiêu.\nĐứng yên sạc đầy thì viên đạn to hơn và mạnh hơn."
		key_label = "Q"
		cooldown = 5.5
		mana_cost = 16.0
		icon_color = Color("fbbf24")

	func execute(aim: Vector2) -> void:
		var charged: float = caster.get_meta(&"focus", 0.0)
		caster.spawn_projectile({
			"kind": &"pierce_round",
			"direction": aim,
			"speed": 1020.0,
			"damage": DAMAGE * (1.0 + charged * 0.5),
			"radius": 13.0 + 5.0 * charged,
			"life": 1.1,
			"power": 2.8,
			"pierce_left": PIERCE,
			"accent": Color("fcd34d"),
		})
		Audio.play_at(&"spark_shot", caster.global_position, -2.0, 0.85)


# ======================================================= E — BƯỚC LÙI SÚNG
class GunStep extends SkillBase:
	const DASH_REACH := 250.0
	const DASH_TIME := 0.18
	const TRAP_DAMAGE := 11.0

	func _init() -> void:
		id = &"gun_step"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 260.0
		aoe_radius = 70.0
		display_name = "Bước Lùi Súng"
		description = "Lướt NGƯỢC hướng ngắm để giữ khoảng cách.\nĐể lại một bãi mìn làm chậm kẻ đuổi theo."
		key_label = "E"
		cooldown = 8.0
		mana_cost = 18.0
		icon_color = Color("f59e0b")

	func execute(aim: Vector2) -> void:
		# Lướt ngược hướng ngắm — đây là điểm khác biệt của chiêu. Người chơi
		# vẫn ngắm về phía đối thủ, nhưng thân thì đi ra xa. Giữ được hướng
		# bắn trong lúc thoát thân.
		var back := -aim.normalized()
		var origin: Vector2 = caster.global_position
		var dest: Vector2 = origin + back * DASH_REACH

		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(dest, caster.body_radius):
				dest = origin + back * (DASH_REACH * 0.45)

		caster.begin_dash(back, DASH_REACH / DASH_TIME, DASH_TIME)
		Audio.play_at(&"dash_fire", origin, -4.0, 0.9)

		caster.spawn_projectile({
			"kind": &"cal_trap",
			"position": origin,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TRAP_DAMAGE,
			"tick_interval": 0.5,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": 1.4,
			"radius": 70.0,
			"life": 4.0,
			"accent": Color("fbbf24"),
		})


# ============================================================= R — ỐNG NHÒM
class Scope extends SkillBase:
	const DURATION := 4.0

	func _init() -> void:
		id = &"scope"
		cast_type = SkillBase.CastType.INSTANT
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Ống Nhòm"
		description = "Trong 4 giây: sát thương đánh thường gấp đôi, nhưng KHÔNG di chuyển được.\nBấm lại để tắt sớm."
		key_label = "R"
		cooldown = 18.0
		mana_cost = 26.0
		icon_color = Color("f97316")

	func execute(_aim: Vector2) -> void:
		var until := Time.get_ticks_msec() + int(DURATION * 1000.0)
		caster.set_meta(&"scope_until", until)
		Audio.play_at(&"ui_select", caster.global_position, -4.0)
		caster.spawn_effect({
			"kind": &"scope_ring",
			"position": caster.global_position,
			"radius": 120.0,
			"life": DURATION,
			"accent": Color("fbbf24"),
		})


# ======================================================= F — PHÁT SÚNG CUỐI
class FinalShot extends SkillBase:
	const RADIUS := 90.0
	const DAMAGE := 46.0
	const CHARGE := 1.0

	func _init() -> void:
		id = &"final_shot"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 820.0
		aoe_radius = RADIUS
		display_name = "Phát Súng Cuối"
		description = "Nạp một viên đạn xuyên qua mọi thứ trên đường bay.\nSát thương tăng theo mức sạc Tâm Điểm."
		key_label = "F"
		cooldown = 30.0
		mana_cost = 44.0
		icon_color = Color("fef08a")

	func execute(_aim: Vector2) -> void:
		var target := ground_point(cast_range)
		var origin: Vector2 = caster.global_position
		var dir := (target - origin)
		if dir.length_squared() < 1.0:
			dir = caster.aim_dir
		dir = dir.normalized()

		var charged: float = caster.get_meta(&"focus", 0.0)
		Audio.play_at(&"spark_shot", origin, 3.0, 0.6)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": origin,
			"radius": 70.0,
			"life": 0.35,
			"accent": Color("fef08a"),
		})
		caster.spawn_projectile({
			"kind": &"rail_round",
			"direction": dir,
			"speed": 1500.0,
			"damage": DAMAGE * (1.0 + charged * 0.6),
			"radius": 20.0,
			"life": 0.95,
			"power": 5.0,
			"pierce_left": 99,
			"accent": Color("fef3c7"),
		})


# ======================================================== NỘI TẠI — TÂM ĐIỂM
class Focus extends Passive:
	## Thời gian đứng yên để sạc đầy.
	const CHARGE_TIME := 2.0
	## Mức sạc tối đa, cộng vào hệ số sát thương đánh thường.
	const MAX_BONUS := 0.5
	const MOVE_EPSILON := 10.0

	var _charge := 0.0

	func _init() -> void:
		display_name = "Tâm Điểm"
		description = "Đứng yên để sạc, tối đa +50% sát thương đánh thường. Di chuyển là mất sạch."

	func tick(delta: float) -> void:
		if owner_champ == null:
			return
		if owner_champ.velocity.length() < MOVE_EPSILON:
			_charge = minf(1.0, _charge + delta / CHARGE_TIME)
		else:
			# Mất sạc nhanh gấp ba lần tốc độ sạc — muốn ăn sát thương cao thì
			# phải thật sự đứng yên, không thể vừa nhích vừa giữ sạc.
			_charge = maxf(0.0, _charge - delta * 3.0 / CHARGE_TIME)
		owner_champ.set_meta(&"focus", _charge)

	func outgoing_multiplier(_target: Champion) -> float:
		return 1.0 + MAX_BONUS * _charge

	func status_text() -> String:
		return "Tâm Điểm · %d%%" % int(round(_charge * MAX_BONUS * 100.0))
