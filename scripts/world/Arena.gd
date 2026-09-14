class_name Arena
extends Node2D
## Đấu trường: hình học sân, vật cản, và nơi quản lý mọi thực thể đang sống
## (tướng, đạn, hiệu ứng).
##
## Arena KHÔNG biết gì về mạng hay luật chơi. Nó chỉ trả lời được câu hỏi
## "chỗ này có đi được không" và "có những ai đang ở đây". Nhờ vậy tầng luật
## chơi (Game.gd) có thể đổi mà không phải sửa đấu trường.

const PLAY_SIZE := Vector2(1750.0, 1180.0)
const WALL_MARGIN := 26.0

## Phát ra mỗi khi có hiệu ứng hình ảnh mới. Tầng mạng bắt tín hiệu này để
## chuyển tiếp sang máy khách, vì hiệu ứng không nằm trong snapshot trạng thái.
signal effect_spawned(config: Dictionary)

var bounds := Rect2()
var obstacles: Array[Rect2] = []

var entities: Node2D      # nơi chứa tướng + vật cản, bật y-sort
var fx: Node2D            # hiệu ứng nằm trên cùng

var champions: Array[Champion] = []
var projectiles: Array[Projectile] = []
var _next_projectile_id := 1

## Giới hạn số hiệu ứng cùng lúc để không tụt khung hình trên điện thoại.
const MAX_PROJECTILES := 140

## Loại bản đồ. Game đặt trước khi add_child.
var map_type: int = GameData.MapType.CLASSIC

# --- Lava Rift ---
var lava_cracks: Array[Rect2] = []
var _lava_tick_accum := 0.0

# --- Storm Eye ---
var storm_center := Vector2.ZERO
var storm_radius := 0.0
var storm_max_radius := 0.0
var storm_shrink_delay := 12.0
var storm_shrink_timer := 0.0
var storm_shrinking := false
var storm_shrink_speed := 28.0
var storm_damage_accum := 0.0
var storm_damage_rate := 2.2

# --- Ambient particles ---
var _ambient_timer := 0.0

func _ready() -> void:
	z_index = -10
	bounds = Rect2(-PLAY_SIZE * 0.5, PLAY_SIZE)
	_build_obstacles()
	_build_map_specific()

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_index = 5
	add_child(fx)

	for r in obstacles:
		var o := Obstacle.new()
		o.name = "Obstacle"
		o.setup(r)
		entities.add_child(o)

	queue_redraw()

func _build_map_specific() -> void:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			_build_lava_cracks()
		GameData.MapType.STORM_EYE:
			_reset_storm()

func _build_lava_cracks() -> void:
	# Vết nứt ngẫu nhiên nhưng seed cố định để hai máy giống nhau.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260913
	for i in range(7):
		var w := rng.randf_range(80.0, 260.0)
		var h := rng.randf_range(16.0, 34.0)
		var x := rng.randf_range(bounds.position.x + 60.0, bounds.end.x - 60.0 - w)
		var y := rng.randf_range(bounds.position.y + 60.0, bounds.end.y - 60.0 - h)
		lava_cracks.append(Rect2(x, y, w, h))

func _reset_storm() -> void:
	storm_center = Vector2.ZERO
	storm_max_radius = maxf(PLAY_SIZE.x, PLAY_SIZE.y) * 0.75
	storm_radius = storm_max_radius
	storm_shrink_delay = 12.0
	storm_shrink_timer = 0.0
	storm_shrinking = false
	storm_damage_accum = 0.0

func _build_obstacles() -> void:
	# Bố cục đối xứng để không ai có lợi thế về địa hình.
	# Toạ độ tính từ tâm sân.
	var defs: Array[Rect2] = []
	match map_type:
		GameData.MapType.FROZEN_LAKE:
			# Hồ băng: ít vật cản hơn, chỉ có mấy tảng băng trôi nhỏ.
			defs = [
				Rect2(-260, -180, 70, 70),
				Rect2(190, -180, 70, 70),
				Rect2(-260, 110, 70, 70),
				Rect2(190, 110, 70, 70),
				Rect2(-50, -300, 100, 60),
				Rect2(-50, 240, 100, 60),
			]
		GameData.MapType.STORM_EYE:
			# Mắt bão: vật cản thưa hơn để di chuyển xung quanh vùng an toàn.
			defs = [
				Rect2(-420, -260, 100, 100),
				Rect2(320, -260, 100, 100),
				Rect2(-420, 160, 100, 100),
				Rect2(320, 160, 100, 100),
			]
		_:
			# Cổ điển + Lava: bố cục đầy đủ.
			defs = [
				Rect2(-470, -300, 120, 120),
				Rect2(350, -300, 120, 120),
				Rect2(-470, 180, 120, 120),
				Rect2(350, 180, 120, 120),
				Rect2(-70, -450, 140, 90),
				Rect2(-70, 360, 140, 90),
			]
	for d in defs:
		obstacles.append(d)

## Hệ số ma sát mặt đất. Champion hỏi tầng này để điều chỉnh vận tốc.
func get_friction_mult() -> float:
	if map_type == GameData.MapType.FROZEN_LAKE:
		return 0.06
	return 1.0

# ------------------------------------------------------------------ truy vấn

func champions_list() -> Array[Champion]:
	return champions

func enemies_of(who: Champion) -> Array[Champion]:
	var out: Array[Champion] = []
	for c in champions:
		if c != who:
			out.append(c)
	return out

func arena_center() -> Vector2:
	return Vector2.ZERO

func spawn_points() -> Array[Vector2]:
	return [Vector2(-620, 0), Vector2(620, 0)]

## Kẹp một vị trí vào trong sân, chừa lại `radius` để thân tướng không lòi ra
## ngoài mép. Dùng cho cả việc giữ tướng trong sân lẫn việc kẹp điểm đặt chiêu.
func clamp_position(pos: Vector2, radius: float = 0.0) -> Vector2:
	var inner := bounds.grow(-radius)
	# Sân nhỏ hơn hai lần bán kính thì `grow` cho ra hình lộn ngược — kẹp về tâm.
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return bounds.get_center()
	return Vector2(
		clampf(pos.x, inner.position.x, inner.end.x),
		clampf(pos.y, inner.position.y, inner.end.y))

## Vị trí này có nằm trong sân không (đã trừ bán kính thân)?
func is_inside(pos: Vector2, radius: float = 0.0) -> bool:
	return bounds.grow(-radius).has_point(pos)

## Khoảng cách ngắn nhất từ một điểm tới mép sân. Số âm nghĩa là đang ở ngoài.
func distance_to_edge(pos: Vector2) -> float:
	var inner := bounds.grow(-1.0)
	var dx := minf(pos.x - inner.position.x, inner.end.x - pos.x)
	var dy := minf(pos.y - inner.position.y, inner.end.y - pos.y)
	return minf(dx, dy)

## Chỗ này có bị chặn không (tường ngoài, vật cản tĩnh, hoặc tường do kỹ năng tạo)?
##
## Lưu ý: các vùng đứng yên (is_zone) không tự gọi hàm này, nên Tường Đá không
## chặn chính nó.
func is_blocked_at(pos: Vector2, radius: float = 0.0) -> bool:
	if not bounds.grow(-radius).has_point(pos):
		return true
	for r in obstacles:
		if r.grow(radius).has_point(pos):
			return true
	for p in projectiles:
		if is_instance_valid(p) and p.blocks_movement and not p.is_dead():
			if p.position.distance_to(pos) < p.radius + radius:
				return true
	return false

# ------------------------------------------------------------------ sinh vật

func spawn_projectile(owner: Champion, config: Dictionary) -> Projectile:
	if projectiles.size() >= MAX_PROJECTILES:
		# Dọn bớt cái cũ nhất thay vì để tràn bộ nhớ.
		var oldest: Projectile = projectiles.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var p := Projectile.new()
	p.id = _next_projectile_id
	_next_projectile_id += 1
	p.owner_peer = owner.peer_id if owner != null else 0
	p.kind = config.get("kind", &"fireball")
	p.direction = config.get("direction", Vector2.RIGHT)
	p.speed = config.get("speed", 520.0)
	p.damage = config.get("damage", 0.0)
	p.radius = config.get("radius", 9.0)
	# Nội tại có thể nới rộng mọi vùng ảnh hưởng (Không Gian Vặn của Hư Không
	# Pháp Sư). Nhân ở đây là chỗ duy nhất áp được cho cả 25 chiêu hiện có.
	if owner != null and owner.area_multiplier != 1.0:
		p.radius *= owner.area_multiplier
	p.max_life = config.get("life", 2.0)
	p.life = p.max_life
	p.status_id = config.get("status_id", &"")
	p.status_stacks = config.get("status_stacks", 0)
	p.status_duration = config.get("status_duration", 4.0)
	p.status_max_stacks = config.get("status_max_stacks", 10)
	p.tick_damage = config.get("tick_damage", 0.0)
	p.tick_interval = config.get("tick_interval", 0.4)
	p.pierce_left = config.get("pierce_left", 0)
	p.power = config.get("power", 0.0)
	p.grow = config.get("grow", false)
	p.grow_to = config.get("grow_to", p.radius)
	p.is_zone = config.get("is_zone", false)
	p.accent = config.get("accent", Color.WHITE)
	p.burns_stacks = config.get("burns_stacks", false)
	p.owner_status_bonus = config.get("owner_status_bonus", &"")
	p.chain_radius = config.get("chain_radius", 0.0)
	p.chain_damage = config.get("chain_damage", 0.0)
	p.chain_requires = config.get("chain_requires", &"")
	p.chain_status = config.get("chain_status", &"")
	p.blocks_movement = config.get("blocks_movement", false)
	p.pull_strength = config.get("pull_strength", 0.0)
	p.pull_radius = config.get("pull_radius", 0.0)
	p.chase_speed = config.get("chase_speed", 0.0)
	# Hút máu của đạn (Huyết Bá): chỉ hồi khi sát thương thực sự trúng người,
	# không tính những phát bị khiên chặn — Projectile tự lo phần đó.
	p.lifesteal = config.get("lifesteal", 0.0)
	p.position = config.get("position", owner.global_position if owner != null else Vector2.ZERO)
	p.z_index = 3

	entities.add_child(p)
	projectiles.append(p)
	return p

## Hiệu ứng thuần hình ảnh (không gây sát thương).
func spawn_effect(config: Dictionary) -> Projectile:
	var e := Projectile.new()
	e.id = _next_projectile_id
	_next_projectile_id += 1
	e.owner_peer = 0
	e.kind = config.get("kind", &"explosion")
	e.direction = config.get("direction", Vector2.RIGHT)
	e.speed = 0.0
	e.damage = 0.0
	e.is_zone = true          # đứng yên, không va chạm
	e.radius = config.get("radius", 30.0)
	e.max_life = config.get("life", 0.35)
	e.life = e.max_life
	e.accent = config.get("accent", Color.WHITE)
	e.tick_damage = 0.0
	e.tick_interval = 999.0   # không bao giờ tick
	e.position = config.get("position", Vector2.ZERO)
	e.z_index = 4

	# Hiệu ứng chỉ để nhìn — tắt mô phỏng va chạm.
	e.set_meta("visual_only", true)
	fx.add_child(e)
	projectiles.append(e)
	# Báo cho tầng mạng để chuyển tiếp sang máy khách.
	effect_spawned.emit(config)
	return e

## Tạo đạn phía máy khách từ dữ liệu host gửi xuống. Không mô phỏng, chỉ vẽ.
func client_spawn_from_network(data: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.id = int(data.get("i", 0))
	p.simulate = false
	p.kind = StringName(str(data.get("k", "fireball")))
	p.radius = float(data.get("r", 9.0))
	p.accent = Color.html(str(data.get("c", "ffffff")))
	p.is_zone = bool(data.get("z", false))
	p.life = 9999.0
	p.max_life = 9999.0
	p.tick_interval = 9999.0
	p.tick_damage = 0.0
	p.damage = 0.0
	p.position = data.get("p", Vector2.ZERO)
	p.z_index = 3
	entities.add_child(p)
	projectiles.append(p)
	return p

## Đồng bộ danh sách đạn theo snapshot: thêm cái mới, cập nhật cái cũ, xoá cái
## không còn. Dùng cho máy khách.
func sync_client_projectiles(list: Array) -> void:
	var alive := {}
	for data in list:
		if not (data is Dictionary):
			continue
		var id := int(data.get("i", 0))
		alive[id] = true
		var found: Projectile = null
		for p in projectiles:
			if is_instance_valid(p) and p.id == id:
				found = p
				break
		if found == null:
			found = client_spawn_from_network(data)
		found.apply_network_state(data)

	# Xoá những đạn host không còn gửi nữa (đã trúng hoặc hết hạn).
	var i := projectiles.size() - 1
	while i >= 0:
		var p := projectiles[i]
		if not is_instance_valid(p):
			projectiles.remove_at(i)
		elif not p.get_meta("visual_only", false) and not alive.has(p.id):
			p.queue_free()
			projectiles.remove_at(i)
		i -= 1

func spawn_hit_spark(pos: Vector2, color: Color) -> void:
	spawn_effect({
		"kind": &"explosion",
		"position": pos,
		"radius": 14.0,
		"life": 0.16,
		"accent": color,
	})

## Hạt bắn tung khi tướng chết — hiệu ứng điện ảnh.
func spawn_death_burst(pos: Vector2, color: Color) -> void:
	spawn_effect({
		"kind": &"death_burst",
		"position": pos,
		"radius": 42.0,
		"life": 0.55,
		"accent": color,
	})

## Bụi nhỏ phía sau chân khi tướng chạy.
func spawn_footstep_dust(pos: Vector2, color: Color) -> void:
	spawn_effect({
		"kind": &"dust",
		"position": pos,
		"radius": 9.0,
		"life": 0.28,
		"accent": color,
	})

# ------------------------------------------------------------------ mô phỏng

## Chỉ host gọi hàm này.
func step(delta: float) -> void:
	# 1. Cho từng viên đạn tiến lên. Viên nào hết đời thì đánh dấu chết.
	for p in projectiles:
		if not is_instance_valid(p) or p.is_dead():
			continue
		if p.get_meta("visual_only", false):
			# Hiệu ứng hình ảnh: chỉ đếm ngược thời gian sống.
			p.life -= delta
			if p.life <= 0.0:
				p.kill()
			continue
		if not p.step(delta, self):
			p.kill()

	# 2. Giải quyết va chạm đạn-đạn. Làm sau khi tất cả đã di chuyển để hai
	#    viên bay ngược chiều nhau trong cùng khung hình vẫn gặp được nhau.
	_resolve_clashes()

	# 3. Dọn những viên đã chết.
	var i := projectiles.size() - 1
	while i >= 0:
		var p := projectiles[i]
		if not is_instance_valid(p) or p.is_dead():
			if is_instance_valid(p):
				p.queue_free()
			projectiles.remove_at(i)
		i -= 1

	# 4. Cơ chế bản đồ (lava, bão, v.v.)
	_step_map_mechanics(delta)

	# Bản đồ có hiệu ứng động (bão thu hẹp, lava nhấp nháy) cần vẽ lại.
	if map_type == GameData.MapType.LAVA_RIFT or map_type == GameData.MapType.STORM_EYE:
		queue_redraw()

## Cơ chế đặc biệt của từng bản đồ: lava, băng trơn, bão, v.v.
func _step_map_mechanics(delta: float) -> void:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			_step_lava(delta)
		GameData.MapType.STORM_EYE:
			_step_storm(delta)
	# Hạt môi trường: spawn định kỳ cho từng bản đồ.
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = 0.18
		_spawn_ambient_particle()

func _step_lava(delta: float) -> void:
	_lava_tick_accum += delta
	if _lava_tick_accum < 0.5:
		return
	_lava_tick_accum = 0.0
	for c in champions:
		if not c.is_alive():
			continue
		for r in lava_cracks:
			if r.has_point(c.global_position):
				c.take_damage(3.5, 0)
				c.add_status(GameData.ST_BURN, 1, 3.0, 0, 8)
				break

func _step_storm(delta: float) -> void:
	if not storm_shrinking:
		storm_shrink_timer += delta
		if storm_shrink_timer >= storm_shrink_delay:
			storm_shrinking = true
	else:
		storm_radius = maxf(80.0, storm_radius - storm_shrink_speed * delta)

	# Gây sát thương cho ai ngoài vùng an toàn.
	storm_damage_accum += delta
	if storm_damage_accum >= 1.0:
		storm_damage_accum = 0.0
		var dmg := 4.0 + (storm_max_radius - storm_radius) * 0.025
		for c in champions:
			if not c.is_alive():
				continue
			if c.global_position.distance_to(storm_center) > storm_radius:
				c.take_damage(dmg, 0)
				# Hiệu ứng sét nhỏ.
				spawn_effect({
					"kind": &"explosion",
					"position": c.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
					"radius": 18.0,
					"life": 0.18,
					"accent": Color("c4b5fd"),
				})

## Hạt môi trường nền: tuyết, tro bụi, mưa nhẹ tuỳ bản đồ.
func _spawn_ambient_particle() -> void:
	var b := bounds
	var pos := Vector2(
		randf_range(b.position.x, b.end.x),
		randf_range(b.position.y, b.end.y))
	match map_type:
		GameData.MapType.LAVA_RIFT:
			# Tia lửa cam bay lên rồi tắt.
			spawn_effect({
				"kind": &"ember",
				"position": pos,
				"radius": 3.0 + randf() * 3.0,
				"life": 0.4 + randf() * 0.5,
				"accent": Color(1.0, 0.45 + randf() * 0.35, 0.1, 0.7),
			})
		GameData.MapType.FROZEN_LAKE:
			# Bông tuyết trắng rơi chậm.
			spawn_effect({
				"kind": &"snow",
				"position": pos,
				"radius": 2.0 + randf() * 2.5,
				"life": 1.2 + randf() * 1.0,
				"accent": Color(0.85, 0.92, 1.0, 0.55 + randf() * 0.25),
			})
		GameData.MapType.STORM_EYE:
			# Mưa nhỏ hoặc giọt nước mờ.
			spawn_effect({
				"kind": &"rain",
				"position": pos,
				"radius": 1.5 + randf() * 1.5,
				"life": 0.35 + randf() * 0.3,
				"accent": Color(0.6, 0.75, 0.9, 0.35 + randf() * 0.2),
			})

## Đặt lại cơ chế bản đồ cho ván mới.
func reset_for_round() -> void:
	match map_type:
		GameData.MapType.STORM_EYE:
			_reset_storm()
	queue_redraw()

## Một viên đạn có tham gia đối đầu không?
func _clashable(p: Projectile) -> bool:
	return is_instance_valid(p) and not p.is_dead() and not p.is_zone \
		and not p.get_meta("visual_only", false) and p.power > 0.0

## Hai viên đạn của hai phe chạm nhau: bên mạnh hơn đập vỡ bên yếu hơn, nhưng
## bị tiêu hao tầm bay tương ứng với sức mạnh của viên kia.
##
## Đây là chỗ tạo ra chiều sâu chiến thuật: bắn một viên yếu vào viên mạnh của
## đối thủ không phá được nó, nhưng đủ để nó hết tầm trước khi tới chỗ bạn.
func _resolve_clashes() -> void:
	var n := projectiles.size()
	for i in range(n):
		var a := projectiles[i]
		if not _clashable(a):
			continue
		for j in range(i + 1, n):
			var b := projectiles[j]
			if not _clashable(b) or a.owner_peer == b.owner_peer:
				continue
			var reach := a.radius + b.radius
			if a.position.distance_squared_to(b.position) > reach * reach:
				continue
			_clash(a, b)
			if a.is_dead():
				break

func _clash(a: Projectile, b: Projectile) -> void:
	var midpoint := (a.position + b.position) * 0.5

	# Ngang sức: cả hai cùng vỡ, không bên nào có lợi.
	if is_equal_approx(a.power, b.power):
		a.kill()
		b.kill()
		_spawn_clash_fx(midpoint, Color("ffe08a"), 34.0)
		Audio.play_at(&"clash", midpoint)
		return

	var winner := a if a.power > b.power else b
	var loser := b if a.power > b.power else a

	# Tầm bay bị rút bớt: viên yếu càng mạnh (so với viên thắng) thì viên thắng
	# càng mất nhiều tầm. Tỉ lệ 0.25 - 0.80 để luôn thấy rõ hệ quả.
	var ratio := clampf(loser.power / maxf(winner.power, 0.001), 0.0, 1.0)
	var drained: float = winner.max_life * (0.25 + 0.55 * ratio)
	winner.life = maxf(winner.life - drained, 0.02)
	# Bản thân viên thắng cũng yếu đi, nên lần đối đầu sau sẽ bất lợi hơn.
	winner.power = maxf(winner.power - loser.power * 0.5, 0.1)
	loser.kill()

	_spawn_clash_fx(midpoint, winner.accent, 30.0 + 14.0 * ratio)
	Audio.play_at(&"clash_win", midpoint)
	Audio.play_at(&"clash_lose", loser.position, -4.0)

func _spawn_clash_fx(pos: Vector2, color: Color, radius: float) -> void:
	spawn_effect({
		"kind": &"explosion",
		"position": pos,
		"radius": radius,
		"life": 0.28,
		"accent": color,
	})

## Danh sách đạn rút gọn để nhét vào snapshot mạng.
func projectile_snapshot() -> Array:
	var out: Array = []
	for p in projectiles:
		if is_instance_valid(p) and not p.get_meta("visual_only", false):
			out.append(p.network_state())
	return out

func clear_projectiles() -> void:
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()

# ------------------------------------------------------------------ hiển thị

func _map_edge_color() -> Color:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			return Color(1.0, 0.22, 0.10)
		GameData.MapType.FROZEN_LAKE:
			return Color(0.25, 0.65, 1.0)
		GameData.MapType.STORM_EYE:
			return Color(0.55, 0.35, 1.0)
	return Color(1.0, 0.42, 0.12)

func _map_ground_colors() -> Array[Color]:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			return [Color("1a0f0f"), Color("261a1a")]
		GameData.MapType.FROZEN_LAKE:
			return [Color("0f141a"), Color("141d26")]
		GameData.MapType.STORM_EYE:
			return [Color("120f1a"), Color("1a1626")]
	return [Color("100f16"), Color("1b1a26")]

func _draw() -> void:
	var edge := _map_edge_color()
	var ground := _map_ground_colors()

	# Viền phát sáng quanh sân — màu thay đổi theo bản đồ.
	_rounded_rect(bounds.grow(26.0), 72.0, Color(edge.r, edge.g, edge.b, 0.05))
	_rounded_rect(bounds.grow(14.0), 62.0, Color(edge.r, edge.g, edge.b, 0.10))
	_rounded_rect(bounds.grow(6.0), 54.0, Color(edge.r, edge.g, edge.b, 0.18))

	# Mặt sân hai lớp để có chiều sâu.
	_rounded_rect(bounds, 48.0, ground[0])
	_rounded_rect(bounds.grow(-12.0), 42.0, ground[1])

	# Lát gạch kim cương isometric: mảng sáng/tối xen kẽ tạo cảm giác 2.5D.
	_draw_iso_tiles(ground)

	# Đáy bệ dày phía dưới mép sân — cả đấu trường như một bục đá nổi.
	_draw_platform_skirt(edge)

	# Lưới mờ: giúp ước lượng khoảng cách và tốc độ khi di chuyển.
	var grid := 140.0
	var inset := 40.0
	var gx := bounds.position.x + inset
	while gx < bounds.end.x - inset:
		draw_line(Vector2(gx, bounds.position.y + inset), Vector2(gx, bounds.end.y - inset),
			Color(1, 1, 1, 0.022), 1.0)
		gx += grid
	var gy := bounds.position.y + inset
	while gy < bounds.end.y - inset:
		draw_line(Vector2(bounds.position.x + inset, gy), Vector2(bounds.end.x - inset, gy),
			Color(1, 1, 1, 0.022), 1.0)
		gy += grid

	# Mảng sáng/tối cố định để mặt sân đỡ trơn. Seed cố định nên hai máy luôn
	# vẽ ra y hệt nhau — quan trọng vì đây là game mạng.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	for i in range(54):
		var w := rng.randf_range(80.0, 230.0)
		var h := rng.randf_range(60.0, 180.0)
		var x := rng.randf_range(bounds.position.x + 30.0, bounds.end.x - 30.0 - w)
		var y := rng.randf_range(bounds.position.y + 30.0, bounds.end.y - 30.0 - h)
		var light := rng.randf() > 0.5
		var col := Color(1.0, 0.85, 0.7, 0.020) if light else Color(0, 0, 0, 0.09)
		_rounded_rect(Rect2(x, y, w, h), 30.0, col)

	# Vạch chia giữa sân và vòng tròn tâm.
	draw_line(Vector2(0, bounds.position.y + inset), Vector2(0, bounds.end.y - inset),
		Color(1, 1, 1, 0.06), 2.0)
	draw_arc(Vector2.ZERO, 170.0, 0.0, TAU, 64, Color(1, 0.6, 0.3, 0.08), 6.0, true)
	draw_arc(Vector2.ZERO, 170.0, 0.0, TAU, 64, Color(1, 1, 1, 0.05), 2.0, true)

	_draw_map_specific()

## Gạch lát kim cương isometric trên toàn mặt sân.
##
## Mỗi viên là hình thoi 2:1, hai màu sáng/tối xen kẽ theo (ix+iy) chẵn lẻ —
## đúng cách các game isometric fake chiều sâu bằng 2D thuần. Kích thước viên
## lớn (150x75) để tổng số polygon giữ ở mức ~700, vẽ một lần nên không ảnh
## hưởng khung hình.
func _draw_iso_tiles(ground: Array[Color]) -> void:
	var tile_w := 150.0
	var tile_h := 75.0
	var inset := 34.0
	var light := Color(ground[1].r + 0.045, ground[1].g + 0.045, ground[1].b + 0.05, 1.0)
	var dark := Color(ground[0].r * 0.8, ground[0].g * 0.8, ground[0].b * 0.85, 1.0)
	var grout := Color(1, 1, 1, 0.035)

	# Duyệt theo trục iso: toạ độ thế giới = ((ix-iy)*w/2, (ix+iy)*h/2).
	var ix_min := -12
	var ix_max := 14
	var iy_min := -10
	var iy_max := 12
	for ix in range(ix_min, ix_max):
		for iy in range(iy_min, iy_max):
			var cx := (ix - iy) * (tile_w * 0.5)
			var cy := (ix + iy) * (tile_h * 0.5)
			# Bỏ viên nào rơi ngoài vùng sân (chừa mép inset).
			if cx < bounds.position.x + inset - tile_w \
					or cx > bounds.end.x - inset + tile_w \
					or cy < bounds.position.y + inset - tile_h \
					or cy > bounds.end.y - inset + tile_h:
				continue
			var pts := PackedVector2Array([
				Vector2(cx, cy - tile_h * 0.5),
				Vector2(cx + tile_w * 0.5, cy),
				Vector2(cx, cy + tile_h * 0.5),
				Vector2(cx - tile_w * 0.5, cy),
			])
			draw_colored_polygon(pts, light if (ix + iy) % 2 == 0 else dark)
			# Đường mạch gạch mảnh.
			draw_line(pts[0], pts[1], grout, 1.0)
			draw_line(pts[1], pts[2], grout, 1.0)

## Đáy bệ: dải tối dần chạy dọc mép dưới sân, làm sân như bục đá dày cỡ 2.5D.
func _draw_platform_skirt(edge: Color) -> void:
	var skirt_h := 22.0
	for i in range(6):
		var t := float(i) / 6.0
		var y := bounds.end.y + skirt_h * t
		var alpha := 0.55 * (1.0 - t) + 0.05
		var col := Color(0.02, 0.02, 0.04, alpha)
		draw_rect(Rect2(bounds.position.x - 26.0 + i * 3.0, y,
			bounds.size.x + 52.0 - i * 6.0, skirt_h / 6.0 + 1.0), col)
	# Viền sáng đáy cùng màu map — ánh sáng hắt từ viền sân xuống.
	draw_line(Vector2(bounds.position.x - 26.0, bounds.end.y + skirt_h),
		Vector2(bounds.end.x + 26.0, bounds.end.y + skirt_h),
		Color(edge.r, edge.g, edge.b, 0.16), 2.0)

func _draw_map_specific() -> void:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			_draw_lava()
		GameData.MapType.FROZEN_LAKE:
			_draw_ice()
		GameData.MapType.STORM_EYE:
			_draw_storm()

func _draw_lava() -> void:
	for r in lava_cracks:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003 + r.position.x * 0.01)
		var col := Color(1.0, 0.25, 0.08, 0.35 * pulse)
		_rounded_rect(r, 8.0, col)
		draw_rect(r, Color(1.0, 0.45, 0.15, 0.12), false, 1.5)

func _draw_ice() -> void:
	# Tô lớp băng xanh nhạt lên toàn sân.
	_rounded_rect(bounds.grow(-6.0), 44.0, Color(0.55, 0.85, 1.0, 0.04))
	# Vết nứt băng.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	for i in range(18):
		var x1 := rng.randf_range(bounds.position.x + 20.0, bounds.end.x - 20.0)
		var y1 := rng.randf_range(bounds.position.y + 20.0, bounds.end.y - 20.0)
		var x2 := x1 + rng.randf_range(-90.0, 90.0)
		var y2 := y1 + rng.randf_range(-90.0, 90.0)
		draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(0.75, 0.95, 1.0, 0.10), 1.2)

func _draw_storm() -> void:
	# Vòng an toàn.
	if storm_radius > 0.0:
		var alpha := 0.08 if storm_shrinking else 0.04
		draw_arc(storm_center, storm_radius, 0.0, TAU, 96,
			Color(0.6, 0.85, 1.0, alpha), 4.0, true)
		draw_arc(storm_center, storm_radius, 0.0, TAU, 96,
			Color(0.4, 0.7, 1.0, alpha * 1.5), 2.0, true)
		# Vạch cảnh báo bên ngoài vùng an toàn.
		var warn := 0.15 + 0.10 * sin(Time.get_ticks_msec() * 0.004)
		draw_arc(storm_center, storm_radius + 18.0, 0.0, TAU, 64,
			Color(1.0, 0.2, 0.2, warn), 2.0, true)

func _rounded_rect(rect: Rect2, radius: float, color: Color, segments: int = 6) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centers := [
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
	]
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	for i in range(4):
		for s in range(segments + 1):
			var a: float = starts[i] + (PI * 0.5) * float(s) / float(segments)
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
