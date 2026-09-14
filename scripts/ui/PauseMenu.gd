class_name PauseMenu
extends Control
## Menu tạm trong trận: Tiếp tục / Cài đặt / Về menu.
##
## Vì sao cần: trên điện thoại không có phím ESC, nên bản trước vào trận rồi là
## không có đường ra ngoài. Trên PC thì ESC vừa huỷ chiêu vừa thoát menu nên dễ
## bấm nhầm. Nút pause tách hẳn hai việc đó ra.
##
## Node này đặt `process_mode = ALWAYS` để vẫn bấm được khi cây scene bị tạm dừng.

signal resumed()
signal exit_requested()

var game: Game = null

var _panel: PanelContainer
var _keybinds: KeybindsPanel = null
var _settings_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Không tạm dừng node này, nếu không thì bấm nút sẽ không ăn.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	# Lớp nền mờ chặn mọi cú bấm lọt xuống game phía dưới.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(_panel)

	# Panel dark-fantasy: nền xanh-đen sâu, viền cam 2 lớp (mảnh ngoài + vát
	# sáng trong), shadow trượt xuống — panel đọc như tấm kim loại đúc dày
	# nổi lên khỏi lớp nền mờ phía sau.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("100f18")
	sb.border_color = Color("ff7a2f")
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	_panel.add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.99, 0.92, 0.85))
	root.add_child(title)

	# Nét phân cách kim loại dưới tiêu đề — gạch màu cam mảnh giữa hai vạch tối.
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color("ff7a2f")
	root.add_child(divider)

	root.add_child(_big("TIẾP TỤC", Color("38bdf8"), func() -> void: resumed.emit()))
	root.add_child(_big("CÀI ĐẶT ÂM THANH", Color("a78bfa"), _toggle_settings))

	# Khối cài đặt, ẩn sẵn — bấm nút trên mới hiện.
	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	root.add_child(_settings_box)
	_settings_box.add_child(_slider("Âm lượng chung", Settings.master_volume,
		func(v: float) -> void:
			Settings.master_volume = v
			Settings.save_settings()))
	_settings_box.add_child(_slider("Hiệu ứng", Settings.sound_volume,
		func(v: float) -> void:
			Settings.sound_volume = v
			Settings.save_settings()
			Audio.refresh_volume()))
	_settings_box.add_child(_slider("Rung màn hình", Settings.screen_shake / 2.0,
		func(v: float) -> void:
			Settings.screen_shake = v * 2.0
			Settings.save_settings()))

	root.add_child(_big("GÁN PHÍM", Color("7dd3fc"), _open_keybinds))
	root.add_child(_big("VỀ MENU CHÍNH", Color("f87171"), func() -> void: exit_requested.emit()))

	var hint := Label.new()
	hint.text = "Nhấn ESC hoặc P để đóng"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	root.add_child(hint)

func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible
	Audio.play(&"ui_click")

func _open_keybinds() -> void:
	if _keybinds != null:
		return
	_keybinds = KeybindsPanel.new()
	_keybinds.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_keybinds)
	_keybinds.closed.connect(func() -> void:
		_keybinds.queue_free()
		_keybinds = null)

func _big(text: String, tint: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 16)
	# Nút đúc nổi đồng bộ với MainMenu._big_button: viền đáy dày (vát 3D),
	# shadow trượt xuống, hover phát quầng màu tint, pressed lún vào.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 0.95)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.6)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(9)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r * 0.32, tint.g * 0.32, tint.b * 0.32, 1.0)
	hover.border_color = Color(tint.r, tint.g, tint.b, 1.0)
	hover.shadow_color = Color(tint.r, tint.g, tint.b, 0.35)
	hover.shadow_size = 8
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.r * 0.10, tint.g * 0.10, tint.b * 0.10, 1.0)
	pressed.shadow_size = 0
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		action.call())
	return b

func _slider(caption: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 26)
	var cap := Label.new()
	cap.text = caption
	cap.custom_minimum_size = Vector2(130, 0)
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	row.add_child(cap)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = clampf(value, 0.0, 1.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row
