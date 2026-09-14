extends Node
## Âm thanh của game, TỔNG HỢP BẰNG CODE chứ không dùng file ngoài.
##
## Vì sao không tải file âm thanh sẵn:
##   - Không vướng bản quyền. Mọi file trên mạng đều có điều kiện giấy phép, và
##     nếu sau này bạn phát hành game thì đó là rủi ro thật.
##   - Không phụ thuộc file ngoài: đổi cao độ, độ dài, âm sắc bằng cách sửa số.
##   - Dung lượng gần như bằng không.
##
## Cách hoạt động: dựng mẫu PCM bằng vài hàm sóng cơ bản (sine, vuông, răng cưa,
## nhiễu), ghép và bọc đường bao, rồi nhét vào AudioStreamWAV. Chạy một lần lúc
## khởi động, mất chưa tới 100ms.

const RATE := 22050
const POOL_SIZE := 20

var _bank: Dictionary = {}                 # tên -> AudioStream (WAV synth hoặc ogg pack)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer = null
var _menu_music: AudioStreamPlayer = null
var _champ_music: AudioStreamPlayer = null
var _map_ambient: AudioStreamPlayer = null

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_bank()
	_start_ambient()

# ------------------------------------------------------------------ phát tiếng

## Phát một hiệu ứng, không gắn với vị trí.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	# AudioStream (không còn AudioStreamWAV) vì bank giờ chứa cả ogg thật
	# từ pack SFX lẫn tiếng synth tự sinh.
	var stream: AudioStream = _bank.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = volume_db + _volume_offset()
	p.play()

## Phát hiệu ứng tại một vị trí trong thế giới, tự giảm âm theo khoảng cách
## tới camera. Đơn giản hơn AudioStreamPlayer2D và không cần quản lý vòng đời node.
func play_at(sound: StringName, world_pos: Vector2, volume_db: float = 0.0,
		pitch: float = 1.0) -> void:
	var cam := get_viewport().get_camera_2d()
	var atten := 0.0
	if cam != null:
		var dist := cam.global_position.distance_to(world_pos)
		atten = clampf(1.0 - dist / 1400.0, 0.0, 1.0)
		atten = atten * atten          # rơi nhanh theo bình phương cho tự nhiên
	if atten <= 0.01:
		return
	play(sound, volume_db + linear_to_db(atten), pitch)

## Phát với độ cao ngẫu nhiên quanh giá trị gốc — dùng cho tiếng lặp lại nhiều
## lần như trúng đòn, tránh nghe như máy.
func play_varied(sound: StringName, world_pos: Vector2, volume_db: float = 0.0,
		spread: float = 0.12) -> void:
	play_at(sound, world_pos, volume_db, randf_range(1.0 - spread, 1.0 + spread))

func _volume_offset() -> float:
	return linear_to_db(maxf(Settings.sound_volume, 0.0001))

# --------------------------------------------------------------- dựng kho tiếng

func _build_bank() -> void:
	# --- Giao diện ---
	_bank[&"ui_click"] = _wav(_decay(_osc(0.06, 950.0, 1500.0, OSC_SINE, 0.30), 3.0))
	_bank[&"ui_hover"] = _wav(_decay(_osc(0.04, 620.0, 820.0, OSC_SINE, 0.14), 3.0))
	_bank[&"ui_back"] = _wav(_decay(_osc(0.09, 700.0, 300.0, OSC_SINE, 0.24), 2.5))
	# Tiếng chọn tướng: hai nốt nhảy lên, nghe như "xác nhận".
	_bank[&"ui_select"] = _wav(_cat(
		_decay(_osc(0.07, 620.0, 940.0, OSC_TRIANGLE, 0.26), 3.0),
		_decay(_osc(0.10, 940.0, 1250.0, OSC_SINE, 0.22), 2.2)))

	# --- Hư Không Pháp Sư: âm kim loại, nhiều hơi thở, khác hẳn tông lửa/băng ---
	# Tia nhỏ: một tiếng "vút" cao và ngắn.
	_bank[&"void_bolt"] = _wav(_decay(_osc(0.10, 1180.0, 620.0, OSC_TRIANGLE, 0.22), 3.4))
	# Vụ nổ không gian: tiếng nổ có âm lượng riêng trầm phía dưới.
	_bank[&"void_blast"] = _wav(_mix(
		_decay(_noise(0.24, 0.42, 0.30), 2.0),
		_decay(_osc(0.26, 240.0, 60.0, OSC_SINE, 0.30), 1.8)))
	# Dịch chuyển: hai tiếng vút ngược chiều nhau, nghe như "biến mất rồi hiện ra".
	_bank[&"blink"] = _wav(_cat(
		_decay(_osc(0.09, 1400.0, 380.0, OSC_SINE, 0.24), 3.2),
		_decay(_osc(0.11, 420.0, 1500.0, OSC_SINE, 0.22), 2.6)))
	# Hố đen: tiếng trầm rung, dài, nghe như thứ gì đó đang nuốt không gian.
	_bank[&"black_hole"] = _wav(_mix(
		_decay(_osc(0.70, 90.0, 48.0, OSC_SINE, 0.34), 1.3),
		_decay(_noise(0.55, 0.20, 0.14), 1.5)))
	# Sụp đổ: nổ lớn, có tiếng kim loại vỡ phía trên.
	_bank[&"void_collapse"] = _wav(_mix(_mix(
		_decay(_noise(0.42, 0.60, 0.24), 1.6),
		_decay(_osc(0.40, 180.0, 42.0, OSC_SINE, 0.36), 1.5)),
		_decay(_osc(0.22, 900.0, 300.0, OSC_SQUARE, 0.14), 2.4)))

	# --- Trúng đòn / hạ gục ---
	_bank[&"hit"] = _wav(_mix(
		_decay(_noise(0.09, 0.55, 0.55), 2.2),
		_decay(_osc(0.09, 320.0, 90.0, OSC_SQUARE, 0.20), 2.0)))
	_bank[&"hit_big"] = _wav(_mix(
		_decay(_noise(0.24, 0.65, 0.30), 1.6),
		_decay(_osc(0.24, 200.0, 55.0, OSC_SINE, 0.45), 1.8)))
	_bank[&"death"] = _wav(_decay(
		_osc(0.75, 420.0, 60.0, OSC_SAW, 0.32, 1.6), 1.4))
	_bank[&"heal"] = _wav(_decay(
		_osc(0.42, 480.0, 880.0, OSC_SINE, 0.22, 0.7), 1.6))

	# --- Hỏa Pháp Sư ---
	_bank[&"fireball"] = _wav(_cat(
		_decay(_noise(0.20, 0.42, 0.22), 1.5),
		_decay(_osc(0.22, 430.0, 170.0, OSC_SAW, 0.24), 1.8)))
	_bank[&"fireball_burn"] = _wav(_decay(_noise(0.55, 0.30, 0.12), 1.2))
	_bank[&"firewall"] = _wav(_decay(
		_mix(_noise(0.6, 0.34, 0.10), _osc(0.6, 150.0, 90.0, OSC_SINE, 0.16)), 1.1))
	_bank[&"dash_fire"] = _wav(_decay(
		_mix(_noise(0.3, 0.40, 0.35), _osc(0.3, 260.0, 900.0, OSC_SINE, 0.20, 0.5)), 1.7))
	_bank[&"detonate"] = _wav(_cat(
		_decay(_noise(0.55, 0.85, 0.18), 1.5),
		_decay(_osc(0.55, 130.0, 38.0, OSC_SINE, 0.55), 1.3)))

	# --- Sát Thủ Bóng Tối ---
	_bank[&"slash"] = _wav(_mix(
		_decay(_noise(0.13, 0.45, 0.75), 2.4),
		_decay(_osc(0.13, 1800.0, 600.0, OSC_TRIANGLE, 0.20), 2.6)))
	_bank[&"slash_crit"] = _wav(_mix(_mix(
		_decay(_noise(0.18, 0.55, 0.85), 2.0),
		_decay(_osc(0.18, 2400.0, 700.0, OSC_TRIANGLE, 0.30), 2.2)),
		_decay(_osc(0.18, 1200.0, 350.0, OSC_SQUARE, 0.14), 2.2)))
	_bank[&"shadow_bolt"] = _wav(_decay(
		_mix(_noise(0.26, 0.34, 0.16), _osc(0.26, 620.0, 210.0, OSC_TRIANGLE, 0.22, 0.8)), 1.7))
	_bank[&"teleport"] = _wav(_decay(
		_osc(0.26, 1300.0, 240.0, OSC_SINE, 0.28, 0.6), 1.9))
	_bank[&"mark"] = _wav(_cat(
		_decay(_osc(0.3, 300.0, 520.0, OSC_SINE, 0.24, 0.8), 1.5),
		_decay(_osc(0.3, 520.0, 700.0, OSC_SINE, 0.16), 1.5)))
	_bank[&"execute"] = _wav(_cat(
		_decay(_noise(0.35, 0.70, 0.25), 1.6),
		_decay(_osc(0.5, 240.0, 48.0, OSC_SAW, 0.40, 1.4), 1.4)))

	# --- Va chạm đạn ---
	_bank[&"clash"] = _wav(_mix(_mix(
		_decay(_noise(0.16, 0.55, 0.9), 2.6),
		_decay(_osc(0.16, 2600.0, 900.0, OSC_SQUARE, 0.22), 3.0)),
		_decay(_osc(0.16, 900.0, 200.0, OSC_SINE, 0.20), 2.4)))
	_bank[&"clash_lose"] = _wav(_decay(
		_mix(_noise(0.13, 0.42, 0.7), _osc(0.13, 1400.0, 400.0, OSC_TRIANGLE, 0.20)), 2.6))
	_bank[&"clash_win"] = _wav(_cat(
		_decay(_noise(0.14, 0.60, 0.85), 2.4),
		_decay(_osc(0.2, 500.0, 900.0, OSC_SINE, 0.24), 2.0)))

	# --- Băng Sương ---
	_bank[&"ice_shard"] = _wav(_decay(
		_mix(_osc(0.24, 2200.0, 1500.0, OSC_SINE, 0.24),
			_osc(0.24, 3300.0, 2400.0, OSC_SINE, 0.12)), 2.0))
	_bank[&"ice_nova"] = _wav(_cat(
		_decay(_osc(0.4, 1800.0, 500.0, OSC_SINE, 0.30), 1.6),
		_decay(_noise(0.4, 0.35, 0.6), 1.6)))
	_bank[&"freeze"] = _wav(_decay(
		_mix(_osc(0.5, 900.0, 2600.0, OSC_SINE, 0.20),
			_decay(_noise(0.5, 0.22, 0.9), 1.0)), 1.4))

	# --- Lôi Đình ---
	_bank[&"thunder"] = _wav(_cat(
		_decay(_noise(0.12, 0.75, 0.95), 3.0),
		_decay(_noise(0.4, 0.40, 0.20), 1.5)))
	_bank[&"chain"] = _wav(_cat(
		_decay(_noise(0.1, 0.55, 0.9), 3.0),
		_decay(_noise(0.1, 0.42, 0.9), 3.0)))
	_bank[&"blink"] = _wav(_decay(
		_osc(0.14, 500.0, 1800.0, OSC_SQUARE, 0.22, 0.5), 2.4))

	# --- Thạch Vệ ---
	_bank[&"stone_throw"] = _wav(_decay(
		_mix(_noise(0.2, 0.45, 0.25), _osc(0.2, 190.0, 90.0, OSC_SQUARE, 0.22)), 2.0))
	_bank[&"stone_wall"] = _wav(_cat(
		_decay(_noise(0.22, 0.55, 0.20), 2.0),
		_decay(_osc(0.35, 150.0, 60.0, OSC_SINE, 0.38), 1.6)))
	_bank[&"shield"] = _wav(_decay(
		_mix(_osc(0.45, 620.0, 940.0, OSC_SINE, 0.22),
			_osc(0.45, 930.0, 1400.0, OSC_SINE, 0.12)), 1.7))

	# --- Vòng đấu ---
	_bank[&"countdown"] = _wav(_decay(_osc(0.14, 700.0, 700.0, OSC_SINE, 0.26), 2.2))
	_bank[&"fight"] = _wav(_cat(
		_decay(_osc(0.2, 500.0, 800.0, OSC_SAW, 0.30), 1.4),
		_decay(_osc(0.35, 800.0, 1200.0, OSC_SAW, 0.26), 1.4)))
	_bank[&"round_win"] = _wav(_cat(_cat(
		_decay(_osc(0.14, 660.0, 660.0, OSC_SINE, 0.26), 2.0),
		_decay(_osc(0.14, 880.0, 880.0, OSC_SINE, 0.26), 2.0)),
		_decay(_osc(0.3, 1180.0, 1180.0, OSC_SINE, 0.28), 1.6)))

	# --- Thời Sư ---
	# Tua ngược: tiếng "vút" lên rồi đổ xuống — nghe như kim đồng hồ quay nguợc.
	_bank[&"time_rewind"] = _wav(_cat(
		_decay(_osc(0.16, 320.0, 1900.0, OSC_SINE, 0.24, 0.7), 2.0),
		_decay(_osc(0.12, 1900.0, 420.0, OSC_SINE, 0.18, 1.3), 2.6)))

	# --- Pack SFX thật (80 CC0 RPG SFX, opengameart) ---
	# Nạp ogg từ res://assets/audio/rpg_sfx/ rồi ĐÈ lên các key tổng hợp cùng
	# tên. Thư mục không có (build thiếu asset) thì giữ nguyên tiếng synth —
	# game vẫn có âm thanh, chỉ là kém "thật" hơn.
	_override_bank_from_pack()

# ------------------------------------------------------------------ tổng hợp

## Bản đồ key -> file ogg trong pack 80 CC0 RPG SFX. Chọn theo "chất" nghe
## gần nhất: lửa dùng spell_fire, băng dùng spell, bóng tối dùng chain (tiếng
## kim loại kéo dài), sét dùng stones (tiếng nổ trầm), ...
const _SFX_PACK_DIR := "res://assets/audio/rpg_sfx/"
const _SFX_OVERRIDES := {
	&"fireball": "spell_fire_01.ogg",
	&"firewall": "spell_fire_02.ogg",
	&"dash_fire": "spell_fire_03.ogg",
	&"fireball_burn": "spell_fire_04.ogg",
	&"detonate": "spell_fire_05.ogg",
	&"ice_shard": "spell_01.ogg",
	&"ice_nova": "spell_02.ogg",
	&"freeze": "item_gem_01.ogg",
	&"shadow_bolt": "chain_01.ogg",
	&"teleport": "chain_02.ogg",
	&"blink": "chain_03.ogg",
	&"thunder": "stones_01.ogg",
	&"stone_throw": "stones_02.ogg",
	&"stone_wall": "stones_03.ogg",
	&"slash": "blade_01.ogg",
	&"slash_crit": "blade_02.ogg",
	&"hit": "blade_03.ogg",
	&"hit_big": "creature_hurt_01.ogg",
	&"death": "creature_die_01.ogg",
	&"clash": "metal_01.ogg",
	&"execute": "metal_02.ogg",
	&"shield": "metal_03.ogg",
	&"mark": "book_01.ogg",
	&"heal": "book_02.ogg",
	&"void_blast": "misc_01.ogg",
	&"void_bolt": "misc_02.ogg",
	&"void_collapse": "misc_03.ogg",
	&"black_hole": "misc_04.ogg",
}

func _override_bank_from_pack() -> void:
	for key: StringName in _SFX_OVERRIDES:
		var path := _SFX_PACK_DIR + String(_SFX_OVERRIDES[key])
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			_bank[key] = stream

const OSC_SINE := 0
const OSC_SQUARE := 1
const OSC_SAW := 2
const OSC_TRIANGLE := 3

## Sóng cơ bản, quét tần số từ f0 sang f1 trong suốt thời lượng.
func _osc(dur: float, f0: float, f1: float, kind: int, amp: float,
		curve: float = 1.0) -> PackedFloat32Array:
	var n := maxi(int(dur * float(RATE)), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, pow(t, curve))
		phase += TAU * f / float(RATE)
		var v := 0.0
		match kind:
			OSC_SINE:
				v = sin(phase)
			OSC_SQUARE:
				v = 1.0 if sin(phase) >= 0.0 else -1.0
			OSC_SAW:
				v = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			OSC_TRIANGLE:
				v = asin(sin(phase)) * (2.0 / PI)
		out[i] = v * amp
	return out

## Nhiễu trắng đã lọc thông thấp — nền tảng của tiếng nổ, tiếng lướt gió.
## cutoff càng nhỏ thì tiếng càng trầm và đục.
func _noise(dur: float, amp: float, cutoff: float) -> PackedFloat32Array:
	var n := maxi(int(dur * float(RATE)), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var prev := 0.0
	var alpha := clampf(cutoff, 0.005, 1.0)
	for i in range(n):
		var white := rng.randf_range(-1.0, 1.0)
		prev = prev + alpha * (white - prev)
		out[i] = prev * amp
	return out

## Bọc đường bao tắt dần: biên độ giảm theo (1-t)^power.
func _decay(src: PackedFloat32Array, power: float) -> PackedFloat32Array:
	var n := src.size()
	var out := src.duplicate()
	for i in range(n):
		var t := float(i) / float(maxf(float(n), 1.0))
		out[i] = out[i] * pow(1.0 - t, power)
	return out

## Trộn hai lớp âm thanh chồng lên nhau.
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = va + vb
	return out

## Nối hai đoạn âm thanh liên tiếp.
func _cat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size() + b.size())
	for i in range(a.size()):
		out[i] = a[i]
	for i in range(b.size()):
		out[a.size() + i] = b[i]
	return out

## Đóng gói mẫu PCM thành AudioStreamWAV để engine phát được.
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

# ---------------------------------------------------------------- nhạc nền

## Một lớp nền trầm rất nhẹ, lặp vô tận, để đấu trường không im lặng đến khô khan.
## Không phải nhạc — chỉ là không gian âm thanh.
func _start_ambient() -> void:
	var dur := 8.0
	var n := int(dur * float(RATE))
	var pad := PackedFloat32Array()
	pad.resize(n)
	# Ba nốt trầm lệch nhau chút tạo nhịp thở chậm.
	for i in range(n):
		var t := float(i) / float(RATE)
		var swell := 0.5 + 0.5 * sin(TAU * t / dur)
		var v := sin(TAU * 55.0 * t) * 0.5
		v += sin(TAU * 82.5 * t) * 0.3
		v += sin(TAU * 110.0 * t + 0.7) * 0.2
		pad[i] = v * 0.16 * (0.55 + 0.45 * swell)

	var wav := _wav(pad)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = wav
	_ambient.volume_db = -14.0 + _volume_offset()
	add_child(_ambient)
	_ambient.play()

## Bật/tắt nhạc nền, dùng cho màn hình cài đặt.
func set_ambient_enabled(on: bool) -> void:
	if _ambient == null:
		return
	if on and not _ambient.playing:
		_ambient.play()
	elif not on and _ambient.playing:
		_ambient.stop()

func refresh_volume() -> void:
	if _ambient != null:
		_ambient.volume_db = -14.0 + _volume_offset()

## Bắt đầu phát nền (gọi từ menu chính). Nhạc nền đã tự chạy từ _ready, nên
## hàm này chỉ đảm bảo nó đang bật — an toàn khi gọi nhiều lần.
func play_music() -> void:
	set_ambient_enabled(Settings.sound_volume > 0.01)

# ------------------------------------------------------------------ nhạc menu

func _build_music(dur: float, build_fn: Callable) -> AudioStreamWAV:
	var n := int(dur * float(RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	build_fn.call(buf, n, dur)
	var wav := _wav(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

## Nhạc nền menu: bản nhạc hùng tráng đọc vẽ bằng sequencer mã hoá.
##
## Cấu trúc: Am - F - C - G, 8 ô nhịp lặp vô tận, ~100 BPM:
##   - Pad hợp âm ba nốt, swell chậm như dàn dây.
##   - Bass đánh vào phách 1 và 3, envelope pluck.
##   - Arpeggio 8 nốt chạy liên tục (tam giác), tạo cảm giác "chạy về phía trước".
##   - Melody pentatonic xuất hiện ở ô 3-4 và 7-8 — có cái để người chơi ngân.
##   - Kick vào phách + hi-hat offbeat nhịp nhẹ.
## Mọi nốt viết thêm vào buffer bằng envelope riêng nên không bao giờ nổ tiếng.
func _start_menu_music() -> void:
	var wav := _build_music(19.2, _compose_menu_track)
	_menu_music = AudioStreamPlayer.new()
	_menu_music.stream = wav
	_menu_music.volume_db = -9.0 + _volume_offset()
	add_child(_menu_music)

## Trợ giúp viết một nốt vào buffer: sine/tam giác + envelope attack/decay.
## Nốt luôn bắt đầu ở pha 0 và envelope luôn về 0 ở hai đầu → không click.
func _seq_note(buf: PackedFloat32Array, start_t: float, freq: float, dur: float,
		amp: float, osc_kind: int = OSC_SINE, attack: float = 0.004,
		release: float = 0.12) -> void:
	var i0 := int(start_t * float(RATE))
	var count := int(dur * float(RATE))
	var phase := 0.0
	for j in range(count):
		var idx := i0 + j
		if idx < 0 or idx >= buf.size():
			continue
		var tt := float(j) / float(RATE)
		phase += TAU * freq / float(RATE)
		var v := sin(phase)
		if osc_kind == OSC_TRIANGLE:
			v = asin(v) * (2.0 / PI)
		elif osc_kind == OSC_SAW:
			v = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		var env := minf(tt / maxf(attack, 0.0001), 1.0)
		var rel := dur - tt
		env *= minf(rel / maxf(release, 0.0001), 1.0)
		# Phần decay làm nốt gọn dần tự nhiên như gảy đàn.
		env *= exp(-tt * 1.6)
		buf[idx] += v * env * amp

## Kick: quét tần số 90Hz -> 40Hz, thump ngắn.
func _seq_kick(buf: PackedFloat32Array, start_t: float, amp: float) -> void:
	var i0 := int(start_t * float(RATE))
	var count := int(0.13 * float(RATE))
	var phase := 0.0
	for j in range(count):
		var idx := i0 + j
		if idx < 0 or idx >= buf.size():
			continue
		var tt := float(j) / float(RATE)
		var f := lerpf(95.0, 42.0, clampf(tt / 0.13, 0.0, 1.0))
		phase += TAU * f / float(RATE)
		var env := exp(-tt * 26.0)
		buf[idx] += sin(phase) * env * amp

## Hi-hat: chùm nhiễu rất ngắn.
func _seq_hat(buf: PackedFloat32Array, start_t: float, amp: float) -> void:
	var i0 := int(start_t * float(RATE))
	var count := int(0.035 * float(RATE))
	if i0 < 0 or i0 + count >= buf.size():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var prev := 0.0
	for j in range(count):
		var white := rng.randf_range(-1.0, 1.0)
		prev = prev + 0.55 * (white - prev)
		buf[i0 + j] += prev * exp(-float(j) / float(RATE) * 90.0) * amp

## Bản nhạc menu: Am Am F F C C G G, mỗi ô 2.4 giây.
func _compose_menu_track(buf: PackedFloat32Array, _n: int, _dur: float) -> void:
	var bar := 2.4
	var bars := 8
	# root của bass mỗi ô (A2 A2 F2 F2 C3 C3 G2 G2).
	var roots: Array[float] = [110.0, 110.0, 87.31, 87.31, 130.81, 130.81, 98.0, 98.0]
	# Hợp âm pad: A minor, F major, C major, G major (cặp ô lặp lại).
	var chords := [
		[220.00, 261.63, 329.63],   # Am: A3 C4 E4
		[220.00, 261.63, 329.63],
		[174.61, 220.00, 261.63],   # F:  F3 A3 C4
		[174.61, 220.00, 261.63],
		[261.63, 329.63, 392.00],   # C:  C4 E4 G4
		[261.63, 329.63, 392.00],
		[196.00, 246.94, 293.66],   # G:  G3 B3 D4
		[196.00, 246.94, 293.66],
	]
	var eighth := bar / 8.0
	var quarter := bar / 4.0

	# --- Pad: ba nốt mỗi ô, swell chậm như dàn dây ---
	for b in range(bars):
		var t0 := float(b) * bar
		for k in range(3):
			_seq_note(buf, t0, chords[b][k], bar, 0.085, OSC_SINE, 0.45, 0.6)

	# --- Bass: phách 1 và 3 của mỗi ô ---
	for b in range(bars):
		var t0 := float(b) * bar
		_seq_note(buf, t0, roots[b], 1.05, 0.34, OSC_SINE, 0.005, 0.25)
		_seq_note(buf, t0 + bar * 0.5, roots[b], 1.05, 0.30, OSC_SINE, 0.005, 0.25)
		# Nốt bass năm (quint) mỏng chạy đệm ở phách 2.
		_seq_note(buf, t0 + quarter, roots[b] * 1.5, 0.5, 0.10, OSC_SINE, 0.005, 0.2)

	# --- Arpeggio: tám nốt một ô, lên một quãng tám, sóng tam giác ---
	var arp_order: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]
	for b in range(bars):
		var t0 := float(b) * bar
		for s in range(8):
			var tone: float = chords[b][arp_order[s]] * 2.0
			_seq_note(buf, t0 + float(s) * eighth, tone, eighth * 0.92, 0.075,
				OSC_TRIANGLE, 0.004, 0.06)

	# --- Melody: cụm câu ở ô 3-4 và 7-8 (tính bằng phách, 1 phách = 0.6s) ---
	# Câu A: bước lên rồi lượn về — A4 C5 E5 D5, C5 D5 E5 D5.
	var melody_a := [
		[0.0, 0.5, 440.00], [0.5, 0.5, 523.25], [1.0, 1.0, 659.25],
		[2.5, 0.5, 587.33], [3.0, 0.5, 523.25], [3.5, 0.5, 587.33],
		[4.0, 1.5, 659.25], [6.0, 1.0, 523.25],
	]
	# Câu B: khép lại, hạ về A4 — E5 C5 D5 C5, A4.
	var melody_b := [
		[0.0, 1.0, 659.25], [1.5, 0.5, 523.25], [2.0, 0.5, 587.33],
		[3.0, 1.0, 523.25], [4.0, 1.5, 440.00],
	]
	var beat := 0.6
	for ev in melody_a:
		_seq_note(buf, 2.0 * bar + float(ev[0]) * beat, float(ev[2]),
			float(ev[1]) * beat, 0.16, OSC_SINE, 0.006, 0.18)
		# Lớp bồi âm mỏng cho melody mềm như sáo.
		_seq_note(buf, 2.0 * bar + float(ev[0]) * beat, float(ev[2]) * 2.0,
			float(ev[1]) * beat, 0.045, OSC_SINE, 0.006, 0.18)
	for ev in melody_b:
		_seq_note(buf, 6.0 * bar + float(ev[0]) * beat, float(ev[2]),
			float(ev[1]) * beat, 0.15, OSC_SINE, 0.006, 0.18)
		_seq_note(buf, 6.0 * bar + float(ev[0]) * beat, float(ev[2]) * 2.0,
			float(ev[1]) * beat, 0.04, OSC_SINE, 0.006, 0.18)

	# --- Trống: kick vào phách, hi-hat vào chỗ offbeat ---
	for b in range(bars):
		var t0 := float(b) * bar
		for q in range(4):
			_seq_kick(buf, t0 + float(q) * quarter, 0.30 if q % 2 == 0 else 0.22)
			_seq_hat(buf, t0 + float(q) * quarter + quarter * 0.5, 0.045)

## Nhạc chọn tướng: cùng hệ sequencer nhưng nhanh và dồn dập hơn (nhạc ẩn số:
## người chơi sắp bước vào trận đấu nên năng lượng phải cao hơn menu).
func _start_champ_music() -> void:
	var wav := _build_music(12.0, _compose_champ_track)
	_champ_music = AudioStreamPlayer.new()
	_champ_music.stream = wav
	_champ_music.volume_db = -9.0 + _volume_offset()
	add_child(_champ_music)

## Bản nhạc chọn tướng: Am Am F G, mỗi ô 1.8 giây (~133 BPM), arp dày hơn.
func _compose_champ_track(buf: PackedFloat32Array, _n: int, _dur: float) -> void:
	var bar := 1.8
	var bars := 8
	var roots: Array[float] = [110.0, 110.0, 87.31, 98.0, 110.0, 110.0, 87.31, 98.0]
	var chords := [
		[220.00, 261.63, 329.63],
		[220.00, 261.63, 329.63],
		[174.61, 220.00, 261.63],
		[196.00, 246.94, 293.66],
		[220.00, 261.63, 329.63],
		[220.00, 261.63, 329.63],
		[174.61, 220.00, 261.63],
		[196.00, 246.94, 293.66],
	]
	var eighth := bar / 8.0
	var quarter := bar / 4.0

	for b in range(bars):
		var t0 := float(b) * bar
		for k in range(3):
			_seq_note(buf, t0, chords[b][k], bar, 0.075, OSC_SINE, 0.3, 0.4)
		# Bass chạy cả tám nốt một ô — tạo xung năng lượng.
		for s in range(4):
			_seq_note(buf, t0 + float(s) * quarter, roots[b], quarter * 0.9, 0.26,
				OSC_SINE, 0.004, 0.1)
	# Arp 16 nốt một ô (mỗi nốt nửa eighth) — dồn dập.
	var arp_order: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]
	for b in range(bars):
		var t0 := float(b) * bar
		for s in range(16):
			var tone: float = chords[b][arp_order[s % 8]] * (2.0 if s % 16 < 8 else 4.0)
			_seq_note(buf, t0 + float(s) * eighth * 0.5, tone, eighth * 0.45, 0.055,
				OSC_TRIANGLE, 0.003, 0.04)
	# Trống đậm hơn: kick mọi phách, hat mọi eighth.
	for b in range(bars):
		var t0 := float(b) * bar
		for q in range(4):
			_seq_kick(buf, t0 + float(q) * quarter, 0.34)
		for s in range(8):
			_seq_hat(buf, t0 + float(s) * eighth, 0.05)

func play_menu_music() -> void:
	if _menu_music == null:
		_start_menu_music()
	if _champ_music != null and _champ_music.playing:
		_champ_music.stop()
	if _ambient != null and _ambient.playing:
		_ambient.stop()
	if _menu_music != null and not _menu_music.playing:
		_menu_music.volume_db = -10.0 + _volume_offset()
		_menu_music.play()

func play_champ_music() -> void:
	if _champ_music == null:
		_start_champ_music()
	if _menu_music != null and _menu_music.playing:
		_menu_music.stop()
	if _ambient != null and _ambient.playing:
		_ambient.stop()
	if _champ_music != null and not _champ_music.playing:
		_champ_music.volume_db = -10.0 + _volume_offset()
		_champ_music.play()

func stop_menu_music() -> void:
	if _menu_music != null and _menu_music.playing:
		_menu_music.stop()
	if _champ_music != null and _champ_music.playing:
		_champ_music.stop()
	# Trở về ambient chiến đấu nếu đang trong trận
	if _ambient != null and Settings.sound_volume > 0.01:
		_ambient.play()

# ------------------------------------------------------------------ ambient bản đồ

## Tổng hợp âm nền đặc trưng cho từng bản đồ.
func play_map_ambient(map_type: int) -> void:
	stop_map_ambient()
	if Settings.sound_volume <= 0.01:
		return
	var wav: AudioStreamWAV = _build_map_ambient_wav(map_type)
	if wav == null:
		return
	_map_ambient = AudioStreamPlayer.new()
	_map_ambient.stream = wav
	_map_ambient.volume_db = -16.0 + _volume_offset()
	add_child(_map_ambient)
	_map_ambient.play()

func stop_map_ambient() -> void:
	if _map_ambient != null:
		_map_ambient.stop()
		_map_ambient.queue_free()
		_map_ambient = null

func _build_map_ambient_wav(map_type: int) -> AudioStreamWAV:
	match map_type:
		GameData.MapType.LAVA_RIFT:
			return _wav(_lava_ambient())
		GameData.MapType.FROZEN_LAKE:
			return _wav(_ice_ambient())
		GameData.MapType.STORM_EYE:
			return _wav(_storm_ambient())
		_:
			return null

## Magma: tiếng rì rào trầm xen kẽ tiếng nứt nhỏ.
func _lava_ambient() -> PackedFloat32Array:
	var dur := 4.0
	var n := int(dur * float(RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777777
	for i in range(n):
		var t := float(i) / float(RATE)
		# Nền rì rào trầm
		var v := rng.randf_range(-0.12, 0.12)
		# Tiếng nứt định kỳ
		var crack := fmod(t, 0.7)
		if crack < 0.08:
			var intensity := 1.0 - crack / 0.08
			v += rng.randf_range(-0.35, 0.35) * intensity * intensity
		out[i] = v * 0.18
	return out

## Băng: gió lạnh thổi đều, tần số thấp.
func _ice_ambient() -> PackedFloat32Array:
	var dur := 5.0
	var n := int(dur * float(RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 888888
	var prev := 0.0
	for i in range(n):
		var white := rng.randf_range(-0.18, 0.18)
		prev = prev + 0.02 * (white - prev)
		var wind := sin(TAU * 32.0 * float(i) / float(RATE)) * 0.06
		out[i] = (prev + wind) * 0.18
	return out

## Bão: sấm xa trầm + gió rít.
func _storm_ambient() -> PackedFloat32Array:
	var dur := 6.0
	var n := int(dur * float(RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999999
	var prev := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-0.22, 0.22)
		prev = prev + 0.015 * (white - prev)
		# Gió rít cao
		var wind := sin(TAU * 55.0 * t + sin(TAU * 0.3 * t) * 8.0) * 0.08
		# Tiếng sấm xa định kỳ
		var rumble := 0.0
		var thunder := fmod(t, 2.5)
		if thunder < 0.4:
			var intensity := 1.0 - thunder / 0.4
			rumble = sin(TAU * 45.0 * t) * 0.18 * intensity * intensity
		out[i] = (prev + wind + rumble) * 0.16
	return out
