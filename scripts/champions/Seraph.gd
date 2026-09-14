extends RefCounted
## THIÊN SỨ — hỗ trợ, chuyên khiên và vùng hồi máu.
##
## Ý tưởng thiết kế: tướng duy nhất trong game thắng bằng cách SỐNG LÂU chứ không
## phải bằng cách giết nhanh. Bộ chiêu cho phép đứng trong vùng của mình và trao
## đổi sát thương có lợi — đối thủ càng cố dồn sát thương thì càng mất thời gian.
##
##   - Nội tại Phước Lành: mọi lần hồi máu đều cộng thêm 20% thành khiên
##   - E Khiên Phước: khiên phản 30% sát thương đạn về kẻ bắn
##   - R Vùng Thiêng: vùng hồi máu + tăng tốc, biến một khoảng sân thành lãnh địa
##   - F Thiên Khai: sấm sét diện rộng, dùng để đẩy đối thủ ra khỏi vùng của mình

func build_champion(c: Champion) -> void:
	c.display_name = "Thiên Sứ"
	c.max_hp = 104.0
	c.hp = c.max_hp
	c.max_mana = 120.0
	c.mana = c.max_mana
	c.mana_regen = 14.0
	c.move_speed = 252.0
	c.body_radius = 21.0
	c.accent = Color("fde68a")
	c.skills.clear()
	for s in [LightWave.new(), BlessedShield.new(), Sanctuary.new(), DivineSmite.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = StaffTap.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [LightWave.new(), BlessedShield.new(), Sanctuary.new(), DivineSmite.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return StaffTap.new()

func build_passive():
	return Blessing.new()


# ========================================================= ĐÁNH THƯỜNG — QUYỀN TRƯỢNG
class StaffTap extends SkillBase:
	const RANGE := 520.0
	const SPEED := 640.0
	const DAMAGE := 6.0

	func _init() -> void:
		id = &"staff_tap"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 540.0
		aoe_radius = 0.0
		display_name = "Quang Tiễn"
		description = "Phóng một mũi sáng từ quyền trượng, tầm xa.\nKhông tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.5
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fef3c7")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"spark_shot",
			"direction": aim,
			"speed": SPEED,
			"damage": DAMAGE,
			"radius": 7.0,
			"life": RANGE / SPEED,
			"power": 1.0,
			"accent": Color("fef9c3"),
		})
		Audio.play_at(&"bolt", caster.global_position, -10.0, 1.35)


# ======================================================= Q — SÓNG ÁNH SÁNG
class LightWave extends SkillBase:
	const DAMAGE := 15.0
	const HEAL := 8.0
	const SLOW_TIME := 2.0

	func _init() -> void:
		id = &"light_wave"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 620.0
		aoe_radius = 0.0
		display_name = "Sóng Ánh Sáng"
		description = "Phóng sóng năng lượng gây sát thương và làm chậm.\nBắn trúng thì bản thân được hồi máu."
		key_label = "Q"
		cooldown = 4.5
		mana_cost = 16.0
		icon_color = Color("fde68a")

	func execute(aim: Vector2) -> void:
		Audio.play_at(&"ui_select", caster.global_position, -6.0, 1.1)
		caster.spawn_projectile({
			"kind": &"light_wave",
			"direction": aim,
			"speed": 760.0,
			"damage": DAMAGE,
			"radius": 13.0,
			"life": 1.0,
			"power": 2.0,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": SLOW_TIME,
			"accent": Color("fef9c3"),
		})
		# Hồi máu kèm theo, kích hoạt nội tại Phước Lành để sinh thêm khiên.
		caster.heal(HEAL)


# ======================================================= E — KHIÊN PHƯỚC
class BlessedShield extends SkillBase:
	const SHIELD := 42.0
	const DURATION := 5.0
	const REFLECT := 0.30

	func _init() -> void:
		id = &"blessed_shield"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Khiên Phước"
		description = "Bọc mình trong khiên hấp thụ sát thương.\nTrong lúc có khiên, phản lại 30% sát thương đạn về kẻ bắn."
		key_label = "E"
		cooldown = 13.0
		mana_cost = 26.0
		icon_color = Color("fbbf24")

	func execute(_aim: Vector2) -> void:
		caster.add_shield(SHIELD)
		caster.set_meta(&"reflect_until", Time.get_ticks_msec() + int(DURATION * 1000.0))
		Audio.play_at(&"shield", caster.global_position, -2.0, 0.85)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 100.0,
			"life": 0.45,
			"accent": Color("fde68a"),
		})


# ======================================================= R — VÙNG THIÊNG
class Sanctuary extends SkillBase:
	const RADIUS := 175.0
	const LIFETIME := 6.0
	const HEAL_PER_TICK := 4.0

	func _init() -> void:
		id = &"sanctuary"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 420.0
		aoe_radius = RADIUS
		display_name = "Vùng Thiêng"
		description = "Tạo vùng đất thiêng hồi máu theo nhịp và TĂNG TỐC cho người đứng trong.\nĐứng trong vùng thì gần như không thể bị dồn chết."
		key_label = "R"
		cooldown = 17.0
		mana_cost = 38.0
		icon_color = Color("fcd34d")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"ui_select", center, -1.0, 0.75)
		caster.spawn_projectile({
			"kind": &"sanctuary",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			# Sát thương 0 nhưng vẫn cần một tick dương để vùng được xử lý; phần
			# hồi máu do nội tại đọc vị trí đứng mà làm.
			"tick_damage": 0.1,
			"tick_interval": 0.5,
			"radius": RADIUS,
			"life": LIFETIME,
			"accent": Color("fef9c3"),
		})
		caster.heal(HEAL_PER_TICK)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": center,
			"radius": RADIUS,
			"life": 0.5,
			"accent": Color("fde68a"),
		})
		# Ấn chú vàng thánh thiện bung ra khi vùng thiêng thành hình.
		VFXLibrary.arcane_burst(caster.world.fx, center, Color("fde68a"), RADIUS * 0.7)


# ======================================================== F — THIÊN KHAI
class DivineSmite extends SkillBase:
	const RADIUS := 190.0
	const DAMAGE := 30.0
	const STUN := 0.8
	const HEAL := 26.0
	const DELAY := 0.7

	func _init() -> void:
		id = &"divine_smite"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 520.0
		aoe_radius = RADIUS
		display_name = "Thiên Khai"
		description = "Giáng một cột sáng xuống vùng đã chọn, gây sát thương và CHOÁNG.\nBản thân được hồi máu lớn ngay khi chiêu giáng xuống."
		key_label = "F"
		cooldown = 32.0
		mana_cost = 48.0
		icon_color = Color("fffbeb")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"ui_select", center, 1.0, 0.65)

		# Vòng cảnh báo trước, cho đối thủ thời gian bước ra — chiêu mạnh thì
		# phải né được, nếu không nó chỉ là "bấm là trúng".
		caster.spawn_effect({
			"kind": &"telegraph",
			"position": center,
			"radius": RADIUS,
			"life": DELAY,
			"accent": Color("fef9c3"),
		})

		var tree := caster.get_tree()
		if tree == null:
			return
		var caster_ref := caster
		var peer := caster.peer_id
		tree.create_timer(DELAY).timeout.connect(func() -> void:
			if caster_ref == null or not is_instance_valid(caster_ref):
				return
			Audio.play_at(&"thunder", center, 2.0, 0.7)
			caster_ref.spawn_effect({
				"kind": &"explosion",
				"position": center,
				"radius": RADIUS,
				"life": 0.6,
				"accent": Color("fffbeb"),
			})
			for e in caster_ref.world.enemies_of(caster_ref):
				if not e.is_alive():
					continue
				if e.global_position.distance_to(center) > RADIUS + e.body_radius:
					continue
				e.take_damage(DAMAGE, peer)
				e.add_status(GameData.ST_FREEZE, 1, STUN, peer)
				e.apply_knockback(e.global_position - center, 200.0)
			caster_ref.heal(HEAL)
		)


# ======================================================= NỘI TẠI — PHƯỚC LÀNH
class Blessing extends Passive:
	## Tỉ lệ máu hồi được chuyển thêm thành khiên.
	const SHIELD_RATIO := 0.20
	## Thời gian khiên tồn tại sau mỗi lần hồi máu.
	const SHIELD_TIME := 4.0

	func _init() -> void:
		display_name = "Phước Lành"
		description = "Mỗi lần hồi máu đều cộng thêm 20% giá trị đó thành khiên tạm thời."

	func on_heal(amount: float) -> float:
		if owner_champ != null and amount > 0.0:
			owner_champ.add_shield(amount * SHIELD_RATIO)
		return amount

	## Phản sát thương khiên: đọc cờ `reflect_until` do Khiên Phước đặt.
	func on_damage_taken(amount: float, source_peer: int) -> void:
		if owner_champ == null or source_peer == 0:
			return
		var until: int = int(owner_champ.get_meta(&"reflect_until", 0))
		if until <= 0 or Time.get_ticks_msec() > until:
			return
		var src := _find(source_peer)
		if src == null or not src.is_alive():
			return
		src.take_damage(amount * 0.30, owner_champ.peer_id)

	func _find(pid: int) -> Champion:
		if owner_champ == null or owner_champ.world == null:
			return null
		for c in owner_champ.world.champions_list():
			if c.peer_id == pid:
				return c
		return null

	func status_text() -> String:
		if owner_champ == null:
			return ""
		var until: int = int(owner_champ.get_meta(&"reflect_until", 0))
		if until > Time.get_ticks_msec():
			return "Phước Lành · đang phản đòn"
		return ""
