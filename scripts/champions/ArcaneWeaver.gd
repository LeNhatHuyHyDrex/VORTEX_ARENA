extends RefCounted
## HƯ KHÔNG PHÁP SƯ — tướng chuyên đặt vùng và dịch chuyển.
##
## Ý tưởng thiết kế: đây là tướng dạy người chơi cách dùng hệ thống chọn vùng.
## Gần như mọi chiêu đều là loại GROUND — bấm phím trước để xem vòng phạm vi,
## rồi bấm chuột trái để chốt. Chơi tướng này một lúc là quen tay với luồng mới.
##
## Chuỗi logic người chơi tự tìm ra:
##   Q đánh dấu vùng nổ, F ăn thêm sát thương lên mục tiêu đã bị đánh dấu
##   E dịch chuyển tới chỗ đã chọn, để lại một vụ nổ ngay tại chỗ vừa đứng
##   R dựng Hố Đen hút đối thủ vào giữa, giữ họ trong đó cho Q và F đánh
##
## Điểm hay: E vừa là chiêu rút lui vừa là chiêu áp sát, tuỳ người chơi đặt
## vùng ở đâu. Cùng một chiêu, hai cách dùng hoàn toàn khác nhau.

func build_champion(c: Champion) -> void:
	c.display_name = "Hư Không Pháp Sư"
	c.max_hp = 94.0
	c.hp = c.max_hp
	c.max_mana = 115.0
	c.mana = c.max_mana
	c.mana_regen = 13.0
	c.move_speed = 242.0
	c.body_radius = 21.0
	c.accent = Color("8b5cf6")
	c.skills.clear()
	for s in [VoidBlast.new(), Blink.new(), BlackHole.new(), Collapse.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = VoidBolt.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [VoidBlast.new(), Blink.new(), BlackHole.new(), Collapse.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return VoidBolt.new()


# ==================================================== ĐÁNH THƯỜNG — TIA HƯ KHÔNG
class VoidBolt extends SkillBase:
	func _init() -> void:
		id = &"void_bolt"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 620.0
		aoe_radius = 0.0
		display_name = "Tia Hư Không"
		description = "Bắn một tia năng lượng tím. Không tốn năng lượng."
		key_label = "LMB"
		cooldown = 0.5
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("a78bfa")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"void_bolt",
			"direction": aim,
			"speed": 700.0,
			"damage": 5.5,
			"radius": 8.0,
			"life": 1.1,
			"power": 0.95,
			"accent": Color("a78bfa"),
		})
		Audio.play_at(&"void_bolt", caster.global_position, -9.0, 1.25)


# ================================================== Q — VỤ NỔ KHÔNG GIAN
class VoidBlast extends SkillBase:
	const RADIUS := 105.0
	const DAMAGE := 20.0
	const MARK_TIME := 6.0

	func _init() -> void:
		id = &"void_blast"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 470.0
		aoe_radius = RADIUS
		display_name = "Vụ Nổ Không Gian"
		description = "Nổ tại vùng đã chọn, gây sát thương và ĐÁNH DẤU mục tiêu.\nMục tiêu bị đánh dấu chịu thêm sát thương từ Sụp Đổ."
		key_label = "Q"
		cooldown = 5.0
		mana_cost = 18.0
		icon_color = Color("8b5cf6")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"void_blast", center)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": center,
			"radius": RADIUS,
			"life": 0.45,
			"accent": Color("a78bfa"),
		})
		for e in enemies_in_radius(center, RADIUS):
			e.take_damage(DAMAGE, caster.peer_id)
			e.add_status(GameData.ST_MARK, 1, MARK_TIME, caster.peer_id, 3)
			caster.spawn_effect({
				"kind": &"explosion",
				"position": e.global_position,
				"radius": 40.0,
				"life": 0.3,
				"accent": Color("c4b5fd"),
			})


# ========================================================= E — DỊCH CHUYỂN
class Blink extends SkillBase:
	const DASH_TIME := 0.18
	const LEAVE_RADIUS := 92.0
	const LEAVE_DAMAGE := 14.0
	## Khoảng cách tối thiểu để tránh dịch chuyển vào đúng chỗ đang đứng.
	const MIN_DISTANCE := 40.0

	func _init() -> void:
		id = &"blink"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 520.0
		aoe_radius = LEAVE_RADIUS
		display_name = "Dịch Chuyển"
		description = "Dịch chuyển tới vùng đã chọn.\nĐể lại một vụ nổ tại chỗ vừa đứng, gây sát thương kẻ bám theo."
		key_label = "E"
		cooldown = 11.0
		mana_cost = 24.0
		icon_color = Color("c084fc")

	func execute(_aim: Vector2) -> void:
		var origin: Vector2 = caster.global_position
		var destination := ground_point(cast_range)

		# Không cho dịch chuyển vào trong vật cản — nếu chỗ đích bị chặn thì
		# lùi về phía trước một đoạn thay vì huỷ chiêu (đã tốn năng lượng rồi).
		if caster.world != null and caster.world.has_method("is_blocked_at"):
			if caster.world.is_blocked_at(destination, caster.body_radius):
				var dir := (destination - origin).normalized()
				destination = origin + dir * MIN_DISTANCE

		var delta := destination - origin
		if delta.length() < MIN_DISTANCE:
			delta = delta.normalized() * MIN_DISTANCE if delta.length() > 1.0 \
				else Vector2.RIGHT * MIN_DISTANCE
			destination = origin + delta

		# Vụ nổ tại chỗ cũ, trước khi rời đi.
		caster.spawn_effect({
			"kind": &"explosion",
			"position": origin,
			"radius": LEAVE_RADIUS,
			"life": 0.4,
			"accent": Color("a78bfa"),
		})
		for e in enemies_in_radius(origin, LEAVE_RADIUS):
			e.take_damage(LEAVE_DAMAGE, caster.peer_id)
			e.add_status(GameData.ST_SLOW, 1, 2.0, caster.peer_id)
		Audio.play_at(&"blink", origin)

		# Dịch chuyển tức thì rồi mới mở khoá, để `begin_dash` chỉ giữ hình ảnh
		# chuyển động chứ không kéo lê nhân vật qua cả bản đồ.
		caster.global_position = destination
		caster.begin_dash(delta.normalized(), 0.0, DASH_TIME)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": destination,
			"radius": 54.0,
			"life": 0.35,
			"accent": Color("c4b5fd"),
		})
		Audio.play_at(&"blink", destination, -3.0, 1.2)


# ============================================================ R — HỐ ĐEN
class BlackHole extends SkillBase:
	const RADIUS := 165.0
	const PULL := 165.0
	const LIFETIME := 3.2
	const TICK_DAMAGE := 3.5

	func _init() -> void:
		id = &"black_hole"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 420.0
		aoe_radius = RADIUS
		display_name = "Hố Đen"
		description = "Mở một hố đen HÚT mọi đối thủ quanh đó vào tâm.\nVừa hút vừa gây sát thương theo nhịp và làm chậm."
		key_label = "R"
		cooldown = 22.0
		mana_cost = 40.0
		icon_color = Color("7c3aed")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"black_hole", center)
		caster.spawn_projectile({
			"kind": &"black_hole",
			"position": center,
			"direction": Vector2.RIGHT,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TICK_DAMAGE,
			"tick_interval": 0.35,
			"radius": RADIUS,
			"life": LIFETIME,
			"status_id": GameData.ST_SLOW,
			"status_stacks": 1,
			"status_duration": 1.2,
			"pull_strength": PULL,
			"pull_radius": RADIUS,
			"accent": Color("8b5cf6"),
		})


# ========================================================== F — SỤP ĐỔ
class Collapse extends SkillBase:
	const RADIUS := 200.0
	const DAMAGE := 30.0
	## Sát thương cộng thêm cho mỗi stack Đánh Dấu trên mục tiêu.
	const MARK_BONUS := 26.0
	const DELAY := 0.85
	const STUN_TIME := 0.7

	func _init() -> void:
		id = &"collapse"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 560.0
		aoe_radius = RADIUS
		display_name = "Sụp Đổ"
		description = "Nứt toác không gian tại vùng đã chọn.\nMục tiêu đang bị ĐÁNH DẤU chịu thêm sát thương và bị choáng."
		key_label = "F"
		cooldown = 30.0
		mana_cost = 48.0
		icon_color = Color("ddd6fe")

	func execute(_aim: Vector2) -> void:
		var center := ground_point(cast_range)
		Audio.play_at(&"void_blast", center, 2.0, 0.7)

		# Cảnh báo trước: vẽ một vòng mờ đúng bằng vùng nổ. Người chơi đối diện
		# có gần một giây để bước ra — đây là chiêu mạnh nên phải né được.
		caster.spawn_effect({
			"kind": &"telegraph",
			"position": center,
			"radius": RADIUS,
			"life": DELAY,
			"accent": Color("c4b5fd"),
		})

		# Chờ hết thời gian cảnh báo rồi mới nổ. Dùng timer của cây scene vì
		# `execute` không được phép await (nó chạy trong vòng tick mô phỏng).
		var tree := caster.get_tree()
		if tree == null:
			return
		var caster_ref := caster
		var peer := caster.peer_id
		tree.create_timer(DELAY).timeout.connect(func() -> void:
			if caster_ref == null or not is_instance_valid(caster_ref):
				return
			caster_ref.spawn_effect({
				"kind": &"explosion",
				"position": center,
				"radius": RADIUS,
				"life": 0.55,
				"accent": Color("8b5cf6"),
			})
			# Bùng nổ tinh thể hư không — vòng ấn chú xoay + mảnh vỡ bay.
			VFXLibrary.arcane_burst(caster_ref.world.fx, center,
				Color("a78bfa"), RADIUS * 0.8)
			Audio.play_at(&"void_collapse", center, 3.0)
			for e in caster_ref.world.enemies_of(caster_ref):
				if not e.is_alive():
					continue
				if e.global_position.distance_to(center) > RADIUS + e.body_radius:
					continue
				var marks: int = e.get_stacks(GameData.ST_MARK)
				var dmg := DAMAGE + MARK_BONUS * float(marks)
				if marks > 0:
					e.consume_status(GameData.ST_MARK)
					e.add_status(GameData.ST_FREEZE, 1, STUN_TIME, peer)
				e.take_damage(dmg, peer)
				e.apply_knockback(e.global_position - center, 240.0)
			)


# ======================================================== NỘI TẠI — KHÔNG GIAN VẶN
func build_passive():
	return WarpedSpace.new()


## Nội tại KHÔNG GIAN VẶN: mọi vùng ảnh hưởng rộng thêm 20%.
##
## Hệ số được nhân ở `Arena.spawn_projectile` chứ không sửa từng chiêu, nên nó
## áp cho cả 25 chiêu hiện có mà không phải đụng vào file tướng nào.
class WarpedSpace extends Passive:
	const AREA_BONUS := 0.2

	func _init() -> void:
		display_name = "Không Gian Vặn"
		description = "Mọi vùng ảnh hưởng của bạn rộng thêm 20%."

	func area_multiplier() -> float:
		return 1.0 + AREA_BONUS
