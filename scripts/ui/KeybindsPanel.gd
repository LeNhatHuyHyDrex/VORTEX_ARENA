class_name KeybindsPanel
extends Control
## Màn hình tự gán phím.
##
## Cách dùng: bấm vào ô phím -> ô chuyển sang "Bấm phím mới..." -> bấm phím
## bất kỳ (hoặc nút chuột / nút tay cầm) là xong. Nếu phím đó đang được hành
## động khác dùng, hành động cũ tự nhả ra — tránh một phím kích hai việc.
##
## Panel được dựng thành lớp phủ đè lên menu chính, nên không cần đổi scene
## và giữ nguyên tướng đang chọn.

signal closed()

## Hành động nào được phép gán lại, theo thứ tự hiện ra.
const BINDABLE: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"basic_attack", &"skill_1", &"skill_2", &"skill_3", &"skill_4",
]

const GROUPS := [
	{"title": "Di chuyển", "actions": [&"move_up", &"move_down", &"move_left", &"move_right"]},
	{"title": "Tấn công", "actions": [&"basic_attack"]},
	{"title": "Kỹ năng", "actions": [&"skill_1", &"skill_2", &"skill_3", &"skill_4"]},
]

var _list: VBoxContainer
var _key_buttons: Dictionary = {}
var _capturing: StringName = &""
var _capture_button: Button = null
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	_build()
	_refresh()

func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	# Chỉ nhận sự kiện "nhấn xuống", bỏ qua di chuyển chuột và cần analog.
	var pressed := false
	if event is InputEventKey:
		var k := event as InputEventKey
		pressed = k.pressed and not k.echo
		if k.keycode == KEY_ESCAPE:
			_stop_capture()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	if not pressed:
		return

	InputSetup.rebind(_capturing, event)
	_stop_capture()
	_refresh()
	get_viewport().set_input_as_handled()

func _build() -> void:
	# Lớp nền mờ, bấm ra ngoài khung thì đóng.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			closed.emit())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("12111a")
	sb.border_color = Color("ff7a2f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	root.add_child(_mk_label("ĐIỀU KHIỂN", 22, Color("ffd9b8")))
	root.add_child(_mk_label(
		"Bấm vào ô phím rồi bấm phím mới. Phím đang dùng cho việc khác sẽ tự nhả ra.",
		13, Color(1, 1, 1, 0.5)))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_hint = _mk_label("", 13, Color("ff9f5a"))
	root.add_child(_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	var reset := Button.new()
	reset.text = "Khôi phục mặc định"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.custom_minimum_size = Vector2(0, 40)
	_style_button(reset, Color("94a3b8"))
	reset.pressed.connect(func() -> void:
		InputSetup.reset_bindings()
		_refresh()
		_hint.text = "Đã đưa toàn bộ phím về mặc định.")
	row.add_child(reset)

	var done := Button.new()
	done.text = "Xong"
	done.custom_minimum_size = Vector2(140, 40)
	_style_button(done, Color("38bdf8"))
	done.pressed.connect(func() -> void: closed.emit())
	row.add_child(done)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_key_buttons.clear()

	for group in GROUPS:
		var g: Dictionary = group
		_list.add_child(_mk_label(str(g["title"]), 14, Color("ffb27a")))
		var actions: Array = g["actions"]
		for action in actions:
			_list.add_child(_build_row(StringName(str(action))))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_list.add_child(spacer)

func _build_row(action: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 38)

	var name_lbl := _mk_label(InputSetup.ACTION_LABELS.get(action, String(action)),
		14, Color(0.92, 0.92, 0.98))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var key_btn := Button.new()
	key_btn.custom_minimum_size = Vector2(150, 34)
	key_btn.text = InputSetup.primary_label(action)
	_style_button(key_btn, Color("7c7f8c"))
	key_btn.pressed.connect(func() -> void: _start_capture(action, key_btn))
	row.add_child(key_btn)
	_key_buttons[String(action)] = key_btn

	var clear_btn := Button.new()
	clear_btn.text = "X"
	clear_btn.custom_minimum_size = Vector2(34, 34)
	_style_button(clear_btn, Color("94a3b8"))
	clear_btn.pressed.connect(func() -> void:
		InputSetup.clear_action(action)
		_refresh())
	row.add_child(clear_btn)

	return row

# ------------------------------------------------------------- bắt phím mới

func _start_capture(action: StringName, button: Button) -> void:
	_stop_capture()
	_capturing = action
	_capture_button = button
	button.text = "Bấm phím mới..."
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.48, 0.18, 0.35)
	sb.border_color = Color("ff7a2f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", sb)
	_hint.text = "Đang chờ phím cho “%s”. Bấm Esc để huỷ." % [
		InputSetup.ACTION_LABELS.get(action, String(action))]

func _stop_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_style_button(_capture_button, Color("7c7f8c"))
	_capturing = &""
	_capture_button = null
	_hint.text = ""

# ------------------------------------------------------------------ tiện ích

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _style_button(b: Button, tint: Color) -> void:
	b.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.18, tint.g * 0.18, tint.b * 0.18, 0.95)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 1.0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
