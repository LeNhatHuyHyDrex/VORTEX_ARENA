extends Node
## Kiểm tra khói (smoke test) chạy thật toàn bộ bộ kỹ năng của tướng mới.
##
## Nạp Game.tscn ở chế độ SOLO, ép cast từng chiêu + đánh thường, để 3 giây
## hiệu ứng chạy, rồi đổi phía: bot cầm tướng mới đánh lại mình. Mọi lỗi
## runtime sẽ hiện trong log headless.

const FIGHT_WAIT := 5.0

func _ready() -> void:
	await _test_kit(&"time_weaver", &"fire_mage")
	await _test_kit(&"tamer", &"time_weaver")
	print("SMOKE_DONE")
	get_tree().quit()

func _test_kit(id: StringName, enemy_id: StringName) -> void:
	Game.pending_mode = GameData.Mode.SOLO
	Game.pending_champion = id
	Game.pending_enemy_champion = enemy_id
	Game.pending_bot_difficulty = GameData.Difficulty.HARD
	Game.pending_map = GameData.MapType.CLASSIC

	var packed: PackedScene = load("res://scenes/Game.tscn")
	var scene := packed.instantiate()
	add_child(scene)

	# Đợi hết đếm ngược để vào FIGHT.
	var waited := 0.0
	while waited < FIGHT_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()

	var g := scene as Game
	if g == null or g.local_champ == null or g.enemy_champ == null:
		push_error("SMOKE: thiếu champion cho " + str(id))
		scene.queue_free()
		return

	# Ép cast toàn bộ 4 kỹ năng + đánh thường, nhịp cách nhau cho rõ lỗi.
	for i in range(g.local_champ.skills.size()):
		var s: SkillBase = g.local_champ.skills[i]
		var ok := s.try_cast(g.local_champ.aim_dir, g.enemy_champ.global_position)
		print("SMOKE ", str(id), " slot", i, "(", s.display_name, ") -> ", ok)
		await get_tree().create_timer(0.45).timeout
	# Vòng Lùi lần 2 sau khi đã có lịch sử di chuyển.
	var rewind: SkillBase = g.local_champ.skills[1]
	if rewind != null and rewind.id == &"rewind":
		print("SMOKE rewind x2 -> ", rewind.try_cast(Vector2.LEFT, Vector2.ZERO))
	g.local_champ.basic_attack.try_cast(Vector2.RIGHT, Vector2.ZERO)

	# Để trận đấu chạy tiếp: bot (đối thủ) tự ra chiêu, hiệu ứng tự tắt.
	var run := 0.0
	while run < 4.0:
		await get_tree().process_frame
		run += get_process_delta_time()

	print("SMOKE ", str(id), " vs ", str(enemy_id),
		" hp_local=", g.local_champ.hp, " hp_enemy=", g.enemy_champ.hp)
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
