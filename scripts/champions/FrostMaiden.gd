extends RefCounted
const VFXLibrary := preload("res://scripts/vfx/VFXLibrary.gd")
## BĂNG SƯƠNG NỮ — tướng khống chế. Không đánh nhanh, nhưng bắt được đối thủ
## là giữ được họ tại chỗ.
##
## Ý tưởng thiết kế: mọi đòn đều dẫn tới Đóng Băng, và Đóng Băng mới là thứ
## đáng sợ — vì nó vừa khoá di chuyển vừa khoá luôn cả việc ra chiêu. Nhưng
## thời gian đóng băng rất ngắn, nên muốn khai thác thì phải chuẩn bị trước.
##
## Chuỗi logic người chơi tự tìm ra:
##   Q gây Lạnh -> Q lần nữa lên mục tiêu đang Lạnh thì thành Đóng Băng
##   W lên mục tiêu đang Đóng Băng thì đập vỡ, sát thương tăng vọt
##   R đóng băng diện rộng, kèm Vỡ Giáp để cả đội dễ dứt điểm

func build_champion(c: Champion) -> void:
	c.display_name = "Băng Sương Nữ"
	c.max_hp = 92.0
	c.hp = c.max_hp
	c.max_mana = 110.0
	c.mana = c.max_mana
	c.mana_regen = 12.0
	c.move_speed = 240.0
	c.body_radius = 21.0
	c.accent = Color("7dd3fc")
	c.skills.clear()
	for s in [IceLance.new(), FrostNova.new(), IceSlide.new(), AbsoluteZero.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = FrostShard.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [IceLance.new(), FrostNova.new(), IceSlide.new(), AbsoluteZero.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return FrostShard.new()


# ======================================================= ĐÁNH THƯỜNG — TIA BĂNG
class FrostShard extends SkillBase:
	func _init() -> void:
		id = &"frost_shard"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 620.0
		aoe_radius = 0.0
		display_name = "Tia Băng"
		description = "Bắn mảnh băng nhỏ, kèm chút làm chậm. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.45
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("a5e8ff")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"ice_shard",
			"direction": aim,
			"speed": 680.0,
			"damage": 5.0,
			"radius": 7.0,
			"life": 1.15,
			"power": 0.9,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": 1.6,
			"accent": Color("a5e8ff"),
		})
		Audio.play_at(&"ice_shard", caster.global_position, -9.0, 1.3)


# ========================================================= Q — BĂNG TIỄN
class IceLance extends SkillBase:
	const SLOW_TIME := 3.0
	## Đóng băng khi bắn trúng mục tiêu vốn đã bị làm chậm.
	const FREEZE_TIME := 1.1

	func _init() -> void:
		id = &"ice_lance"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 700.0
		aoe_radius = 0.0
		display_name = "Băng Tiễn"
		description = "Phóng giáo băng xuyên qua kẻ địch, gây Lạnh.\nNếu mục tiêu ĐÃ BỊ LẠNH thì chuyển thành ĐÓNG BĂNG."
		key_label = "Q"
		cooldown = 3.6
		mana_cost = 14.0
		icon_color = Color("7dd3fc")

	func execute(aim: Vector2) -> void:
		# Tự quyết định hệ quả ngay lúc bắn, dựa trên trạng thái hiện tại của
		# mục tiêu — vì đạn bay không tự biết nên trao đổi gì.
		var dir := aim.normalized()
		var will_freeze := false
		var probe := enemies_in_cone(caster.global_position, dir, 520.0, 0.25)
		for e in probe:
			if e.has_status(GameData.ST_SLOW):
				will_freeze = true
				break

		caster.spawn_projectile({
			"kind": &"ice_lance",
			"direction": dir,
			"speed": 900.0,
			"damage": 10.0,
			"radius": 9.0,
			"life": 0.62,
			"power": 2.6,
			"pierce_left": 1,
			"status_id": GameData.ST_FREEZE if will_freeze else GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": FREEZE_TIME if will_freeze else SLOW_TIME,
			"accent": Color("bdf0ff"),
		})
		Audio.play_at(&"ice_shard", caster.global_position, -3.0, 0.85)


# ========================================================= W — VÒNG BĂNG
class FrostNova extends SkillBase:
	const RADIUS := 195.0
	const DAMAGE := 14.0
	## Sát thương cộng thêm khi đập vỡ mục tiêu đang bị đóng băng.
	const SHATTER_BONUS := 22.0
	const SLOW_TIME := 2.5

	func _init() -> void:
		id = &"frost_nova"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 195.0
		display_name = "Vòng Băng"
		description = "Sóng lạnh lan quanh người, gây sát thương và làm chậm.\nMục tiêu ĐANG ĐÓNG BĂNG bị ĐẬP VỠ, chịu thêm sát thương lớn."
		key_label = "E"
		cooldown = 8.5
		mana_cost = 24.0
		icon_color = Color("38bdf8")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"ice_nova", caster.global_position)
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.ice_spikes(caster.world.fx, caster.global_position, RADIUS * 0.75)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.42,
			"accent": Color("bdf0ff"),
		})
		for e in enemies_in_radius(caster.global_position, RADIUS):
			var shattered: bool = e.has_status(GameData.ST_FREEZE)
			var dmg := DAMAGE + (SHATTER_BONUS if shattered else 0.0)
			if shattered:
				# Đập vỡ thì giải phóng luôn trạng thái đóng băng.
				e.clear_status(GameData.ST_FREEZE)
			e.take_damage(dmg, caster.peer_id)
			e.add_status(GameData.ST_SLOW, 1, SLOW_TIME, caster.peer_id)
			e.apply_knockback(e.global_position - caster.global_position, 150.0)
			if shattered:
				caster.spawn_effect({
					"kind": &"explosion",
					"position": e.global_position,
					"radius": 60.0,
					"life": 0.35,
					"accent": Color("e0f7ff"),
				})


# ========================================================= E — TRƯỢT BĂNG
class IceSlide extends SkillBase:
	const DASH_SPEED := 880.0
	const DASH_TIME := 0.2
	const DASH_REACH := 205.0

	func _init() -> void:
		id = &"ice_slide"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 260.0
		aoe_radius = 0.0
		display_name = "Trượt Băng"
		description = "Lướt đi, để lại vệt băng làm chậm kẻ đi qua."
		key_label = "R"
		cooldown = 6.0
		mana_cost = 16.0
		icon_color = Color("93e5ff")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH
		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"ice_shard", start, -6.0, 0.7)

		# Tường băng dựng lại ngay chỗ vừa rời đi, vuông góc với hướng lướt.
		#
		# Đây là phần nâng cấp chính: Trượt Băng từ chỗ chỉ là "chạy trốn để lại
		# vệt chậm" thành chiêu có hai công dụng. Lướt ra xa thì có tường chắn
		# đạn phía sau; lướt xuyên qua đối thủ thì dựng tường ngay trước mặt họ.
		# Cùng một cú bấm, hai cách dùng — tuỳ hướng người chơi chọn.
		var perp := Vector2(-dir.y, dir.x)
		for i in range(3):
			var offset := (float(i) - 1.0) * 62.0
			caster.spawn_projectile({
				"kind": &"ice_wall",
				"position": start + perp * offset,
				"direction": perp,
				"speed": 0.0,
				"is_zone": true,
				"blocks_movement": true,
				"tick_damage": 2.0,
				"tick_interval": 0.6,
				"status_id": GameData.ST_SLOW,
				"status_stacks": 1,
				"status_duration": 1.5,
				"radius": 40.0,
				"life": 4.0,
				"accent": Color("bdf0ff"),
			})

		# Vệt băng: vừa làm chậm vừa gây sát thương nhẹ theo nhịp.
		for i in range(5):
			var t := float(i) / 4.0
			caster.spawn_projectile({
				"kind": &"ice_patch",
				"position": start.lerp(end, t),
				"speed": 0.0,
				"is_zone": true,
				"tick_damage": 3.0,
				"tick_interval": 0.5,
				"radius": 40.0,
				"life": 3.5,
				"status_id": GameData.ST_SLOW,
				"status_stacks": 1,
				"status_duration": 1.8,
				"accent": Color("7dd3fc"),
			})


# ================================================= R — TUYỆT ĐỐI ĐÓNG BĂNG
class AbsoluteZero extends SkillBase:
	const RADIUS := 350.0
	const DAMAGE := 18.0
	const FREEZE_TIME := 1.6
	## Sau khi đóng băng thì dán luôn Vỡ Giáp, để đối thủ bị dứt điểm dễ hơn.
	const BREAK_TIME := 4.0

	func _init() -> void:
		id = &"absolute_zero"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 350.0
		display_name = "Tuyệt Đối Đóng Băng"
		description = "Đóng băng mọi đối thủ trong tầm rộng.\nMục tiêu bị đóng băng còn dính VỠ GIÁP, nhận thêm 25% sát thương."
		key_label = "F"
		cooldown = 28.0
		mana_cost = 45.0
		icon_color = Color("e0f7ff")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"freeze", caster.global_position)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": RADIUS,
			"life": 0.6,
			"accent": Color("e0f7ff"),
		})
		for e in enemies_in_radius(caster.global_position, RADIUS):
			e.take_damage(DAMAGE, caster.peer_id)
			e.add_status(GameData.ST_FREEZE, 1, FREEZE_TIME, caster.peer_id)
			e.add_status(GameData.ST_BREAK, 1, BREAK_TIME, caster.peer_id)
			caster.spawn_effect({
				"kind": &"explosion",
				"position": e.global_position,
				"radius": 70.0,
				"life": 0.4,
				"accent": Color("93e5ff"),
			})


# ============================================================ NỘI TẠI — BĂNG GIÁP
func build_passive():
	return FrostArmor.new()


## Nội tại BĂNG GIÁP: bị đánh thì có 25% cơ hội đóng băng kẻ tấn công 0.45 giây.
##
## Có thời gian chờ 3 giây, và đây là con số quan trọng: không có nó thì chỉ cần
## đối thủ bắn liên tục là bị khoá cứng vĩnh viễn — nội tại sẽ biến từ "thưởng
## cho việc chịu đòn" thành "không thể chơi được".
class FrostArmor extends Passive:
	const CHANCE := 0.25
	const FREEZE_TIME := 0.45
	const COOLDOWN := 3.0

	var _cd := 0.0

	func _init() -> void:
		display_name = "Băng Giáp"
		description = "Bị đánh: 25% cơ hội đóng băng kẻ tấn công 0.45s. Hồi 3s."

	func tick(delta: float) -> void:
		_cd = maxf(0.0, _cd - delta)

	func on_damage_taken(_amount: float, source_peer: int) -> void:
		if _cd > 0.0 or owner_champ == null or source_peer == 0:
			return
		if randf() > CHANCE:
			return
		var src := _find(source_peer)
		if src == null or not src.is_alive():
			return
		_cd = COOLDOWN
		src.add_status(GameData.ST_FREEZE, 1, FREEZE_TIME, owner_champ.peer_id)
		owner_champ.spawn_effect({
			"kind": &"explosion",
			"position": owner_champ.global_position,
			"radius": 70.0,
			"life": 0.32,
			"accent": Color("bdf0ff"),
		})
		Audio.play_at(&"freeze", owner_champ.global_position, -6.0)

	func _find(pid: int) -> Champion:
		if owner_champ == null or owner_champ.world == null:
			return null
		for c in owner_champ.world.champions_list():
			if c.peer_id == pid:
				return c
		return null

	func status_text() -> String:
		return "Băng Giáp · sẵn sàng" if _cd <= 0.0 else "Băng Giáp · %.1fs" % _cd
