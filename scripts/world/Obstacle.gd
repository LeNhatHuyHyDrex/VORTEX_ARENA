class_name Obstacle
extends Node2D
## Vật cản tĩnh trong đấu trường.
##
## Vẽ theo kiểu khối có chiều cao: một mặt trên sáng và một mặt trước tối. Đây là
## thủ thuật để tạo cảm giác "từ trên xuống hơi xéo" mà vẫn giữ game ở hệ 2D.
## Node được đặt tại tâm mép dưới của vật cản để y-sort hoạt động đúng: tướng
## đứng dưới vật cản sẽ bị che, đứng trên thì che ngược lại.

var footprint := Rect2()      # vùng chiếm đất, toạ độ cục bộ
var height := 26.0
var top_color := Color("3d3c4f")
var side_color := Color("15141d")
var edge_color := Color("5f5d78")
## Viền sáng phía trên, hơi ngả cam cho hợp ánh sáng đấu trường.
var rim_color := Color(1.0, 0.62, 0.34, 0.35)

func setup(rect: Rect2, h: float = 26.0) -> void:
	# rect là vùng chiếm đất theo toạ độ thế giới.
	footprint = Rect2(-rect.size.x * 0.5, -rect.size.y, rect.size.x, rect.size.y)
	height = h
	position = Vector2(rect.get_center().x, rect.end.y)
	queue_redraw()

func _draw() -> void:
	var w := footprint.size.x
	var h := footprint.size.y
	# Bóng đổ trên mặt đất, lệch xuống dưới cho khớp hướng sáng.
	draw_rect(Rect2(footprint.position + Vector2(4, 3), footprint.size),
		Color(0, 0, 0, 0.40))
	# Thân khối (mặt trước tối) — kéo dài lên trên theo chiều cao.
	draw_rect(Rect2(-w * 0.5, -h - height, w, h + height), side_color)
	# Mặt trên sáng.
	draw_rect(Rect2(-w * 0.5, -h - height, w, h), top_color)
	# Viền trên hắt sáng.
	draw_line(Vector2(-w * 0.5, -h - height), Vector2(w * 0.5, -h - height), rim_color, 2.0)
	# Viền ngoài.
	draw_rect(Rect2(-w * 0.5, -h - height, w, h), edge_color, false, 1.5)
	draw_rect(Rect2(-w * 0.5, -h, w, h), Color(0, 0, 0, 0.35), false, 1.0)
