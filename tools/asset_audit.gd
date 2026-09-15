extends SceneTree

const PROJECT_ROOT := "res://"

func _init() -> void:
	var counts := {
		"kaykit_adventurers_glb": _count_files("res://assets/packs/kaykit_adventurers", [".glb"]),
		"kaykit_dungeon_glb": _count_files("res://assets/packs/kaykit_dungeon_remastered", [".glb"]),
		"kenney_ui_png": _count_files("res://assets/art/ui/kenney_full", [".png"]),
		"brackeys_png": _count_files("res://assets/vfx/brackeys_bundle", [".png"]),
		"spell_fx_png": _count_files("res://assets/vfx/spell_fx", [".png"]),
		"rpg_sfx_ogg": _count_files("res://assets/audio/rpg_sfx", [".ogg"]),
	}
	for key in counts:
		print("ASSET_AUDIT %s=%d" % [key, counts[key]])
	print("ASSET_AUDIT_DONE")
	quit()

func _count_files(root_path: String, extensions: Array[String]) -> int:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return 0
	var total := 0
	dir.list_dir_begin()
	while true:
		var item := dir.get_next()
		if item == "":
			break
		if item.begins_with("."):
			continue
		var full := root_path.path_join(item)
		if dir.current_is_dir():
			total += _count_files(full, extensions)
		else:
			for ext in extensions:
				if item.to_lower().ends_with(ext):
					total += 1
					break
	dir.list_dir_end()
	return total
