extends RefCounted
## HƯ ẢNH — sát thủ dịch chuyển, tướng của những pha né đòn.
##
## Ý tưởng thiết kế: đây là tướng trả lời câu hỏi "làm sao để né chiêu rồi vẫn
## đánh trả được". Cả bộ chiêu xoay quanh MỘT tài nguyên duy nhất: cái bóng.
##
##   - Nội tại tự đặt bóng sau lưng mỗi 4 giây
##   - Q Tốc Biến: lướt tức thì, để lại bóng tại chỗ cũ — hồi chỉ 3 giây
##   - E Đổi Bóng: hoán đổi vị trí với bóng, tức là quay về chỗ cũ trong tích tắc
##   - F Đâm Từ Bóng: nhảy ra sau lưng đối thủ rồi để lại bóng tại đó
##
## Chuỗi phô diễn đẹp nhất: Q lướt qua đối thủ → đánh → E quay về chỗ cũ → đối
## thủ không biết mình đang ở đâu. Người mới sẽ dùng Q để chạy trốn và E để...
## cũng chạy trốn, nên hai chiêu đó thành vô dụng với họ.

## Vị trí bóng được lưu trên chính tướng qua `set_meta`, không lưu trong skill.
##
## Lý do: cả ba chiêu Q/E/F đều cần đọc cùng một cái bóng. Nếu mỗi chiêu giữ
## một bản riêng thì chúng sẽ lệch nhau ngay sau cú lướt đầu tiên.
const META_SHADOW := &"shadow_pos"
const META_HAS := &"shadow_alive"

func build_champion(c: Champion) -> void:
	c.display_name = "Hư Ảnh"
	c.max_hp = 96.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 11.0
	c.move_speed = 286.0
	c.body_radius = 20.0
	c.accent = Color("22d3ee")
	c.skills.clear()
	for s in [BlinkStep.new(), ShadowSwap.new(), TwinEcho.new(), BackStrike.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = PhantomEdge.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [BlinkStep.new(), ShadowSwap.new(), TwinEcho.new(), BackStrike.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return PhantomEdge.new()

func build_passive():
	return ShadowTrail.new()


# ======================================================= ĐÁNH THƯỜNG — ẢNH KIẾM
class PhantomEdge extends SkillBase:
	func _init() -> void:
		id = &"phantom_edge"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 520.0
		aoe_radius = 0.0
		display_name = "Ảnh Kiếm"
		description = "Phóng lưỡi dao ánh sáng. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.4
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("67e8f9")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"phantom_edge",
			"direction": aim,
			"speed": 760.0,
			"damage": 5.0,
			"radius": 8.0,
			"life": 1.0,
			"power": 1.0,
			"accent": Color("67e8f9"),
		})
		Audio.play_at(&"void_bolt", caster.global_position, -10.0, 1.4)


# ============================================================ Q — TỐC BIẾN
class BlinkStep extends SkillBase:
	const DASH_REACH := 230.0
	const DASH_TIME := 0.12

	func _init() -> void:
		id = &"blink_step"
		# INSTANT: bấm là lướt luôn. Chiêu né đòn mà bắt xác nhận thêm một cú
		# bấm nữa thì đã ăn đòn xong rồi.
		cast_type = SkillBase.CastType.INSTANT
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Tốc Biến"
		description = "Lướt tức thì theo hướng ngắm, để lại một cái bóng tại chỗ cũ.\nHồi chiêu rất ngắn — đây là chiêu né đòn chính."
		key_label = "Q"
		cooldown = 3.0
		mana_cost = 8.0
		icon_color = Color("22d3ee")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var origin: Vector2 = caster.global_position
		var dest: Vector2 = origin + dir * DASH_REACH

		# Không lướt vào trong tường — nếu đích bị chặn thì lướt ngắn lại thay
		# vì huỷ chiêu. Người chơi đã bấm rồi, không nên mất lượt.
		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(dest, caster.body_radius):
				dest = origin + dir * (DASH_REACH * 0.45)

		caster.set_meta(META_SHADOW, origin)
		caster.set_meta(META_HAS, true)
		# Tốc biến: vòng ảnh cyan nở tại chỗ đứng — bóng ở lại nơi cũ.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.shock_ring(caster.world.fx, origin, 44.0,
				Color(0.4, 0.85, 0.95, 0.5), 0.3)
		caster.spawn_effect({
			"kind": &"shadow_marker",
			"position": origin,
			"radius": 22.0,
			"life": 4.0,
			"accent": Color("22d3ee"),
		})

		caster.begin_dash(dir, DASH_REACH / DASH_TIME, DASH_TIME)
		Audio.play_at(&"blink", origin, -3.0, 1.25)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": dest,
			"radius": 40.0,
			"life": 0.25,
			"accent": Color("a5f3fc"),
		})


# ============================================================ E — ĐỔI BÓNG
class ShadowSwap extends SkillBase:
	func _init() -> void:
		id = &"shadow_swap"
		cast_type = SkillBase.CastType.INSTANT
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Đổi Bóng"
		description = "Hoán đổi vị trí với cái bóng gần nhất.\nKhông có bóng thì chiêu không làm gì — hãy tạo bóng bằng Tốc Biến trước."
		key_label = "E"
		cooldown = 5.0
		mana_cost = 12.0
		icon_color = Color("0ea5e9")

	func can_cast() -> bool:
		# Không có bóng thì không cho bấm, để người chơi không mất năng lượng
		# cho một chiêu chắc chắn không làm gì.
		if caster == null or not caster.get_meta(META_HAS, false):
			return false
		return super.can_cast()

	func block_reason() -> String:
		if caster != null and not caster.get_meta(META_HAS, false):
			return "Chưa có bóng"
		return super.block_reason()

	func execute(_aim: Vector2) -> void:
		var shadow: Vector2 = caster.get_meta(META_SHADOW, caster.global_position)
		var here: Vector2 = caster.global_position

		# Bóng ở lại chỗ vừa rời đi, nên chuỗi Q → E → Q vẫn còn bóng để dùng.
		caster.set_meta(META_SHADOW, here)

		caster.global_position = shadow
		caster.velocity = Vector2.ZERO
		Audio.play_at(&"blink", here, -2.0, 0.85)
		Audio.play_at(&"teleport", shadow)

		for pos in [here, shadow]:
			caster.spawn_effect({
				"kind": &"explosion",
				"position": pos,
				"radius": 46.0,
				"life": 0.3,
				"accent": Color("67e8f9"),
			})
		# Đổi bóng cũng gây sát thương nhẹ quanh chỗ đáp xuống, để chiêu này
		# không hoàn toàn chỉ là di chuyển.
		for e in enemies_in_radius(shadow, 74.0):
			e.take_damage(9.0, caster.peer_id)
			e.add_status(GameData.ST_SLOW, 1, 1.2, caster.peer_id)


# ============================================================ R — BÓNG BỘI
class TwinEcho extends SkillBase:
	const DURATION := 5.0

	func _init() -> void:
		id = &"twin_echo"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 160.0
		display_name = "Bóng Bội"
		description = "Trong 5 giây, mọi chiêu bạn tung ra đều bắn thêm một bản sao từ vị trí bóng."
		key_label = "R"
		cooldown = 14.0
		mana_cost = 22.0
		icon_color = Color("38bdf8")

	func execute(_aim: Vector2) -> void:
		# Đánh dấu trên tướng; phần bắn thêm do nội tại Bóng Theo đọc cờ này.
		caster.set_meta(&"echo_until", Time.get_ticks_msec() + int(DURATION * 1000.0))
		Audio.play_at(&"ui_select", caster.global_position)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 130.0,
			"life": 0.5,
			"accent": Color("22d3ee"),
		})


# ========================================================= F — ĐÂM TỪ BÓNG
class BackStrike extends SkillBase:
	const SEARCH := 460.0
	const BEHIND_OFFSET := 62.0
	const DAMAGE := 24.0

	func _init() -> void:
		id = &"back_strike"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 460.0
		aoe_radius = 70.0
		display_name = "Đâm Từ Bóng"
		description = "Lao tới sau lưng đối thủ gần nhất và đâm một nhát nặng.\nĐể lại bóng tại chỗ vừa đứng, nên rút lui được ngay bằng Đổi Bóng."
		key_label = "F"
		cooldown = 20.0
		mana_cost = 34.0
		icon_color = Color("06b6d4")

	func execute(aim: Vector2) -> void:
		var target := nearest_enemy_in_range(SEARCH)
		if target == null:
			# Không có ai thì lướt theo hướng ngắm, vẫn để lại bóng.
			var dir := aim.normalized()
			var from: Vector2 = caster.global_position
			caster.set_meta(META_SHADOW, from)
			caster.set_meta(META_HAS, true)
			caster.begin_dash(dir, 1400.0, 0.16)
			return

		var origin: Vector2 = caster.global_position
		var away := (target.global_position - origin)
		if away.length_squared() < 1.0:
			away = -aim
		var dest: Vector2 = target.global_position + away.normalized() * BEHIND_OFFSET

		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(dest, caster.body_radius + 2.0):
				dest = origin

		caster.set_meta(META_SHADOW, origin)
		caster.set_meta(META_HAS, true)

		caster.global_position = dest
		caster.velocity = Vector2.ZERO
		caster.aim_dir = (target.global_position - caster.global_position).normalized()

		target.take_damage(DAMAGE, caster.peer_id)
		target.add_status(GameData.ST_MARK, 1, 4.0, caster.peer_id, 3)
		Audio.play_at(&"slash_crit", dest)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": dest,
			"radius": 90.0,
			"life": 0.4,
			"accent": Color("a5f3fc"),
		})
		# Đâm từ bóng (ULT): lóe hồng đặc trưng + sóng kép + rung màn hình.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.cast_flash(caster.world.fx, dest, Color("f0abfc"))
			VFXLibrary.shock_ring(caster.world.fx, dest, 104.0,
				Color(0.55, 0.9, 1.0, 0.45), 0.45)
		VFXLibrary.ult_shake(self, 6.0)


# ======================================================== NỘI TẠI — BÓNG THEO
class ShadowTrail extends Passive:
	const INTERVAL := 4.0
	const ECHO_WINDOW_MS := 5000

	var _timer := 0.0

	func _init() -> void:
		display_name = "Bóng Theo"
		description = "Mỗi 4 giây tự để lại một bóng tại chỗ đang đứng. Đổi Bóng dùng bóng đó để quay về."

	func tick(delta: float) -> void:
		if owner_champ == null or not owner_champ.is_alive():
			return
		_timer += delta
		if _timer < INTERVAL:
			return
		_timer = 0.0
		owner_champ.set_meta(META_SHADOW, owner_champ.global_position)
		owner_champ.set_meta(META_HAS, true)
		owner_champ.spawn_effect({
			"kind": &"shadow_marker",
			"position": owner_champ.global_position,
			"radius": 20.0,
			"life": 4.0,
			"accent": Color("22d3ee"),
		})

	func status_text() -> String:
		if not owner_champ.get_meta(META_HAS, false):
			return "Bóng Theo · chưa có bóng"
		if _timer < INTERVAL:
			return "Bóng Theo · %.1fs" % (INTERVAL - _timer)
		return "Bóng Theo · sẵn sàng"
