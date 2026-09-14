extends SceneTree
## Kiểm tra khe cắm asset: in ra ảnh nào tìm được cho từng tướng và từng nhóm.
##
## Chạy: Godot.exe --headless --path . --script tools/check_art.gd
##
## Lưu ý: KHÔNG dùng autoload trong script này — chế độ --script không nạp
## autoload, nên danh sách tướng được ghi thẳng ở đây (trùng GameData.CHAMPION_ORDER).

const IDS: Array[String] = [
	"fire_mage", "shadow_assassin", "frost_maiden", "thunder_warrior",
	"stone_guardian", "arcane_weaver", "mirage", "marksman", "seraph",
	"artificer", "tamer", "time_weaver", "blood_lord", "iron_monk",
	"berserker", "void_samurai", "plague_alchemist",
]

const GROUPS: Array[String] = ["champions/cards", "champions/bodies"]

func _init() -> void:
	var total_missing := 0
	for group in GROUPS:
		var found := 0
		print("== ", group)
		for id in IDS:
			var p := ArtLibrary.find_path(group, id)
			if p == "":
				total_missing += 1
			else:
				found += 1
				print("   + ", id, "  <-  ", p)
		print("   => ", found, "/", IDS.size(), " tướng đã có ảnh")
	print("== ui")
	var ui_found := 0
	const UI_PIECES: Array[String] = ["panel_parchment", "card_frame", "pedestal", "button_normal",
			"button_hover", "title_ribbon", "skill_slot"]
	for piece in UI_PIECES:
		var p2 := ArtLibrary.find_path("ui", piece)
		if p2 != "":
			ui_found += 1
			print("   + ", piece, "  <-  ", p2)
		else:
			print("   - ", piece, "  (fallback vector actief)")
	print("UI coverage: ", ui_found, "/", UI_PIECES.size())
	print("TỔNG thiếu champion: ", total_missing, " / ", IDS.size() * GROUPS.size())
	quit()
