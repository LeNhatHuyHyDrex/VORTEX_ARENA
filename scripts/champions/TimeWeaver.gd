extends RefCounted
## THỜI SƯ — bẻ cong dòng chảy thời gian trên sân đấu.
##
## Ý tưởng thiết kế: tướng duy nhất tương tác với TRÁI NGƯỢC thời gian.
## Không chiêu nào khác trong game cho phép "quay về chỗ mình đứng 2 giây
## trước" — và chính điều đó mở ra lớp kịch thuật hoàn toàn mới: lỡ bước vào
## bẫy thì tua lại, lao hụt thì tua lại, hoặc chủ động lao vào trao chiêu
## rồi rút về đúng điểm an toàn.
##
##   - Nội tại Hồi Quỹ: tụt dưới 50% máu thì tự bật khiên + tăng tốc
##     (mỗi 14 giây một lần) — thời gian "cho mình vay" một nhịp thở.
##   - Q Kẽ Hở Thời Gian: vùng đồng hồ cát trên đất, làm chậm và rút máu
##     theo nhịp. Dồn đủ chậm thì R nổ to.
##   - E Vòng Lùi: quay về vị trí của chính mình 2.2 giây trước — chiêu
##     phòng thủ độc nhất vô nhị.
##   - R Ngưng Trôi: đóng băng mọi thứ trong vùng — không phải bằng băng,
##     mà bằng chính sự chậm trễ đã gắn trên đối thủ: mỗi stack Chậm
##     trở thành sát thương, rồi kết tinh thành Khóa Hồn.
##   - F Vệt Thời Gian: lướt về một hướng, để lại ba vệt thời gian tách
##     chậm đuổi theo sau.
##
## Điểm hay: cả bộ kỹ năng xoay quanh stack Chậm — thứ Băng Sương Nữ cũng
## tạo ra, nên hai tướng kết hợp ăn khớp: đồng đội đóng băng, Thời Sư kết tinh.

const REWIND_SECONDS := 2.2
const PASSIVE_HP_TRIGGER := 0.5
const PASSIVE_COOLDOWN := 14.0

func build_champion(c: Champion) -> void:
	c.display_name = "Thời Sư"
	c.max_hp = 100.0
	c.hp = c.max_hp
	c.max_mana = 112.0
	c.mana = c.max_mana
	c.mana_regen = 11.0
	c.move_speed = 262.0
	c.body_radius = 19.0
	c.accent = Color("fb7185")
	c.skills.clear()
	for s in [TimeRift.new(), Rewind.new(), StutterNova.new(), ChronoTrail.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = ClockhandStrike.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [TimeRift.new(), Rewind.new(), StutterNova.new(), ChronoTrail.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return ClockhandStrike.new()

func build_passive():
	return TimeDebt.new()


# ==================================================== ĐÁNH THƯỜNG — KIM ĐỒNG
class ClockhandStrike extends SkillBase:
	const RANGE := 560.0
	const SPEED := 620.0
	const DAMAGE := 6.0
	const SLOW_TIME := 1.2

	func _init() -> void:
		id = &"clockhand_strike"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 580.0
		aoe_radius = 0.0
		display_name = "Kim Xuyên Tâm"
		description = "Bắn kim đồng hồ bay xa, trúng thì Chậm 1 stack —\nnguồn gắn Chậm rẻ tiền nhất của bà. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.5
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("fda4af")

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
			"accent": Color("fda4af"),
		})
		Audio.play_at(&"bolt", caster.global_position, -11.0, 1.6)


# ================================================== Q — KẺ HỞ THỜI GIAN
class TimeRift extends SkillBase:
	const TICK_DAMAGE := 4.0
	const LIFETIME := 4.0

	func _init() -> void:
		id = &"time_rift"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 300.0
		aoe_radius = 85.0
		display_name = "Kẽ Hở"
		description = "Mở một vùng thời gian nứt vỡ tại điểm chọn.\nĐứng trong vùng bị rút máu theo nhịp và Chậm dồn dần, tồn tại 4 giây."
		key_label = "Q"
		cooldown = 7.0
		mana_cost = 20.0
		icon_color = Color("fb7185")

	func execute(_aim: Vector2) -> void:
		var at := ground_point(cast_range)
		Audio.play_at(&"mark", at, -4.0, 0.9)
		caster.spawn_projectile({
			"kind": &"time_rift",
			"position": at,
			"direction": caster.aim_dir,
			"is_zone": true,
			"radius": 85.0,
			"life": LIFETIME,
			"power": 0.0,
			"tick_damage": TICK_DAMAGE,
			"tick_interval": 0.5,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": 1.5,
			"accent": Color("fb7185"),
		})
		# Vòng ấn chú thời gian bung ra khi kẽ hở mở — tấm kính không gian vỡ.
		VFXLibrary.arcane_burst(caster.world.fx, at, Color("f0abfc"), 70.0)
		# Mảnh kính thời gian xoè tại điểm mở kẽ — chữ ký hồng tím riêng.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.spell_seq(caster.world.fx, "fx7_energyBall", at, 1.0,
				Color(0.95, 0.6, 0.85, 0.8), 26.0)


# =========================================================== E — VÒNG LÙI
class Rewind extends SkillBase:
	## Lịch sử vị trí của chính người niệm, ghi mỗi tick.
	## Mỗi phần tử là Vector3(t_giây, x, y) — gói gọn một mẫu vị trí.
	var _history: Array = []

	func _init() -> void:
		id = &"rewind"
		cast_type = SkillBase.CastType.INSTANT
		cast_range = 0.0
		aoe_radius = 0.0
		display_name = "Vòng Lùi"
		description = "Tua ngược 2.2 giây: quay về đúng vị trí mình đứng lúc đó.\nNhận khiên và Tăng Tốc một nhịp. Chiêu phòng thủ không tướng nào có."
		key_label = "E"
		cooldown = 9.0
		mana_cost = 25.0
		icon_color = Color("fecdd3")

	## Ghi lịch sử vị trí. Chạy cả khi chiêu đang hồi — lịch sử phải liên tục,
	## nếu không lúc bấm sẽ không có gì để quay về.
	func tick(delta: float) -> void:
		super.tick(delta)
		if caster == null or not caster.is_alive():
			_history.clear()
			return
		var now := Time.get_ticks_msec() / 1000.0
		_history.append(Vector3(now, caster.global_position.x, caster.global_position.y))
		# Chỉ giữ đúng cửa sổ cần dùng, cộng dư một chút cho tìm kiếm mượt.
		while _history.size() > 2 and _history[0].x < now - REWIND_SECONDS - 0.5:
			_history.pop_front()

	func execute(_aim: Vector2) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var want := now - REWIND_SECONDS
		# Tìm mẫu lịch sử gần thời điểm muốn quay về nhất.
		var from: Vector2 = caster.global_position
		var best := Vector3(now, from.x, from.y)
		var best_diff := INF
		for entry in _history:
			var diff: float = absf(entry.x - want)
			if diff < best_diff:
				best_diff = diff
				best = entry
		# Nếu lịch sử trống (mới vào trận đã bấm) thì lùi về hướng ngược đang
		# ngắm một đoạn ngắn — vẫn có cảm giác "tua lại" chứ không nuột chữ ký.
		if best_diff == INF:
			var back: Vector2 = from - caster.aim_dir * 120.0
			best = Vector3(now, back.x, back.y)

		Audio.play_at(&"time_rewind", from, 0.0, 1.0)

		# Bóng thời gian ở chỗ đang đứng: người chơi thấy được "mình vừa ở đâu".
		caster.spawn_effect({
			"kind": &"shadow_marker",
			"position": from,
			"radius": 30.0,
			"life": 0.5,
			"accent": Color("fecdd3"),
		})
		# Dịch chuyển tức thời về vị trí quá khứ. Vị trí này từng hợp lệ nên
		# không cần kiểm tra va chạm lại.
		caster.global_position = Vector2(best.y, best.z)
		caster.apply_knockback(Vector2.ZERO, 0.0)
		caster.add_shield(12.0)
		caster.add_status(GameData.ST_HASTE, 2, 1.0, caster.peer_id)
		# Vòng xung kích nhỏ ở điểm đến.
		caster.spawn_effect({
			"kind": &"explosion",
			"position": Vector2(best.y, best.z),
			"radius": 70.0,
			"life": 0.4,
			"accent": Color("fecdd3"),
		})
		_history.clear()


# ======================================================= R — NGƯNG TRÔI
class StutterNova extends SkillBase:
	const BASE_DAMAGE := 10.0
	const PER_SLOW_STACK := 3.0
	const RADIUS := 230.0

	func _init() -> void:
		id = &"stutter_nova"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = RADIUS
		display_name = "Ngưng Trôi"
		description = "Kết tinh mọi stack Chậm trên đối thủ xung quanh thành sát thương (mỗi stack +3).\nSau đó gắn Khóa Hồn 2 stack — mở đường cho combo kết liễu."
		key_label = "R"
		cooldown = 16.0
		mana_cost = 40.0
		icon_color = Color("f43f5e")

	func execute(_aim: Vector2) -> void:
		var center: Vector2 = caster.global_position
		Audio.play_at(&"ice_nova", center, 0.0, 0.8)
		# Sóng xung kích hình mặt đồng hồ lan ra.
		caster.spawn_effect({
			"kind": &"clock_nova",
			"position": center,
			"radius": RADIUS,
			"life": 0.55,
			"accent": Color("fb7185"),
		})
		# Ngưng trôi: cầu năng lượng hồng nổ quanh người + vòng mặt đồng hồ thứ hai.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.arcane_blast(caster.world.fx, center, RADIUS, Color("fb7185"), 0)
			VFXLibrary.shock_ring(caster.world.fx, center, RADIUS * 1.1,
				Color(0.95, 0.75, 0.85, 0.35), 0.5)
		for e in enemies_in_radius(center, RADIUS):
			var slow: int = e.get_stacks(GameData.ST_SLOW)
			e.take_damage(BASE_DAMAGE + PER_SLOW_STACK * slow, caster.peer_id)
			if e.consume_status(GameData.ST_SLOW) > 0:
				e.add_status(GameData.ST_MARK, 2, 4.0, caster.peer_id)
		# Tác dụng phụ: chính mình được tăng tốc — thời gian trôi nhanh hơn với người niệm.
		caster.add_status(GameData.ST_HASTE, 2, 1.5, caster.peer_id)


# ==================================================== F — VỆT THỜI GIAN
class ChronoTrail extends SkillBase:
	const DASH_REACH := 320.0
	const DASH_TIME := 0.2
	const ZONE_RADIUS := 55.0
	const ZONE_TICK := 3.0
	const ZONE_LIFE := 2.5

	func _init() -> void:
		id = &"chrono_trail"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 340.0
		aoe_radius = ZONE_RADIUS
		display_name = "Vệt Thời Gian"
		description = "Lướt về hướng chọn, để lại ba vệt thời gian tách rời.\nVệt rút máu và làm chậm ai đuổi theo — rút lui mà vẫn gây áp lực."
		key_label = "F"
		cooldown = 18.0
		mana_cost = 35.0
		icon_color = Color("fda4af")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		Audio.play_at(&"dash_fire", start, 0.0, 1.2)
		caster.begin_dash(dir, DASH_REACH / DASH_TIME, DASH_TIME)

		# Ba vệt rải dọc đường lướt: 25% - 55% - 85%.
		var marks: Array[float] = [0.25, 0.55, 0.85]
		for m in marks:
			var at: Vector2 = start + dir * (DASH_REACH * m)
			caster.spawn_projectile({
				"kind": &"time_rift",
				"position": at,
				"direction": dir,
				"is_zone": true,
				"radius": ZONE_RADIUS,
				"life": ZONE_LIFE,
				"power": 0.0,
				"tick_damage": ZONE_TICK,
				"tick_interval": 0.45,
				"status_id": GameData.ST_SLOW,
				"status_stacks": 1,
				"status_duration": 1.2,
				"accent": Color("fda4af"),
			})


# ==================================================== NỘI TẠI — HỒI QUỸ
class TimeDebt extends Passive:
	var _cooldown_left := 0.0
	var _armed := true

	func _init() -> void:
		display_name = "Hồi Quỹ"
		description = "Tụt dưới 50% máu thì thời gian 'cho vay' một nhịp: tự nhận khiên 12 và Tăng Tốc 1.5 giây. Mỗi 14 giây tối đa một lần."

	func tick(delta: float) -> void:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		if not _armed:
			# Hồi lại trạng thái sẵn sàng khi máu đã ở lại trên ngưỡng.
			if owner_champ != null and owner_champ.hp / maxf(owner_champ.max_hp, 1.0) > PASSIVE_HP_TRIGGER + 0.12:
				_armed = true

	func on_damage_taken(_amount: float, _source_peer: int) -> void:
		if owner_champ == null or not _armed or _cooldown_left > 0.0:
			return
		if owner_champ.hp / maxf(owner_champ.max_hp, 1.0) > PASSIVE_HP_TRIGGER:
			return
		_armed = false
		_cooldown_left = PASSIVE_COOLDOWN
		owner_champ.add_shield(12.0)
		owner_champ.add_status(GameData.ST_HASTE, 2, 1.5, owner_champ.peer_id)
		owner_champ.spawn_effect({
			"kind": &"clock_nova",
			"position": owner_champ.global_position,
			"radius": 60.0,
			"life": 0.4,
			"accent": Color("fecdd3"),
		})

	func status_text() -> String:
		if _cooldown_left > 0.0:
			return "Hồi Quỹ · %.0fs" % _cooldown_left
		return "Hồi Quỹ · sẵn sàng"
