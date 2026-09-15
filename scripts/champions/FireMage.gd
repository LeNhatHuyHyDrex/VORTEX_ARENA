extends RefCounted
## HỎA PHÁP SƯ — tướng tầm xa, chuyên dồn stack Bỏng rồi kích nổ.
##
## Ý tưởng thiết kế: không có skill nào tự nói "hãy đánh theo thứ tự này".
## Mỗi skill chỉ để lại hoặc tiêu thụ một trạng thái. Người chơi tự phát hiện ra
## rằng Q dồn Bỏng, W đốt nhanh hơn nếu đã có Bỏng, E hồi Q nếu lướt trúng mục
## tiêu đang cháy, và R biến toàn bộ Bỏng thành một cú nổ lớn.
##
## Nhờ vậy cùng một bộ 4 skill cho ra nhiều đường combo khác nhau, tuỳ người chơi
## muốn đánh nhanh, đánh chắc, hay nhốt đối thủ trong tường lửa.

func build_champion(c: Champion) -> void:
	c.display_name = "Hỏa Pháp Sư"
	c.max_hp = 100.0
	c.hp = c.max_hp
	c.max_mana = 100.0
	c.mana = c.max_mana
	c.mana_regen = 11.0
	c.move_speed = 245.0
	c.body_radius = 22.0
	c.accent = Color("ff7a2f")
	c.skills.clear()
	for s in [Fireball.new(), FlameWall.new(), BlazeDash.new(), Detonate.new()]:
		s.bind(c)
		c.skills.append(s)
	# Đánh thường riêng: tia lửa nhỏ, bắn nhanh, không tốn năng lượng.
	c.basic_attack = SparkBolt.new()
	c.basic_attack.bind(c)

## Trả về danh sách skill chưa gắn tướng. Menu chọn tướng dùng hàm này để hiển
## thị mô tả mà không cần dựng cả một Champion.
func skill_preview() -> Array:
	return [Fireball.new(), FlameWall.new(), BlazeDash.new(), Detonate.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return SparkBolt.new()


# ======================================================== ĐÁNH THƯỜNG — TIA LỬA
class SparkBolt extends SkillBase:
	func _init() -> void:
		id = &"spark_bolt"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 520.0
		aoe_radius = 0.0
		display_name = "Tia Lửa"
		description = "Bắn nhanh một tia lửa nhỏ. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.42
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("ffb066")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"bolt",
			"direction": aim,
			"speed": 700.0,
			"damage": 6.0,
			"radius": 7.0,
			"life": 1.1,
			"power": 0.8,
			"accent": Color("ff9a4a"),
		})
		Audio.play_at(&"fireball", caster.global_position, -9.0, 1.35)


# =============================================================== Q — HỎA CẦU
class Fireball extends SkillBase:
	func _init() -> void:
		id = &"fireball"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 700.0
		aoe_radius = 0.0
		display_name = "Hỏa Cầu"
		description = "Bắn cầu lửa: sát thương + dồn 1 stack Bỏng.\nNền tảng của mọi combo."
		key_label = "Q"
		cooldown = 3.2
		mana_cost = 12.0
		icon_color = Color("ff8c3a")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"fireball",
			"direction": aim,
			"speed": 620.0,
			"damage": 11.0,
			"radius": 11.0,
			"life": 1.7,
			"power": 2.2,
			"status_id": GameData.ST_BURN,
			"status_stacks": 1,
			"status_duration": 5.0,
			"accent": Color("ff7a2f"),
		})
		Audio.play_at(&"fireball", caster.global_position)
		# Lớp niệm chiêu: lóe cam ngắn tại tay Staff — mỗi skill lửa đều có
		# "khởi động" riêng trước khi đạn bay.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.cast_flash(caster.world.fx, caster.global_position + aim.normalized() * 26.0,
				Color(1.0, 0.55, 0.2))


# ============================================================== W — TƯỜNG LỬA
class FlameWall extends SkillBase:
	## Bán kính vùng lửa.
	const ZONE_RADIUS := 82.0
	## Khoảng cách đặt vùng lửa tính từ người niệm.
	const PLACE_DISTANCE := 240.0
	## Thời gian tồn tại.
	const LIFETIME := 5.0

	func _init() -> void:
		id = &"flame_wall"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 420.0
		aoe_radius = 82.0
		display_name = "Tường Lửa"
		description = "Đặt vùng lửa gây sát thương theo nhịp.\nMục tiêu đang Bỏng đứng trong lửa sẽ bị dồn thêm stack."
		key_label = "E"
		cooldown = 9.0
		mana_cost = 22.0
		icon_color = Color("ffb020")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(PLACE_DISTANCE, aim)
		caster.spawn_projectile({
			"kind": &"firewall",
			"position": center,
			"direction": Vector2.RIGHT,
			"speed": 0.0,
			"is_zone": true,
			"damage": 0.0,
			"tick_damage": 6.0,
			"tick_interval": 0.4,
			"radius": ZONE_RADIUS,
			"life": LIFETIME,
			"accent": Color("ff7a2f"),
			# Đánh dấu để đấu trường biết đây là vùng "nuôi Bỏng".
			"burns_stacks": true,
			"owner_status_bonus": GameData.ST_BURN,
		})
		# Cột lửa phun lên khi tường lửa thành hình — cảm giác vùng cháy thật sự
		# bùng lên thay vì chỉ có vòng sáng nằm im trên sàn.
		VFXLibrary.fire_eruption(caster.world.fx, center, ZONE_RADIUS * 0.55)
		# Lớp pack: dấu vòng lửa khắc trên đất + lửa hút vào tâm vùng.
		VFXLibrary.fire_ground(caster.world.fx, center, ZONE_RADIUS)
		Audio.play_at(&"firewall", center)


# ============================================================== E — LƯỚT LỬA
class BlazeDash extends SkillBase:
	const DASH_SPEED := 950.0
	const DASH_TIME := 0.18
	const DASH_REACH := 215.0

	func _init() -> void:
		id = &"blaze_dash"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 260.0
		aoe_radius = 0.0
		display_name = "Lướt Lửa"
		description = "Lướt theo hướng ngắm, để lại vệt lửa.\nNếu xuyên trúng đối thủ ĐANG BỎNG: hồi ngay Hỏa Cầu và dồn thêm 1 stack."
		key_label = "R"
		cooldown = 6.0
		mana_cost = 15.0
		icon_color = Color("ff5f1f")

	func execute(aim: Vector2) -> void:
		var dir := aim.normalized()
		var start: Vector2 = caster.global_position
		var end: Vector2 = start + dir * DASH_REACH

		caster.begin_dash(dir, DASH_SPEED, DASH_TIME)
		Audio.play_at(&"dash_fire", start)
		# Vệt lửa bùng theo đường lướt.
		VFXLibrary.fire_eruption(caster.world.fx, start + dir * DASH_REACH * 0.5, 40.0)
		# Lớp pack: chém lửa theo đúng góc dash — vệt lửa có "hướng", không phải
		# một cột đứng im giữa đường.
		VFXLibrary.fire_slash(caster.world.fx, start.lerp(end, 0.5),
			rad_to_deg(dir.angle()), 1.15)

		# Vệt lửa dọc đường lướt — biến đường lướt thành công cụ kiểm soát khu vực.
		for i in range(5):
			var t := float(i) / 4.0
			caster.spawn_projectile({
				"kind": &"firewall",
				"position": start.lerp(end, t),
				"speed": 0.0,
				"is_zone": true,
				"tick_damage": 4.0,
				"tick_interval": 0.4,
				"radius": 34.0,
				"life": 1.6,
				"accent": Color("ff7a2f"),
			})

		# Cung lửa hai bên: đây là phần biến chiêu lướt thành chiêu tấn công.
		# Không lướt thẳng rồi để lại một vệt — mà quét một hình quạt về hai
		# phía, nên người chơi giỏi có thể lướt XUYÊN QUA đối thủ và đốt cả hai
		# bên sườn cùng lúc. Ai chỉ bấm lướt để chạy thì không bao giờ thấy phần
		# này hoạt động.
		var perp := Vector2(-dir.y, dir.x)
		for side in [-1.0, 1.0]:
			for i in range(3):
				var t := 0.30 + 0.30 * float(i)
				var pos: Vector2 = start.lerp(end, t) + perp * (side * (46.0 + 26.0 * float(i)))
				caster.spawn_projectile({
					"kind": &"firewall",
					"position": pos,
					"speed": 0.0,
					"is_zone": true,
					"tick_damage": 5.0,
					"tick_interval": 0.4,
					"radius": 38.0,
					"life": 2.2,
					"accent": Color("ffa347"),
				})

		# Kiểm tra xem có xuyên qua ai đang cháy không.
		var refunded := false
		for e in enemies():
			if _distance_to_segment(e.global_position, start, end) <= 38.0 + e.body_radius:
				e.take_damage(8.0, caster.peer_id)
				if e.has_status(GameData.ST_BURN):
					e.add_status(GameData.ST_BURN, 1, 5.0, caster.peer_id)
					refunded = true
		if refunded:
			# Đây là mấu chốt combo: lướt xuyên mục tiêu đang cháy để xả thêm Hỏa Cầu.
			for s in caster.skills:
				if s.id == &"fireball":
					s.reset_cooldown()
			caster.spawn_effect({
				"kind": &"explosion",
				"position": caster.global_position,
				"radius": 46.0,
				"life": 0.35,
				"accent": Color("ffd24a"),
			})

	## Khoảng cách từ điểm p tới đoạn thẳng ab — dùng để biết ai bị lướt xuyên qua.
	func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 0.0001:
			return p.distance_to(a)
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		return p.distance_to(a + ab * t)


# ============================================================== R — BÙNG NỔ
class Detonate extends SkillBase:
	const RADIUS := 380.0
	const BASE_DAMAGE := 14.0
	const DAMAGE_PER_STACK := 9.0
	## Từ mức stack này trở lên thì kèm hiệu ứng làm chậm.
	const SLOW_THRESHOLD := 4

	func _init() -> void:
		id = &"detonate"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 320.0
		display_name = "Bùng Nổ"
		description = "Tiêu thụ TOÀN BỘ stack Bỏng trên mọi đối thủ trong tầm.\nSát thương = 14 + 9 mỗi stack. Từ 4 stack trở lên còn làm chậm."
		key_label = "F"
		cooldown = 26.0
		mana_cost = 40.0
		icon_color = Color("ff3d00")

	func execute(_aim: Vector2) -> void:
		Audio.play_at(&"detonate", caster.global_position)
		if caster.world != null and "fx" in caster.world:
			# ULT Hỏa: nổ cầu lửa nhiều lớp (frame nổ + tia cắt + sóng kép +
			# khói đen) và rung màn hình — đòn kết phải "nặng" hơn mọi skill.
			VFXLibrary.fire_blast(caster.world.fx, caster.global_position, RADIUS * 0.7, 1)
			VFXLibrary.ult_shake(self, 8.0)
		var targets := enemies_in_radius(caster.global_position, RADIUS)
		var total := 0
		for e in targets:
			var stacks: int = e.consume_status(GameData.ST_BURN)
			if stacks <= 0:
				continue
			total += stacks
			var dmg := BASE_DAMAGE + DAMAGE_PER_STACK * float(stacks)
			e.take_damage(dmg, caster.peer_id)
			e.apply_knockback((e.global_position - caster.global_position), 260.0 + 40.0 * float(stacks))
			if stacks >= SLOW_THRESHOLD:
				e.add_status(GameData.ST_SLOW, 1, 2.5, caster.peer_id)
			caster.spawn_effect({
				"kind": &"explosion",
				"position": e.global_position,
				"radius": 40.0 + 14.0 * float(stacks),
				"life": 0.5,
				"accent": Color("ff5f1f"),
			})
		# Nếu không ai dính Bỏng thì vẫn phát nổ tại chỗ cho có phản hồi thị giác.
		if total == 0:
			caster.spawn_effect({
				"kind": &"explosion",
				"position": caster.global_position + caster.aim_dir * 60.0,
				"radius": 60.0,
				"life": 0.4,
				"accent": Color("ff7a2f"),
			})


# ============================================================ NỘI TẠI — THIÊU ĐỐT
func build_passive():
	return EmberFeed.new()


## Nội tại THIÊU ĐỐT: cứ 2 đòn đánh thường thì cộng thêm 1 stack Bỏng lên mục
## tiêu gần nhất, và mục tiêu đang Bỏng chịu thêm 8% sát thương từ Hỏa Pháp Sư.
##
## Vì sao gắn vào đánh thường: chiêu Q đã cộng Bỏng rồi, nên nội tại phải thưởng
## cho việc dùng đánh thường — nếu không thì người chơi chỉ bấm Q rồi đứng chờ
## hồi chiêu, và cả bộ chiêu còn lại thành vô nghĩa.
class EmberFeed extends Passive:
	const HITS_PER_STACK := 2
	const BURN_BONUS := 0.08

	var _hits := 0

	func _init() -> void:
		display_name = "Thiêu Đốt"
		description = "Mỗi 2 đòn đánh thường cộng 1 stack Bỏng. Mục tiêu đang Bỏng chịu thêm 8% sát thương từ bạn."

	func on_basic_cast() -> void:
		if owner_champ == null:
			return
		_hits += 1
		if _hits < HITS_PER_STACK:
			return
		_hits = 0
		var e := owner_champ.nearest_enemy(620.0)
		if e != null:
			e.add_status(GameData.ST_BURN, 1, 5.0, owner_champ.peer_id)

	func outgoing_multiplier(target: Champion) -> float:
		if target != null and target.has_status(GameData.ST_BURN):
			return 1.0 + BURN_BONUS
		return 1.0

	func status_text() -> String:
		return "Thiêu Đốt · %d/%d" % [_hits, HITS_PER_STACK]
