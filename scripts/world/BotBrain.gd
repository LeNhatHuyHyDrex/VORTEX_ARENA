class_name BotBrain
extends RefCounted
## Trí tuệ đơn giản cho chế độ luyện tập.
##
## Mục đích không phải là tạo ra đối thủ khó, mà là tạo ra thứ để người chơi
## thử combo: bot giữ khoảng cách hợp lý, né theo hình sin, và ra chiêu theo
## đúng logic mà người chơi sẽ dùng. Nhờ vậy ta kiểm tra được cả hệ thống
## tương tác skill chứ không chỉ riêng đường đạn.

var champion: Champion
var target: Champion = null

## Khoảng cách bot muốn giữ với đối thủ.
var preferred_range := 280.0
## Độ trễ phản ứng (giây) — càng lớn bot càng "người".
## 0.15 là mức đủ để người chơi kịp thấy bot phản ứng mà vẫn thấy nó lanh.
var reaction := 0.15
## Xác suất dùng chiêu mỗi khi có cơ hội.
var cast_chance := 0.95
## Bán kính coi là "có đạn đang bay tới mình".
var dodge_radius := 210.0

var _move := Vector2.ZERO
var _aim := Vector2.RIGHT
var _cast := 0
## Điểm bot muốn đặt chiêu vùng (loại GROUND). Tính lại mỗi lần ra chiêu.
var _target_point := Vector2.ZERO
var _strafe := 1.0
var _strafe_timer := 0.0
var _reaction_timer := 0.0
var _pending := Vector2.ZERO

## Bật/tắt phần ra chiêu. Phòng luyện tập dùng cờ này để giữ bot đứng yên làm
## bao cát mà không phải xoá hẳn nó.
var skills_enabled := true

## Hướng cần né, tính lại mỗi tick từ các viên đạn đang bay tới.
var _threat := Vector2.ZERO
## Còn bao lâu nữa mới được né tiếp, tránh bot giật liên tục.
var _dodge_cooldown := 0.0
## Đang trong một cú né: giữ hướng né cho tới khi hết thời gian.
var _dodge_timer := 0.0
var _dodge_dir := Vector2.ZERO

var DODGE_TIME := 0.32
var DODGE_RECHARGE := 1.1

func _init(c: Champion, difficulty: int = GameData.Difficulty.NORMAL) -> void:
	champion = c
	# Tầm xa thì giữ khoảng, cận chiến thì lao vào.
	preferred_range = _preferred_range_for(c.champion_id)
	_strafe = 1.0 if randf() > 0.5 else -1.0
	_apply_difficulty(difficulty)

## Điều chỉnh thông số AI theo độ khó đã chọn.
func _apply_difficulty(d: int) -> void:
	match d:
		GameData.Difficulty.EASY:
			reaction = 0.38
			cast_chance = 0.55
			dodge_radius = 140.0
			DODGE_TIME = 0.22
			DODGE_RECHARGE = 1.8
		GameData.Difficulty.HARD:
			reaction = 0.08
			cast_chance = 0.98
			dodge_radius = 260.0
			DODGE_TIME = 0.42
			DODGE_RECHARGE = 0.75
		_:
			pass  # NORMAL dùng giá trị mặc định

## Khoảng cách bot muốn giữ, theo đặc điểm từng tướng.
func _preferred_range_for(id: StringName) -> float:
	match id:
		&"fire_mage":
			return 300.0        # bắn xa, giữ khoảng
		&"frost_maiden":
			return 290.0        # khống chế tầm trung
		&"thunder_warrior":
			return 210.0        # lao vào rồi lùi ra
		&"stone_guardian":
			return 130.0        # chậm, nhưng muốn áp sát để đè
		&"arcane_weaver":
			return 250.0        # đặt vùng từ xa, tránh bị áp sát
		&"mirage":
			return 70.0         # cận chiến, nhưng vào ra liên tục
		&"marksman":
			return 420.0        # giữ thật xa để sạc Tâm Điểm
		&"seraph":
			return 300.0        # pháp sư ánh sáng, đánh thường đã là đạn xa
		&"artificer":
			return 290.0        # đủ xa để rải bẫy trước
		&"tamer":
			return 310.0        # để thú làm việc, mình đứng sau ném dao
		&"time_weaver":
			return 290.0        # gieo vùng thời gian từ xa
		&"shadow_assassin":
			return 62.0         # cận chiến thuần
		&"blood_lord":
			return 92.0         # hút máu cận chiến, dám đứng đổi máu
		&"iron_monk":
			return 95.0         # võ tăng cần dán sát mục tiêu để nuôi nội tại
		&"berserker":
			return 85.0         # càng gần càng mạnh (Tử Chiến)
		&"void_samurai":
			return 72.0         # sát thủ kỹ thuật, vào-xả-ra
		&"plague_alchemist":
			return 330.0        # gieo độc từ xa, tránh đổi máu
	return 250.0

func update(delta: float, tgt: Champion) -> void:
	target = tgt
	_cast = 0
	_move = Vector2.ZERO
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_threat = _scan_threat()

	if champion == null or not champion.is_alive() or target == null or not target.is_alive():
		return

	var to: Vector2 = target.global_position - champion.global_position
	var dist := to.length()
	var dir := to.normalized() if dist > 0.001 else Vector2.RIGHT
	_aim = _predict_aim(dir, dist)

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.7, 1.8)
		if randf() < 0.35:
			_strafe = -_strafe

	# --- Né đòn: ưu tiên cao nhất, trên cả việc giữ khoảng cách ---
	#
	# Đây là thứ làm bot trông "biết chơi" thay vì đứng ăn đạn. Bot chỉ né khi
	# có đạn đang bay thẳng tới và đã hết thời gian chờ, nên nó không nhảy
	# loạn xạ — nhìn ra được là nó đang tránh một đòn cụ thể.
	if _threat != Vector2.ZERO and _dodge_cooldown <= 0.0 and _dodge_timer <= 0.0:
		_dodge_dir = _pick_dodge_dir(_threat)
		_dodge_timer = DODGE_TIME
		_dodge_cooldown = DODGE_RECHARGE
	if _dodge_timer > 0.0:
		_move = _avoid_walls(_dodge_dir)
		# Vẫn ra chiêu trong lúc né — vừa né vừa bắn mới là cách chơi đúng.
		_update_cast(delta, dist)
		return

	# --- Di chuyển: giữ khoảng mong muốn + đi ngang để khó bị bắn trúng ---
	var perp := Vector2(-dir.y, dir.x) * _strafe
	if dist > preferred_range + 70.0:
		# Ở xa quá: vừa tiến vừa đi ngang, không lao thẳng cho dễ bị bắn tỉa.
		_move = (dir * 1.0 + perp * 0.45).normalized()
	elif dist < preferred_range - 70.0:
		# Ở gần quá: lùi ra nhưng vẫn bắn. Đây là "tấn công lùi" — giữ được
		# sát thương trong khi tạo khoảng cách, thay vì bỏ chạy mất lượt.
		_move = (-dir * 1.0 + perp * 0.5).normalized()
	else:
		_move = (perp * 0.85 + dir * 0.15).normalized()

	_update_cast(delta, dist)
	_move = _avoid_walls(_move)

## Phần ra chiêu, tách riêng để lúc né vẫn gọi được.
func _update_cast(delta: float, dist: float) -> void:
	if not skills_enabled:
		return
	_reaction_timer -= delta
	if _reaction_timer <= 0.0:
		_reaction_timer = reaction
		_pending = _decide(_aim, dist)
		# Khi đang né và máu thấp, ưu tiên dùng dash để thoát xa hơn.
		if _dodge_timer > 0.0 and champion.hp / maxf(champion.max_hp, 1.0) < 0.4:
			var dash_slot := _dash_slot_for(champion.champion_id)
			if dash_slot >= 0 and _ready(dash_slot):
				_pending = Vector2(1 << dash_slot, 0)
	_cast = int(_pending.x)
	# Đánh thường: nếu đối thủ trong tầm và chiêu sẵn sàng thì bật bit đánh thường.
	if champion != null and champion.basic_attack != null \
			and champion.basic_attack.can_cast() \
			and dist < _basic_attack_range() \
			and randf() < 0.92:
		_cast |= 1 << 4
	# Điểm đặt chiêu vùng: nhắm vào chỗ đối thủ SẼ tới, không phải chỗ đang đứng.
	# Hệ số 0.22 giây là khoảng thời gian đạn/vùng kịp kích hoạt.
	_target_point = target.global_position + target.velocity * 0.22

## Tầm đánh thường ước tính: cận chiến thì gần, tầm xa thì xa hơn.
## Seraph/Artificer/Tamer/TimeWeaver đã đổi đánh thường thành đạn bay xa —
## nên bot cũng phải đứng xa tương ứng, nếu không nó lao vào ăn đòn oan.
func _basic_attack_range() -> float:
	match champion.champion_id:
		&"mirage", &"shadow_assassin", &"stone_guardian":
			return 95.0
		&"blood_lord":
			return 92.0
		&"iron_monk":
			return 96.0
		&"berserker":
			return 104.0
		&"void_samurai":
			return 114.0
		&"marksman", &"fire_mage", &"frost_maiden", &"arcane_weaver", &"plague_alchemist", \
				&"seraph", &"artificer", &"tamer", &"time_weaver":
			return 420.0
		_:
			return 260.0

## Chỉ số kỹ năng lướt/dash của từng tướng, dùng để thoát hiểm. -1 = không có.
func _dash_slot_for(id: StringName) -> int:
	match id:
		&"fire_mage":       return 2
		&"shadow_assassin": return 1
		&"frost_maiden":    return 2
		&"thunder_warrior": return 1
		&"arcane_weaver":   return 1
		&"mirage":          return 0
		&"marksman":        return 1
		&"time_weaver":     return 3
		&"blood_lord":      return 1
		&"iron_monk":       return 0
		&"berserker":       return 0
		&"void_samurai":    return 2
		&"stone_guardian", &"seraph", &"artificer", &"tamer", &"plague_alchemist":
			return -1
	return -1

## Quét các viên đạn đang bay tới và trả về hướng cần tránh.
##
## Chỉ tính đạn đang tiến LẠI GẦN mình, và chỉ tính khi đường bay của nó thực sự
## hướng về phía mình — nếu không thì bot sẽ né cả những viên bắn đi chỗ khác.
func _scan_threat() -> Vector2:
	if champion == null or champion.world == null:
		return Vector2.ZERO
	var world := champion.world
	if not world.has_method("champions_list"):
		return Vector2.ZERO

	var sum := Vector2.ZERO
	var me: Vector2 = champion.global_position
	for p in world.projectiles:
		if not is_instance_valid(p) or p.is_dead() or p.is_zone:
			continue
		if p.owner_peer == champion.peer_id:
			continue
		# Đạn đứng yên (vùng đất) không né — né vùng thì phải bước ra, không
		# phải lách ngang, mà việc đó đã do phần giữ khoảng cách lo.
		if p.speed <= 0.0:
			continue
		var to_me: Vector2 = me - p.position
		var dist := to_me.length()
		if dist > dodge_radius or dist < 1.0:
			continue
		# Đạn có đang bay về phía mình không? So góc giữa hướng bay và hướng tới mình.
		if p.direction.normalized().dot(to_me.normalized()) < 0.72:
			continue
		# Viên nào gần hơn thì đáng né hơn.
		sum += to_me.normalized() * (1.0 - dist / dodge_radius)
	return sum

## Chọn hướng né: vuông góc với hướng nguy hiểm, chọn bên nào thoáng hơn.
func _pick_dodge_dir(threat: Vector2) -> Vector2:
	var away := threat.normalized()
	var left := Vector2(-away.y, away.x)
	var right := -left
	# Ưu tiên bên không bị vật cản chặn.
	if champion.world != null and champion.world.has_method("is_blocked_at"):
		var probe_l: Vector2 = champion.global_position + left * 90.0
		var probe_r: Vector2 = champion.global_position + right * 90.0
		var blocked_l: bool = champion.world.is_blocked_at(probe_l, champion.body_radius)
		var blocked_r: bool = champion.world.is_blocked_at(probe_r, champion.body_radius)
		if blocked_l and not blocked_r:
			return right
		if blocked_r and not blocked_l:
			return left
	# Không bị chặn thì chọn bên theo hướng đang đi ngang, để né mà không đổi
	# hướng đột ngột.
	return left if _strafe > 0.0 else right

## Đón đầu mục tiêu cho đạn bay — bắn về phía đối thủ sẽ tới, không phải chỗ
## đang đứng.
func _predict_aim(dir: Vector2, dist: float) -> Vector2:
	var speed := 620.0
	var lead := clampf(dist / speed, 0.0, 0.45)
	return (dir + target.velocity * lead).normalized()

## Trả về Vector2(bitmask chiêu, 0). Dùng Vector2 để gói hai giá trị số vào
## một biến mà không cần tạo Dictionary mỗi tick.
##
## Mỗi tướng có một thứ tự ưu tiên riêng, viết theo đúng logic mà người chơi
## giỏi sẽ dùng: chuẩn bị trạng thái trước, rồi mới tung đòn khai thác trạng
## thái đó. Bot không cần giỏi — nó chỉ cần chơi đúng luật để người tập thấy
## được combo hoạt động.
func _decide(_dir: Vector2, dist: float) -> Vector2:
	if randf() > cast_chance:
		return Vector2(0, 0)

	match champion.champion_id:
		&"fire_mage":
			return Vector2(_decide_fire(dist), 0)
		&"shadow_assassin":
			return Vector2(_decide_shadow(dist), 0)
		&"frost_maiden":
			return Vector2(_decide_frost(dist), 0)
		&"thunder_warrior":
			return Vector2(_decide_thunder(dist), 0)
		&"stone_guardian":
			return Vector2(_decide_stone(dist), 0)
		&"arcane_weaver":
			return Vector2(_decide_arcane(dist), 0)
		&"mirage":
			return Vector2(_decide_mirage(dist), 0)
		&"marksman":
			return Vector2(_decide_marksman(dist), 0)
		&"seraph":
			return Vector2(_decide_seraph(dist), 0)
		&"artificer":
			return Vector2(_decide_artificer(dist), 0)
		&"tamer":
			return Vector2(_decide_tamer(dist), 0)
		&"blood_lord":
			return Vector2(_decide_blood_lord(dist), 0)
		&"iron_monk":
			return Vector2(_decide_iron_monk(dist), 0)
		&"berserker":
			return Vector2(_decide_berserker(dist), 0)
		&"void_samurai":
			return Vector2(_decide_void_samurai(dist), 0)
		&"plague_alchemist":
			return Vector2(_decide_plague_alchemist(dist), 0)
	return Vector2(0, 0)

## Hỏa Pháp Sư: dồn Bỏng bằng Q, nhốt bằng E, lướt để hồi Q, nổ khi đủ stack.
func _decide_fire(dist: float) -> int:
	var burn: int = target.get_stacks(GameData.ST_BURN)
	if _ready(3) and burn >= 3 and dist < 380.0:
		return 1 << 3                       # Bùng Nổ
	if _ready(1) and dist < 330.0 and randf() < 0.6:
		return 1 << 1                       # Tường Lửa
	if _ready(2) and dist < 230.0:
		return 1 << 2                       # Lướt Lửa
	if _ready(0) and dist < 620.0:
		return 1 << 0                       # Hỏa Cầu
	return 0

## Sát Thủ: đánh dấu trước, rồi dịch chuyển vào và chém.
func _decide_shadow(dist: float) -> int:
	var marks: int = target.get_stacks(GameData.ST_MARK)
	if _ready(3) and dist < 195.0 and (marks >= 2 or target.hp < target.max_hp * 0.4):
		return 1 << 3                       # Tử Ảnh
	if _ready(2) and dist < 430.0:
		return 1 << 2                       # Khóa Hồn
	if _ready(1) and dist < 300.0 and marks > 0:
		return 1 << 1                       # Ảnh Bộ
	if _ready(0) and dist < 92.0:
		return 1 << 0                       # Chém Đôi
	return 0

## Băng Sương Nữ: bắn Băng Tiễn hai lần để thành Đóng Băng, rồi Vòng Băng đập vỡ.
func _decide_frost(dist: float) -> int:
	var frozen: bool = target.has_status(GameData.ST_FREEZE)
	var chilled: bool = target.has_status(GameData.ST_SLOW)
	if _ready(1) and frozen and dist < 240.0:
		return 1 << 1                       # Vòng Băng đập vỡ
	if _ready(3) and dist < 330.0 and (frozen or chilled):
		return 1 << 3                       # Tuyệt Đối Đóng Băng
	if _ready(0) and dist < 700.0:
		return 1 << 0                       # Băng Tiễn
	if _ready(2) and dist < 210.0 and randf() < 0.4:
		return 1 << 2                       # Trượt Băng
	return 0

## Lôi Đình: gắn Tích Điện bằng E/R, rồi Sét Đánh để lan, Thiên Lôi để choáng.
func _decide_thunder(dist: float) -> int:
	var charged: bool = target.has_status(GameData.ST_CHARGE)
	if _ready(3) and charged and dist < 420.0:
		return 1 << 3                       # Thiên Lôi
	if _ready(2) and dist < 230.0:
		return 1 << 2                       # Nạp Điện
	if _ready(1) and dist < 300.0 and not charged:
		return 1 << 1                       # Lướt Sét (gắn Tích Điện)
	if _ready(0) and dist < 700.0:
		return 1 << 0                       # Sét Đánh
	return 0

## Thạch Vệ Binh: dán Vỡ Giáp bằng R rồi Địa Chấn, chặn đường bằng Tường Đá.
func _decide_stone(dist: float) -> int:
	var broken: bool = target.has_status(GameData.ST_BREAK)
	if _ready(3) and dist < 250.0:
		return 1 << 3                       # Địa Chấn
	if _ready(2) and dist < 170.0 and not champion.has_status(GameData.ST_SHIELD):
		return 1 << 2                       # Khiên Đá
	if _ready(1) and dist > 260.0 and dist < 420.0 and randf() < 0.35:
		return 1 << 1                       # Tường Đá
	if _ready(0) and dist < 700.0:
		return 1 << 0                       # Đá Lăn
	return 0

func _ready(index: int) -> bool:
	return _ready_at(champion.skills, index)

## Hư Không Pháp Sư: mở Hố Đen giữ chân, đánh dấu bằng Q, rồi Sụp Đổ dứt điểm.
## E chỉ dùng để thoát khi đối thủ áp sát quá gần.
func _decide_arcane(dist: float) -> int:
	var marks: int = target.get_stacks(GameData.ST_MARK)
	if _ready(3) and dist < 520.0 and (marks >= 1 or target.hp < target.max_hp * 0.5):
		return 1 << 3                       # Sụp Đổ
	if _ready(2) and dist < 360.0 and dist > 120.0:
		return 1 << 2                       # Hố Đen
	if _ready(0) and dist < 460.0:
		return 1 << 0                       # Vụ Nổ Không Gian
	if _ready(1) and dist < 130.0:
		return 1 << 1                       # Dịch Chuyển để thoát ra xa
	return 0

## Hư Ảnh: vào bằng F, đánh, rồi Q/E để thoát. Ưu tiên Q khi đang bị áp sát.
func _decide_mirage(dist: float) -> int:
	var marks: int = target.get_stacks(GameData.ST_MARK)
	if _ready(3) and dist < 380.0:
		return 1 << 3                       # Đâm Từ Bóng
	if _ready(1) and dist < 300.0 and randf() < 0.5:
		return 1 << 1                       # Đổi Bóng
	if _ready(2) and dist < 260.0:
		return 1 << 2                       # Bóng Bội
	if _ready(0) and dist < 220.0:
		return 1 << 0                       # Tốc Biến để áp sát
	return 0

## Xạ Thủ: đứng xa, bắn tỉa, lùi khi bị áp sát.
func _decide_marksman(dist: float) -> int:
	if _ready(3) and dist < 760.0 and target.hp < target.max_hp * 0.55:
		return 1 << 3                       # Phát Súng Cuối
	if _ready(1) and dist < 170.0:
		return 1 << 1                       # Bước Lùi Súng
	if _ready(0) and dist < 720.0:
		return 1 << 0                       # Xuyên Thấu
	if _ready(2) and dist > 400.0 and target.hp < target.max_hp * 0.7:
		return 1 << 2                       # Ống Nhòm khi đã an toàn
	return 0

## Thiên Sứ: giữ khiên, đặt vùng thiêng khi máu thấp.
func _decide_seraph(dist: float) -> int:
	var hp_ratio: float = champion.hp / maxf(champion.max_hp, 1.0)
	if _ready(3) and dist < 460.0 and (hp_ratio < 0.6 or target.hp < target.max_hp * 0.4):
		return 1 << 3                       # Thiên Khai
	if _ready(1) and dist < 220.0 and not champion.has_status(GameData.ST_SHIELD):
		return 1 << 1                       # Khiên Phước
	if _ready(2) and hp_ratio < 0.7:
		return 1 << 2                       # Vùng Thiêng
	if _ready(0) and dist < 600.0:
		return 1 << 0                       # Sóng Ánh Sáng
	return 0

## Luyện Thuật Sư: rải bẫy ở tầm trung, đặt pháo khi đối thủ đứng yên.
func _decide_artificer(dist: float) -> int:
	if _ready(3) and dist < 400.0 and dist > 140.0:
		return 1 << 3                       # Pháo Cố Định
	if _ready(2) and dist > 200.0 and dist < 420.0 and randf() < 0.5:
		return 1 << 2                       # Bẫy Laser
	if _ready(1) and dist < 520.0:
		return 1 << 1                       # Súng Điện
	if _ready(0) and dist < 360.0:
		return 1 << 0                       # Mìn Nổ
	return 0

## Chủ Ưng: giữ đàn thú hoạt động liên tục, F để dứt điểm.
func _decide_tamer(dist: float) -> int:
	if _ready(3) and dist < 300.0 and target.hp < target.max_hp * 0.5:
		return 1 << 3                       # Sói Đoàn
	if _ready(2) and dist < 400.0:
		return 1 << 2                       # Đàn Bầy
	if _ready(1) and dist < 380.0:
		return 1 << 1                       # Khống Chế
	if _ready(0) and dist < 300.0:
		return 1 << 0                       # Triệu Hồ
	return 0

## Huyết Bá: lao vào bằng Đàn Dơi, mở Dòng Máu khi đổi máu được lợi,
## dùng Huyết Tiễn để hồi máu khi không áp sát nổi, Trường Sinh để sống sót.
func _decide_blood_lord(dist: float) -> int:
	var hp_ratio: float = champion.hp / maxf(champion.max_hp, 1.0)
	if _ready(3) and dist < 420.0 and (hp_ratio < 0.75 or target.hp < target.max_hp * 0.6):
		return 1 << 3                       # Dòng Máu: nhốt địch, mình hồi
	if _ready(2) and hp_ratio < 0.55:
		return 1 << 2                       # Trường Sinh
	if _ready(1) and dist > 160.0 and dist < 400.0:
		return 1 << 1                       # Đàn Dơi: áp sát + hồi máu
	if _ready(0) and dist < 500.0:
		return 1 << 0                       # Huyết Tiễn
	return 0

## Thiết Quyền Sư: Phong Bộ áp sát, Thiên Chưởng Ấn dán Vỡ Giáp rồi
## Nhất Quyền thu hoạch; Chung Vàng giữ mạng giữa giao tranh.
func _decide_iron_monk(dist: float) -> int:
	var broken: bool = target.has_status(GameData.ST_BREAK)
	var hp_ratio: float = champion.hp / maxf(champion.max_hp, 1.0)
	if _ready(3) and dist < 190.0 and (broken or target.hp < target.max_hp * 0.45):
		return 1 << 3                       # Nhất Quyền Trấn Hồn
	if _ready(2) and dist < 170.0:
		return 1 << 2                       # Thiên Chưởng Ấn
	if _ready(0) and dist > 180.0 and dist < 420.0:
		return 1 << 0                       # Phong Bộ áp sát
	if _ready(1) and hp_ratio < 0.65:
		return 1 << 1                       # Chung Vàng
	return 0

## Cuồng Chiến: nhảy vào bằng Bước Nhảy, Xoáy Rìu càn quét, Chiến Hào giữ
## mạng, Phán Quyết chặt mục tiêu còn ít máu.
func _decide_berserker(dist: float) -> int:
	var hp_ratio: float = champion.hp / maxf(champion.max_hp, 1.0)
	if _ready(3) and dist < 200.0 and target.hp < target.max_hp * 0.5:
		return 1 << 3                       # Phán Quyết
	if _ready(0) and dist > 150.0 and dist < 380.0:
		return 1 << 0                       # Bước Nhảy Chém
	if _ready(2) and dist < 140.0:
		return 1 << 2                       # Xoáy Rìu
	if _ready(1) and hp_ratio < 0.6:
		return 1 << 1                       # Chiến Hào
	return 0

## Kiếm Thánh: Hư Không Bước lao xuyên đánh dấu, Nhất Đao Lưu mở Chí Mạng,
## Vạn Kiếm Mộ nhốt địch, Nghịch Phong Trảm tích Sát Ý.
func _decide_void_samurai(dist: float) -> int:
	var marks: int = target.get_stacks(GameData.ST_MARK)
	if _ready(3) and dist < 380.0 and (marks >= 2 or target.hp < target.max_hp * 0.55):
		return 1 << 3                       # Vạn Kiếm Mộ
	if _ready(2) and dist > 140.0 and dist < 420.0:
		return 1 << 2                       # Hư Không Bước
	if _ready(1) and dist < 270.0:
		return 1 << 1                       # Nhất Đao Lưu
	if _ready(0) and dist < 180.0:
		return 1 << 0                       # Nghịch Phong Trảm
	return 0

## Độc Sư: gieo Vực Độc trước, Tiêu Độc Tiễn dồn stack, detonate khi đủ 4+
## lớp độc, Thanh Lọc khi bị tập sát.
func _decide_plague_alchemist(dist: float) -> int:
	var poison: int = target.get_stacks(GameData.ST_POISON)
	var hp_ratio: float = champion.hp / maxf(champion.max_hp, 1.0)
	if _ready(3) and dist < 400.0 and poison >= 4:
		return 1 << 3                       # Đại Nổ Dịch Bệnh
	if _ready(0) and dist > 140.0 and dist < 420.0:
		return 1 << 0                       # Vực Độc
	if _ready(1) and dist < 520.0:
		return 1 << 1                       # Tiêu Độc Tiễn
	if _ready(2) and hp_ratio < 0.5:
		return 1 << 2                       # Thanh Lọc
	return 0

## Điểm bot muốn đặt chiêu vùng (loại GROUND).
func target_point() -> Vector2:
	return _target_point

func _ready_at(skills: Array, index: int) -> bool:
	if index >= skills.size():
		return false
	var s: SkillBase = skills[index]
	return s != null and s.can_cast()

## Nếu hướng đi đâm vào tường thì xoay dần cho tới khi tìm được hướng thoáng.
##
## Trường hợp đặc biệt quan trọng: khi bot đã ở NGOÀI sân (bị hất văng ra), mọi
## điểm dò đều bị coi là bị chặn nên vòng lặp dưới sẽ không tìm được hướng nào
## và trả về Vector2.ZERO — bot đứng im vĩnh viễn. Nên phải xét "đang ở ngoài"
## trước, và khi đó lái thẳng về tâm sân bất kể hướng mong muốn.
func _avoid_walls(desired: Vector2) -> Vector2:
	if champion.world == null or not champion.world.has_method("is_blocked_at"):
		return desired

	var safe := _safe_zone_move()
	if safe != Vector2.ZERO:
		return safe

	var probe: Vector2 = champion.global_position + desired * 46.0
	if not champion.world.is_blocked_at(probe, champion.body_radius):
		return desired
	for angle in [0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.6, -2.6]:
		var rotated := desired.rotated(angle)
		var p: Vector2 = champion.global_position + rotated * 46.0
		if not champion.world.is_blocked_at(p, champion.body_radius):
			return rotated
	return Vector2.ZERO

## Khi bot ở ngoài sân hoặc dính sát mép, trả về hướng đi về tâm sân.
## Trả Vector2.ZERO khi bot đang ở vị trí bình thường.
##
## Vì sao tách riêng khỏi `_avoid_walls`: đây là ưu tiên cao hơn mọi tính toán
## chiến thuật — đang ở ngoài sân thì việc duy nhất có nghĩa là quay về, không
## phải giữ khoảng cách với đối thủ.
func _safe_zone_move() -> Vector2:
	if champion.world == null or not champion.world.has_method("distance_to_edge"):
		return Vector2.ZERO

	var edge: float = champion.world.distance_to_edge(champion.global_position)
	# Ngưỡng rộng hơn bán kính thân một chút để bot không dính sát mép rồi
	# kẹt lại giữa hai lệnh mâu thuẫn.
	var margin: float = champion.body_radius + 34.0
	if edge > margin:
		return Vector2.ZERO

	var center := Vector2.ZERO
	if champion.world.has_method("arena_center"):
		center = champion.world.arena_center()
	var back := center - champion.global_position
	if back.length_squared() < 1.0:
		return Vector2.ZERO
	return back.normalized()

func move_vector() -> Vector2:
	return _move

func aim_vector() -> Vector2:
	return _aim

func cast_mask() -> int:
	return _cast
