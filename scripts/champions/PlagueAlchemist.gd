extends RefCounted
## ĐỘC SƯ — luyện độc sư tầm xa, giết người bằng đồng hồ đếm ngược.
##
## Ý tưởng thiết kế: pháp sư độc đúng nghĩa — KHÔNG bắn đòn to, mà gieo Nhiễm
## Độc rồi khai thác. Mọi nguồn đòn của ông đều dán độc: bình ném đánh thường,
## tiêu độc tiễn dồn nhanh, Vực Độc gieo vùng bám đuổi. Điểm nhấn là nội tại
## Cấy Độc: đánh trúng kẻ nhiễm độc hoàn năng lượng, nên ông xoay chiêu liên
## tục không bao giờ cạn. Đại Nổ Dịch Bệnh là hồi kết: đốt toàn bộ stack độc
## thành một cú nổ — càng chịu đựng lâu, nổ càng đau.
##
## Chuỗi logic:
##   W Tiêu Độc Tiễn dồn 3 stack nhanh
##   Q Vực Độc gieo vùng, địch buộc rời vị trí
##   đánh thường ném bình tiếp tục nuôi độc
##   R Đại Nổ Dịch Bệnh đốt toàn bộ stack độc
##   E Thanh Lọc tự cleanse khi bị dồn sát thương

func build_champion(c: Champion) -> void:
	c.display_name = "Độc Sư"
	c.max_hp = 104.0
	c.hp = c.max_hp
	c.max_mana = 120.0
	c.mana = c.max_mana
	c.mana_regen = 11.0
	c.move_speed = 248.0
	c.body_radius = 19.0
	c.accent = Color("84cc16")
	c.skills.clear()
	for s in [ToxicPool.new(), PoisonDart.new(), Purify.new(), PlagueDetonation.new()]:
		s.bind(c)
		c.skills.append(s)
	c.basic_attack = FlaskToss.new()
	c.basic_attack.bind(c)

func skill_preview() -> Array:
	return [ToxicPool.new(), PoisonDart.new(), Purify.new(), PlagueDetonation.new()]

## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản.
func basic_attack_preview():
	return FlaskToss.new()


# ======================================================= ĐÁNH THƯỜNG — NÉM BÌNH ĐỘC
class FlaskToss extends SkillBase:
	const RANGE := 540.0
	const DAMAGE := 6.0
	const POISON_STACKS := 1
	const POISON_TIME := 5.0
	const POISON_MAX := 8

	func _init() -> void:
		id = &"flask_toss"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 560.0
		aoe_radius = 0.0
		display_name = "Ném Bình Độc"
		description = "Ném bình thủy tinh nổ tung thành độc: 6 sát thương\n+ 1 Nhiễm Độc. Đạn bay xa, đòi căn góc."
		key_label = "LMB"
		cooldown = 0.55
		mana_cost = 0.0
		is_basic = true
		icon_color = Color("a3e635")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"flask",
			"direction": aim,
			"speed": 560.0,
			"damage": DAMAGE,
			"radius": 8.0,
			"life": RANGE / 560.0,
			"power": 1.0,
			"status_id": GameData.ST_POISON,
			"status_stacks": POISON_STACKS,
			"status_duration": POISON_TIME,
			"status_max_stacks": POISON_MAX,
			"accent": Color("a3e635"),
		})
		Audio.play_at(&"fireball", caster.global_position, -10.0, 1.4)


# ========================================================= Q — VỰC ĐỘC
class ToxicPool extends SkillBase:
	const CAST_RANGE := 440.0
	const RADIUS := 135.0
	const TICK_DAMAGE := 5.0
	const TICK_INTERVAL := 0.5
	const LIFE := 4.0
	const POISON_MAX := 8

	func _init() -> void:
		id = &"toxic_pool"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 460.0
		aoe_radius = RADIUS
		display_name = "Vực Độc"
		description = "Tràn một vũng độc tại điểm chọn: 5 sát thương + 1\nNhiễm Độc mỗi 0.5 giây, kéo dài 4 giây."
		key_label = "Q"
		cooldown = 9.0
		mana_cost = 26.0
		icon_color = Color("84cc16")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(CAST_RANGE, aim)
		Audio.play_at(&"firewall", center, -4.0, 0.9)
		caster.spawn_projectile({
			"kind": &"toxic_zone",
			"position": center,
			"speed": 0.0,
			"is_zone": true,
			"tick_damage": TICK_DAMAGE,
			"tick_interval": TICK_INTERVAL,
			"status_id": GameData.ST_POISON,
			"status_stacks": 1,
			"status_duration": 5.0,
			"status_max_stacks": POISON_MAX,
			"radius": RADIUS,
			"life": LIFE,
			"accent": Color("84cc16"),
		})
		# Búng bọt độc nổ tung khi bình rơi vỡ — dấu ấn xanh lục loang ra.
		VFXLibrary.arcane_burst(caster.world.fx, center, Color("a3e635"), RADIUS * 0.6)


# ========================================================= W — TIÊU ĐỘC TIẾN
class PoisonDart extends SkillBase:
	const DAMAGE := 8.0
	const POISON_STACKS := 3
	const POISON_TIME := 5.0
	const POISON_MAX := 8

	func _init() -> void:
		id = &"poison_dart"
		cast_type = SkillBase.CastType.DIRECTION
		cast_range = 560.0
		aoe_radius = 0.0
		display_name = "Tiêu Độc Tiễn"
		description = "Phóng mũi tiễn độc bay nhanh: 8 sát thương +\n3 Nhiễm Độc. Chiêu dồn stack nhanh nhất."
		key_label = "E"
		cooldown = 4.5
		mana_cost = 16.0
		icon_color = Color("65a30d")

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"phantom_edge",
			"direction": aim,
			"speed": 780.0,
			"damage": DAMAGE,
			"radius": 8.0,
			"life": 1.1,
			"power": 1.2,
			"status_id": GameData.ST_POISON,
			"status_stacks": POISON_STACKS,
			"status_duration": POISON_TIME,
			"status_max_stacks": POISON_MAX,
			"accent": Color("a3e635"),
		})
		Audio.play_at(&"shadow_bolt", caster.global_position, -8.0, 1.2)


# ========================================================= E — THANH LỌC
class Purify extends SkillBase:
	const SHIELD := 16.0
	const HASTE_TIME := 1.8

	## Các trạng thái xấu mà chiêu này rửa sạch — kể cả độc của chính mình.
	const DEBUFFS: Array[StringName] = [
		GameData.ST_BURN, GameData.ST_MARK, GameData.ST_SLOW,
		GameData.ST_FREEZE, GameData.ST_BREAK, GameData.ST_POISON,
	]

	func _init() -> void:
		id = &"purify"
		cast_type = SkillBase.CastType.SELF
		cast_range = 0.0
		aoe_radius = 70.0
		display_name = "Thanh Lọc"
		description = "Uống thuốc giải: rửa sạch mọi trạng thái xấu trên mình\n(Bỏng, Chậm, Đóng Băng, Nhiễm Độc...), nhận 16 khiên + Tăng Tốc."
		key_label = "R"
		cooldown = 12.0
		mana_cost = 20.0
		icon_color = Color("bef264")

	func execute(_aim: Vector2) -> void:
		for debuff in DEBUFFS:
			caster.clear_status(debuff)
		caster.add_shield(SHIELD)
		caster.add_status(GameData.ST_HASTE, 1, HASTE_TIME, caster.peer_id)
		Audio.play_at(&"heal", caster.global_position, -4.0, 1.1)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": caster.global_position,
			"radius": 74.0,
			"life": 0.45,
			"accent": Color("bef264"),
		})


# ========================================================= R — ĐẠI NỔ DỊCH BỆNH
class PlagueDetonation extends SkillBase:
	const CAST_RANGE := 420.0
	const RADIUS := 170.0
	const BASE_DAMAGE := 10.0
	const PER_STACK := 7.0

	func _init() -> void:
		id = &"plague_detonation"
		cast_type = SkillBase.CastType.GROUND
		cast_range = 440.0
		aoe_radius = RADIUS
		display_name = "Đại Nổ Dịch Bệnh"
		description = "Kích nổ toàn bộ Nhiễm Độc tại vùng chọn: 10 sát thương\n+ 7 cho MỖI lớp độc bị đốt. Stack càng nhiều nổ càng to."
		key_label = "F"
		cooldown = 26.0
		mana_cost = 40.0
		icon_color = Color("4d7c0f")

	func execute(aim: Vector2) -> void:
		var center: Vector2 = ground_point(CAST_RANGE, aim)
		Audio.play_at(&"detonate", center, 0.0, 1.0)
		# Bùng khói độc tier-ultimate + mưa độc loang + rung màn hình.
		if caster.world != null and "fx" in caster.world:
			VFXLibrary.poison_burst(caster.world.fx, center, RADIUS, 1)
			VFXLibrary.poison_puddle(caster.world.fx, center, RADIUS * 0.8)
		VFXLibrary.ult_shake(self, 6.5)
		for e in enemies_in_radius(center, RADIUS):
			var stacks: int = e.consume_status(GameData.ST_POISON)
			e.take_damage(BASE_DAMAGE + PER_STACK * stacks, caster.peer_id)
		caster.spawn_effect({
			"kind": &"explosion",
			"position": center,
			"radius": RADIUS,
			"life": 0.5,
			"accent": Color("a3e635"),
		})


# ============================================================ NỘI TẠI — CẤY ĐỘC
func build_passive():
	return ToxinHarvest.new()


## Nội tại CẤY ĐỘC: đánh trúng kẻ đang Nhiễm Độc hoàn 1.5 năng lượng.
##
## Vì sao hoàn năng lượng chứ không phải sát thương: toàn bộ kit của ông đã
## nuôi được sát thương qua stack độc rồi; nội tại chỉ cần giải bài toán tài
## nguyên — cho phép ông xoay chiêu liên tục MIỄN PHÍ, đổi lại phải giữ nhịp
## bắn trúng kẻ nhiễm độc.
class ToxinHarvest extends Passive:
	const MANA_PER_HIT := 1.5

	func _init() -> void:
		display_name = "Cấy Độc"
		description = "Mỗi lần gây sát thương lên kẻ đang Nhiễm Độc, hoàn 1.5 năng lượng."

	func on_deal_damage(target: Champion, _amount: float) -> void:
		if owner_champ == null or not owner_champ.is_alive():
			return
		if target == null or not is_instance_valid(target) or not target.is_alive():
			return
		if not target.has_status(GameData.ST_POISON):
			return
		owner_champ.mana = minf(owner_champ.mana + MANA_PER_HIT, owner_champ.max_mana)

	func status_text() -> String:
		return "Cấy Độc"
