extends Node
## Smoke test chạy HEADLESS: dựng toàn bộ 17 tướng (build + preview + passive)
## và cho BotBrain của từng tướng ra quyết định vài trăm frame — đủ để lộ lỗi
## parse/type/runtime trong dữ liệu tướng mới mà không cần người chơi.
##
## Chạy:
##   godot --headless --path . res://tools/SmokeAll.tscn

var _frames := 0
var _brains: Array = []
var _targets: Array = []

func _ready() -> void:
	var ids: Array = GameData.CHAMPION_ORDER
	var ok := 0
	for id in ids:
		var script: Script = GameData.CHAMPION_SCRIPTS.get(id)
		if script == null:
			push_error("SMOKE: thiếu script cho " + str(id))
			continue
		var inst: RefCounted = script.new()
		var c := Champion.new()
		c.champion_id = id
		c.peer_id = 1000 + ok
		# build_champion: gán stats, dựng 4 skill + đánh thường
		inst.build_champion(c)
		# skill_preview / basic_attack_preview: menu dùng hai hàm này
		var preview: Array = inst.skill_preview()
		if preview.size() != 4:
			push_error("SMOKE: " + str(id) + " preview != 4 skill")
		if inst.basic_attack_preview() == null:
			push_error("SMOKE: " + str(id) + " thiếu basic preview")
		# passive: dựng + setup
		var passive = inst.build_passive()
		if passive == null:
			push_error("SMOKE: " + str(id) + " thiếu passive")
		else:
			passive.setup(c)
		# BotBrain: AI ra quyết định từng tướng
		var brain := BotBrain.new(c, GameData.Difficulty.HARD)
		_brains.append(brain)
		_targets.append(c)
		ok += 1
	print("SMOKE: dựng được ", ok, "/", ids.size(), " tướng")

func _process(_delta: float) -> void:
	_frames += 1
	# Mỗi frame: bot của mỗi tướng "nghĩ" về mục tiêu kế tiếp trong danh sách.
	for i in range(_brains.size()):
		var brain = _brains[i]
		var me = brain.champion
		var other = _targets[(i + 1) % _targets.size()]
		brain.update(1.0 / 60.0, other)
		if brain.cast_mask() < 0:
			push_error("SMOKE: cast_mask âm cho " + str(me.champion_id))
	if _frames >= 240:
		print("SMOKE_OK frames=", _frames)
		get_tree().quit()
