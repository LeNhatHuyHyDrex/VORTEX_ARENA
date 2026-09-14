extends Node
## Công cụ chụp ảnh kiểm tra giao diện.
##
## Chạy game thật trong vài giây rồi lưu ảnh màn hình ra user://shots.
##
## Lưu ý: KHÔNG dùng await RenderingServer.frame_post_draw vì trong headless
## tín hiệu này không bao giờ phát ra. Chạy KHÔNG --headless, dùng đồng hồ bấm
## giờ riêng để có giới hạn thời gian cứng cho mỗi ảnh.

const HARD_LIMIT := 40.0

var _shots: Array = [
	# --- Menu ngoài, bốn màn ---
	{"scene": "res://scenes/MainMenu.tscn", "wait": 1.8, "name": "01_title"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 1.8, "name": "02_mode",
		"after_load": "_open_mode"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.0, "name": "03_champion",
		"after_load": "_open_champion"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 1.8, "name": "04_settings",
		"after_load": "_open_settings"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.4, "name": "05_keybinds",
		"after_load": "_open_keybinds"},
	# --- Trong trận ---
	{"scene": "res://scenes/Game.tscn", "wait": 4.5, "name": "06_fight",
		"before_load": "_solo"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.0, "name": "07_aim_direction",
		"before_load": "_solo", "after_load": "_arm_direction"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.0, "name": "08_aim_ground",
		"before_load": "_solo_fire", "after_load": "_arm_ground"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.0, "name": "09_touch_controls",
		"before_load": "_practice_touch"},
	{"scene": "res://scenes/Game.tscn", "wait": 3.0, "name": "10_practice_panel",
		"before_load": "_practice", "after_load": "_open_practice_panel"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.0, "name": "11_champ_arcane",
		"after_load": "_open_arcane"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.0, "name": "12_arcane_ground",
		"before_load": "_solo_arcane", "after_load": "_arm_ground"},
	{"scene": "res://scenes/Game.tscn", "wait": 6.0, "name": "13_arcane_ult",
		"before_load": "_solo_arcane", "after_load": "_arm_ult"},
	# --- Tính năng mới của đợt này ---
	{"scene": "res://scenes/Game.tscn", "wait": 3.5, "name": "14_pause",
		"before_load": "_solo", "after_load": "_open_pause"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "15_champ_mirage",
		"after_load": "_open_mirage"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.0, "name": "16_mirage_fight",
		"before_load": "_solo_mirage"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.5, "name": "17_tamer_pack",
		"before_load": "_solo_tamer", "after_load": "_summon_wolves"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "18_champ_marksman",
		"after_load": "_open_marksman"},
	# --- Đợt nâng cấp hiển thị + Thời Sư ---
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "19_map_previews",
		"after_load": "_open_map"},
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "20_champ_timeweaver",
		"after_load": "_open_timeweaver"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.5, "name": "21_timeweaver_fight",
		"before_load": "_solo_timeweaver"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.8, "name": "22_cast_indicator",
		"before_load": "_solo_timeweaver", "after_load": "_arm_time_ground"},
	{"scene": "res://scenes/Game.tscn", "wait": 3.72, "name": "23_whip_anim",
		"before_load": "_solo_tamer", "after_load": "_whip_snap"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.4, "name": "24_time_rift_zone",
		"before_load": "_solo_timeweaver", "after_load": "_cast_time_rift"},
	# --- Đợt 5 tướng mới + logic vai trò + HUD bảng chiêu ---
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "25_champ_bloodlord",
		"after_load": "_open_bloodlord"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.0, "name": "26_bloodlord_fight",
		"before_load": "_solo_bloodlord", "after_load": "_blood_claw"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.0, "name": "27_iron_monk_fight",
		"before_load": "_solo_iron_monk"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.0, "name": "28_berserker_fight",
		"before_load": "_solo_berserker"},
	{"scene": "res://scenes/Game.tscn", "wait": 5.0, "name": "29_void_samurai_fight",
		"before_load": "_solo_void_samurai"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.8, "name": "30_plague_toxic",
		"before_load": "_solo_plague", "after_load": "_arm_toxic_pool"},
	{"scene": "res://scenes/Game.tscn", "wait": 4.0, "name": "31_armed_invalid",
		"before_load": "_solo_plague", "after_load": "_arm_out_of_range"},
	# --- Đợt 2.5D: đếm ngược mở màn + banner kết thúc trận ---
	{"scene": "res://scenes/Game.tscn", "wait": 1.1, "name": "32_countdown",
		"before_load": "_solo"},
	{"scene": "res://scenes/Game.tscn", "wait": 1.2, "name": "33_victory_banner",
		"before_load": "_solo", "after_load": "_force_match_end"},
	# --- Đợt khe cắm asset: thẻ tướng mặc định (Hỏa Pháp Sư) ---
	{"scene": "res://scenes/MainMenu.tscn", "wait": 2.2, "name": "34_champ_default",
		"after_load": "_open_champ_default"},
]

func _ready() -> void:
	var out_dir := ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)
	for shot in _shots:
		await _capture(shot, out_dir)
		# Shot 09 bật nút cảm ứng để chụp; khôi phục NGAY sau đó, nếu không mọi
		# shot phía sau (bảng chiêu mới, dải kỹ năng, chỉ báo cast) đều chạy
		# trong chế độ cảm ứng và không bao giờ hiện UI bàn phím/một số thứ.
		if str(shot["name"]) == "09_touch_controls":
			_restore_settings()
	_restore_settings()
	print("CAPTURE_DONE")
	get_tree().quit()

# ------------------------------------------------------------ thiết lập cảnh

func _open_mode(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(1)

func _open_champion(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"thunder_warrior")

func _open_settings(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(4)

func _open_keybinds(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(4)
	if scene.has_method("_open_keybinds"):
		scene._open_keybinds()
		if scene._keybinds != null and scene._keybinds._key_buttons.has("skill_1"):
			var b: Button = scene._keybinds._key_buttons["skill_1"]
			scene._keybinds._start_capture(&"skill_1", b)

func _solo() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"shadow_assassin"

func _solo_fire() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"fire_mage"

func _practice() -> void:
	Game.pending_mode = GameData.Mode.PRACTICE
	Game.pending_champion = &"fire_mage"

func _solo_arcane() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"arcane_weaver"

func _solo_mirage() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"mirage"

func _solo_tamer() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"tamer"

func _open_mirage(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"mirage")

func _open_marksman(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"marksman")

func _open_map(scene: Node) -> void:
	# Màn chọn bản đồ: dừng ở đây để chụp các thẻ preview.
	if scene.has_method("_show"):
		scene._show(2)

func _open_timeweaver(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"time_weaver")

func _solo_timeweaver() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"time_weaver"

## Lên đạn Kẽ Hở (ô 0) để chụp vòng phạm vi chiêu — chính là thứ từng mất dấu.
func _arm_time_ground(scene: Node) -> void:
	await get_tree().create_timer(3.5).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 0
			g.armed_point = g.local_champ.global_position + Vector2(240, -90)
			g.armed_valid = true

## Bắn roi đúng lúc để khung hình chụp trúng cú vung.
func _whip_snap(scene: Node) -> void:
	await get_tree().create_timer(3.6).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null and g.enemy_champ != null:
			var dir: Vector2 = (g.enemy_champ.global_position - g.local_champ.global_position).normalized()
			g.local_champ.basic_attack.try_cast(dir, Vector2.ZERO)

## Thả một vùng Kẽ Hở + nổ Ngưng Trôi để chụp hiệu ứng đồng hồ.
func _cast_time_rift(scene: Node) -> void:
	await get_tree().create_timer(3.4).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null and g.enemy_champ != null:
			var target: Vector2 = g.enemy_champ.global_position
			g.local_champ.skills[0].try_cast(g.local_champ.aim_dir, target)
			await get_tree().create_timer(0.6).timeout
			g.local_champ.skills[2].try_cast(g.local_champ.aim_dir, target)

func _open_pause(scene: Node) -> void:
	await get_tree().create_timer(2.0).timeout
	if scene is Game:
		(scene as Game).set_paused(true)

## Thả vài con sói ra để thấy đàn thú trong ảnh.
func _summon_wolves(scene: Node) -> void:
	await get_tree().create_timer(2.6).timeout
	if not (scene is Game):
		return
	var g := scene as Game
	if g.local_champ == null:
		return
	for i in range(3):
		var a := TAU * float(i) / 3.0
		g.arena.spawn_projectile(g.local_champ, {
			"kind": &"spirit_wolf",
			"position": g.local_champ.global_position + Vector2(cos(a), sin(a)) * 90.0,
			"direction": Vector2.RIGHT.rotated(a),
			"speed": 320.0,
			"damage": 10.0,
			"radius": 18.0,
			"life": 5.0,
			"power": 0.0,
			"chase_speed": 6.0,
			"accent": Color("4ade80"),
		})

func _open_arcane(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"arcane_weaver")

## Lên đạn Sụp Đổ (ô 3) — chiêu có vòng cảnh báo trước khi nổ.
func _arm_ult(scene: Node) -> void:
	await get_tree().create_timer(3.2).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 3
			g.armed_point = g.local_champ.global_position + Vector2(210, -40)
			g.armed_valid = true

var _touch_was_on := false

## Nạp autoload Settings theo đường dẫn node thay vì định danh tĩnh.
## Vì sao: chế độ `--script` KHÔNG nạp autoload, tham chiếu tĩnh `Settings`
## làm script fail compile ngay từ đầu — trước đó cả bộ chụp ảnh không chạy nổi.
func _settings_node() -> Node:
	var root := get_tree().root
	return root.get_node_or_null("Settings")

func _practice_touch() -> void:
	var s := _settings_node()
	if s == null:
		return
	_touch_was_on = s.show_touch_controls
	s.show_touch_controls = true
	Game.pending_mode = GameData.Mode.PRACTICE
	Game.pending_champion = &"frost_maiden"

func _restore_settings() -> void:
	var s := _settings_node()
	if s == null:
		return
	s.show_touch_controls = _touch_was_on
	s.save_settings()

## Lên đạn một chiêu theo hướng (ô 0 = Hỏa Cầu) và trỏ về phía đối thủ.
func _arm_direction(scene: Node) -> void:
	await get_tree().create_timer(2.4).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 0
			g.armed_point = g.local_champ.global_position + Vector2(420, -60)
			g.armed_valid = true

## Lên đạn một chiêu chọn vùng (ô 1 = Tường Lửa) và đặt vùng lệch về một bên.
func _arm_ground(scene: Node) -> void:
	await get_tree().create_timer(2.4).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 1
			g.armed_point = g.local_champ.global_position + Vector2(250, -110)
			g.armed_valid = true

func _open_practice_panel(scene: Node) -> void:
	if scene is Game:
		var g := scene as Game
		g.practice_panel_open = true
		g.practice_dummy = true
		g.practice_bot = false

# ------------------------------------------------- đợt 5 tướng mới

func _open_bloodlord(scene: Node) -> void:
	if scene.has_method("_show"):
		# Screen enum: TITLE=0, MODE=1, MAP=2, CHAMPION=3 — màn CHAMPION là 3
		# sau khi màn chọn bản đồ được chèn vào.
		scene._show(3)
	if scene.has_method("_select_champion"):
		scene._select_champion(&"blood_lord")

func _solo_bloodlord() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"blood_lord"

func _solo_iron_monk() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"iron_monk"

func _solo_berserker() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"berserker"

func _solo_void_samurai() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"void_samurai"

func _solo_plague() -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = &"plague_alchemist"

## Cào máu về phía địch để thấy vuốt + hiệu ứng hút máu của Huyết Bá.
func _blood_claw(scene: Node) -> void:
	await get_tree().create_timer(3.6).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null and g.enemy_champ != null:
			var dir: Vector2 = (g.enemy_champ.global_position - g.local_champ.global_position).normalized()
			g.local_champ.basic_attack.try_cast(dir, Vector2.ZERO)
			g.local_champ.skills[0].try_cast(dir, Vector2.ZERO)  # Huyết Tiễn

## Lên đạn Vực Độc (ô 0) trong tầm — chụp vòng xanh + bảng mô tả chiêu mới.
func _arm_toxic_pool(scene: Node) -> void:
	await get_tree().create_timer(3.4).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 0
			g.armed_point = g.local_champ.global_position + Vector2(260, -80)
			g.armed_valid = true

## Lên đạn NGOÀI tầm — chụp bảng đỏ "NGOÀI TẦM" và vòng phạm vi đỏ.
##
## Điểm armed được Game tính lại từ vị trí chuột THẬT mỗi frame, nên cách duy
## nhất để có trạng thái đỏ là kéo con trỏ tới góc xa của cửa sổ (gấp đôi tầm
## chiêu trở lên) bằng warp_mouse.
func _arm_out_of_range(scene: Node) -> void:
	await get_tree().create_timer(3.4).timeout
	if scene is Game:
		var g := scene as Game
		if g.local_champ != null:
			g.armed_slot = 0
			var vp := g.get_viewport_rect().size
			Input.warp_mouse(Vector2(vp.x - 30.0, 40.0))
			await get_tree().process_frame
			await get_tree().process_frame
			g.armed_valid = g.local_champ.global_position.distance_to(g.armed_point) > 460.0

## Ép trận đấu kết thúc ngay để chụp banner thắng — không cần chơi thật 3 ván.
## Đặt thẳng các biến mà HUD MATCH_END đọc: phase, match_winner, status_message.
func _force_match_end(scene: Node) -> void:
	await get_tree().create_timer(0.4).timeout
	if scene is Game:
		var g := scene as Game
		g.phase = Game.Phase.MATCH_END
		g.match_winner = 1
		g.status_message = "BẠN THẮNG!"
		g.stats_damage_dealt = 486.0
		g.stats_max_combo = 14
		g.stats_rounds_won = 3
		g.current_round = 5

## Mở màn chọn tướng mà KHÔNG chọn ai — để thấy thẻ mặc định (Hỏa Pháp Sư)
## cùng khe cắm ảnh asset nếu đã có file trong assets/art/.
func _open_champ_default(scene: Node) -> void:
	if scene.has_method("_show"):
		scene._show(3)

# --------------------------------------------------------------- chụp

func _capture(shot: Dictionary, out_dir: String) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	if shot.has("before_load"):
		call(shot["before_load"])

	var packed: PackedScene = load(str(shot["scene"]))
	if packed == null:
		push_error("Không load được scene " + str(shot["scene"]))
		return
	var scene := packed.instantiate()
	add_child(scene)

	if shot.has("after_load"):
		call(shot["after_load"], scene)

	var waited := 0.0
	var wait_for := float(shot["wait"])
	while waited < wait_for:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > HARD_LIMIT:
			print("SHOT TIMEOUT ", shot["name"])
			return

	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var path := out_dir + "/" + str(shot["name"]) + ".png"
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err)
