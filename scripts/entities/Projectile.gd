class_name Projectile
extends Node2D
## Gộp ba loại hiệu ứng chiến đấu vào một lớp:
##   - Đạn bay (Hỏa Cầu, Ám Tiễn): di chuyển, trúng thì biến mất.
##   - Vùng đất (Tường Lửa): đứng yên, gây sát thương theo nhịp.
##   - Vụ nổ (Bùng Nổ, Tử Ảnh): bán kính loang ra rồi tắt.
##
## Trên host thì step() mô phỏng; trên máy khách thì chỉ nhận vị trí từ snapshot
## và vẽ. Nhờ vậy hai bên thấy giống hệt nhau mà không cần mô phỏng trùng lặp.

var id := 0
var owner_peer := 0
var direction := Vector2.RIGHT
var speed := 520.0
var damage := 0.0
var radius := 9.0
var max_life := 2.0
var life := 2.0

## Độ khoan dung va chạm: đòn trúng được tính khi còn cách bán kính thân một
## khoảng nhỏ. Vì sao cần: nhân vật vẽ CAO trên gốc toạ độ (chân tại gốc, đầu
## cao ~58px*scale) nhưng tâm va chạm nằm ở chân — người chơi ngắm vào THÂN
## nhân vật thì đạn bay "sát người" mà không được tính là trúng, gây cảm giác
## oan. Thêm 7px cho cảm giác trúng thoải mái mà vẫn không méo.
const HIT_GRACE := 7.0

## Tỉ lệ hút máu: phần trăm sát thương gây ra được hoàn về máu của người bắn.
## 0 = không hút. Dùng cho Huyết Bá và các chiêu hút máu tương lai.
var lifesteal := 0.0
var status_id: StringName = &""
var status_stacks := 0
var status_duration := 4.0
## Số stack tối đa được phép dồn lên mục tiêu (Khóa Hồn chỉ cho 3).
var status_max_stacks := 10
## true = vùng lửa nuôi stack: mục tiêu đang có sẵn status này thì dồn thêm 1.
var burns_stacks := false
## Status mà vùng này "nuôi" thêm mỗi nhịp.
var owner_status_bonus: StringName = &""

## Sét lan: khi trúng đích, nếu mục tiêu thoả điều kiện thì gây thêm sát thương
## lên mọi kẻ đứng gần. Khai báo bằng dữ liệu để chiêu nào cũng tái dùng được,
## không phải viết riêng cho từng tướng.
var chain_radius := 0.0
var chain_damage := 0.0
## Chỉ lan khi mục tiêu đang có status này. Rỗng = lan vô điều kiện.
var chain_requires: StringName = &""
## Status cắm lên những mục tiêu bị lan tới.
var chain_status: StringName = &""

## Sát thương theo nhịp (dùng cho vùng đất).
var tick_damage := 0.0
var tick_interval := 0.4
var _tick_timer := 0.0

## Số mục tiêu còn có thể xuyên qua. 0 = dừng ở mục tiêu đầu tiên.
var pierce_left := 0

## Sức mạnh dùng khi hai viên đạn đối đầu nhau. Bên nào cao hơn thì đập vỡ
## được bên kia. Bằng 0 nghĩa là không tham gia va chạm đạn-đạn — dùng cho
## vùng đất và hiệu ứng hình ảnh.
var power := 0.0

## Đánh dấu đã chết. Không xoá node ngay vì vòng lặp va chạm còn phải đọc trạng
## thái của các viên khác trong cùng khung hình; Arena dọn sau.
var _dead := false

func kill() -> void:
	_dead = true

func is_dead() -> bool:
	return _dead

## Vụ nổ loang dần bán kính theo thời gian.
var grow := false
var grow_to := 0.0

## true = vùng đứng yên (tường lửa, vùng độc...).
var is_zone := false

## true = chặn cả đường đi của tướng, không chỉ gây sát thương. Dùng cho Tường Đá.
var blocks_movement := false

## Lực hút về tâm vùng, tính bằng pixel mỗi giây. 0 = không hút.
##
## Dùng cho Hố Đen. Khác với lực đẩy lùi ở chỗ nó tác động LIÊN TỤC mỗi khung
## hình chứ không phải một cú giật, nên nạn nhân bị kéo trượt dần vào tâm —
## cảm giác "không thoát ra được" mạnh hơn hẳn một cú đẩy.
var pull_strength := 0.0
## Bán kính tác dụng của lực hút. 0 = dùng chính bán kính vùng.
var pull_radius := 0.0

## Tốc độ tự đổi hướng để đuổi theo đối thủ gần nhất. 0 = bay thẳng.
##
## Dùng cho thú triệu hồi (sói của Chủ Ưng). Càng lớn thì càng bám dai; để 0 thì
## bay thẳng như mọi viên đạn khác, nên không ảnh hưởng gì tới các chiêu cũ.
var chase_speed := 0.0
## Thời gian sống tối đa của một con thú, tách khỏi `life` để dễ đọc ý định.
var chase_target: Champion = null

var kind: StringName = &"fireball"
var accent := Color("ff7a2f")

## Trên máy khách không mô phỏng — chỉ vẽ theo vị trí host gửi xuống.
var simulate := true

## Mục tiêu đã trúng, tránh một vùng gây sát thương liên tục mỗi frame.
var _hit_once: Dictionary = {}

## Vệt mờ phía sau đạn, làm chuyển động trông nhanh và mượt hơn.
var _trail: Array[Vector2] = []
const TRAIL_MAX := 7

func _ready() -> void:
	z_index = 3

func step(delta: float, world: Node) -> bool:
	## Trả về false khi đạn cần bị xoá.
	life -= delta
	if life <= 0.0:
		return false

	if not is_zone and speed > 0.0:
		# Thú đuổi mồi: tự xoay hướng bay về phía đối thủ gần nhất trước khi
		# dịch chuyển. Đổi `direction` chứ không đổi vị trí, nên nó vẫn tuân
		# theo tốc độ bay và vẫn va tường như mọi viên đạn khác.
		if chase_speed > 0.0:
			var prey := _find_prey(world)
			if prey != null:
				var want: Vector2 = (prey.global_position - position).normalized()
				direction = direction.lerp(want, clampf(chase_speed * delta, 0.0, 1.0)).normalized()
		var prev := position
		position += direction * speed * delta
		_trail.push_front(prev)
		if _trail.size() > TRAIL_MAX:
			_trail.resize(TRAIL_MAX)

	if grow:
		var progress := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
		radius = lerpf(radius, grow_to, minf(progress * 3.0, 1.0))

	# Chạm tường thì dừng.
	if not is_zone and world.has_method("is_blocked_at") and world.is_blocked_at(position, radius):
		return false

	_tick_timer -= delta
	var do_tick := _tick_timer <= 0.0
	if do_tick:
		_tick_timer = tick_interval

	for c in world.champions_list():
		if c.peer_id == owner_peer or not c.is_alive():
			continue
		if position.distance_to(c.global_position) > radius + c.body_radius + HIT_GRACE:
			continue

		if is_zone or tick_damage > 0.0:
			# Vùng đất: chỉ ăn theo nhịp, không ăn mỗi frame.
			if not do_tick or _hit_once.has(c.peer_id):
				continue
			_hit_once[c.peer_id] = true
			_apply_hit(c, world, tick_damage)
		else:
			_apply_hit(c, world, damage)
			if pierce_left > 0:
				pierce_left -= 1
			else:
				return false

	# Xoá sổ trúng theo nhịp để nhịp sau lại ăn được.
	if do_tick:
		_hit_once.clear()

	# Lực hút: kéo mọi tướng địch trong bán kính về phía tâm vùng.
	#
	# Cố ý dịch thẳng vị trí thay vì cộng vào vận tốc: vận tốc bị `_update_velocity`
	# ghi đè mỗi khung hình, còn lực đẩy lùi thì tắt rất nhanh (dùng cho cú giật).
	# Dịch vị trí cho ra lực kéo đều tay và dễ đoán — đúng cảm giác "bị hút vào".
	# Vẫn hỏi `is_blocked_at` trước khi dịch để không kéo xuyên qua tường.
	if pull_strength > 0.0:
		var reach := pull_radius if pull_radius > 0.0 else radius
		for c in world.champions_list():
			if c.peer_id == owner_peer or not c.is_alive():
				continue
			var to_center: Vector2 = position - c.global_position
			var dist := to_center.length()
			if dist > reach or dist < 1.0:
				continue
			# Càng gần tâm lực càng yếu, để nạn nhân không bị dồn cứng vào một điểm.
			var falloff := clampf(dist / reach, 0.0, 1.0)
			var step_vec := to_center.normalized() * pull_strength * falloff * delta
			var dest: Vector2 = c.global_position + step_vec
			if world.has_method("is_blocked_at") and world.is_blocked_at(dest, c.body_radius):
				continue
			c.global_position = dest

	return true

func _apply_hit(target: Champion, world: Node, dmg: float) -> void:
	var applied := false
	if dmg > 0.0:
		applied = target.take_damage(dmg, owner_peer)
	if status_id != &"" and status_stacks > 0:
		target.add_status(status_id, status_stacks, status_duration, owner_peer, status_max_stacks)

	# Hút máu: hoàn về người bắn một phần sát thương thực sự gây ra.
	# Chỉ hút khi đòn ĐÃ ĂN (applied), không hút khi bị khiên chặn trọn.
	if lifesteal > 0.0 and applied:
		var owner_champ := _find_owner(world)
		if owner_champ != null and owner_champ.is_alive():
			owner_champ.heal(dmg * lifesteal)

	# Vùng lửa nuôi stack: đứng trong lửa mà đang cháy thì cháy dữ hơn.
	if burns_stacks and owner_status_bonus != &"" and target.has_status(owner_status_bonus):
		target.add_status(owner_status_bonus, 1, status_duration, owner_peer)
	if target.has_method("apply_knockback") and not is_zone:
		target.apply_knockback(direction, 90.0)
	if world.has_method("spawn_hit_spark"):
		world.spawn_hit_spark(target.global_position, accent)
	_try_chain(target, world)

## Tìm chủ sở hữu viên đạn theo peer_id (dùng cho hút máu).
func _find_owner(world: Node) -> Champion:
	if world == null or not world.has_method("champions_list"):
		return null
	for c in world.champions_list():
		if c.peer_id == owner_peer:
			return c
	return null

## Tìm mồi cho thú đuổi: đối thủ còn sống gần nhất.
func _find_prey(world: Node) -> Champion:
	if world == null or not world.has_method("champions_list"):
		return null
	var best: Champion = null
	var best_d := INF
	for c in world.champions_list():
		if c.peer_id == owner_peer or not c.is_alive():
			continue
		var d: float = position.distance_squared_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

## Sét lan sang những kẻ đứng gần mục tiêu vừa trúng.
func _try_chain(target: Champion, world: Node) -> void:
	if chain_radius <= 0.0 or chain_damage <= 0.0:
		return
	if chain_requires != &"" and not target.has_status(chain_requires):
		return
	for other in world.champions_list():
		if other == target or other.peer_id == owner_peer or not other.is_alive():
			continue
		if other.global_position.distance_to(target.global_position) > chain_radius:
			continue
		other.take_damage(chain_damage, owner_peer)
		if chain_status != &"":
			other.add_status(chain_status, 1, 5.0, owner_peer)
		if world.has_method("spawn_hit_spark"):
			world.spawn_hit_spark(other.global_position, accent)

# ------------------------------------------------------------- đồng bộ mạng

func network_state() -> Dictionary:
	return {
		"i": id,
		"p": position,
		"r": radius,
		"k": String(kind),
		"c": accent.to_html(false),
		"z": is_zone,
	}

func apply_network_state(data: Dictionary) -> void:
	position = data.get("p", position)
	radius = float(data.get("r", radius))

# ------------------------------------------------------------------ hiển thị

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	match kind:
		&"fireball":
			_draw_fireball()
		&"firewall":
			_draw_firewall()
		&"shadow_bolt":
			_draw_shadow_bolt()
		&"slash":
			_draw_slash()
		&"whip_lash":
			_draw_whip_lash()
		&"time_rift":
			_draw_time_rift()
		&"clock_nova":
			_draw_clock_nova()
		&"bolt":
			_draw_bolt()
		&"ice_shard", &"ice_lance":
			_draw_ice()
		&"ice_patch":
			_draw_ice_patch()
		&"thunder_bolt", &"thunder_strike":
			_draw_thunder()
		&"boulder":
			_draw_boulder()
		&"stone_wall":
			_draw_stone_wall()
		&"explosion":
			_draw_explosion()
		&"void_bolt":
			_draw_void_bolt()
		&"black_hole":
			_draw_black_hole()
		&"telegraph":
			_draw_telegraph()
		# --- Nhóm đạn nhỏ: cùng một kiểu vẽ, khác màu ---
		&"phantom_edge", &"snipe_round", &"arc_bolt", &"spark_shot":
			_draw_small_round()
		# --- Nhóm đạn xuyên: vẽ dài theo hướng bay ---
		&"pierce_round", &"rail_round":
			_draw_lance()
		&"light_wave":
			_draw_light_wave()
		# --- Nhóm vùng đặt trên đất ---
		&"shadow_marker":
			_draw_shadow_marker()
		&"cal_trap", &"mine":
			_draw_mine()
		&"scope_ring":
			_draw_scope_ring()
		&"sanctuary":
			_draw_sanctuary()
		&"laser_fence":
			_draw_laser_fence()
		&"autocannon":
			_draw_autocannon()
		&"thunder_zone":
			_draw_thunder_zone()
		&"toxic_zone":
			_draw_toxic_zone()
		&"flask":
			_draw_flask()
		&"blade_storm_zone":
			_draw_blade_storm()
		&"ice_wall":
			_draw_ice_wall()
		&"spirit_wolf":
			_draw_spirit_wolf()
		&"death_burst":
			_draw_death_burst()
		&"dust":
			_draw_dust()
		&"ember":
			_draw_ember()
		&"snow":
			_draw_snow()
		&"rain":
			_draw_rain()
		&"firework":
			_draw_firework()
		&"confetti":
			_draw_confetti()
		_:
			draw_circle(Vector2.ZERO, radius, accent)

## Đạn tròn nhỏ: lõi sáng + quầng + đuôi mờ dần về phía sau.
func _draw_small_round() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	draw_circle(Vector2.ZERO, radius * 2.2, Color(accent.r, accent.g, accent.b, 0.18))
	draw_circle(Vector2.ZERO, radius, accent)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.92))
	for i in range(3):
		var f := float(i + 1) / 3.0
		draw_circle(-dir * radius * (1.3 + f * 2.0), radius * (0.5 - f * 0.32),
			Color(accent.r, accent.g, accent.b, 0.35 * (1.0 - f)))

## Đạn xuyên: thân dài như mũi giáo, có vệt sáng dọc.
func _draw_lance() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var half := radius * 3.4
	draw_colored_polygon(PackedVector2Array([
		dir * half, perp * radius * 0.55, -dir * half * 0.8, -perp * radius * 0.55,
	]), Color(accent.r, accent.g, accent.b, 0.42))
	draw_line(-dir * half * 0.7, dir * half * 0.85, Color(1, 1, 1, 0.9), radius * 0.42, true)
	draw_circle(dir * half, radius * 0.5, Color(1, 1, 1, 0.95))

## Sóng ánh sáng: cung tròn lan theo hướng bay.
func _draw_light_wave() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var base := dir.angle()
	var r := radius * 1.8
	draw_arc(Vector2.ZERO, r, base - 1.1, base + 1.1, 20,
		Color(accent.r, accent.g, accent.b, 0.85), radius * 0.7, true)
	draw_arc(Vector2.ZERO, r * 0.6, base - 0.9, base + 0.9, 16,
		Color(1, 1, 1, 0.7), radius * 0.4, true)

## Bóng của Hư Ảnh: hình người mờ, nhấp nháy.
func _draw_shadow_marker() -> void:
	var pulse := 0.5 + sin(life * 6.0) * 0.2
	_ellipse_at(Vector2(0, 4), radius * 0.9, radius * 0.36,
		Color(accent.r, accent.g, accent.b, 0.35 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24,
		Color(accent.r, accent.g, accent.b, 0.7), 2.0, true)
	# Bóng người đứng mờ phía trên.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 2), Vector2(6, 2), Vector2(4, -22), Vector2(-4, -22),
	]), Color(accent.r, accent.g, accent.b, 0.28))
	draw_circle(Vector2(0, -26), 6.0, Color(accent.r, accent.g, accent.b, 0.28))

## Mìn: đế tròn + ba chấu + đèn nhấp nháy.
func _draw_mine() -> void:
	var blink := 0.45 + sin(life * 9.0) * 0.45
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.15, 0.12, 0.10, 0.75))
	draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 20,
		Color(accent.r, accent.g, accent.b, 0.85), 2.0, true)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + life * 0.6
		draw_line(Vector2(cos(a), sin(a)) * radius * 0.3,
			Vector2(cos(a), sin(a)) * radius * 0.85,
			Color(accent.r, accent.g, accent.b, 0.6), 2.0, true)
	draw_circle(Vector2.ZERO, 3.4, Color(1, 0.35, 0.2, blink))

## Vòng ống nhòm: hai vòng tròn đồng tâm + vạch chữ thập.
func _draw_scope_ring() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, 0.5), 2.4, true)
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 36,
		Color(accent.r, accent.g, accent.b, 0.35), 1.8, true)
	var cross: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1)]
	for d in cross:
		draw_line(-d * radius * 0.9, d * radius * 0.9,
			Color(1, 1, 1, 0.35), 1.2, true)

## Vùng thiêng: vòng tròn sáng + tia sáng từ trên chiếu xuống.
func _draw_sanctuary() -> void:
	var pulse := 0.5 + sin(life * 3.0) * 0.12
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.13 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56,
		Color(accent.r, accent.g, accent.b, 0.75), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.66, -life * 1.4, -life * 1.4 + 2.6, 24,
		Color(1, 1, 1, 0.5), 2.4, true)
	# Vài tia sáng rơi từ trên xuống.
	for i in range(6):
		var a := TAU * float(i) / 6.0 + life * 0.3
		var p := Vector2(cos(a), sin(a)) * radius * 0.75
		draw_line(p + Vector2(0, -26), p, Color(1, 1, 0.92, 0.28), 3.0, true)

## Hàng rào laser: một đoạn thẳng đứng dọc theo `direction`.
func _draw_laser_fence() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var pulse := 0.6 + sin(life * 12.0) * 0.35
	var a := -dir * radius
	var b := dir * radius
	draw_line(a, b, Color(accent.r, accent.g, accent.b, 0.28), 12.0, true)
	draw_line(a, b, Color(1, 0.45, 0.45, pulse), 3.0, true)
	draw_circle(a, 3.0, Color(1, 0.6, 0.6, 0.9))
	draw_circle(b, 3.0, Color(1, 0.6, 0.6, 0.9))

## Trụ pháo: đế + thân trụ + nòng xoay theo mục tiêu gần nhất.
func _draw_autocannon() -> void:
	draw_circle(Vector2.ZERO, radius * 0.42, Color(0.18, 0.14, 0.11, 0.8))
	draw_arc(Vector2.ZERO, radius * 0.42, 0.0, TAU, 22,
		Color(accent.r, accent.g, accent.b, 0.8), 2.4, true)
	# Nòng xoay chậm, gợi ý nó đang tìm mục tiêu.
	var a := life * 1.8
	draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * radius * 0.7,
		Color(0.65, 0.6, 0.55), 5.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color(accent.r, accent.g, accent.b, 0.9))

## Vùng sét: vòng tròn và tia chớp nhấp nháy.
func _draw_thunder_zone() -> void:
	var on := sin(life * 14.0) > 0.2
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.45), 2.2, true)
	if on:
		for i in range(4):
			var a := TAU * float(i) / 4.0 + life * 2.0
			var p := Vector2(cos(a), sin(a)) * radius * 0.7
			draw_line(p, p + Vector2(cos(a + 0.5), sin(a + 0.5)) * 22.0,
				Color(1, 0.95, 0.5, 0.85), 2.6, true)

## Vùng độc: đầm lầy xanh sậm, bọt khí sủi và hơi độc bốc lên.
func _draw_toxic_zone() -> void:
	var pulse := 0.5 + sin(life * 5.0) * 0.12
	# Nền đất nhiễm độc: hai lớp xanh lục đậm.
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.14))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(accent.r, accent.g, accent.b, 0.10 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44,
		Color(accent.r, accent.g, accent.b, 0.55), 2.4, true)
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 36,
		Color(accent.r, accent.g, accent.b, 0.30), 1.6, true)
	# Bọt khí nổi: các bong bóng nhỏ phình lên rồi vỡ.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9931
	for i in range(7):
		var ph := fposmod(life * 0.9 + rng.randf(), 1.0)
		var a := rng.randf_range(0.0, TAU)
		var d := radius * rng.randf_range(0.1, 0.75)
		var base := Vector2(cos(a), sin(a)) * d
		var rise := -ph * 12.0
		var sz := (2.0 + rng.randf() * 2.4) * (1.0 - ph * 0.5)
		draw_circle(base + Vector2(0, rise), sz,
			Color(accent.r, accent.g, accent.b, (0.55 - ph * 0.35) * (0.4 + ph)))
	# Vài xương nhỏ mờ dưới đáy — gợi ý "chỗ này là nơi của độc".
	for i in range(3):
		var x := (float(i) - 1.0) * radius * 0.4
		draw_line(Vector2(x, radius * 0.3), Vector2(x + 5.0, radius * 0.3 - 4.0),
			Color(0.85, 0.95, 0.7, 0.25), 1.4, true)

## Bình độc bay (Độc Sư đánh thường): thân bình thuỷ tinh + lõi độc lắc lư.
func _draw_flask() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var wob := sin(life * 22.0) * 1.6
	# Vệt độc nhỏ rơi phía sau.
	for i in range(3):
		var f := float(i + 1) / 3.0
		draw_circle(-dir * (4.0 + f * 9.0) + Vector2(0, f * 2.0),
			2.4 - f * 0.7, Color(accent.r, accent.g, accent.b, 0.4 * (1.0 - f)))
	# Thân bình: tròn dẹt màu thuỷ tinh.
	_ellipse_at(Vector2(0, wob * 0.3), 8.5, 7.0, Color(0.72, 0.85, 0.45, 0.5))
	# Lõi độc bên trong, lay động theo đường bay.
	draw_circle(Vector2(wob * 0.4, wob * 0.3), 4.6, Color(accent.r, accent.g, accent.b, 0.95))
	draw_circle(Vector2(wob * 0.4, wob * 0.3), 2.0, Color(0.85, 1.0, 0.55, 0.9))
	# Cổ bình + nút.
	draw_line(Vector2(0, -5.0), Vector2(0, -10.0), Color(0.78, 0.88, 0.6, 0.85), 3.2)
	draw_circle(Vector2(0, -11.0), 2.4, Color(0.6, 0.42, 0.2, 0.95))
	# Highlight thuỷ tinh.
	draw_line(Vector2(-3.0, -2.0 + wob * 0.3), Vector2(-1.0, -6.0 + wob * 0.3),
		Color(1, 1, 1, 0.5), 1.2, true)

## Vạn Kiếm Mộ (Kiếm Thánh R): vùng mưa kiếm xoay tròn, lưỡi kiếm mọc quanh vành.
func _draw_blade_storm() -> void:
	var t := life
	var spin := t * 3.4
	# Nền vùng tối gần như Hư Không.
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.13))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, 0.5), 2.2, true)
	# Xoáy trung tâm mờ.
	draw_arc(Vector2.ZERO, radius * 0.45, 0.0, TAU, 32,
		Color(accent.r, accent.g, accent.b, 0.22), 1.4, true)
	# Vòng lưỡi kiếm xoay: mỗi lưỡi là một vệt dài theo tiếp tuyến.
	var blades := 9
	for i in range(blades):
		var a := TAU * float(i) / float(blades) + spin
		var dir := Vector2(cos(a), sin(a))
		var r := radius * 0.88
		var tip := dir * r
		var tail := dir.rotated(0.42) * r * 0.62
		draw_line(tail, tip, Color(0.92, 0.94, 1.0, 0.75), 2.6, true)
		draw_line(tail, tip, Color(accent.r, accent.g, accent.b, 0.5), 1.2, true)
	# Kiếm rơi ngẫu nhiên trong vùng: các vệt trắng nhỏ sổ xuống.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in range(6):
		var ph := fposmod(t * 1.6 + rng.randf(), 1.0)
		var a := rng.randf_range(0.0, TAU)
		var d := radius * rng.randf_range(0.15, 0.8)
		var base := Vector2(cos(a), sin(a)) * d
		var fall := ph * 16.0
		var sz := (2.0 + rng.randf() * 2.0) * (1.0 - ph * 0.4)
		draw_line(base + Vector2(0, fall - 8.0), base + Vector2(0, fall),
			Color(1, 1, 1, 0.5 * (1.0 - ph)), sz, true)

## Tường băng: khối chữ nhật bo góc, có vân nứt.
func _draw_ice_wall() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.UP
	var perp := Vector2(-dir.y, dir.x)
	var w := radius
	var h := radius * 1.5
	var pts := PackedVector2Array([
		dir * h + perp * w, dir * h - perp * w, -dir * h - perp * w, -dir * h + perp * w,
	])
	draw_colored_polygon(pts, Color(0.74, 0.93, 1.0, 0.55))
	draw_colored_polygon(PackedVector2Array([
		dir * h * 0.8 + perp * w * 0.7, dir * h * 0.8 - perp * w * 0.7,
		-dir * h * 0.8 - perp * w * 0.7, -dir * h * 0.8 + perp * w * 0.7,
	]), Color(0.88, 0.97, 1.0, 0.7))
	# Vân nứt
	draw_line(dir * h * 0.5, -dir * h * 0.4, Color(1, 1, 1, 0.5), 1.4, true)
	draw_line(dir * h * 0.1 + perp * w * 0.4, -dir * h * 0.6 - perp * w * 0.2,
		Color(1, 1, 1, 0.35), 1.2, true)

## Sói tinh linh: thân bốn chân, đầu hướng theo hướng bay.
func _draw_spirit_wolf() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var flip := 1.0 if dir.x >= 0.0 else -1.0
	# Bóng dưới chân
	_ellipse_at(Vector2(0, 6), 16.0, 5.0, Color(0, 0, 0, 0.3))
	# Thân
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14 * flip, -6), Vector2(10 * flip, -6),
		Vector2(13 * flip, 2), Vector2(-12 * flip, 2),
	]), Color(accent.r, accent.g, accent.b, 0.85))
	# Đầu + mõm
	draw_colored_polygon(PackedVector2Array([
		Vector2(9 * flip, -8), Vector2(20 * flip, -4),
		Vector2(19 * flip, 1), Vector2(9 * flip, 2),
	]), Color(accent.r, accent.g, accent.b, 0.95))
	# Tai
	draw_colored_polygon(PackedVector2Array([
		Vector2(11 * flip, -8), Vector2(14 * flip, -14), Vector2(16 * flip, -8),
	]), Color(accent.r, accent.g, accent.b, 0.9))
	# Mắt sáng
	draw_circle(Vector2(15 * flip, -4), 1.8, Color(1, 1, 1, 0.95))
	# Bốn chân
	var legs: Array[float] = [-9.0, -3.0, 5.0, 11.0]
	for k in legs:
		draw_line(Vector2(k * flip, 2), Vector2(k * flip + sin(life * 18.0 + k) * 2.0, 9),
			Color(accent.r, accent.g, accent.b, 0.8), 2.6, true)
	# Đuôi
	draw_line(Vector2(-13 * flip, -4),
		Vector2(-22 * flip, -10 + sin(life * 10.0) * 3.0),
		Color(accent.r, accent.g, accent.b, 0.7), 2.4, true)

## Hạt bắn ra khi chết: nhiều chấm nhỏ bay tỏa theo mọi hướng rồi biến mất.
func _draw_death_burst() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(18):
		var angle := rng.randf_range(0.0, TAU)
		var dist := radius * rng.randf_range(0.2, 1.0) * t
		var p := Vector2(cos(angle), sin(angle)) * dist
		var sz := radius * rng.randf_range(0.08, 0.18) * (1.0 - t * 0.5)
		var alpha := a * rng.randf_range(0.6, 1.0)
		draw_circle(p, sz, Color(accent.r, accent.g, accent.b, alpha))
	# Lõi sáng ở tâm, tắt dần.
	draw_circle(Vector2.ZERO, radius * 0.4 * (1.0 - t), Color(1, 1, 1, a * 0.8))

## Bụi chân: vài chấm mờ nhỏ tản ra rồi biến mất.
func _draw_dust() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = 8888
	for i in range(5):
		var angle := rng.randf_range(0.0, TAU)
		var dist := radius * rng.randf_range(0.1, 0.8) * t
		var p := Vector2(cos(angle), sin(angle)) * dist
		var sz := radius * rng.randf_range(0.15, 0.35) * (1.0 - t * 0.6)
		draw_circle(p, sz, Color(accent.r, accent.g, accent.b, a * rng.randf_range(0.4, 0.9)))

## Tia lửa bay lên rồi tắt dần.
func _draw_ember() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var drift := Vector2(0.0, -t * radius * 1.2)
	var a := (1.0 - t) * accent.a
	draw_circle(drift, radius * (1.0 - t * 0.4), Color(accent.r, accent.g, accent.b, a))

## Bông tuyết lục giác rơi chậm.
func _draw_snow() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var drift := Vector2(sin(t * 3.0) * radius * 0.6, t * radius * 0.8)
	var a := (1.0 - t) * accent.a
	var pts := PackedVector2Array()
	for i in range(6):
		var angle := TAU * float(i) / 6.0 - PI * 0.5
		pts.append(drift + Vector2(cos(angle), sin(angle)) * radius * (1.0 - t * 0.3))
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, a))

## Giọt mưa rơi thẳng.
func _draw_rain() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var drift := Vector2(0.0, t * radius * 2.5)
	var a := (1.0 - t) * accent.a
	draw_line(drift, drift + Vector2(0.0, radius * 1.4),
		Color(accent.r, accent.g, accent.b, a), radius * 0.5, true)

## Pháo hoa: nở ra rồi tắt dần.
func _draw_firework() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * accent.a
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 1000 + position.y)
	for i in range(8):
		var angle := rng.randf_range(0.0, TAU)
		var dist := radius * rng.randf_range(0.3, 1.0) * t
		var p := Vector2(cos(angle), sin(angle)) * dist
		var sz := radius * rng.randf_range(0.12, 0.28) * (1.0 - t * 0.5)
		draw_circle(p, sz, Color(accent.r, accent.g, accent.b, a * rng.randf_range(0.6, 1.0)))
	draw_circle(Vector2.ZERO, radius * 0.35 * (1.0 - t), Color(1, 1, 1, a * 0.9))

## Confetti: hình chữ nhật nhỏ rơi xuống.
func _draw_confetti() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var drift := Vector2(sin(t * 4.0 + position.x) * radius * 0.5, t * radius * 3.0)
	var a := (1.0 - t) * accent.a
	var w := radius * 0.8
	var h := radius * 0.4
	var rot := t * 2.5
	var c := cos(rot)
	var s := sin(rot)
	var pts := PackedVector2Array([
		drift + Vector2(-w * c + h * s, -w * s - h * c),
		drift + Vector2(w * c + h * s, w * s - h * c),
		drift + Vector2(w * c - h * s, w * s + h * c),
		drift + Vector2(-w * c - h * s, -w * s + h * c),
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, a))

## Tiện ích vẽ ellipse tại chỗ, dùng cho vài hình ở trên.
func _ellipse_at(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

## Tia hư không: giọt năng lượng tím, có quầng và đuôi mờ.
func _draw_void_bolt() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	draw_circle(Vector2.ZERO, radius * 2.4, Color(accent.r, accent.g, accent.b, 0.20))
	draw_circle(Vector2.ZERO, radius, Color("c4b5fd"))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.92))
	# Đuôi: vài chấm nhỏ dần về phía sau, gợi hướng bay.
	for i in range(3):
		var t := float(i + 1) / 3.0
		draw_circle(-dir * radius * (1.4 + t * 1.8), radius * (0.5 - t * 0.32),
			Color(accent.r, accent.g, accent.b, 0.4 * (1.0 - t)))

## Hố đen: đĩa tối ở giữa, vành sáng tím, và các tia bị hút vào.
func _draw_black_hole() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	# Vành ngoài mờ dần theo bán kính.
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.45), 2.5, true)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.30), 2.0, true)

	# Lõi tối, to dần rồi thu lại ở cuối vòng đời.
	var core := radius * (0.16 + 0.10 * sin(t * PI))
	draw_circle(Vector2.ZERO, core * 1.9, Color(0.04, 0.02, 0.08, 0.92))
	draw_circle(Vector2.ZERO, core, Color(0, 0, 0, 0.98))

	# Vài tia xoáy bị hút vào tâm — thứ làm mắt đọc ra "đang hút".
	for i in range(5):
		var a := t * 7.0 + float(i) * TAU / 5.0
		var r0 := radius * 0.85
		var r1 := radius * 0.35
		draw_line(Vector2(cos(a), sin(a)) * r0, Vector2(cos(a + 0.6), sin(a + 0.6)) * r1,
			Color(accent.r, accent.g, accent.b, 0.55), 2.0, true)

## Vòng cảnh báo trước khi chiêu nổ.
##
## Vẽ viền đậm dần và một vòng thu nhỏ dần về tâm: người chơi đối diện đọc được
## ngay "sắp nổ ở đây, phải bước ra". Đây là thứ khiến chiêu mạnh vẫn công bằng.
func _draw_telegraph() -> void:
	var left := clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var urgency := 1.0 - left

	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.10 + urgency * 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56,
		Color(accent.r, accent.g, accent.b, 0.55 + urgency * 0.4), 3.0, true)
	# Vòng thu nhỏ: khi nó chạm tâm thì chiêu nổ.
	draw_arc(Vector2.ZERO, radius * left, 0.0, TAU, 48,
		Color(1, 1, 1, 0.55), 2.0, true)

## Mảnh băng: khối thoi màu lam nhạt, có viền sáng và tinh thể lấp lánh.
func _draw_ice() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var len_ := radius * 2.6
	var pts := PackedVector2Array([
		dir * len_, perp * radius * 0.8, -dir * len_ * 0.7, -perp * radius * 0.8,
	])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.38))
	var inner := PackedVector2Array([
		dir * len_ * 0.8, perp * radius * 0.45, -dir * len_ * 0.5, -perp * radius * 0.45,
	])
	draw_colored_polygon(inner, Color("e0f7ff"))
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.92))
	# Viền sáng
	draw_line(dir * len_ * 0.9, -dir * len_ * 0.6, Color(1, 1, 1, 0.55), 1.2, true)
	# Tinh thể lấp lánh
	var twinkle := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + twinkle
		var p := Vector2(cos(a), sin(a)) * radius * 0.6
		draw_circle(p, 1.8 * twinkle, Color(1, 1, 1, 0.8 * twinkle))

## Vệt băng trên mặt đất.
func _draw_ice_patch() -> void:
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.14))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 30, Color(accent.r, accent.g, accent.b, 0.4), 2.0, true)
	# Vài tinh thể nhỏ nằm rải trong vệt.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(7):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.0, radius * 0.85)
		var p := Vector2(cos(a), sin(a)) * d
		var s := rng.randf_range(3.0, 6.0)
		draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color("bdf0ff"), 1.5)
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color("bdf0ff"), 1.5)

## Tia sét: đường gấp khúc chói với nhánh phụ.
func _draw_thunder() -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var segs := 7
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var jitter := 0.0 if i == 0 or i == segs else rng.randf_range(-radius, radius) * 0.9
		pts.append(dir * (t * radius * 2.6 - radius * 1.3) + perp * jitter)
	# Tia chính
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(1, 1, 0.75, 0.95), 3.4, true)
		draw_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.92), 1.4, true)
	# Nhánh phụ
	for i in range(2, segs - 1):
		var branch := pts[i] + perp * rng.randf_range(-radius * 0.6, radius * 0.6)
		draw_line(pts[i], branch, Color(1, 1, 0.6, 0.55), 1.6, true)
	# Quầng sáng
	draw_circle(Vector2.ZERO, radius * 1.6, Color(1, 0.95, 0.5, 0.28))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.85))

## Đá lăn: khối đa giác xù xì.
func _draw_boulder() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13579
	var pts := PackedVector2Array()
	var segs := 9
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		var r := radius * rng.randf_range(0.82, 1.12)
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("6b6660"))
	var inner := PackedVector2Array()
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		inner.append(Vector2(cos(a), sin(a)) * radius * 0.62)
	draw_colored_polygon(inner, Color("8a857e"))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.22, Color("a8a29e"))

## Tường đá: khối chữ nhật có chiều cao, cùng phong cách với vật cản tĩnh.
func _draw_stone_wall() -> void:
	var w := radius * 2.0
	var h := radius * 1.4
	var height := radius * 0.9
	draw_rect(Rect2(-w * 0.5, -h * 0.5 - height, w, h + height), Color("2a2724"))
	draw_rect(Rect2(-w * 0.5, -h * 0.5 - height, w, h), Color("4a453f"))
	draw_line(Vector2(-w * 0.5, -h * 0.5 - height), Vector2(w * 0.5, -h * 0.5 - height),
		Color("6b6660"), 2.0)
	draw_rect(Rect2(-w * 0.5, -h * 0.5 - height, w, h), Color("5f5a54"), false, 1.5)

## Đạn đánh thường: viên nhỏ, gọn, màu theo tướng.
func _draw_bolt() -> void:
	for i in range(_trail.size()):
		var local := to_local(_trail[i])
		var a := (1.0 - float(i) / float(TRAIL_MAX)) * 0.3
		draw_circle(local, radius * 0.7, Color(accent.r, accent.g, accent.b, a))
	draw_circle(Vector2.ZERO, radius * 1.25, Color(accent.r, accent.g, accent.b, 0.28))
	draw_circle(Vector2.ZERO, radius, accent)
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1, 1, 1, 0.9))

func _draw_fireball() -> void:
	# Vệt mờ đa lớp
	for i in range(_trail.size()):
		var local := to_local(_trail[i])
		var f := float(i) / float(TRAIL_MAX)
		var a := (1.0 - f) * 0.45
		var rr := radius * (1.2 - f * 0.7)
		draw_circle(local, rr * 1.4, Color(1.0, 0.35, 0.08, a * 0.35))
		draw_circle(local, rr, Color(1.0, 0.55, 0.2, a))
	var pulse := 0.9 + sin(Time.get_ticks_msec() * 0.02) * 0.1
	# Quầng lửa ngoài cùng
	draw_circle(Vector2.ZERO, radius * 2.0 * pulse, Color(1.0, 0.25, 0.08, 0.14))
	draw_circle(Vector2.ZERO, radius * 1.5 * pulse, Color(1.0, 0.45, 0.15, 0.28))
	draw_circle(Vector2.ZERO, radius * pulse, Color("ff8c3a"))
	draw_circle(Vector2.ZERO, radius * 0.65 * pulse, Color("ffd24a"))
	draw_circle(Vector2.ZERO, radius * 0.32, Color(1, 1, 1, 0.92))
	# Lưỡi lửa nhỏ quanh viên cầu
	var t := Time.get_ticks_msec() * 0.005
	for i in range(5):
		var a := TAU * float(i) / 5.0 + t
		var p := Vector2(cos(a), sin(a)) * radius * 0.85
		var flicker := 0.7 + 0.3 * sin(t * 3.0 + i)
		draw_circle(p, radius * 0.35 * flicker, Color(1.0, 0.5, 0.15, 0.55 * flicker))

func _draw_firewall() -> void:
	# Vùng lửa: nền mờ + các lưỡi lửa nhấp nhô.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.4, 0.1, 0.16))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.55), 2.0, true)
	var t := Time.get_ticks_msec() * 0.004
	var n := 14
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var rr := radius * (0.55 + 0.4 * absf(sin(t + float(i) * 1.3)))
		var p := Vector2(cos(a), sin(a)) * rr
		var h := 6.0 + 5.0 * absf(sin(t * 1.4 + float(i)))
		var col := Color(1.0, 0.6 + 0.2 * sin(t + float(i)), 0.15, 0.8)
		draw_circle(p, h * 0.5, col)

func _draw_shadow_bolt() -> void:
	for i in range(_trail.size()):
		var local := to_local(_trail[i])
		var a := (1.0 - float(i) / float(TRAIL_MAX)) * 0.4
		draw_circle(local, radius * 0.8, Color(0.66, 0.33, 0.97, a))
	draw_circle(Vector2.ZERO, radius * 1.3, Color(0.66, 0.33, 0.97, 0.3))
	draw_circle(Vector2.ZERO, radius, Color("a855f7"))
	draw_circle(Vector2.ZERO, radius * 0.45, Color("e9d5ff"))

func _draw_slash() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.9
	var base := direction.angle()
	draw_arc(Vector2.ZERO, radius, base - 0.7, base + 0.7, 18,
		Color(accent.r, accent.g, accent.b, a), 5.0, true)

## Vùng thời gian nứt vỡ của Thời Sư: mặt đồng hồ trên đất.
##
## Vòng ngoài + vạch phút + hai kim quay NGƯỢC chiều + hạt cát rơi vào tâm.
## Kim quay ngược là chi tiết báo hiệu "thời gian ở đây trôi sai chiều".
func _draw_time_rift() -> void:
	var t := life
	# Vòng ngoài: hai lớp.
	draw_circle(Vector2.ZERO, radius, Color(accent.r, accent.g, accent.b, 0.07))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56,
		Color(accent.r, accent.g, accent.b, 0.55), 2.4, true)
	draw_arc(Vector2.ZERO, radius * 0.88, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, 0.3), 1.6, true)
	# 12 vạch phút quanh mặt đồng hồ.
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var long := i % 3 == 0
		var r0 := radius * 0.80
		var r1 := radius * (0.90 if long else 0.86)
		draw_line(Vector2(cos(a), sin(a)) * r0, Vector2(cos(a), sin(a)) * r1,
			Color(1, 1, 1, 0.4 if long else 0.22), 1.8 if long else 1.2, true)
	# Kim phút quay ngược (chậm), kim giờ quay ngược (nhanh gấp đôi cảm giác).
	var minute := -t * 1.5
	var hour := -t * 0.5 + 2.1
	draw_line(Vector2.ZERO, Vector2(cos(minute), sin(minute)) * radius * 0.68,
		Color(1, 0.95, 0.9, 0.75), 2.2, true)
	draw_line(Vector2.ZERO, Vector2(cos(hour), sin(hour)) * radius * 0.42,
		Color(1, 0.85, 0.8, 0.6), 2.6, true)
	draw_circle(Vector2.ZERO, 3.4, Color(1, 1, 1, 0.85))
	# Hạt cát thời gian rơi vào tâm theo vòng xoắn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 86420
	for i in range(7):
		var phase := fposmod(t * 0.7 + float(i) / 7.0, 1.0)
		var aa := phase * TAU * 2.0 + float(i) * 1.3
		var rr := radius * (1.0 - phase) * 0.8
		var p := Vector2(cos(aa), sin(aa)) * rr
		draw_circle(p, 2.2 * (1.0 - phase * 0.5),
			Color(accent.r, accent.g, accent.b, 0.5 * (1.0 - phase)))

## Sóng xung kích mặt đồng hồ: vòng lan ra với vạch khắc chạy theo, kim quét.
func _draw_clock_nova() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.9
	# Vòng lan ra.
	var wave := radius * (0.25 + t * 0.75)
	draw_arc(Vector2.ZERO, wave, 0.0, TAU, 64,
		Color(accent.r, accent.g, accent.b, a * 0.8), 3.2, true)
	draw_arc(Vector2.ZERO, wave * 0.82, 0.0, TAU, 56,
		Color(1, 1, 1, a * 0.5), 1.6, true)
	# Vạch khắc xoay cùng lúc vòng lan.
	for i in range(12):
		var an := TAU * float(i) / 12.0 + t * 1.2
		var p1 := Vector2(cos(an), sin(an)) * wave * 0.9
		var p2 := Vector2(cos(an), sin(an)) * wave * 1.04
		draw_line(p1, p2, Color(accent.r, accent.g, accent.b, a * 0.7), 2.0, true)
	# Kim đồng hồ quét một vòng trong lúc nổ.
	var sweep := -t * TAU * 1.5
	draw_line(Vector2.ZERO, Vector2(cos(sweep), sin(sweep)) * wave * 0.95,
		Color(1, 1, 1, a * 0.65), 2.4, true)
	# Lõi sáng tâm.
	draw_circle(Vector2.ZERO, radius * 0.12 * (1.0 - t), Color(1, 1, 1, a * 0.9))

## Vệt roi quất: cung dày quét nhanh theo hướng, kèm tia lửa đầu roi.
##
## Roi quất là đòn đánh thường của Chủ Ưng nên phải thấy RÕ: ba lớp cung
## (quầng, thân, lõi trắng) + chớp sáng ở đầu mút + vài hạt bụi văng.
func _draw_whip_lash() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.95
	var base := direction.angle()
	# Cung quét mở dần theo tiến độ — như roi đang quét ngang đất.
	var spread := 0.55 + t * 0.25
	var sweep_start := base - spread
	var sweep_end := base + spread
	# Quầng ngoài mờ
	draw_arc(Vector2.ZERO, radius * 1.08, sweep_start, sweep_end, 22,
		Color(accent.r, accent.g, accent.b, a * 0.30), radius * 0.22, true)
	# Thân roi: cung dày
	draw_arc(Vector2.ZERO, radius, sweep_start, sweep_end, 22,
		Color(accent.r, accent.g, accent.b, a), radius * 0.14, true)
	# Lõi trắng mảnh
	draw_arc(Vector2.ZERO, radius * 0.92, sweep_start + 0.1, sweep_end - 0.1, 18,
		Color(1, 1, 1, a * 0.85), radius * 0.05, true)
	# Đầu roi: chớp sáng chạy dọc cung theo thời gian.
	var tip_a := sweep_start + (sweep_end - sweep_start) * clampf(t * 1.4, 0.0, 1.0)
	var tip := Vector2(cos(tip_a), sin(tip_a)) * radius
	draw_circle(tip, radius * 0.10 * (1.0 - t * 0.4), Color(1, 1, 1, a))
	draw_circle(tip, radius * 0.05, Color(accent.r, accent.g, accent.b, a))
	# Bụi đất văng sau đầu roi.
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	for i in range(4):
		var aa := tip_a + rng.randf_range(-0.3, 0.3)
		var dd := radius * rng.randf_range(0.95, 1.18)
		var p := Vector2(cos(aa), sin(aa)) * dd
		draw_circle(p, radius * rng.randf_range(0.03, 0.07),
			Color(0.9, 0.85, 0.7, a * 0.5))

func _draw_explosion() -> void:
	var t := 1.0 - clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
	var a := (1.0 - t) * 0.85
	# Sóng xung kích mở rộng
	var wave_r := radius * (0.3 + t * 0.7)
	draw_arc(Vector2.ZERO, wave_r, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, a * 0.55), 3.0, true)
	draw_circle(Vector2.ZERO, radius * t, Color(accent.r, accent.g, accent.b, a * 0.25))
	# Vòng trong sáng
	draw_arc(Vector2.ZERO, radius * 0.65 * t, 0.0, TAU, 32,
		Color(1.0, 0.92, 0.75, a * 0.8), 2.8, true)
	# Các tia bắn ra từ tâm
	var rng := RandomNumberGenerator.new()
	rng.seed = 13579
	for i in range(10):
		var angle := rng.randf_range(0.0, TAU)
		var inner := radius * 0.15 * t
		var outer := radius * (0.5 + rng.randf() * 0.5) * t
		var p1 := Vector2(cos(angle), sin(angle)) * inner
		var p2 := Vector2(cos(angle), sin(angle)) * outer
		draw_line(p1, p2, Color(accent.r, accent.g, accent.b, a * 0.7), 2.2, true)
