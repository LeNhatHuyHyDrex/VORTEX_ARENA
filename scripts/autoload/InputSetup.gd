extends Node
## Bảng điều khiển, dựng bằng code và cho phép người chơi tự gán lại phím.
##
## Lịch sử: bản đầu dùng Q/W/E/R cho kỹ năng, nhưng W trùng với phím đi lên.
## Bản này đổi mặc định sang Q/E/R/F (bỏ trống W cho di chuyển) và gán thêm
## 1/2/3/4 làm phím phụ, ai quen kiểu nào cũng dùng được.
##
## Phím người chơi tự đổi được lưu trong Settings và nạp lại mỗi lần mở game.

## Bốn action kỹ năng, đúng thứ tự bit trong cast_mask.
const SKILL_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3", &"skill_4"]

const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const AIM_ACTIONS: Array[StringName] = [&"aim_up", &"aim_down", &"aim_left", &"aim_right"]
const ATTACK_ACTION := &"basic_attack"
## Huỷ chiêu đang chờ chọn vùng. Tách thành action riêng để người chơi gán lại
## được, và để nó không lẫn với ESC (ESC còn dùng để thoát về menu).
const CANCEL_ACTION := &"cancel_cast"

## Tên hiển thị trong màn hình gán phím.
const ACTION_LABELS := {
	&"move_up": "Đi lên",
	&"move_down": "Đi xuống",
	&"move_left": "Đi sang trái",
	&"move_right": "Đi sang phải",
	&"basic_attack": "Đánh thường / Xác nhận chiêu",
	&"cancel_cast": "Huỷ chiêu đang chọn",
	&"skill_1": "Kỹ năng 1",
	&"skill_2": "Kỹ năng 2",
	&"skill_3": "Kỹ năng 3",
	&"skill_4": "Kỹ năng 4",
}

## Phím mặc định. Mỗi phần tử là một mô tả event:
##   {"t":"key",  "k": <KEY_*>}
##   {"t":"mouse","b": <MOUSE_BUTTON_*>}
##   {"t":"btn",  "b": <JOY_BUTTON_*>}
##   {"t":"axis", "a": <JOY_AXIS_*>, "v": <hướng>}
const DEFAULT_BINDINGS := {
	&"move_up": [
		{"t": "key", "k": KEY_W}, {"t": "key", "k": KEY_UP},
		{"t": "axis", "a": JOY_AXIS_LEFT_Y, "v": -1.0},
	],
	&"move_down": [
		{"t": "key", "k": KEY_S}, {"t": "key", "k": KEY_DOWN},
		{"t": "axis", "a": JOY_AXIS_LEFT_Y, "v": 1.0},
	],
	&"move_left": [
		{"t": "key", "k": KEY_A}, {"t": "key", "k": KEY_LEFT},
		{"t": "axis", "a": JOY_AXIS_LEFT_X, "v": -1.0},
	],
	&"move_right": [
		{"t": "key", "k": KEY_D}, {"t": "key", "k": KEY_RIGHT},
		{"t": "axis", "a": JOY_AXIS_LEFT_X, "v": 1.0},
	],
	# Ngắm bằng cần phải tay cầm; trên PC vẫn ngắm bằng chuột.
	&"aim_up": [{"t": "axis", "a": JOY_AXIS_RIGHT_Y, "v": -1.0}],
	&"aim_down": [{"t": "axis", "a": JOY_AXIS_RIGHT_Y, "v": 1.0}],
	&"aim_left": [{"t": "axis", "a": JOY_AXIS_RIGHT_X, "v": -1.0}],
	&"aim_right": [{"t": "axis", "a": JOY_AXIS_RIGHT_X, "v": 1.0}],
	&"basic_attack": [
		{"t": "mouse", "b": MOUSE_BUTTON_LEFT},
		{"t": "btn", "b": JOY_BUTTON_A},
	],
	# Chuột phải để huỷ chiêu đang chờ. ESC cũng huỷ được nhưng ESC còn kiêm
	# việc thoát về menu nên không đưa vào bảng gán phím.
	&"cancel_cast": [
		{"t": "mouse", "b": MOUSE_BUTTON_RIGHT},
		{"t": "btn", "b": JOY_BUTTON_B},
	],
	# Kỹ năng: Q/E/R/F là chính, 1/2/3/4 là phím phụ. Cố ý bỏ trống W.
	&"skill_1": [
		{"t": "key", "k": KEY_Q}, {"t": "key", "k": KEY_1},
		{"t": "btn", "b": JOY_BUTTON_X},
	],
	&"skill_2": [
		{"t": "key", "k": KEY_E}, {"t": "key", "k": KEY_2},
		{"t": "btn", "b": JOY_BUTTON_Y},
	],
	&"skill_3": [
		{"t": "key", "k": KEY_R}, {"t": "key", "k": KEY_3},
		{"t": "btn", "b": JOY_BUTTON_LEFT_SHOULDER},
	],
	&"skill_4": [
		{"t": "key", "k": KEY_F}, {"t": "key", "k": KEY_4},
		{"t": "btn", "b": JOY_BUTTON_RIGHT_SHOULDER},
	],
}

func _ready() -> void:
	Settings.bindings_changed.connect(apply_bindings)
	apply_bindings()

## Mọi action mà game dùng, gộp lại một chỗ.
func all_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(MOVE_ACTIONS)
	out.append_array(AIM_ACTIONS)
	out.append_array(SKILL_ACTIONS)
	out.append(ATTACK_ACTION)
	out.append(CANCEL_ACTION)
	return out

## Nạp lại toàn bộ bảng phím từ cài đặt (hoặc mặc định nếu chưa đổi gì).
func apply_bindings() -> void:
	for action in all_actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for desc in bindings_for(action):
			var ev := describe_to_event(desc)
			if ev != null:
				InputMap.action_add_event(action, ev)

## Danh sách mô tả event của một action: ưu tiên bản người chơi đã lưu.
func bindings_for(action: StringName) -> Array:
	var saved: Variant = Settings.bindings.get(String(action))
	if saved is Array and not (saved as Array).is_empty():
		return saved
	return DEFAULT_BINDINGS.get(action, [])

## Gán một phím mới cho action. Trả về true nếu thành công.
##
## Nếu phím đã được action khác dùng thì tự gỡ khỏi action cũ — tránh tình
## trạng một phím kích hoạt hai hành động cùng lúc.
func rebind(action: StringName, event: InputEvent) -> bool:
	var desc := event_to_describe(event)
	if desc.is_empty() or str(desc.get("t", "")) == "axis":
		return false   # không cho gán cần analog, dễ làm hỏng bảng phím

	for other in all_actions():
		if other == action:
			continue
		var list: Array = bindings_for(other).duplicate(true)
		var changed := false
		var i := list.size() - 1
		while i >= 0:
			if _same_binding(list[i], desc):
				list.remove_at(i)
				changed = true
			i -= 1
		if changed:
			Settings.bindings[String(other)] = list

	# Phím mới thay thế phím cùng loại của chính action này (bàn phím thay bàn
	# phím, chuột thay chuột) để không dồn thành một đống phím cũ.
	var mine: Array = bindings_for(action).duplicate(true)
	var filtered: Array = []
	for b in mine:
		if str(b.get("t", "")) != str(desc.get("t", "")):
			filtered.append(b)
	filtered.append(desc)
	Settings.bindings[String(action)] = filtered
	Settings.save_settings()
	apply_bindings()
	return true

## Xoá hết phím của một action (người chơi có thể để trống).
func clear_action(action: StringName) -> void:
	Settings.bindings[String(action)] = []
	Settings.save_settings()
	apply_bindings()

## Khôi phục toàn bộ về mặc định.
func reset_bindings() -> void:
	Settings.bindings.clear()
	Settings.save_settings()
	apply_bindings()

# ------------------------------------------------------- chuyển đổi mô tả

func describe_to_event(desc: Dictionary) -> InputEvent:
	match str(desc.get("t", "")):
		"key":
			var key_ev := InputEventKey.new()
			key_ev.physical_keycode = int(desc.get("k", 0))
			return key_ev
		"mouse":
			var mouse_ev := InputEventMouseButton.new()
			mouse_ev.button_index = int(desc.get("b", 1))
			return mouse_ev
		"btn":
			var btn_ev := InputEventJoypadButton.new()
			btn_ev.button_index = int(desc.get("b", 0))
			return btn_ev
		"axis":
			var axis_ev := InputEventJoypadMotion.new()
			axis_ev.axis = int(desc.get("a", 0))
			axis_ev.axis_value = float(desc.get("v", 1.0))
			return axis_ev
	return null

func event_to_describe(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return {"t": "key", "k": int(code)}
	if event is InputEventMouseButton:
		return {"t": "mouse", "b": int((event as InputEventMouseButton).button_index)}
	if event is InputEventJoypadButton:
		return {"t": "btn", "b": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		return {"t": "axis", "a": int(m.axis), "v": signf(m.axis_value)}
	return {}

## So sánh hai mô tả event. Phím bàn phím lưu ở khoá "k", chuột và nút tay
## cầm lưu ở khoá "b" nên phải tra cả hai.
func _same_binding(a: Dictionary, b: Dictionary) -> bool:
	var ta := str(a.get("t", ""))
	if ta != str(b.get("t", "")):
		return false
	match ta:
		"key":
			return int(a.get("k", -1)) == int(b.get("k", -2))
		"mouse", "btn":
			return int(a.get("b", -1)) == int(b.get("b", -2))
		"axis":
			return int(a.get("a", -1)) == int(b.get("a", -2))
	return false

## Mô tả phím bằng chữ để hiện lên nút trong màn hình gán phím.
func describe_label(desc: Dictionary) -> String:
	match str(desc.get("t", "")):
		"key":
			return OS.get_keycode_string(int(desc.get("k", 0)))
		"mouse":
			return _mouse_label(int(desc.get("b", 1)))
		"btn":
			return "Nút %d" % int(desc.get("b", 0))
		"axis":
			return "Cần analog"
	return "?"

func _mouse_label(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "Chuột trái"
		MOUSE_BUTTON_RIGHT:
			return "Chuột phải"
		MOUSE_BUTTON_MIDDLE:
			return "Chuột giữa"
	return "Chuột %d" % button

# ------------------------------------------------------------------ truy vấn

## Nhãn phím chính của một action, đọc từ bảng phím đang dùng.
##
## Ưu tiên phím bàn phím (vì dễ đọc nhất), rồi tới chuột, rồi nút tay cầm.
## Trả về "—" nếu action chưa có phím nào.
func primary_label(action: StringName) -> String:
	var list := bindings_for(action)
	var fallback := ""
	for desc in list:
		var label := describe_label(desc)
		if str(desc.get("t", "")) == "key":
			return label
		if fallback == "":
			fallback = label
	return fallback if fallback != "" else "—"

## 5 nhãn theo đúng thứ tự HUD: 4 kỹ năng rồi tới đánh thường.
## Gọi mỗi khi cần vẽ lại — người chơi đổi phím là chữ đổi theo ngay,
## không cần sửa từng file tướng.
func skill_key_labels() -> Array[String]:
	var out: Array[String] = []
	for action in SKILL_ACTIONS:
		out.append(primary_label(action))
	out.append(primary_label(ATTACK_ACTION))
	return out

## Vector di chuyển đã chuẩn hoá, dài tối đa 1.
func get_move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

## Hướng ngắm từ cần phải tay cầm. Trả về Vector2.ZERO nếu không đụng cần.
func get_stick_aim() -> Vector2:
	var v := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	return Vector2.ZERO if v.length() < 0.25 else v.normalized()
