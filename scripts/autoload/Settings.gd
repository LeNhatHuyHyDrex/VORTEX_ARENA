extends Node
## Cấu hình người dùng, lưu vào user://settings.cfg (hoạt động cả trên Windows
## lẫn Android — Godot tự ánh xạ user:// vào thư mục ghi được của từng nền tảng).

const PATH := "user://settings.cfg"

## Phát ra khi bảng phím thay đổi, để InputSetup nạp lại ngay.
signal bindings_changed()

var player_name := "Người chơi"
var master_volume := 0.8
var show_touch_controls := false   # tự bật khi phát hiện nền tảng cảm ứng
var screen_shake := 1.0            # 0 = tắt, 1 = bình thường
var sound_volume := 0.9
## Bảng phím người chơi tự gán: tên action -> mảng mô tả event.
## Rỗng nghĩa là dùng mặc định trong InputSetup.
var bindings: Dictionary = {}
## Hệ số máu của tướng: 1.0 (100%), 1.5 (150%), 2.0 (200%), 2.5 (250%), 3.0 (300%).
## Tăng lên giúp trận đấu lâu hơn, kéo dài thời gian giao tranh và thử nghiệm combo.
var hp_multiplier: float = 1.0

func _ready() -> void:
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS":
		show_touch_controls = true
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	# Ép kiểu tường minh: get_value trả về Variant, gán thẳng vào biến có kiểu
	# sẽ bị Godot coi là lỗi.
	player_name = str(cfg.get_value("player", "name", player_name))
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	screen_shake = clampf(float(cfg.get_value("video", "screen_shake", screen_shake)), 0.0, 2.0)
	sound_volume = clampf(float(cfg.get_value("audio", "sfx", sound_volume)), 0.0, 1.0)
	hp_multiplier = clampf(float(cfg.get_value("gameplay", "hp_multiplier", hp_multiplier)), 0.5, 5.0)
	var saved_bindings: Variant = cfg.get_value("input", "bindings", {})
	if saved_bindings is Dictionary:
		bindings = saved_bindings
	if not OS.has_feature("mobile"):
		show_touch_controls = bool(cfg.get_value("input", "touch", show_touch_controls))
	_apply()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("audio", "sfx", sound_volume)
	cfg.set_value("gameplay", "hp_multiplier", hp_multiplier)
	cfg.set_value("input", "bindings", bindings)
	cfg.set_value("input", "touch", show_touch_controls)
	cfg.save(PATH)
	_apply()

func _apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
