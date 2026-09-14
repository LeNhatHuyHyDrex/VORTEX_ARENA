class_name SpriteSeq
extends Node2D
## Phát một chuỗi frame cắt từ spritesheet của pack VFX (2D Spell Effects…).
##
## Vì sao không dùng AnimatedSprite2D + SpriteFrames: tài nguyên là MỘT ảnh lưới
## lớn, dựng SpriteFrames lúc chạy phải tạo hàng chục AtlasTexture — rác GC và
## chậm. Vẽ trực tiếp từng ô bằng draw_texture_rect_region thì không tạo node
## con nào, khớp với phong cách "_draw-first" của project.
##
## Lớp này tự giải phóng mình khi phát xong (trừ khi loop = true), nên caller
## chỉ cần add_child rồi quên đi — không rò rỉ node trong arena.

var sheet: Texture2D = null
var cols := 1
var rows := 1
var count := 1
var frame_w := 0.0
var frame_h := 0.0
var fps := 22.0
var loop := false
var tint := Color.WHITE
var pixel_scale := 1.0
var rotation_deg := 0.0
var additive := false
var flip_h := false
var free_when_done := true

var _t := 0.0
var _frame := 0
var _done := false

static func from_manifest(man: Dictionary, tex: Texture2D) -> SpriteSeq:
	var s := SpriteSeq.new()
	s.sheet = tex
	s.cols = int(man.get("cols", 1))
	s.rows = int(man.get("rows", 1))
	s.count = int(man.get("count", 1))
	s.frame_w = float(man.get("fw", 1))
	s.frame_h = float(man.get("fh", 1))
	return s

func _ready() -> void:
	rotation_degrees = rotation_deg
	if additive:
		material = CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Chỉ hiện đúng thời lượng: loop thì đứng yên, không loop thì tự hủy.
	if not loop:
		var life := float(count) / maxf(fps, 0.01)
		get_tree().create_timer(life + 0.05).timeout.connect(func() -> void:
			if is_instance_valid(self) and free_when_done:
				queue_free())

func _process(delta: float) -> void:
	_t += delta * fps
	_frame = int(_t)
	if loop:
		_frame %= count
	elif _frame >= count:
		_frame = count - 1
		if not _done:
			_done = true
	queue_redraw()

func _draw() -> void:
	if sheet == null or frame_w <= 0.0 or frame_h <= 0.0:
		return
	var cx := _frame % cols
	var cy := _frame / cols
	var src := Rect2(Vector2(cx * frame_w, cy * frame_h), Vector2(frame_w, frame_h))
	var dst_size := Vector2(frame_w, frame_h) * pixel_scale
	var dst := Rect2(-dst_size * 0.5, dst_size)
	# Lật ngang bằng scale âm quanh tâm — dùng cho hiệu ứng theo hướng dash.
	var xform := Transform2D().scaled(Vector2(-pixel_scale if flip_h else pixel_scale, pixel_scale))
	draw_set_transform_matrix(Transform2D(0.0, Vector2.ZERO, xform.get_scale(), Vector2.ZERO))
	draw_texture_rect_region(sheet, dst, src, tint)
	draw_set_transform_matrix(Transform2D())
