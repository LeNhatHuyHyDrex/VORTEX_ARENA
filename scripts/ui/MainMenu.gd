extends Control
## Menu ngoài, chia thành bốn màn.
##
## Luồng đi: TIÊU ĐỀ -> CHỌN CHẾ ĐỘ -> CHỌN TƯỚNG -> vào trận.
## Riêng phòng luyện tập đi tắt: TIÊU ĐỀ -> CHỌN TƯỚNG.
##
## Vì sao tách màn thay vì nhồi hết vào một trang: bản cũ để chọn tướng, chọn
## chế độ, nhập IP, chỉnh âm lượng và gán phím trên cùng một trang. Người mới
## vào không biết bắt đầu từ đâu. Tách ra thì mỗi màn chỉ hỏi đúng một câu.

enum Screen { TITLE, MODE, MAP, CHAMPION, SETTINGS, ONLINE_HELP }

var _screen: int = Screen.TITLE
## Chế độ người chơi đã chọn ở màn CHỌN CHẾ ĐỘ, chờ tới màn chọn tướng.
var _pending_mode: int = GameData.Mode.SOLO
var _pending_map: int = GameData.MapType.CLASSIC
var _selected: StringName = &"fire_mage"
var _enemy_selected: StringName = &"shadow_assassin"

var _backdrop: MenuBackdrop
var _content: MarginContainer
var _status: Label

# Các node cần giữ tham chiếu giữa các lần dựng màn.
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _server_box: VBoxContainer
var _detail_box: VBoxContainer
var _portraits: Dictionary = {}
const ChampionPedestalClass := preload("res://scripts/ui/ChampionPedestal.gd")
const ArenaPreviewClass := preload("res://scripts/ui/ArenaPreview.gd")

var _keybinds: KeybindsPanel = null
var _fade_overlay: ColorRect = null
var _pedestal = null
var _arena_preview = null
var _first_show := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = MenuBackdrop.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)

	# Lớp phủ đen để hiệu ứng fade chuyển màn.
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color.BLACK
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.modulate = Color.TRANSPARENT
	add_child(_fade_overlay)

	# Lớp nội dung nằm trên nền; nền không nhận input nên không chắn nút.
	var layer := MarginContainer.new()
	layer.name = "Content"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_theme_constant_override("margin_left", 40)
	layer.add_theme_constant_override("margin_right", 40)
	layer.add_theme_constant_override("margin_top", 24)
	layer.add_theme_constant_override("margin_bottom", 22)
	add_child(layer)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	layer.add_child(col)

	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_content)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(1, 0.78, 0.45, 0.95))
	col.add_child(_status)

	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.server_list_changed.connect(_refresh_servers)
	Net.start_discovery()

	_show(Screen.TITLE)
	Audio.play_menu_music()

# ------------------------------------------------------------- đổi màn

func _show(screen: int) -> void:
	if _first_show:
		_first_show = false
		_show_immediate(screen)
		return
	# Fade đen nhanh rồi chuyển màn.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	_fade_overlay.modulate = Color.TRANSPARENT
	tween.tween_property(_fade_overlay, "modulate", Color.WHITE, 0.12)
	tween.tween_callback(func() -> void:
		_show_immediate(screen)
	)
	tween.tween_property(_fade_overlay, "modulate", Color.TRANSPARENT, 0.14)

func _show_immediate(screen: int) -> void:
	_screen = screen
	for c in _content.get_children():
		c.queue_free()
	# Nền chỉ nổi bật ở màn tiêu đề; các màn sau cần chỗ đọc chữ nên làm tối đi.
	if _backdrop != null:
		_backdrop.modulate = Color(1, 1, 1, 1.0 if screen == Screen.TITLE else 0.32)

	match screen:
		Screen.TITLE:
			Audio.play_menu_music()
			_build_title()
		Screen.MODE:
			Audio.play_menu_music()
			_build_mode()
		Screen.MAP:
			Audio.play_menu_music()
			_build_map()
		Screen.CHAMPION:
			Audio.play_champ_music()
			_build_champion()
		Screen.SETTINGS:
			Audio.play_menu_music()
			_build_settings()
		Screen.ONLINE_HELP:
			Audio.play_menu_music()
			_build_online_help()

func _go_back() -> void:
	Audio.play(&"ui_back")
	match _screen:
		Screen.MODE:
			_show(Screen.TITLE)
		Screen.MAP:
			_show(Screen.MODE)
		Screen.CHAMPION:
			# Phòng luyện tập vào thẳng từ tiêu đề nên quay lại tiêu đề.
			if _pending_mode == GameData.Mode.PRACTICE:
				_show(Screen.MAP)
			else:
				_show(Screen.MAP)
		Screen.SETTINGS:
			_show(Screen.TITLE)
		Screen.ONLINE_HELP:
			_show(Screen.MODE)
		_:
			_show(Screen.TITLE)

# ============================================================= MÀN TIÊU ĐỀ

func _build_title() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_content.add_child(root)

	# --- Tiêu đề trên cùng ---
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(top)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	top.add_child(spacer)

	var title := Label.new()
	title.text = "FORGEAX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", Color(0.99, 0.98, 1.0))
	# Quầng sáng quanh chữ để nổi trên nền có hai tướng đứng hai bên.
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.12, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 12)
	top.add_child(title)

	var sub := Label.new()
	sub.text = "Đối kháng 1v1  ·  tự ghép kỹ năng thành combo của riêng bạn"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	top.add_child(sub)

	# Tên người chơi đặt ngay dưới tiêu đề, không để chung với hàng nút — chung
	# chỗ thì ô nhập bị chèn vào nút và trông như lỗi bố cục.
	var name_gap := Control.new()
	name_gap.custom_minimum_size = Vector2(0, 14)
	top.add_child(name_gap)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(name_row)
	name_row.add_child(_label("Tên hiển thị", 13, Color(1, 1, 1, 0.5)))
	_name_edit = LineEdit.new()
	_name_edit.text = Settings.player_name
	_name_edit.placeholder_text = "Nhập tên"
	_name_edit.custom_minimum_size = Vector2(220, 34)
	_style_input(_name_edit)
	name_row.add_child(_name_edit)

	# --- Nút ở dưới cùng ---
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	var play := _big_button("CHƠI NGAY", "Đấu với bot hoặc vào phòng LAN",
		Color("ff7a2f"), 58)
	play.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		_pending_mode = GameData.Mode.SOLO
		_show(Screen.MODE))
	bottom.add_child(play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)

	var practice := _big_button("PHÒNG LUYỆN TẬP",
		"Thử mọi combo, bật tắt hồi chiêu và hình nộm", Color("38bdf8"), 50)
	practice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	practice.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		_pending_mode = GameData.Mode.PRACTICE
		_show(Screen.MAP))
	row.add_child(practice)

	var settings := _big_button("CÀI ĐẶT", "Âm thanh, điều khiển, nút cảm ứng",
		Color("a78bfa"), 50)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		_show(Screen.SETTINGS))
	row.add_child(settings)

	var quit := _big_button("THOÁT", "Đóng game", Color("94a3b8"), 50)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(quit)

# ========================================================= MÀN CHỌN CHẾ ĐỘ

func _build_mode() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_content.add_child(root)

	root.add_child(_screen_title("CHỌN CHẾ ĐỘ", "Bạn muốn đấu với ai?"))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# --- Cột trái: hai lựa chọn chính ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(400, 0)
	cols.add_child(left)

	var solo := ModeCard.new()
	solo.title = "Đấu với bot"
	solo.subtitle = "Một máy, vào trận ngay"
	solo.tint = Color("ff7a2f")
	solo.icon = ModeCard.Icon.BOT
	solo.custom_minimum_size = Vector2(0, 72)
	solo.pressed.connect(func() -> void:
		_pending_mode = GameData.Mode.SOLO
		_show(Screen.MAP))
	left.add_child(solo)

	var host := ModeCard.new()
	host.title = "Mở phòng LAN"
	host.subtitle = "Máy này làm chủ phòng, đối thủ vào bằng IP"
	host.tint = Color("38bdf8")
	host.icon = ModeCard.Icon.ANTENNA
	host.custom_minimum_size = Vector2(0, 72)
	host.pressed.connect(_start_host)
	left.add_child(host)

	# --- Chọn độ khó bot ---
	left.add_child(_label("ĐỘ KHÓ BOT", 12, Color(1, 1, 1, 0.4)))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	left.add_child(diff_row)
	var _diff_buttons: Array[Button] = []
	for diff_data in [["Dễ", GameData.Difficulty.EASY, Color("4ade80")],
					  ["Trung bình", GameData.Difficulty.NORMAL, Color("fbbf24")],
					  ["Khó", GameData.Difficulty.HARD, Color("f87171")]]:
		var dbtn := Button.new()
		dbtn.text = diff_data[0]
		dbtn.custom_minimum_size = Vector2(0, 32)
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.add_theme_font_size_override("font_size", 13)
		var dcol: Color = diff_data[2]
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(dcol.r * 0.2, dcol.g * 0.2, dcol.b * 0.2, 0.9)
		dsb.border_color = Color(dcol.r, dcol.g, dcol.b, 0.6)
		dsb.set_border_width_all(1)
		dsb.set_corner_radius_all(6)
		dbtn.add_theme_stylebox_override("normal", dsb)
		var dhover := dsb.duplicate() as StyleBoxFlat
		dhover.bg_color = Color(dcol.r * 0.35, dcol.g * 0.35, dcol.b * 0.35, 1.0)
		dhover.border_color = Color(dcol.r, dcol.g, dcol.b, 1.0)
		dbtn.add_theme_stylebox_override("hover", dhover)
		dbtn.add_theme_stylebox_override("pressed", dhover)
		var dpressed := dsb.duplicate() as StyleBoxFlat
		dpressed.bg_color = Color(dcol.r * 0.5, dcol.g * 0.5, dcol.b * 0.5, 1.0)
		dpressed.border_color = Color(dcol.r, dcol.g, dcol.b, 1.0)
		dbtn.add_theme_stylebox_override("focus", dpressed)
		dbtn.add_theme_stylebox_override("disabled", dpressed)
		var diff_val: int = diff_data[1]
		dbtn.pressed.connect(func() -> void:
			Game.pending_bot_difficulty = diff_val
			Audio.play(&"ui_click")
			# Cập nhật trạng thái bấm của cả ba nút.
			for b in _diff_buttons:
				b.disabled = false
			dbtn.disabled = true)
		diff_row.add_child(dbtn)
		_diff_buttons.append(dbtn)
	# Mặc định chọn Trung bình.
	_diff_buttons[1].disabled = true

	left.add_child(_label("Máy này: %s" % GameData.get_local_ip(), 13,
		Color(0.6, 0.9, 1.0, 0.75)))

	# --- Cột phải: vào phòng có sẵn ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	right.add_child(_label("PHÒNG TÌM THẤY TRONG MẠNG LAN", 13, Color(1, 1, 1, 0.45)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_server_box = VBoxContainer.new()
	_server_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_server_box)
	_refresh_servers(Net.found_servers())

	right.add_child(_label("HOẶC NHẬP IP MÁY CHỦ", 13, Color(1, 1, 1, 0.45)))
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	right.add_child(ip_row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.10"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.custom_minimum_size = Vector2(0, 38)
	_style_input(_ip_edit)
	ip_row.add_child(_ip_edit)
	var join := Button.new()
	join.text = "Vào phòng"
	join.custom_minimum_size = Vector2(110, 38)
	_style_button(join, Color("22d3ee"))
	join.pressed.connect(func() -> void: _start_join())
	ip_row.add_child(join)

	# Lối vào màn hướng dẫn: người muốn đánh xa nhau qua internet (PC với
	# điện thoại) sẽ cần Tailscale — nhấn để xem 3 bước, không phải đoán mò.
	var online_help := Button.new()
	online_help.text = "Chơi qua Internet với bạn ở xa? Xem hướng dẫn 3 bước ›"
	online_help.custom_minimum_size = Vector2(0, 32)
	_style_button(online_help, Color("a78bfa"))
	online_help.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		_show(Screen.ONLINE_HELP))
	right.add_child(online_help)

	root.add_child(_back_button())

# ============================================================ MÀN CHỌN BẢN ĐỒ

func _build_map() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_content.add_child(root)

	root.add_child(_screen_title("CHỌN BẢN ĐỒ", "Mỗi đấu trường có quy luật riêng"))

	var cols := GridContainer.new()
	cols.columns = 2
	cols.add_theme_constant_override("h_separation", 14)
	cols.add_theme_constant_override("v_separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	for map_type in GameData.MAP_ORDER:
		var info: Dictionary = GameData.MAP_INFO.get(map_type, {})
		var card := ModeCard.new()
		card.title = str(info.get("name", "Bản đồ"))
		card.subtitle = str(info.get("tagline", ""))
		card.tint = info.get("color", Color.WHITE)
		# Hình thu nhỏ sân đấu thật thay vì icon phong cảnh chung chung.
		card.map_preview = int(map_type)
		card.custom_minimum_size = Vector2(0, 112)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mt := map_type
		card.pressed.connect(func() -> void:
			_pending_map = mt
			Audio.play(&"ui_click")
			_show(Screen.CHAMPION))
		cols.add_child(card)

	var hint := Label.new()
	hint.text = str(GameData.MAP_INFO.get(_pending_map, {}).get("hint", ""))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	root.add_child(_back_button())

# ========================================================== MÀN CHỌN TƯỚNG

func _build_champion() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_content.add_child(root)

	var heading := "CHỌN TƯỚNG"
	if _pending_mode == GameData.Mode.PRACTICE:
		heading = "CHỌN TƯỚNG ĐỂ LUYỆN"
	root.add_child(_screen_title(heading,
		"Bấm vào thẻ tướng để xem bộ kỹ năng và mẹo combo"))

	# ========= KHUNG CHÍNH: LƯỚI THẺ | BỆ TRƯNG BÀY 2.5D | THẺ CHI TIẾT =========
	# Bản cũ nhồi ba tầng DỌC (dashboard 270px + hàng nút + preview 210px):
	# tổng cao vượt màn 720p nên các tầng đè lên nhau. Bản này xếp NGANG ba
	# cột, mỗi cột cuộn riêng — không tầng nào chồng tầng nào nữa.
	_arena_preview = null
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	# --- Cột trái: lưới thẻ tướng 5×4, cuộn dọc khi thiếu chỗ ---
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main.add_child(grid_scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid)

	_portraits.clear()
	for id in GameData.champion_ids():
		var portrait := ChampionPortrait.new()
		portrait.champion_id = id
		portrait.custom_minimum_size = Vector2(96, 118)
		portrait.pressed.connect(_select_champion)
		grid.add_child(portrait)
		_portraits[String(id)] = portrait

	# --- Cột giữa: bệ đá trưng bày tướng 2.5D + hàng chọn đối thủ ---
	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 8)
	center_col.custom_minimum_size = Vector2(250, 0)
	main.add_child(center_col)

	_pedestal = ChampionPedestalClass.new()
	center_col.add_child(_pedestal)
	# Đặt sau add_child để đè lên default trong _ready của bệ.
	_pedestal.custom_minimum_size = Vector2(250, 292)

	if _pending_mode == GameData.Mode.SOLO or _pending_mode == GameData.Mode.PRACTICE:
		var enemy_col := VBoxContainer.new()
		enemy_col.add_theme_constant_override("separation", 4)
		center_col.add_child(enemy_col)
		enemy_col.add_child(_label("ĐỐI THỦ (BOT)", 11, Color(1, 0.65, 0.45, 0.85)))
		var enemy_scroll := ScrollContainer.new()
		enemy_scroll.custom_minimum_size = Vector2(0, 46)
		enemy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		enemy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		enemy_col.add_child(enemy_scroll)
		var enemy_strip := HBoxContainer.new()
		enemy_strip.add_theme_constant_override("separation", 6)
		enemy_scroll.add_child(enemy_strip)
		for id in GameData.champion_ids():
			var p := ChampionPortrait.new()
			p.champion_id = id
			p.compact = true
			p.custom_minimum_size = Vector2(40, 42)
			p.pressed.connect(_select_enemy_champion)
			enemy_strip.add_child(p)

	# --- Cột phải: thẻ chi tiết + bộ kỹ năng, cuộn dọc ---
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(330, 0)
	right_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# KHE CẮM ART: giấy da PNG cho panel chi tiết; thiếu ảnh thì dùng style
	# kính tối như cũ, cả hai đường đều giữ chữ đọc được.
	var parchment := ArtLibrary.ui_texture("panel_parchment")
	if parchment != null:
		var parchment_sb := StyleBoxTexture.new()
		parchment_sb.texture = parchment
		# Phủ lớp tối để chữ trắng vẫn nổi trên nền giấy sáng.
		parchment_sb.modulate_color = Color(0.32, 0.30, 0.38, 0.94)
		parchment_sb.texture_margin_left = 14.0
		parchment_sb.texture_margin_right = 14.0
		parchment_sb.texture_margin_top = 12.0
		parchment_sb.texture_margin_bottom = 12.0
		parchment_sb.content_margin_left = 4.0
		parchment_sb.content_margin_right = 4.0
		parchment_sb.content_margin_top = 4.0
		parchment_sb.content_margin_bottom = 4.0
		right_card.add_theme_stylebox_override("panel", parchment_sb)
	else:
		var right_sb := StyleBoxFlat.new()
		right_sb.bg_color = Color(0.06, 0.07, 0.10, 0.92)
		right_sb.border_color = Color(0.25, 0.30, 0.42, 0.8)
		right_sb.set_border_width_all(2)
		right_sb.set_corner_radius_all(10)
		right_card.add_theme_stylebox_override("panel", right_sb)
	main.add_child(right_card)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_card.add_child(right_margin)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_margin.add_child(detail_scroll)

	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_box)

	# --- Hàng nút hành động ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	actions.add_child(_back_button())

	var rand := _big_button("NGẪU NHIÊN", "Chọn ngẫu nhiên cho bạn và đối thủ",
		Color("a78bfa"), 48)
	rand.custom_minimum_size = Vector2(170, 0)
	rand.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		var ids := GameData.champion_ids()
		_select_champion(ids[randi() % ids.size()])
		_select_enemy_champion(ids[randi() % ids.size()])
	)
	actions.add_child(rand)

	var start := _big_button("BẮT ĐẦU", _start_caption(), Color("ff7a2f"), 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_start_match)
	actions.add_child(start)

	# Giữ lựa chọn TÍCH SỮ từ lần gọi _select_champion trước khi màn kịp dựng
	# (ví dụ tool chụp ảnh gọi _show(3) rồi gọi _select_champion ngay — _show
	# đi qua tween fade nên build bị hoãn 0.12s). Không có selection hợp lệ
	# mới mặc định fire_mage.
	var initial: StringName = _selected \
		if GameData.CHAMPION_SCRIPTS.has(_selected) else &"fire_mage"
	_select_champion(initial)
	_select_enemy_champion(_enemy_selected)

## Chọn tướng cho bot (chỉ trong SOLO / PRACTICE).
func _select_enemy_champion(id: StringName) -> void:
	_enemy_selected = id
	Audio.play(&"ui_select")
	# Cập nhật viền sáng cho ảnh đại diện bot.
	for key in _portraits.keys():
		var p: ChampionPortrait = _portraits[key]
		p.bot_selected = StringName(key) == id

func _start_caption() -> String:
	match _pending_mode:
		GameData.Mode.PRACTICE:
			return "Vào phòng luyện tập"
		_:
			return "Vào trận với bot"

# =========================================================== MÀN CÀI ĐẶT

## Màn hướng dẫn chơi qua Internet: 3 bước cài Tailscale để hai thiết bị
## ở hai mạng khác nhau thấy nhau như trong cùng một mạng LAN.
##
## Vì sao là Tailscale: game chỉ có chế độ LAN (Host/Join bằng IP). Tailscale
## cấp cho mỗi thiết bị một địa chỉ 100.x.y.z cố định, đánh nhau qua internet
## mà không cần mở port trên router — đúng mức hiểu biết của người mới.
func _build_online_help() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_content.add_child(box)

	box.add_child(_screen_title("CHƠI QUA INTERNET — 3 BƯỚC",
		"Hai thiết bị ở hai mạng khác nhau, không cần mở port router"))

	var steps := [
		["1", "Cài Tailscale cho CẢ HAI thiết bị",
			"Máy tính và điện thoại đều tải tại tailscale.com/download, "
			+ "rồi đăng nhập cùng MỘT tài khoản. Bật Tailscale trên cả hai trước khi chơi."],
		["2", "Máy tính tạo phòng",
			"Vào \"Chơi với bạn\" → TẠO PHÒNG. Màn hình hiện một địa chỉ IP "
			+ "dạng 100.x.y.z — đây là địa chỉ của máy bạn trong mạng ảo Tailscale."],
		["3", "Điện thoại tham gia phòng",
			"Trên thiết bị của bạn bè: mở Tailscale trước, rồi vào THAM GIA PHÒNG "
			+ "và dán đúng địa chỉ 100.x.y.z vừa đọc. Kết nối xong là đánh được."],
	]
	for step in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)

		var num := Label.new()
		num.text = str(step[0])
		num.add_theme_font_size_override("font_size", 26)
		num.add_theme_color_override("font_color", Color("a78bfa"))
		num.custom_minimum_size = Vector2(30, 0)
		row.add_child(num)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)

		col.add_child(_label(str(step[1]), 15, Color(1, 1, 1, 0.9)))
		var detail := Label.new()
		detail.text = str(step[2])
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 13)
		detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.58))
		col.add_child(detail)

	var note := Label.new()
	note.text = ("Lưu ý: cả hai thiết bị phải đang BẬT Tailscale cùng lúc. "
		+ "Nếu kết nối chậm, thử bật chữ Key expiry = off trong trang quản trị Tailscale.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	box.add_child(note)

func _build_settings() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_content.add_child(root)

	root.add_child(_screen_title("CÀI ĐẶT", "Mọi thay đổi được lưu lại cho lần sau"))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# --- Cột trái: âm thanh và điều khiển ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(420, 0)
	cols.add_child(left)

	left.add_child(_label("ÂM THANH", 13, Color(1, 1, 1, 0.45)))
	left.add_child(_slider_row("Âm lượng chung", Settings.master_volume,
		func(v: float) -> void:
			Settings.master_volume = v
			Settings.save_settings()))
	left.add_child(_slider_row("Hiệu ứng kỹ năng", Settings.sound_volume,
		func(v: float) -> void:
			Settings.sound_volume = v
			Settings.save_settings()
			Audio.refresh_volume()))
	left.add_child(_slider_row("Rung màn hình", Settings.screen_shake / 2.0,
		func(v: float) -> void:
			Settings.screen_shake = v * 2.0
			Settings.save_settings()))

	left.add_child(_label("CÂN BẰNG TRẬN ĐẤU", 13, Color(1, 0.8, 0.45, 0.85)))
	left.add_child(_hp_slider_row("Độ dài trận (% Máu)", Settings.hp_multiplier,
		func(v: float) -> void:
			Settings.hp_multiplier = v
			Settings.save_settings()))

	left.add_child(_label("ĐIỀU KHIỂN", 13, Color(1, 1, 1, 0.45)))
	var keys := _big_button("GÁN PHÍM", "Đổi phím di chuyển, kỹ năng, đánh thường",
		Color("a78bfa"), 52)
	keys.pressed.connect(_open_keybinds)
	left.add_child(keys)

	var touch_check := CheckBox.new()
	touch_check.text = "Hiện nút cảm ứng trên màn hình"
	touch_check.add_theme_font_size_override("font_size", 14)
	touch_check.button_pressed = Settings.show_touch_controls
	touch_check.toggled.connect(func(on: bool) -> void:
		Settings.show_touch_controls = on
		Settings.save_settings())
	left.add_child(touch_check)

	# --- Cột phải: hướng dẫn nhanh ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	right.add_child(_label("CÁCH CHƠI", 13, Color(1, 1, 1, 0.45)))
	var guide := Label.new()
	guide.text = (
		"Di chuyển bằng WASD, ngắm bằng chuột.\n\n"
		+ "Chuột trái là đánh thường — giữ để đánh liên tục.\n\n"
		+ "Bấm Q E R F để chọn kỹ năng. Kỹ năng cần hướng hoặc cần vùng sẽ hiện "
		+ "vòng phạm vi trước; bấm chuột trái lần nữa để dùng, chuột phải để huỷ.\n\n"
		+ "Cuộn chuột để zoom camera, Tab mở bảng điều khiển trong phòng luyện tập, "
		+ "ESC để lùi lại một bước."
	)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 14)
	guide.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(guide)

	root.add_child(_back_button())

func _open_keybinds() -> void:
	if _keybinds != null:
		return
	_keybinds = KeybindsPanel.new()
	add_child(_keybinds)
	_keybinds.closed.connect(func() -> void:
		_keybinds.queue_free()
		_keybinds = null)

# --------------------------------------------------------------- chọn tướng

func _select_champion(id: StringName) -> void:
	_selected = id
	for key in _portraits.keys():
		var p: ChampionPortrait = _portraits[key]
		p.selected = StringName(key) == id
	_show_champion_detail(id)
	if _pedestal != null:
		_pedestal.set_champion(id)
	if _arena_preview != null:
		_arena_preview.set_champion(id)
	if _backdrop != null:
		# Đổi luôn tướng đứng ở nền cho khớp với lựa chọn.
		_backdrop.right_champion = id
	Audio.play(&"ui_select")

## Mô tả chi tiết: ảnh lớn + tên/vai trò/tagline + mẹo combo + danh sách kỹ năng.
func _show_champion_detail(id: StringName) -> void:
	# Guard null: _select_champion có thể được gọi NGAY SAU _show() trong khi
	# màn chưa dựng xong (_show đi qua tween fade 0.12s) — _detail_box vẫn null.
	if _detail_box == null:
		return
	for c in _detail_box.get_children():
		c.queue_free()

	var info: Dictionary = GameData.CHAMPION_INFO.get(id, {})
	var col: Color = GameData.champion_color(id)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.custom_minimum_size = Vector2(0, 168)
	_detail_box.add_child(head)

	var big := ChampionPortrait.new()
	big.champion_id = id
	big.selected = true
	big.custom_minimum_size = Vector2(132, 168)
	big.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(big)

	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 5)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(meta)

	var name_lbl := Label.new()
	name_lbl.text = str(info.get("name", id))
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", col)
	meta.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.text = str(info.get("role", ""))
	role_lbl.add_theme_font_size_override("font_size", 14)
	role_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	meta.add_child(role_lbl)

	var tag := Label.new()
	tag.text = str(info.get("tagline", ""))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(tag)

	# Mẹo combo đặt ngay cạnh tên tướng — đây là thứ người chơi cần đọc nhất.
	var hint := Label.new()
	hint.text = "MẸO COMBO:  " + str(GameData.COMBO_HINTS.get(id, ""))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 0.86, 0.7, 0.85))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(hint)

	# --- Nội tại: hiện thành một thẻ riêng vì nó là điểm khác biệt giữa các tướng ---
	var pv := GameData.champion_passive_info(id)
	if not pv.is_empty():
		var pv_box := VBoxContainer.new()
		pv_box.add_theme_constant_override("separation", 1)
		meta.add_child(pv_box)

		var pv_name := Label.new()
		pv_name.text = "NỘI TẠI — " + str(pv["name"])
		pv_name.add_theme_font_size_override("font_size", 14)
		pv_name.add_theme_color_override("font_color", col.lightened(0.35))
		pv_box.add_child(pv_name)

		var pv_desc := Label.new()
		pv_desc.text = str(pv["description"])
		pv_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv_desc.add_theme_font_size_override("font_size", 12)
		pv_desc.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.85))
		pv_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv_box.add_child(pv_desc)

	# --- Danh sách kỹ năng ---
	_detail_box.add_child(_label("BỘ KỸ NĂNG", 13, Color(1, 1, 1, 0.45)))

	var script: GDScript = GameData.champion_script(id)
	if script != null:
		var builder: Object = script.new()
		if builder.has_method("skill_preview"):
			var skills: Array = builder.skill_preview()
			var labels := InputSetup.skill_key_labels()
			for i in range(skills.size()):
				var s: SkillBase = skills[i]
				var key_text := labels[i] if i < labels.size() else s.key_label
				_detail_box.add_child(_skill_row(s, key_text))
			if builder.has_method("basic_attack_preview"):
				var basic = builder.basic_attack_preview()
				if basic != null:
					var atk_label := labels[4] if labels.size() > 4 else "LMB"
					_detail_box.add_child(_skill_row(basic, atk_label))

## Một dòng kỹ năng: thẻ phím + tên + loại chiêu + mô tả.
func _skill_row(s: SkillBase, key_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 44)

	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(60, 34)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slot_texture := ArtLibrary.ui_texture("skill_slot")
	var chip_sb: StyleBox
	if slot_texture != null:
		var textured_sb := StyleBoxTexture.new()
		textured_sb.texture = slot_texture
		textured_sb.modulate_color = Color(1, 1, 1, 0.82)
		textured_sb.texture_margin_left = 8.0
		textured_sb.texture_margin_right = 8.0
		textured_sb.texture_margin_top = 6.0
		textured_sb.texture_margin_bottom = 6.0
		chip_sb = textured_sb
	else:
		var fallback_sb := StyleBoxFlat.new()
		fallback_sb.bg_color = Color(s.icon_color.r * 0.2, s.icon_color.g * 0.2,
			s.icon_color.b * 0.2, 1.0)
		fallback_sb.border_color = s.icon_color
		fallback_sb.set_border_width_all(1)
		fallback_sb.set_corner_radius_all(9)
		chip_sb = fallback_sb
	chip.add_theme_stylebox_override("panel", chip_sb)
	var chip_lbl := Label.new()
	chip_lbl.text = key_text
	chip_lbl.add_theme_font_size_override("font_size", 14)
	chip_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	chip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(chip_lbl)
	row.add_child(chip)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	text.add_child(head)

	var n := Label.new()
	n.text = s.display_name
	n.add_theme_font_size_override("font_size", 15)
	n.add_theme_color_override("font_color", s.icon_color)
	head.add_child(n)

	var bits: Array[String] = [_cast_type_label(s.cast_type)]
	if s.mana_cost > 0.0:
		bits.append("%d năng lượng" % int(s.mana_cost))
	bits.append("hồi %.1fs" % s.cooldown)
	var cost := Label.new()
	cost.text = " · ".join(bits)
	cost.add_theme_font_size_override("font_size", 12)
	cost.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	head.add_child(cost)

	var d := Label.new()
	d.text = s.description.replace("\n", " ")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(d)

	return row

## Chữ mô tả loại chiêu, dùng ở menu để người chơi biết trước cách bấm.
func _cast_type_label(cast_type: int) -> String:
	match cast_type:
		SkillBase.CastType.GROUND:
			return "chọn vùng"
		SkillBase.CastType.SELF:
			return "quanh người"
		SkillBase.CastType.INSTANT:
			return "bấm là ra"
		_:
			return "theo hướng"

# ------------------------------------------------------------------ vào trận

func _start_match() -> void:
	_commit_name()
	Net.leave()
	Audio.stop_menu_music()
	Game.pending_mode = _pending_mode
	Game.pending_champion = _selected
	Game.pending_map = _pending_map
	Game.pending_enemy_champion = _enemy_selected
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _start_host() -> void:
	_commit_name()
	Audio.stop_menu_music()
	var err := Net.host_game(GameData.DEFAULT_PORT, Settings.player_name)
	if err != OK:
		_status.text = "Không mở được phòng. Cổng %d có thể đang bị chiếm." % GameData.DEFAULT_PORT
		return
	Net.players[1]["champion"] = _selected
	Game.pending_mode = GameData.Mode.HOST
	Game.pending_champion = _selected
	Game.pending_map = GameData.MapType.CLASSIC
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _start_join(ip: String = "") -> void:
	var target := ip if ip != "" else _ip_edit.text.strip_edges()
	if target == "":
		_status.text = "Nhập IP máy chủ, hoặc bấm vào một phòng trong danh sách."
		return
	_commit_name()
	Game.pending_champion = _selected
	Game.pending_map = GameData.MapType.CLASSIC
	_status.text = "Đang kết nối tới %s..." % target
	Net.join_game(target, GameData.DEFAULT_PORT)

func _commit_name() -> void:
	if _name_edit == null:
		return
	Settings.player_name = _name_edit.text.strip_edges()
	if Settings.player_name == "":
		Settings.player_name = "Người chơi"
	Settings.save_settings()

func _on_joined() -> void:
	# Gửi tên + tướng lên chủ phòng rồi mới vào sân, để host biết sinh tướng nào.
	Net.send_register(Settings.player_name, _selected)
	Audio.stop_menu_music()
	Game.pending_mode = GameData.Mode.CLIENT
	Game.pending_map = GameData.MapType.CLASSIC
	_status.text = "Đã kết nối. Đang vào sân..."
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_join_failed(reason: String) -> void:
	_status.text = reason

# ------------------------------------------------------------- danh sách phòng

func _refresh_servers(servers: Array) -> void:
	if _server_box == null or not is_instance_valid(_server_box):
		return
	for child in _server_box.get_children():
		child.queue_free()
	if servers.is_empty():
		_server_box.add_child(_label(
			"Chưa thấy phòng nào. Máy chủ cần bấm “Mở phòng LAN” trước.",
			12, Color(1, 1, 1, 0.38)))
		return
	for srv in servers:
		var b := Button.new()
		b.text = "%s   ·   %s" % [srv.get("name", "Combo Arena"), srv.get("ip", "?")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 13)
		_style_button(b, Color("38bdf8"))
		b.pressed.connect(_start_join.bind(str(srv.get("ip", ""))))
		_server_box.add_child(b)

# ------------------------------------------------------------------ tiện ích UI

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _screen_title(title: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	var ribbon := ArtLibrary.ui_texture("title_ribbon")
	if ribbon != null:
		var banner := TextureRect.new()
		banner.texture = ribbon
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.custom_minimum_size = Vector2(0, 42)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(banner)
	box.add_theme_constant_override("separation", 1)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	box.add_child(t)
	box.add_child(_label(subtitle, 14, Color(1, 1, 1, 0.5)))
	return box

## Nút lớn dùng ở màn tiêu đề và màn chọn tướng: tiêu đề đậm + dòng phụ nhỏ.
func _big_button(title: String, subtitle: String, tint: Color, height: int) -> Button:
	var b := Button.new()
	var normal_texture := ArtLibrary.ui_texture("button_normal")
	var hover_texture := ArtLibrary.ui_texture("button_hover")
	b.text = "%s\n%s" % [title, subtitle]
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 18)
	# Nút "đúc nổi" dark-fantasy: nền tối đậm màu tint, viền 2 lớp (tint + vát
	# sáng trên), bo góc lớn, và shadow nâu-tối trượt xuống dưới — nút đọc như
	# tấm kim loại dập nổi thay vì hình chữ nhật phẳng.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 0.92)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.65)
	sb.set_border_width_all(2)
	# Viền dày hơn ở ĐÁY = vát ánh sáng giả 3D trên nút.
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	if normal_texture != null:
		var textured_normal := StyleBoxTexture.new()
		textured_normal.texture = normal_texture
		textured_normal.modulate_color = Color(1, 1, 1, 0.96)
		textured_normal.texture_margin_left = 14.0
		textured_normal.texture_margin_right = 14.0
		textured_normal.texture_margin_top = 10.0
		textured_normal.texture_margin_bottom = 10.0
		b.add_theme_stylebox_override("normal", textured_normal)
	else:
		b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r * 0.32, tint.g * 0.32, tint.b * 0.32, 1.0)
	hover.border_color = Color(tint.r, tint.g, tint.b, 1.0)
	hover.shadow_color = Color(tint.r, tint.g, tint.b, 0.4)
	hover.shadow_size = 10
	if hover_texture != null:
		var textured_hover := StyleBoxTexture.new()
		textured_hover.texture = hover_texture
		textured_hover.modulate_color = Color(1, 1, 1, 1.0)
		textured_hover.texture_margin_left = 14.0
		textured_hover.texture_margin_right = 14.0
		textured_hover.texture_margin_top = 10.0
		textured_hover.texture_margin_bottom = 10.0
		b.add_theme_stylebox_override("hover", textured_hover)
	else:
		b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	# Nhấn xuống: nút "lún" vào — mất shadow, nền tối đi.
	pressed.bg_color = Color(tint.r * 0.10, tint.g * 0.10, tint.b * 0.10, 1.0)
	pressed.shadow_size = 0
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	return b

func _back_button() -> Button:
	var b := Button.new()
	b.text = "‹  Quay lại"
	b.custom_minimum_size = Vector2(140, 54)
	b.add_theme_font_size_override("font_size", 15)
	_style_button(b, Color("94a3b8"))
	b.pressed.connect(_go_back)
	return b

func _style_input(edit: LineEdit) -> void:
	edit.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	edit.add_theme_stylebox_override("normal", sb)
	var focus := sb.duplicate() as StyleBoxFlat
	focus.border_color = Color("ff7a2f")
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))

func _style_button(b: Button, tint: Color) -> void:
	b.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 0.95)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 1.0)
	hover.border_color = Color(tint.r, tint.g, tint.b, 1.0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)

func _slider_row(caption: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 28)
	var cap := _label(caption, 13, Color(1, 1, 1, 0.72))
	cap.custom_minimum_size = Vector2(140, 0)
	row.add_child(cap)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = clampf(value, 0.0, 1.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 0)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row

func _hp_slider_row(caption: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 28)
	var cap := _label(caption, 13, Color(1, 0.85, 0.55, 0.9))
	cap.custom_minimum_size = Vector2(140, 0)
	row.add_child(cap)
	var s := HSlider.new()
	s.min_value = 1.0
	s.max_value = 3.0
	s.step = 0.25
	s.value = clampf(value, 1.0, 3.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 0)
	var val_label := _label("%d%%" % int(s.value * 100), 13, Color(1, 0.9, 0.6))
	val_label.custom_minimum_size = Vector2(45, 0)
	s.value_changed.connect(func(v: float) -> void:
		val_label.text = "%d%%" % int(v * 100)
		on_change.call(v)
	)
	row.add_child(s)
	row.add_child(val_label)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _screen != Screen.TITLE:
			_go_back()
			get_viewport().set_input_as_handled()
