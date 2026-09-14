class_name Champion
extends CharacterBody2D
## Một tướng trong trận. Vừa là thực thể vật lý vừa là nơi chứa chỉ số,
## status và 4 kỹ năng.
##
## Vòng đời mỗi tick (chỉ host chạy):
##     step(delta, move, aim, cast_mask)
##
## Máy khách không gọi step() — nó nhận snapshot và gọi apply_snapshot().

signal died(champion: Champion, killer_peer: int)
signal damaged(amount: float, source_peer: int)
signal healed(amount: float)
signal skill_cast(index: int, skill: SkillBase)
signal status_changed()
signal hp_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)

# --------------------------------------------------------------- cấu hình

var champion_id: StringName = &"fire_mage"
var display_name := "Tướng"
var peer_id := 0
## true = tướng do máy này điều khiển trực tiếp (đọc bàn phím/cảm ứng).
var is_local := false

# ------------------------------------------------------------- chỉ số gốc

var max_hp := 100.0
var hp := 100.0
## Khiên tạm thời hấp thụ sát thương trước khi trừ vào máu.
var shield := 0.0
var max_mana := 100.0
var mana := 100.0
var mana_regen := 9.0
var move_speed := 250.0
var body_radius := 17.0
var accent := Color.WHITE

# ------------------------------------------------------------ trạng thái

var aim_dir := Vector2.RIGHT
var statuses: Dictionary = {}          # StringName -> StatusEffect
var skills: Array[SkillBase] = []
## Bật ở phòng luyện tập: mọi sát thương đều bị chặn, nhưng vẫn phát hiệu ứng
## trúng đòn để người chơi thấy combo có ăn hay không.
var invincible := false
## Bật ở phòng luyện tập: hồi chiêu về 0 ngay sau mỗi tick, để thử combo liên tục.
var no_cooldown := false
## Đòn đánh thường, gắn với chuột trái. Không tốn năng lượng, hồi chiêu ngắn.
## Tách khỏi mảng skills vì đây là hành động liên tục, không phải kỹ năng chiến thuật.
var basic_attack: SkillBase = null

## Nội tại của tướng. Mỗi tướng có đúng một cái, không trùng nhau.
var passive: Passive = null

## Hệ số nhân bán kính cho mọi vùng/đạn do tướng này sinh ra.
##
## Nội tại Không Gian Vặn của Hư Không Pháp Sư đặt thành 1.2. Nhân ở tầng
## `spawn_projectile` chứ không sửa từng chiêu — nhờ vậy nội tại áp được cho cả
## 25 chiêu hiện có mà không phải đụng vào file nào của tướng.
var area_multiplier := 1.0

var _alive := true
var _flash := 0.0                      # nhấp nháy trắng khi trúng đòn
var _knockback := Vector2.ZERO
var _speed_mult := 1.0
var _prev_cast_mask := 0
var _cast_lock := 0.0                  # >0 thì không nhận input di chuyển
var _dash_velocity := Vector2.ZERO
var _anim_time := 0.0
var _last_killer := 0
var _footstep_timer := 0.0

# --- Trạng thái hoạt ảnh ra chiêu ---
# Thời gian kể từ lần ra chiêu gần nhất (giây). Bắt đầu lớn để "không có chiêu
# nào vừa ra". Visual đọc qua cast_anim_progress() để vẽ cú vung tay/phóng roi.
var _cast_anim_time := 99.0
# Hướng của chiêu vừa ra — vung theo đúng hướng người chơi bắn.
var _cast_anim_dir := Vector2.RIGHT
## Thời lượng toàn bộ cú vung (giây). Sau khoảng này tiến độ về 0.
const CAST_ANIM_DURATION := 0.30

## Tham chiếu tới đấu trường. Kiểu để mở vì Arena cũng tham chiếu Champion.
var world: Node = null

## Node con lo phần vẽ. Tách ra để logic và hiển thị không trộn vào nhau.
var visual: Node2D = null

const ACCEL := 2600.0
const FRICTION := 2200.0
const KNOCKBACK_DECAY := 1800.0

## Vị trí bit trong cast_mask dành cho đánh thường. Bốn bit đầu (0-3) là kỹ năng.
## Gói chung vào một số nguyên giúp gói tin mạng không phải thêm trường mới.
const CAST_BIT_ATTACK := 4

# ------------------------------------------------------------------ khởi tạo

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_collision()
	if visual == null:
		visual = ChampionVisual.new()
		visual.name = "Visual"
		add_child(visual)

func _build_collision() -> void:
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	# Đẩy tâm va chạm xuống một chút để khớp với góc nhìn xéo (chân nhân vật
	# nằm dưới tâm sprite).
	shape.position = Vector2(0, body_radius * 0.35)
	add_child(shape)

## Nạp chỉ số + skill từ script của tướng.
func configure(id: StringName, p_peer_id: int, p_is_local: bool) -> void:
	champion_id = id
	peer_id = p_peer_id
	is_local = p_is_local
	var script: GDScript = GameData.champion_script(id)
	if script == null:
		push_error("Không tìm thấy script cho tướng '%s'" % id)
		return
	# Gọi hàm dựng chỉ số nếu tướng có định nghĩa (mỗi file tướng tự khai báo).
	# Tạo instance thay vì gọi static để không phụ thuộc cách Godot phân giải
	# static method trên tài nguyên GDScript.
	var builder: Object = script.new()
	if builder != null and builder.has_method("build_champion"):
		builder.build_champion(self)

	# Áp dụng hệ số máu từ cài đặt (Settings.hp_multiplier) để trận đấu kéo dài hơn
	if Settings != null and Settings.hp_multiplier > 0.0:
		max_hp = roundf(max_hp * Settings.hp_multiplier)
		hp = max_hp

	# Tướng nào không tự định nghĩa đánh thường thì dùng bản mặc định, để mọi
	# tướng đều có chuột trái dùng được.
	if basic_attack == null:
		basic_attack = DefaultBasicAttack.new()
	basic_attack.bind(self)

	# Nội tại: tướng tự khai báo qua `build_passive()`. Tướng nào chưa có thì
	# bỏ qua — game vẫn chạy bình thường, chỉ là thiếu phần thưởng chiều sâu.
	if builder != null and builder.has_method("build_passive"):
		passive = builder.build_passive()
		if passive != null:
			passive.setup(self)
			area_multiplier = passive.area_multiplier()


## Đòn đánh thường dự phòng: bắn một tia nhỏ, hồi chiêu ngắn, không tốn năng
## lượng. Tướng nào muốn kiểu đánh riêng thì tự gán trong build_champion().
class DefaultBasicAttack extends SkillBase:
	func _init() -> void:
		id = &"basic"
		display_name = "Đánh thường"
		key_label = "LMB"
		cooldown = 0.5
		mana_cost = 0.0
		is_basic = true
		icon_color = Color(0.78, 0.78, 0.86)

	func execute(aim: Vector2) -> void:
		caster.spawn_projectile({
			"kind": &"bolt",
			"direction": aim,
			"speed": 660.0,
			"damage": 7.0,
			"radius": 8.0,
			"life": 1.15,
			"power": 1.0,
			"accent": caster.accent,
		})

# -------------------------------------------------------------- vòng tick

## Một tick mô phỏng đầy đủ. Chỉ host gọi hàm này.
##
## `cast_target` là điểm người chơi đã chọn trên mặt đất (chỉ có ý nghĩa với
## kỹ năng loại GROUND). Với mọi loại khác thì bỏ qua.
func step(delta: float, move: Vector2, aim: Vector2, cast_mask: int,
		cast_target: Vector2 = Vector2.ZERO) -> void:
	if not _alive:
		_anim_time += delta
		return

	_anim_time += delta
	_cast_anim_time = minf(_cast_anim_time + delta, 99.0)
	_flash = maxf(0.0, _flash - delta * 4.0)
	_cast_lock = maxf(0.0, _cast_lock - delta)

	_tick_skills(delta)
	_tick_statuses(delta)
	_tick_passive(delta)
	_regen_mana(delta)
	_update_aim(aim)
	_update_velocity(delta, move)
	_handle_casts(cast_mask, cast_target)
	move_and_slide()
	_clamp_to_arena()
	_tick_footstep(delta, move)

## Chạy nội tại. Tách hàm riêng để chỗ gọi trong `step()` đọc rõ ý định.
func _tick_passive(delta: float) -> void:
	if passive != null:
		passive.tick(delta)

## Bụi chân: tạo hạt bụi nhỏ khi đang chạy trên mặt đất.
func _tick_footstep(delta: float, move: Vector2) -> void:
	if not _alive or move.length_squared() < 0.01 or is_dashing():
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = 0.22
		if world != null and world.has_method("spawn_footstep_dust"):
			var dust_pos := global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			world.spawn_footstep_dust(dust_pos, accent)

func _tick_skills(delta: float) -> void:
	for s in skills:
		s.tick(delta)
	if basic_attack != null:
		basic_attack.tick(delta)
	# Phòng luyện tập: xoá hồi chiêu ngay sau khi tick, nên chiêu luôn sẵn sàng.
	# Đặt sau vòng tick để cooldown vừa đếm xuống đã bị xoá — người chơi thấy
	# vòng hồi chiêu nháy một khung hình rồi đầy lại, đúng cảm giác "vô hạn".
	if no_cooldown:
		for s in skills:
			s.reset_cooldown()
		if basic_attack != null:
			basic_attack.reset_cooldown()

func _regen_mana(delta: float) -> void:
	if mana < max_mana:
		mana = minf(max_mana, mana + mana_regen * delta)
		mana_changed.emit(mana, max_mana)

func _update_aim(aim: Vector2) -> void:
	if aim.length_squared() > 0.0001:
		aim_dir = aim.normalized()

func _update_velocity(delta: float, move: Vector2) -> void:
	# Đang lướt (dash) thì giữ nguyên vận tốc lướt, bỏ qua input.
	if _cast_lock > 0.0 and _dash_velocity != Vector2.ZERO:
		velocity = _dash_velocity
		_dash_velocity = _dash_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * 0.5 * delta)
		_apply_knockback(delta)
		return

	var fmult := _get_arena_friction_mult()
	var target := move * move_speed * _speed_mult
	if move.length_squared() > 0.0001:
		velocity = velocity.move_toward(target, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * fmult * delta)
	_apply_knockback(delta)

func _get_arena_friction_mult() -> float:
	if world != null and world.has_method("get_friction_mult"):
		return world.get_friction_mult()
	return 1.0

func _apply_knockback(delta: float) -> void:
	if _knockback.length_squared() > 0.01:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

func _handle_casts(cast_mask: int, cast_target: Vector2) -> void:
	# Đang bị đóng băng thì không ra được chiêu nào. Đây là toàn bộ sức mạnh
	# của trạng thái Đóng Băng, nên thời gian của nó rất ngắn.
	if is_frozen():
		_prev_cast_mask = cast_mask
		return

	# Đánh thường nằm ở bit 4. Giữ chuột là đánh liên tục theo hồi chiêu, nên
	# không dùng sườn lên như kỹ năng.
	if basic_attack != null and (cast_mask & (1 << CAST_BIT_ATTACK)) != 0:
		if basic_attack.try_cast(aim_dir, cast_target):
			if passive != null:
				passive.on_basic_cast()

	# Kỹ năng: chỉ kích hoạt ở sườn lên (vừa bấm), tránh giữ phím là spam chiêu.
	var rising := cast_mask & ~_prev_cast_mask
	_prev_cast_mask = cast_mask
	if rising == 0:
		return
	for i in range(skills.size()):
		if rising & (1 << i):
			var s := skills[i]
			if s != null:
				s.try_cast(aim_dir, cast_target)

## Kẹp tướng vào trong sân đấu.
##
## Vì sao cần: `move_and_slide()` chỉ giải quyết va chạm với thân vật lý, mà
## sân đấu không có tường vật lý nào — tường ngoài chỉ là một hình chữ nhật
## logic trong `Arena.bounds`. Nên một cú đẩy lùi mạnh có thể ném tướng ra
## ngoài sân, và từ đó không có gì kéo về: camera đi theo vào vùng trống, bot
## thì đứng im vì mọi hướng đều bị coi là bị chặn.
##
## Kẹp ở đây (sau khi di chuyển) là chỗ duy nhất đúng: nó áp cho mọi nguồn
## chuyển động — đi bộ, lướt, lực đẩy lùi — mà không phải sửa từng nơi.
func _clamp_to_arena() -> void:
	if world == null or not world.has_method("clamp_position"):
		return
	var clamped: Vector2 = world.clamp_position(global_position, body_radius)
	if not clamped.is_equal_approx(global_position):
		global_position = clamped
		# Triệt tiêu vận tốc hướng ra ngoài, nếu không tướng cứ dính sát
		# mép sân và trượt dọc theo đó một cách khó chịu.
		velocity = velocity.move_toward(Vector2.ZERO, 900.0)
		_knockback = Vector2.ZERO

## Chỉ dùng khi máy khách nhận snapshot — không mô phỏng, chỉ áp vị trí/trạng thái.
func apply_snapshot(data: Dictionary) -> void:
	var target_pos: Vector2 = data.get("p", global_position)
	# Nội suy nhẹ để chuyển động không bị giật khi gói tin về lệch nhịp.
	global_position = global_position.lerp(target_pos, 0.55)
	velocity = data.get("v", Vector2.ZERO)
	aim_dir = data.get("a", aim_dir)
	var new_hp: float = data.get("hp", hp)
	if not is_equal_approx(new_hp, hp):
		if new_hp < hp:
			_flash = 1.0
			# Máy khách không tự mô phỏng nên phải tự phát tiếng trúng đòn khi
			# thấy máu tụt trong snapshot.
			var lost := hp - new_hp
			Audio.play_varied(&"hit_big" if lost >= 20.0 else &"hit", global_position,
				clampf(-14.0 + lost * 0.7, -20.0, -2.0))
		hp = new_hp
		hp_changed.emit(hp, max_hp)
	mana = data.get("mp", mana)
	mana_changed.emit(mana, max_mana)
	shield = float(data.get("sh", shield))
	var was_alive := _alive
	_alive = data.get("al", true)
	_cast_anim_time = float(data.get("ct", 99.0))
	_cast_anim_dir = data.get("cd", Vector2.RIGHT)
	_sync_statuses_from(data.get("st", {}))
	if was_alive and not _alive:
		died.emit(self, int(data.get("k", 0)))

# ------------------------------------------------------------ trạng thái

func _tick_statuses(delta: float) -> void:
	var expired: Array = []
	for id in statuses.keys():
		var st: StatusEffect = statuses[id]
		if st.tick(delta):
			expired.append(id)
	for id in expired:
		statuses.erase(id)
		_on_status_expired(id)
		status_changed.emit()
	_recompute_speed()

func _on_status_expired(id: StringName) -> void:
	pass

func _sync_statuses_from(raw: Dictionary) -> void:
	# Dựng lại túi status từ snapshot. Chỉ dùng cho hiển thị ở máy khách.
	var changed := raw.size() != statuses.size()
	if not changed:
		for id in raw.keys():
			if not statuses.has(id) or statuses[id].stacks != int(raw[id]):
				changed = true
				break
	if not changed:
		return
	statuses.clear()
	for id in raw.keys():
		var st := StatusEffect.new(StringName(id), 1.0)
		st.stacks = int(raw[id])
		statuses[id] = st
	status_changed.emit()

func _recompute_speed() -> void:
	_speed_mult = 1.0
	if statuses.has(GameData.ST_SLOW):
		_speed_mult *= 0.62
	if statuses.has(GameData.ST_HASTE):
		_speed_mult *= 1.35
	# Đóng băng thì đứng yên hoàn toàn — đây là hiệu ứng mạnh nhất trong game
	# nên thời gian của nó rất ngắn.
	if statuses.has(GameData.ST_FREEZE):
		_speed_mult = 0.0

## Đang bị đóng băng? Dùng để chặn cả di chuyển lẫn ra chiêu.
func is_frozen() -> bool:
	return has_status(GameData.ST_FREEZE)

## Thêm stack status. Trả về số stack thực sự được thêm.
func add_status(id: StringName, stacks: int = 1, duration: float = 4.0,
		source_peer: int = 0, max_stacks: int = 10) -> int:
	if not _alive:
		return 0
	var st: StatusEffect = statuses.get(id)
	if st == null:
		st = StatusEffect.new(id, duration, max_stacks)
		statuses[id] = st
	elif max_stacks != st.max_stacks:
		st.max_stacks = max_stacks
	var added := st.add(stacks, source_peer)
	if added > 0:
		status_changed.emit()
		_recompute_speed()
	return added

func get_stacks(id: StringName) -> int:
	var st: StatusEffect = statuses.get(id)
	return 0 if st == null else st.stacks

func has_status(id: StringName) -> bool:
	return get_stacks(id) > 0

## Tiêu thụ toàn bộ stack của một status, trả về số stack đã lấy đi.
## Đây là API mà các skill "kích nổ" dùng để biến stack thành sát thương.
func consume_status(id: StringName) -> int:
	var st: StatusEffect = statuses.get(id)
	if st == null or st.stacks <= 0:
		return 0
	var n := st.stacks
	statuses.erase(id)
	status_changed.emit()
	_recompute_speed()
	return n

func clear_status(id: StringName) -> void:
	if statuses.erase(id):
		status_changed.emit()

# ---------------------------------------------------------------- sát thương

func is_alive() -> bool:
	return _alive

func can_spend_mana(amount: float) -> bool:
	return mana >= amount

func spend_mana(amount: float) -> void:
	mana = maxf(0.0, mana - amount)
	mana_changed.emit(mana, max_mana)

## Nhận sát thương. Trả về true nếu đòn thực sự ăn (dùng để quyết định có
## phát hiệu ứng trúng đòn hay không).
##
## Cố ý KHÔNG có i-frame: game combo cần nhiều đòn trong một chuỗi đều ăn.
func take_damage(amount: float, source_peer: int = 0) -> bool:
	if not _alive or amount <= 0.0:
		return false

	# Bất tử (phòng luyện tập): chặn sát thương nhưng vẫn báo về để hiện số.
	# Không trả về false ngay từ đầu, vì bên gọi cần biết đòn có trúng hay không
	# để còn vẽ hiệu ứng và số sát thương.
	if invincible:
		_flash = 1.0
		damaged.emit(amount, source_peer)
		return true

	# --- Nội tại của hai bên ---
	#
	# Áp ở ĐÂY, ngay trước khi trừ máu, chứ không áp lúc bắn. Lý do: đây là chỗ
	# duy nhất biết chắc cả người gây lẫn người nhận, và biết lượng sát thương
	# cuối cùng. Áp lúc bắn thì phải sửa từng chiêu một, mà vẫn không tính được
	# các hiệu ứng cộng dồn như Vỡ Giáp.
	var source := _champion_by_peer(source_peer)
	if source != null and source.passive != null:
		amount *= source.passive.outgoing_multiplier(self)
	if passive != null:
		amount *= passive.incoming_multiplier(source_peer)
	amount = maxf(amount, 0.0)
	if amount <= 0.0:
		return false

	# Vỡ Giáp khiến mọi nguồn sát thương đánh vào nặng hơn 25%.
	if has_status(GameData.ST_BREAK):
		amount *= 1.25

	# Khiên hấp thụ trước; chỉ phần vượt quá khiên mới trừ vào máu.
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_flash = 0.6
		Audio.play_at(&"shield", global_position, -10.0)
		if shield <= 0.0:
			clear_status(GameData.ST_SHIELD)
		if amount <= 0.0:
			# Đòn bị khiên chặn trọn: có phản hồi hình ảnh nhưng không tính là
			# trúng đòn thật.
			damaged.emit(0.0, source_peer)
			return false

	hp = maxf(0.0, hp - amount)
	_flash = 1.0
	_last_killer = source_peer
	# Tiếng trúng đòn to nhỏ theo sát thương, và đổi cao độ mỗi lần cho đỡ đơn điệu.
	var vol := clampf(-14.0 + amount * 0.7, -20.0, -2.0)
	Audio.play_varied(&"hit_big" if amount >= 20.0 else &"hit", global_position, vol)
	damaged.emit(amount, source_peer)
	hp_changed.emit(hp, max_hp)
	# Báo cho nội tại của người GÂY đòn rằng đòn đã ăn. Đặt sau khi trừ máu để
	# nội tại đọc được trạng thái mục tiêu lúc này (ví dụ còn sống hay đã chết).
	if source != null and source.passive != null:
		source.passive.on_deal_damage(self, amount)
	if passive != null:
		passive.on_damage_taken(amount, source_peer)
	if hp <= 0.0:
		_die()
	return true

## Cộng khiên. Khiên không cộng dồn vô hạn — lấy giá trị lớn hơn.
func add_shield(amount: float) -> void:
	if not _alive or amount <= 0.0:
		return
	shield = maxf(shield, amount)
	add_status(GameData.ST_SHIELD, 1, 6.0, peer_id)
	Audio.play_at(&"shield", global_position, -4.0)

func heal(amount: float) -> void:
	if not _alive or amount <= 0.0:
		return
	# Nội tại có thể biến đổi lượng hồi (Phước Lành của Thiên Sứ cộng thêm khiên).
	if passive != null:
		amount = passive.on_heal(amount)
	hp = minf(max_hp, hp + amount)
	healed.emit(amount)
	hp_changed.emit(hp, max_hp)

## Tìm tướng theo peer_id. Dùng để nội tại biết ai vừa đánh mình.
func _champion_by_peer(pid: int) -> Champion:
	if world == null or not world.has_method("champions_list"):
		return null
	for c in world.champions_list():
		if c.peer_id == pid:
			return c
	return null

func apply_knockback(direction: Vector2, force: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	_knockback += direction.normalized() * force

func _die() -> void:
	_alive = false
	velocity = Vector2.ZERO
	statuses.clear()
	status_changed.emit()
	Audio.play_at(&"death", global_position, 2.0)
	# Báo cho nội tại của kẻ vừa hạ mình — dùng cho các nội tại kiểu "hạ gục thì
	# hồi chiêu" hoặc "hạ gục thì cộng dồn sức mạnh".
	var killer := _champion_by_peer(_last_killer)
	if killer != null and killer != self and killer.passive != null:
		killer.passive.on_kill(self)
	died.emit(self, _last_killer)

## Đặt lại tướng cho ván mới.
func reset_for_round(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	hp = max_hp
	shield = 0.0
	mana = max_mana
	_alive = true
	_knockback = Vector2.ZERO
	_cast_lock = 0.0
	_dash_velocity = Vector2.ZERO
	_prev_cast_mask = 0
	statuses.clear()
	for s in skills:
		s.reset_cooldown()
	if basic_attack != null:
		basic_attack.reset_cooldown()
	hp_changed.emit(hp, max_hp)
	mana_changed.emit(mana, max_mana)
	status_changed.emit()

# ---------------------------------------------------------------- tiện ích

## Được skill gọi sau khi ra chiêu, để phát tín hiệu cho HUD và hiệu ứng.
func on_skill_cast(skill: SkillBase) -> void:
	var idx := skills.find(skill)
	skill_cast.emit(idx, skill)
	# Kích hoạt hoạt ảnh vung tay/nguyên đọc — mọi đòn đều có phản hồi hình ảnh
	# tức thời, kể cả đánh thường.
	_cast_anim_time = 0.0
	_cast_anim_dir = aim_dir
	# Nội tại chỉ quan tâm KỸ NĂNG, không tính đánh thường — nếu không thì nội
	# tại kiểu "cứ 3 chiêu thì..." sẽ kích hoạt chỉ vì người chơi giữ chuột trái.
	if passive != null and not skill.is_basic:
		passive.on_skill_cast(skill)

## Bắt đầu trạng thái lướt: khoá input di chuyển và gán vận tốc cố định.
func begin_dash(direction: Vector2, speed: float, duration: float) -> void:
	_dash_velocity = direction.normalized() * speed
	_cast_lock = duration
	velocity = _dash_velocity

func is_dashing() -> bool:
	return _cast_lock > 0.0

## Tìm đối thủ gần nhất trong tầm.
func nearest_enemy(max_range: float) -> Champion:
	if world == null or not world.has_method("enemies_of"):
		return null
	var best: Champion = null
	var best_d := max_range * max_range
	for e in world.enemies_of(self):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## Ủy quyền sinh đạn cho đấu trường (đấu trường giữ danh sách để đồng bộ mạng).
func spawn_projectile(config: Dictionary) -> void:
	if world != null and world.has_method("spawn_projectile"):
		world.spawn_projectile(self, config)

## Ủy quyền sinh hiệu ứng hình ảnh.
func spawn_effect(config: Dictionary) -> void:
	if world != null and world.has_method("spawn_effect"):
		world.spawn_effect(config)

func flash_amount() -> float:
	return _flash

func anim_time() -> float:
	return _anim_time

## Tiến độ cú vung vũ khí: 1 ngay sau khi ra chiêu, giảm dần về 0.
## Visual dùng giá trị này để vẽ tay/roi/súng đang chuyển động.
func cast_anim_progress() -> float:
	return clampf(1.0 - _cast_anim_time / CAST_ANIM_DURATION, 0.0, 1.0)

## Hướng của chiêu vừa ra (để vung đúng chiều người chơi bắn).
func cast_anim_dir() -> Vector2:
	return _cast_anim_dir

## Máy khách không chạy step() nên thở/vung tay sẽ đóng băng nếu không tự chạy
## đồng hồ hoạt ảnh. Game gọi hàm này mỗi tick ở chế độ CLIENT.
func advance_visual_time(delta: float) -> void:
	_anim_time += delta
	_cast_anim_time = minf(_cast_anim_time + delta, 99.0)
	_flash = maxf(0.0, _flash - delta * 4.0)

## Túi status rút gọn để nhét vào snapshot mạng: {id: stacks}
func status_snapshot() -> Dictionary:
	var out := {}
	for id in statuses.keys():
		out[String(id)] = statuses[id].stacks
	return out

func network_state() -> Dictionary:
	return {
		"p": global_position,
		"v": velocity,
		"a": aim_dir,
		"hp": hp,
		"mp": mana,
		"sh": shield,
		"st": status_snapshot(),
		"al": _alive,
		# Hoạt ảnh ra chiêu: máy khách không chạy step() nên phải gửi kèm.
		"ct": _cast_anim_time,
		"cd": _cast_anim_dir,
	}
