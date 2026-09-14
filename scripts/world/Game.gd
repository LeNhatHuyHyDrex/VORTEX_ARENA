class_name Game
extends Node2D
## Bộ điều phối một trận đấu: dựng đấu trường, sinh tướng, chạy vòng đấu và
## đồng bộ mạng.
##
## Phân chia trách nhiệm:
##   Arena  — hình học sân và danh sách thực thể.
##   Game   — luật chơi, vòng đấu, ai mô phỏng, ai chỉ hiển thị.
##   Net    — chỉ lo vận chuyển gói tin, không biết gì về luật.

enum Phase { WAITING, COUNTDOWN, FIGHT, ROUND_END, MATCH_END }

## Menu chính ghi vào hai biến này trước khi chuyển cảnh sang Game.tscn.
## Dùng biến tĩnh vì Godot không có API truyền tham số khi đổi scene.
static var pending_mode: int = 0                              # 0 = SOLO
static var pending_champion: StringName = &"fire_mage"
static var pending_map: int = GameData.MapType.CLASSIC
static var pending_bot_difficulty: int = GameData.Difficulty.NORMAL
static var pending_enemy_champion: StringName = &"shadow_assassin"

const ROUNDS_TO_WIN := 3
const COUNTDOWN_TIME := 3.0
const ROUND_END_DELAY := 2.6
const SNAPSHOT_HZ := 60.0
## Thời gian chờ trước khi hồi sinh trong phòng luyện tập.
const RESPAWN_DELAY := 1.4

## Các mức zoom camera, đi từ xa tới gần. Người chơi cuộn chuột để đổi.
const ZOOM_LEVELS: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.05]
const ZOOM_DEFAULT_INDEX := 3
## Tốc độ nội suy zoom, để đổi mức không bị giật.
const ZOOM_LERP := 9.0

var mode: int = GameData.Mode.SOLO
var local_champion_id: StringName = &"fire_mage"
var enemy_champion_id: StringName = Game.pending_enemy_champion

var arena: Arena
var camera: Camera2D
var hud: HUD
var cast_indicator: CastIndicator
var touch: TouchControls = null
var pause_menu: PauseMenu = null
## Menu tạm đang mở hay không. Tách khỏi `get_tree().paused` vì chế độ LAN
## không được phép tạm dừng mô phỏng (sẽ lệch với máy kia), nhưng vẫn phải mở
## được menu để người chơi thoát ra.
var paused := false

var local_champ: Champion = null
var enemy_champ: Champion = null
var bot: BotBrain = null

var phase: int = Phase.COUNTDOWN
var phase_timer := COUNTDOWN_TIME
var scores := {1: 0, 2: 0}
var current_round := 1
var match_winner := 0
var status_message := ""

## Thống kê sau trận (chỉ tính cho ngườ chơi local).
var stats_damage_dealt := 0.0
var stats_max_combo := 0
var stats_rounds_won := 0
var _match_timer := 0.0

var _move := Vector2.ZERO
var _aim := Vector2.RIGHT
var _cast_accum := 0
## Điểm đặt chiêu đi kèm với `_cast_accum` trong cùng khung hình.
var _cast_target := Vector2.ZERO
var _shake := 0.0
## Hướng rung camera. Rung theo hướng đòn đánh cho cảm giác lực đẩy, thay vì
## rung ngẫu nhiên bốn phía như bản trước — mắt đọc ra được "đòn này từ bên phải".
var _shake_dir := Vector2.RIGHT
## Mốc thời gian thực (mili giây) kết thúc đợt dừng hình.
##
## Dùng đồng hồ thực chứ không dùng delta: hitstop hoạt động bằng cách hạ
## `Engine.time_scale`, mà delta lúc đó cũng bị hạ theo — đếm bằng delta thì
## không bao giờ thoát ra được.
var _hitstop_until_ms := 0
var _death_slowmo_until_ms := 0
var _snapshot_accum := 0.0
## Zoom thêm vào khi bắt đầu ván: camera bắt đầu gần hơn rồi từ từ lùi ra.
var _round_start_zoom_extra := 0.45

## Kéo ngón tay bao xa (pixel màn hình) thì chiêu với tới tầm xa tối đa.
## Con số này là cảm giác chơi chứ không phải toán: nhỏ quá thì khó điều khiển
## chính xác, lớn quá thì kéo mỏi tay mà vẫn không tới tầm.
const TOUCH_DRAG_FULL := 130.0

# ---------------------------------------------------- trạng thái chọn vùng chiêu

## Ô kỹ năng đang chờ người chơi chọn hướng/vùng. -1 = không chờ gì.
## Đây là trạng thái thuần giao diện: nó không đi qua mạng, chỉ đổi cách HUD vẽ
## và ý nghĩa của cú bấm chuột trái kế tiếp.
var armed_slot := -1
## Điểm trên mặt đất mà người chơi đang trỏ tới.
var armed_point := Vector2.ZERO
## Điểm đó có nằm trong tầm chiêu không (HUD tô đỏ khi ngoài tầm).
var armed_valid := true

## Mức zoom camera đang chọn (chỉ số trong ZOOM_LEVELS).
var zoom_index := ZOOM_DEFAULT_INDEX

func _ready() -> void:
	randomize()
	mode = pending_mode
	local_champion_id = pending_champion

	arena = Arena.new()
	arena.name = "Arena"
	arena.map_type = pending_map
	add_child(arena)
	Audio.play_map_ambient(pending_map)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	# Zoom nhẹ để tướng chiếm tỉ lệ hợp lý trên màn hình, không bị bé như hạt đậu.
	camera.zoom = Vector2(1.3, 1.3)
	add_child(camera)
	_setup_camera_limits()

	# HUD và điều khiển cảm ứng nằm trong CanvasLayer để không bị ảnh hưởng bởi
	# camera và không bao giờ lệch khỏi màn hình.
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	hud = HUD.new()
	hud.name = "HUD"
	hud.game = self
	ui.add_child(hud)

	# Vùng phạm vi chiêu nằm trong không gian thế giới (không phải trong HUD),
	# vì nó phải bám vào sân đấu và vào tướng chứ không bám vào màn hình.
	cast_indicator = CastIndicator.new()
	cast_indicator.name = "CastIndicator"
	cast_indicator.game = self
	add_child(cast_indicator)

	# Menu tạm nằm trong cùng CanvasLayer với HUD để luôn vẽ trên mọi thứ khác,
	# và ở trên cả CastIndicator.
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.game = self
	pause_menu.visible = false
	pause_menu.resumed.connect(func() -> void: set_paused(false))
	pause_menu.exit_requested.connect(exit_to_menu)
	ui.add_child(pause_menu)

	if Settings.show_touch_controls:
		touch = TouchControls.new()
		touch.name = "TouchControls"
		ui.add_child(touch)

	arena.effect_spawned.connect(_on_effect_spawned)
	Net.game_event.connect(_on_net_event)
	Net.snapshot_received.connect(_on_snapshot)
	Net.disconnected.connect(_on_peer_gone)

	_spawn_champions()
	# Chủ phòng phải đợi máy khách vào mới bắt đầu.
	if mode == GameData.Mode.HOST and Net.players.size() < 2:
		_enter_phase(Phase.WAITING)
	else:
		_enter_phase(Phase.COUNTDOWN)

# ------------------------------------------------------------------ dựng trận

func _spawn_champions() -> void:
	var spawns := arena.spawn_points()

	match mode:
		GameData.Mode.SOLO:
			local_champ = _make_champion(local_champion_id, 1, true, spawns[0])
			enemy_champ = _make_champion(enemy_champion_id, 2, false, spawns[1])
			bot = BotBrain.new(enemy_champ, Game.pending_bot_difficulty)
			status_message = "Luyện tập"
		GameData.Mode.HOST:
			local_champ = _make_champion(local_champion_id, 1, true, spawns[0])
			# Tướng của đối thủ do máy khách đăng ký; mặc định nếu chưa có.
			enemy_champ = _make_champion(enemy_champion_id, 2, false, spawns[1])
			status_message = "Đang chờ đối thủ vào phòng..."
		GameData.Mode.CLIENT:
			# Máy khách biết danh sách người chơi qua bản tin roster của host.
			var ids := Net.players.keys()
			ids.sort()
			var local_id := Net.local_id
			var foe_id := 0
			for id in ids:
				if id != local_id:
					foe_id = id
			if Net.players.has(local_id):
				local_champion_id = Net.players[local_id].get("champion", local_champion_id)
			if Net.players.has(foe_id):
				enemy_champion_id = Net.players[foe_id].get("champion", enemy_champion_id)
			local_champ = _make_champion(local_champion_id, local_id, true, spawns[0])
			enemy_champ = _make_champion(enemy_champion_id, foe_id, false, spawns[1])
			status_message = "Đã vào phòng"
		GameData.Mode.PRACTICE:
			# Phòng luyện tập: một mình, đối thủ là hình nộm hoặc bot tuỳ bảng bật/tắt.
			var ps := practice_spawn_points()
			local_champ = _make_champion(local_champion_id, 1, true, ps[0])
			enemy_champ = _make_champion(enemy_champion_id, 2, false, ps[1])
			bot = BotBrain.new(enemy_champ, Game.pending_bot_difficulty)
			status_message = "Phòng luyện tập"

	_apply_spawn_positions()
	_connect_hud_signals()

func _connect_hud_signals() -> void:
	if hud == null or local_champ == null:
		return
	# Kết nối signal damaged để HUD kích hoạt hiệu ứng flash màn hình.
	if not local_champ.damaged.is_connected(hud._on_local_damaged):
		local_champ.damaged.connect(hud._on_local_damaged)
	# Theo dõi đòn trúng vào đối thủ để đếm combo.
	if enemy_champ != null and not enemy_champ.damaged.is_connected(_on_enemy_damaged_for_combo):
		enemy_champ.damaged.connect(_on_enemy_damaged_for_combo)

func _on_enemy_damaged_for_combo(amount: float, source_peer: int) -> void:
	if source_peer == local_champ.peer_id:
		if hud != null:
			hud.register_hit()
			stats_max_combo = maxi(stats_max_combo, hud.get_combo())
		stats_damage_dealt += amount

func _make_champion(id: StringName, peer_id: int, is_local: bool, pos: Vector2) -> Champion:
	var c := Champion.new()
	c.name = "Champion_%d" % peer_id
	# configure() phải chạy TRƯỚC khi thêm vào cây, vì _ready() dùng body_radius
	# để dựng hình va chạm.
	c.configure(id, peer_id, is_local)
	c.global_position = pos
	c.world = arena
	c.damaged.connect(_on_champion_damaged.bind(c))
	c.died.connect(_on_champion_died)
	arena.entities.add_child(c)
	arena.champions.append(c)
	return c

func _apply_spawn_positions() -> void:
	var spawns := practice_spawn_points() if is_practice() else arena.spawn_points()
	if local_champ != null:
		local_champ.global_position = spawns[0]
	if enemy_champ != null:
		enemy_champ.global_position = spawns[1]

func _setup_camera_limits() -> void:
	var b := arena.bounds
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)

# ------------------------------------------------------------------- vòng đấu

func _enter_phase(p: int) -> void:
	phase = p
	match p:
		Phase.WAITING:
			phase_timer = 0.0
			current_round = 1
			scores = {1: 0, 2: 0}
			match_winner = 0
			stats_damage_dealt = 0.0
			stats_max_combo = 0
			stats_rounds_won = 0
		Phase.COUNTDOWN:
			phase_timer = COUNTDOWN_TIME
			status_message = "Chuẩn bị"
			_round_start_zoom_extra = 0.45
			if current_round == 1:
				_match_timer = 0.0
		Phase.FIGHT:
			phase_timer = 0.0
			status_message = "Đánh!"
		Phase.ROUND_END:
			phase_timer = ROUND_END_DELAY
		Phase.MATCH_END:
			phase_timer = 0.0
			if match_winner == local_champ.peer_id:
				_spawn_victory_fx()

func _update_phase(delta: float) -> void:
	# Chỉ host (và chế độ một máy) quyết định diễn biến ván đấu.
	if mode == GameData.Mode.CLIENT:
		return
	# Phòng luyện tập không có ván: luôn ở trạng thái đánh nhau, không đếm ngược,
	# không kết thúc hiệp. Đây là điều kiện duy nhất cần, nên chặn ngay ở đầu.
	if is_practice():
		phase = Phase.FIGHT
		phase_timer = 0.0
		return

	match phase:
		Phase.WAITING:
			if _both_players_present():
				_enter_phase(Phase.COUNTDOWN)
		Phase.COUNTDOWN:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_enter_phase(Phase.FIGHT)
		Phase.FIGHT:
			_match_timer += delta
			if _check_round_over():
				pass
		Phase.ROUND_END:
			phase_timer -= delta
			if phase_timer <= 0.0:
				if _match_finished():
					match_winner = 1 if int(scores.get(1, 0)) >= ROUNDS_TO_WIN else 2
					var name_ := _champion_name(match_winner)
					status_message = "%s thắng trận!" % name_
					_enter_phase(Phase.MATCH_END)
				else:
					_reset_round()
					_enter_phase(Phase.COUNTDOWN)

func _both_players_present() -> bool:
	return mode != GameData.Mode.HOST or Net.players.size() >= 2

func _check_round_over() -> bool:
	if local_champ == null or enemy_champ == null:
		return false
	if local_champ.is_alive() and enemy_champ.is_alive():
		return false
	# Ai còn sống thì thắng ván này.
	var winner := 0
	if local_champ.is_alive():
		winner = 1
	elif enemy_champ.is_alive():
		winner = 2
	else:
		winner = 0
	if winner != 0:
		scores[winner] = int(scores.get(winner, 0)) + 1
		if winner == local_champ.peer_id:
			stats_rounds_won += 1
	var name_ := "Không ai" if winner == 0 else _champion_name(winner)
	status_message = "%s thắng ván này" % name_
	_enter_phase(Phase.ROUND_END)
	return true

func _champion_name(slot: int) -> String:
	var c := local_champ if slot == 1 else enemy_champ
	return c.display_name if c != null else "?"

func _match_finished() -> bool:
	return int(scores.get(1, 0)) >= ROUNDS_TO_WIN or int(scores.get(2, 0)) >= ROUNDS_TO_WIN

func _reset_round() -> void:
	current_round += 1
	var spawns := arena.spawn_points()
	arena.clear_projectiles()
	arena.reset_for_round()
	if local_champ != null:
		local_champ.reset_for_round(spawns[0])
	if enemy_champ != null:
		enemy_champ.reset_for_round(spawns[1])

# ------------------------------------------------------------------ xử lý tick

func _physics_process(delta: float) -> void:
	if local_champ == null:
		return
	_poll_local_input()
	_update_phase(delta)

	match mode:
		GameData.Mode.CLIENT:
			# Máy khách chỉ gửi ý định lên host, không tự quyết định kết quả.
			Net.send_input(_move, _aim, _cast_accum)
			_cast_accum = 0
			# Máy khách không chạy step() nên tự chạy đồng hồ hoạt ảnh
			# (nhịp thở, cú vung vũ khí) để tướng không bị "đóng băng hình".
			if local_champ != null:
				local_champ.advance_visual_time(delta)
			if enemy_champ != null:
				enemy_champ.advance_visual_time(delta)
		_:
			_simulate(delta)

	_update_camera(delta)
	_update_shake(delta)

func _poll_local_input() -> void:
	_move = InputSetup.get_move_vector()
	_cast_accum = 0
	_cast_target = Vector2.ZERO

	# --- 1. Hướng ngắm: cần cảm ứng > cần tay cầm > chuột ---
	var mouse := get_global_mouse_position()
	var aim := Vector2.ZERO
	if touch != null and touch.aim_active():
		aim = touch.aim_direction()
	elif InputSetup.get_stick_aim() != Vector2.ZERO:
		aim = InputSetup.get_stick_aim()
	else:
		var d := mouse - local_champ.global_position
		if d.length_squared() > 4.0:
			aim = d.normalized()

	# Trên thiết bị cảm ứng, khi không đụng cần ngắm thì tự nhắm mục tiêu gần
	# nhất — bắt người chơi vừa chạy vừa ngắm chính xác bằng ngón tay là quá khó.
	if aim == Vector2.ZERO and Settings.show_touch_controls:
		var e := local_champ.nearest_enemy(2000.0)
		if e != null:
			aim = (e.global_position - local_champ.global_position).normalized()
	if aim != Vector2.ZERO:
		_aim = aim

	# --- 2. Cập nhật điểm đang trỏ tới cho chiêu đang chờ ---
	_update_armed_point(mouse)

	# --- 3. Bấm kỹ năng / xác nhận / huỷ ---
	if touch != null and Settings.show_touch_controls:
		_handle_touch_skill_input()
	else:
		_handle_pc_skill_input()

	# --- 4. Đánh thường: chỉ khi KHÔNG đang chờ xác nhận chiêu ---
	#
	# Đây là điểm mấu chốt của luồng mới: chuột trái vừa là "đánh thường" vừa là
	# "xác nhận chiêu". Nếu đang chờ chiêu thì chuột trái thuộc về chiêu, không
	# được đánh thường cùng lúc.
	if armed_slot == -1:
		var attack_held := Input.is_action_pressed(InputSetup.ATTACK_ACTION)
		if touch != null and touch.attack_held():
			attack_held = true
		if attack_held:
			_cast_accum |= 1 << Champion.CAST_BIT_ATTACK

# ------------------------------------------------------- luồng chọn vùng (PC)

func _handle_pc_skill_input() -> void:
	# Huỷ chiêu đang chờ. Kiểm tra trước tiên để một cú bấm không vừa huỷ vừa ra chiêu.
	if armed_slot != -1 and Input.is_action_just_pressed(InputSetup.CANCEL_ACTION):
		disarm()
		return

	for i in range(InputSetup.SKILL_ACTIONS.size()):
		if Input.is_action_just_pressed(InputSetup.SKILL_ACTIONS[i]):
			press_skill_slot(i)

	# Xác nhận bằng chuột trái.
	if armed_slot != -1 and Input.is_action_just_pressed(InputSetup.ATTACK_ACTION):
		confirm_armed()

# -------------------------------------------------- luồng chọn vùng (cảm ứng)

func _handle_touch_skill_input() -> void:
	# Bấm nút kỹ năng = lên đạn.
	var pressed := touch.consume_pressed_skills()
	for i in range(4):
		if pressed & (1 << i):
			press_skill_slot(i)

	# Nhấc ngón = xác nhận. Nếu ngón đang ở vùng huỷ thì bỏ chiêu.
	var released := touch.consume_released_skills()
	for i in range(4):
		if released & (1 << i):
			if i == armed_slot:
				if touch.release_was_cancel():
					disarm()
				else:
					confirm_armed()

	# Đánh thường trên cảm ứng xử lý ở nhánh riêng bên dưới.
	if touch.attack_held():
		pass

# ------------------------------------------------------------- trạng thái lên đạn

## Người chơi vừa bấm một ô kỹ năng.
##
## Chiêu cần định hướng hoặc chọn vùng thì chỉ "lên đạn" và chờ xác nhận. Chiêu
## không cần gì (bấm là ra) thì tung luôn trong cùng khung hình.
##
## Đây cũng là chỗ cài "dash-cancel": đổi sang chiêu khác khi đang chờ thì chiêu
## cũ bị huỷ nhưng được HOÀN LẠI một phần hồi chiêu. Nhờ vậy người chơi dám
## "lên đạn" chiêu mạnh để doạ rồi lướt đi khi thấy đối thủ né — mất ít hơn hẳn
## so với việc tung chiêu hụt. Đây chính là cơ chế tạo đất phô diễn.
func press_skill_slot(slot: int) -> void:
	if local_champ == null or slot < 0 or slot >= local_champ.skills.size():
		return
	var s: SkillBase = local_champ.skills[slot]
	if s == null or not s.can_cast():
		# Đang hồi chiêu hoặc thiếu năng lượng: bỏ qua, và tắt luôn trạng thái
		# chờ cũ để người chơi không bị kẹt ở một chiêu không dùng được.
		disarm()
		return

	# Huỷ chiêu đang chờ (nếu là chiêu khác) và hoàn lại một phần hồi chiêu.
	if armed_slot != -1 and armed_slot != slot:
		_refund_cancelled(armed_slot)

	if s.needs_aiming():
		armed_slot = slot
		# Mặc định trỏ về hướng đang ngắm để chiêu không nhảy về gốc toạ độ.
		armed_point = local_champ.global_position + _aim * minf(s.cast_range, 240.0)
	else:
		disarm()
		_cast_accum |= 1 << slot
		_cast_target = Vector2.ZERO

## Hoàn lại một phần hồi chiêu cho chiêu vừa bị huỷ.
##
## Tỉ lệ 0.30 là con số cân bằng: đủ để người chơi thấy "huỷ vẫn có lợi" mà
## không đủ để biến việc bấm-huỷ-bấm thành chiến thuật mạnh hơn cả việc bắn trúng.
const CANCEL_REFUND := 0.30

func _refund_cancelled(slot: int) -> void:
	if local_champ == null or slot < 0 or slot >= local_champ.skills.size():
		return
	var s: SkillBase = local_champ.skills[slot]
	if s == null or s.cooldown_left <= 0.0:
		return
	s.cooldown_left = maxf(0.0, s.cooldown_left - s.cooldown * CANCEL_REFUND)

## Chốt chiêu đang chờ và tung ra.
func confirm_armed() -> void:
	if armed_slot == -1:
		return
	var slot := armed_slot
	disarm()
	_cast_accum |= 1 << slot
	_cast_target = armed_point

func disarm() -> void:
	armed_slot = -1

func is_aiming_skill() -> bool:
	return armed_slot != -1

## Chiêu đang chờ (null nếu không chờ gì).
func armed_skill() -> SkillBase:
	if armed_slot == -1 or local_champ == null:
		return null
	if armed_slot >= local_champ.skills.size():
		return null
	return local_champ.skills[armed_slot]

## Cập nhật điểm đang trỏ tới mỗi khung hình.
##
## Trên PC thì điểm là vị trí chuột. Trên cảm ứng thì điểm suy ra từ vector kéo
## ngón tay: hướng kéo là hướng chiêu, độ dài kéo quyết định tầm với xa gần.
## Đây là cách các game MOBA trên điện thoại làm, vì ngón tay che mất chỗ cần ngắm.
func _update_armed_point(mouse: Vector2) -> void:
	var s := armed_skill()
	if s == null:
		if armed_slot != -1:
			disarm()
		return

	if touch != null and Settings.show_touch_controls:
		var drag := touch.skill_drag_vector(armed_slot)
		if drag.length() > 6.0:
			var ratio := clampf(drag.length() / TOUCH_DRAG_FULL, 0.0, 1.0)
			var dir := drag.normalized()
			armed_point = local_champ.global_position + dir * (s.cast_range * ratio)
			_aim = dir
	else:
		armed_point = mouse
		var d := mouse - local_champ.global_position
		if d.length_squared() > 4.0:
			_aim = d.normalized()

	# Điểm ngoài tầm vẫn bấm được (sẽ bị kẹp về mép tầm), nhưng HUD tô đỏ để
	# người chơi biết là không tới nơi mình muốn.
	armed_valid = local_champ.global_position.distance_to(armed_point) <= s.cast_range + 1.0

func _simulate(delta: float) -> void:
	var local_input := {
		"move": _move, "aim": _aim, "cast": _cast_accum, "target": _cast_target,
	}
	_cast_accum = 0
	_cast_target = Vector2.ZERO

	var enemy_input := {
		"move": Vector2.ZERO, "aim": Vector2.RIGHT, "cast": 0, "target": Vector2.ZERO,
	}
	match mode:
		GameData.Mode.SOLO, GameData.Mode.PRACTICE:
			if bot != null and enemy_champ != null and practice_bot_active():
				bot.update(delta, local_champ)
				enemy_input = {
					"move": bot.move_vector(),
					"aim": bot.aim_vector(),
					"cast": bot.cast_mask(),
					"target": bot.target_point(),
				}
		GameData.Mode.HOST:
			# Input của đối thủ đến từ gói tin máy khách gửi lên.
			for id in Net.players.keys():
				if id == Net.local_id:
					continue
				var entry: Variant = Net.players.get(id)
				if entry is Dictionary and entry.has("input"):
					var raw: Dictionary = entry["input"]
					enemy_input = {
						"move": raw.get("move", Vector2.ZERO),
						"aim": raw.get("aim", Vector2.RIGHT),
						"cast": int(raw.get("cast", 0)),
						"target": raw.get("target", Vector2.ZERO),
					}

	# Chỉ mô phỏng khi đang trong hiệp đánh nhau. Phòng luyện tập luôn ở trạng
	# thái đánh nhau vì không có ván thắng thua.
	# Khai báo kiểu tường minh: nếu dùng := với toán tử ba ngôi trộn Variant và
	# số, Godot không suy được kiểu và báo lỗi parse.
	var fighting := phase == Phase.FIGHT or is_practice()
	var local_mask: int = int(local_input["cast"]) if fighting else 0
	var enemy_mask: int = int(enemy_input["cast"]) if fighting else 0
	var local_move: Vector2 = local_input["move"] if fighting else Vector2.ZERO
	var enemy_move: Vector2 = enemy_input["move"] if fighting else Vector2.ZERO

	if local_champ != null:
		local_champ.step(delta, local_move, local_input["aim"], local_mask,
			local_input["target"])
	if enemy_champ != null:
		enemy_champ.step(delta, enemy_move, enemy_input["aim"], enemy_mask,
			enemy_input["target"])

	arena.step(delta)
	_update_practice(delta)

	# Host phát snapshot xuống máy khách.
	if mode == GameData.Mode.HOST:
		_snapshot_accum += delta
		var interval := 1.0 / SNAPSHOT_HZ
		if _snapshot_accum >= interval:
			_snapshot_accum = 0.0
			Net.broadcast_snapshot(_build_snapshot())

func _build_snapshot() -> Dictionary:
	var champs := {}
	if local_champ != null:
		champs[local_champ.peer_id] = local_champ.network_state()
	if enemy_champ != null:
		champs[enemy_champ.peer_id] = enemy_champ.network_state()
	return {
		"champions": champs,
		"projectiles": arena.projectile_snapshot(),
		"phase": phase,
		"timer": phase_timer,
		"scores": scores,
		"msg": status_message,
	}

# -------------------------------------------------------------- phía máy khách

func _on_snapshot(snap: Dictionary) -> void:
	var champs: Dictionary = snap.get("champions", {})
	for pid in champs.keys():
		var c := _champion_by_peer(int(pid))
		if c != null:
			c.apply_snapshot(champs[pid])
	arena.sync_client_projectiles(snap.get("projectiles", []))
	phase = int(snap.get("phase", phase))
	phase_timer = float(snap.get("timer", 0.0))
	scores = snap.get("scores", scores)
	status_message = str(snap.get("msg", status_message))

func _champion_by_peer(pid: int) -> Champion:
	if local_champ != null and local_champ.peer_id == pid:
		return local_champ
	if enemy_champ != null and enemy_champ.peer_id == pid:
		return enemy_champ
	return null

func _on_effect_spawned(config: Dictionary) -> void:
	# Host chuyển tiếp hiệu ứng sang máy khách; máy khách thì thôi.
	if mode == GameData.Mode.HOST:
		Net.broadcast_event({"t": "fx", "c": config})

func _on_net_event(event: Dictionary) -> void:
	if str(event.get("t", "")) == "fx":
		var config: Variant = event.get("c", {})
		if config is Dictionary:
			arena.spawn_effect(config)

## Pháo hoa ăn mừng khi ngườ chơi thắng trận.
func _spawn_victory_fx() -> void:
	if arena == null:
		return
	var colors := [Color("ff7a2f"), Color("38bdf8"), Color("a78bfa"), Color("fbbf24"), Color("4ade80")]
	for i in range(24):
		var pos := Vector2(randf_range(-500, 500), randf_range(-300, 200))
		arena.spawn_effect({
			"kind": &"firework",
			"position": pos,
			"radius": 6.0 + randf() * 10.0,
			"life": 1.2 + randf() * 1.5,
			"accent": colors[randi() % colors.size()],
		})
	for i in range(40):
		var pos := Vector2(randf_range(-600, 600), randf_range(200, 500))
		arena.spawn_effect({
			"kind": &"confetti",
			"position": pos,
			"radius": 3.0 + randf() * 4.0,
			"life": 2.0 + randf() * 2.0,
			"accent": colors[randi() % colors.size()],
		})

func _on_peer_gone() -> void:
	if mode == GameData.Mode.SOLO:
		return
	status_message = "Đối thủ đã rời trận"
	_enter_phase(Phase.MATCH_END)

# ------------------------------------------------------------- camera & rung

func _update_camera(delta: float) -> void:
	var focus := local_champ
	if focus == null or not focus.is_alive():
		# Khi đã chết thì nhìn về phía đối thủ cho đỡ nhàm.
		focus = enemy_champ if enemy_champ != null else local_champ
	if focus == null:
		return
	# Bật position_smoothing trên Camera2D nên chỉ cần gán đích, camera tự mượt.
	camera.global_position = focus.global_position

	# Zoom nội suy về mức đang chọn. Nội suy thay vì gán thẳng để lúc đổi mức
	# camera trượt ra/vào chứ không nhảy cục một.
	# Khi bắt đầu ván, thêm zoom extra để camera gần hơn rồi từ từ lùi ra.
	if _round_start_zoom_extra > 0.001:
		_round_start_zoom_extra = maxf(0.0, _round_start_zoom_extra - delta * 0.35)
	var want := ZOOM_LEVELS[clampi(zoom_index, 0, ZOOM_LEVELS.size() - 1)] + _round_start_zoom_extra
	var target := Vector2(want, want)
	camera.zoom = camera.zoom.lerp(target, clampf(ZOOM_LERP * delta, 0.0, 1.0))

## Đổi mức zoom. `steps` dương = lại gần, âm = ra xa.
func zoom_by(steps: int) -> void:
	zoom_index = clampi(zoom_index + steps, 0, ZOOM_LEVELS.size() - 1)

func zoom_ratio() -> float:
	var idx := clampi(zoom_index, 0, ZOOM_LEVELS.size() - 1)
	return float(idx) / float(ZOOM_LEVELS.size() - 1)

func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 22.0)
	# Rung dọc theo hướng đòn đánh, cộng một chút nhiễu ngang để không bị máy móc.
	var along := _shake_dir * randf_range(0.6, 1.0)
	var across := Vector2(-_shake_dir.y, _shake_dir.x) * randf_range(-0.45, 0.45)
	camera.offset = (along + across) * _shake

# ------------------------------------------------------------- dừng hình

## Dừng hình vài mili giây khi trúng đòn nặng.
##
## Đây là mẹo kinh điển để làm đòn đánh "nặng": chèn một khoảng dừng cực ngắn
## ngay lúc va chạm. Không có nó thì đòn mạnh và đòn nhẹ nghe giống nhau.
##
## Chỉ bật ở chế độ một máy. Trong trận LAN, hạ `time_scale` ở máy chủ sẽ làm
## nhịp mô phỏng lệch khỏi nhịp máy khách đang nội suy.
func hitstop(ms: int) -> void:
	if not (mode == GameData.Mode.SOLO or is_practice()):
		return
	if Settings.screen_shake <= 0.01:
		return
	var now := Time.get_ticks_msec()
	var target := now + ms
	# Đòn liên tiếp thì lấy mốc dài hơn, không chồng thành dừng hình dài bất thường.
	if target > _hitstop_until_ms:
		_hitstop_until_ms = target
		Engine.time_scale = 0.08

func _tick_hitstop() -> void:
	if _hitstop_until_ms <= 0:
		return
	if Time.get_ticks_msec() >= _hitstop_until_ms:
		_hitstop_until_ms = 0
		Engine.time_scale = 1.0

## Chậm thờ khi hạ gục đối thủ — hiệu ứng điện ảnh cổ điển.
func death_slowmo(ms: int) -> void:
	if not (mode == GameData.Mode.SOLO or is_practice()):
		return
	var now := Time.get_ticks_msec()
	var target := now + ms
	if target > _death_slowmo_until_ms:
		_death_slowmo_until_ms = target
		Engine.time_scale = 0.18

func _tick_death_slowmo() -> void:
	if _death_slowmo_until_ms <= 0:
		return
	if Time.get_ticks_msec() >= _death_slowmo_until_ms:
		_death_slowmo_until_ms = 0
		Engine.time_scale = 1.0

func _process(_delta: float) -> void:
	_tick_hitstop()
	_tick_death_slowmo()

func _exit_tree() -> void:
	# Không để lại time_scale méo mó cho scene sau.
	Engine.time_scale = 1.0
	get_tree().paused = false

func _on_champion_damaged(amount: float, _source: int, who: Champion) -> void:
	if amount <= 0.0:
		return
	_shake = minf(11.0, _shake + amount * 0.22 * Settings.screen_shake)
	# Hướng rung = hướng từ camera tới chỗ trúng đòn, nên đòn đánh sang phải
	# thì camera giật sang phải.
	if who != null and camera != null:
		var d := who.global_position - camera.global_position
		if d.length_squared() > 1.0:
			_shake_dir = d.normalized()
	# Dừng hình theo độ nặng của đòn. Ngưỡng 12 để đòn nhỏ (sát thương theo nhịp
	# của vùng lửa, vệt băng) không làm giật nhịp liên tục.
	if amount >= 12.0:
		hitstop(6 if amount < 26.0 else 9)
	_maybe_show_damage(who, amount)

## Hiện số sát thương. Chỉ bật ở phòng luyện tập và chế độ một máy — trong trận
## LAN thì số nhảy ở cả hai máy sẽ lệch nhau vì mỗi bên tự tính thời điểm.
func _maybe_show_damage(who: Champion, amount: float) -> void:
	if amount <= 0.0:
		return
	if not (is_practice() or mode == GameData.Mode.SOLO):
		return
	# Đòn nhỏ (sát thương theo nhịp của vùng lửa, vệt băng) hiện chữ bé hơn để
	# không át mất những đòn thật sự quan trọng.
	var small := amount < 6.0
	var big := amount >= 25.0
	var tint := Color("ffe066") if big else Color(1, 1, 1, 0.92)
	spawn_damage_number(who.global_position + Vector2(0, -46), amount, tint, big, small)

func _on_champion_died(who: Champion, _killer: int) -> void:
	_shake = 12.0 * Settings.screen_shake
	# Hạt bắn tung khi chết.
	if arena != null:
		arena.spawn_death_burst(who.global_position, who.accent)
	# Chậm thờ khi chết — chỉ trong chế độ một máy.
	if mode == GameData.Mode.SOLO or is_practice():
		death_slowmo(450)
	if is_practice():
		return   # phòng luyện tập không có thắng thua, chỉ hồi sinh
	if mode == GameData.Mode.SOLO or mode == GameData.Mode.HOST:
		_check_round_over()

# ------------------------------------------------------------- phòng luyện tập
#
# Phòng luyện tập khác mọi chế độ khác ở chỗ nó KHÔNG có ván thắng thua. Mục
# đích duy nhất là để người chơi thử combo, nên mọi thứ gây cản trở việc thử
# đều phải tắt được: hồi chiêu, năng lượng, cái chết, và cả đối thủ.

## Bot có đang hành động không. Tắt = đối thủ đứng yên nhưng vẫn ăn đòn.
var practice_bot := true
## Hình nộm: đối thủ đứng yên, bất tử, và mọi sát thương đều hiện số.
var practice_dummy := false
var practice_infinite_mana := true
var practice_no_cooldown := true
var practice_god_self := false
var practice_god_enemy := true
## Bảng điều khiển phòng luyện tập có đang mở không (bấm Tab để bật/tắt).
var practice_panel_open := false

## Đồng hồ hồi sinh cho từng peer, để không hồi sinh ngay lập tức mà thấy được
## cảnh chết trong một nhịp.
var _respawn_timers := {}

func is_practice() -> bool:
	return mode == GameData.Mode.PRACTICE

## Trong phòng luyện tập, hai bên đứng gần nhau để vào là thử combo được ngay.
func practice_spawn_points() -> Array[Vector2]:
	return [Vector2(-300, 0), Vector2(300, 0)]

func practice_bot_active() -> bool:
	# Trong phòng luyện tập: bot chỉ hoạt động khi bảng bật "Bot" và không bật
	# "Hình nộm". Trong chế độ SOLO (đấu với bot thật): bot luôn hoạt động.
	if is_practice():
		return practice_bot and not practice_dummy
	return true

## Áp các bật/tắt lên tướng, và lo phần hồi sinh.
func _update_practice(delta: float) -> void:
	if not is_practice():
		return

	if local_champ != null:
		local_champ.invincible = practice_god_self
		local_champ.no_cooldown = practice_no_cooldown
		if practice_infinite_mana:
			local_champ.mana = local_champ.max_mana
	if enemy_champ != null:
		# Hình nộm luôn bất tử, vì mục đích của nó là ăn đòn mãi không chết.
		enemy_champ.invincible = practice_god_enemy or practice_dummy
		enemy_champ.no_cooldown = practice_no_cooldown
		if practice_infinite_mana:
			enemy_champ.mana = enemy_champ.max_mana

	# Hồi sinh: ai chết thì sau một nhịp được dựng lại tại chỗ xuất phát.
	for c in [local_champ, enemy_champ]:
		if c == null:
			continue
		var key: int = c.peer_id
		if c.is_alive():
			_respawn_timers.erase(key)
			continue
		var left: float = float(_respawn_timers.get(key, RESPAWN_DELAY))
		left -= delta
		if left <= 0.0:
			_respawn_timers.erase(key)
			var spawns := practice_spawn_points()
			c.reset_for_round(spawns[0] if c == local_champ else spawns[1])
		else:
			_respawn_timers[key] = left

## Đặt lại phòng luyện tập: hồi đầy máu, xoá mọi hiệu ứng, đưa hai bên về chỗ cũ.
func practice_reset() -> void:
	arena.clear_projectiles()
	_respawn_timers.clear()
	var spawns := practice_spawn_points()
	if local_champ != null:
		local_champ.reset_for_round(spawns[0])
	if enemy_champ != null:
		enemy_champ.reset_for_round(spawns[1])
	status_message = "Đã đặt lại"

## Hồi đầy máu cho cả hai bên mà không đổi vị trí.
func practice_heal_all() -> void:
	for c in [local_champ, enemy_champ]:
		if c != null:
			c.heal(c.max_hp)
			c.shield = 0.0
			c.statuses.clear()
			c.status_changed.emit()
	status_message = "Đã hồi đầy máu"

## Bật/tắt một mục trong bảng. Trả về nhãn để HUD hiện thông báo.
func practice_toggle(key: String) -> void:
	match key:
		"bot":
			practice_bot = not practice_bot
			if practice_bot:
				practice_dummy = false
		"dummy":
			practice_dummy = not practice_dummy
			if practice_dummy:
				practice_bot = false
				practice_god_enemy = true
		"mana":
			practice_infinite_mana = not practice_infinite_mana
		"cooldown":
			practice_no_cooldown = not practice_no_cooldown
		"god_self":
			practice_god_self = not practice_god_self
		"god_enemy":
			practice_god_enemy = not practice_god_enemy

## Danh sách mục trong bảng, dùng chung cho cả việc vẽ và việc bấm.
## Mỗi mục: khoá, nhãn, và trạng thái bật/tắt hiện tại.
func practice_items() -> Array:
	return [
		{"key": "bot", "label": "Bot hoạt động", "on": practice_bot},
		{"key": "dummy", "label": "Hình nộm", "on": practice_dummy},
		{"key": "mana", "label": "Vô hạn năng lượng", "on": practice_infinite_mana},
		{"key": "cooldown", "label": "Tắt hồi chiêu", "on": practice_no_cooldown},
		{"key": "god_self", "label": "Bất tử — bản thân", "on": practice_god_self},
		{"key": "god_enemy", "label": "Bất tử — đối thủ", "on": practice_god_enemy},
	]

## Xử lý cú bấm vào bảng điều khiển. `index` là thứ tự trong practice_items().
func practice_click(index: int) -> void:
	var items := practice_items()
	if index < 0 or index >= items.size():
		return
	practice_toggle(str(items[index]["key"]))
	Audio.play(&"ui_click")

## Hiện số sát thương tại vị trí nạn nhân.
func spawn_damage_number(pos: Vector2, amount: float, color: Color,
		big: bool, small: bool) -> void:
	var n := DamageNumber.new()
	n.setup(amount, color, big, small)
	n.global_position = pos
	arena.fx.add_child(n)
	# Hiệu ứng trúng đòn 2.5D: tia lửa + vòng sóng xung kích tại điểm va chạm.
	# Sát thương theo nhịp (small = tick DOT) chỉ lấp lánh nhẹ mỗi 3 nhịp để
	# không dính cả màn hiệu ứng khi đứng trong vùng cháy.
	if not small or _impact_tick >= 3:
		var strength := 0.6 + clampf(amount / 60.0, 0.0, 1.0)
		if big:
			strength += 0.4
		VFXLibrary.hit_impact(arena.fx, pos, color, strength)
		_impact_tick = 0
	else:
		_impact_tick += 1

## Bộ đếm nhịp để giảm tần suất hiệu ứng va chạm của sát thương DOT.
var _impact_tick := 0

# ------------------------------------------------------------------ tiện ích

func local_skill_list() -> Array:
	return local_champ.skills if local_champ != null else []

func exit_to_menu() -> void:
	Net.leave()
	Audio.stop_map_ambient()
	# Phải bỏ tạm dừng trước khi đổi scene, nếu không menu chính cũng bị đứng.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ---------------------------------------------------------------- menu tạm

## Bật/tắt menu tạm.
##
## Chỉ tạm dừng mô phỏng ở chế độ một máy. Trong trận LAN mà tạm dừng cục bộ thì
## máy kia vẫn chạy tiếp, hai bên lệch nhau ngay — nên ở LAN chỉ hiện menu chứ
## không dừng game.
func set_paused(on: bool) -> void:
	paused = on
	if pause_menu != null:
		pause_menu.visible = on
	if on:
		# Mở menu thì huỷ luôn chiêu đang chờ, tránh việc đóng menu ra lại thấy
		# chiêu cũ vẫn đang chờ xác nhận.
		disarm()
	var local_only := mode == GameData.Mode.SOLO or is_practice()
	get_tree().paused = on and local_only
	if on:
		# Mở menu giữa lúc đang dừng hình thì phải trả tốc độ về bình thường,
		# nếu không menu sẽ chạy ở 8% tốc độ và trông như bị treo.
		_hitstop_until_ms = 0
		Engine.time_scale = 1.0

func toggle_pause() -> void:
	set_paused(not paused)

func is_paused() -> bool:
	return paused

func _unhandled_input(event: InputEvent) -> void:
	# Cuộn chuột để zoom. Dùng _unhandled_input nên HUD/bảng điều khiển nào đã
	# xử lý sự kiện thì cuộn chuột không ảnh hưởng tới camera.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_by(1)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(-1)
				get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_ESCAPE:
			# ESC là nút "lùi một bước" theo thứ tự ưu tiên: đang chờ chọn vùng
			# thì huỷ chiêu, đang mở bảng luyện tập thì đóng bảng, đang mở menu
			# tạm thì đóng menu, còn không thì mở menu tạm.
			#
			# Bản trước cho ESC thoát thẳng về menu — bấm nhầm một cái là mất
			# cả trận. Giờ thoát game phải đi qua menu tạm, hai bước rõ ràng.
			if armed_slot != -1:
				disarm()
			elif practice_panel_open:
				practice_panel_open = false
			elif paused:
				set_paused(false)
			else:
				set_paused(true)
			get_viewport().set_input_as_handled()
		KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			if is_practice():
				practice_panel_open = not practice_panel_open
				get_viewport().set_input_as_handled()
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_by(-1)
			get_viewport().set_input_as_handled()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_by(1)
			get_viewport().set_input_as_handled()
