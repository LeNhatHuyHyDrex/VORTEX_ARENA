class_name SkillBase
extends RefCounted
## Lớp cơ sở cho mọi kỹ năng.
##
## Mỗi tướng giữ 4 skill. Skill KHÔNG tự biết gì về tướng khác — nó chỉ đọc/ghi
## status trên mục tiêu. Nhờ vậy ghép skill nào với skill nào cũng chạy, và các
## combo nằm ở cách người chơi sắp thứ tự, không phải ở code cứng.

var id: StringName = &""
var display_name := "Skill"
var description := ""
var key_label := "Q"
var cooldown := 6.0
var mana_cost := 0.0
var icon_color := Color.WHITE

## Kỹ năng này cần người chơi chọn gì trước khi ra chiêu?
##
## Đây là thứ quyết định luồng bấm: INSTANT/SELF ra ngay khi bấm; DIRECTION và
## GROUND phải bấm để "lên đạn" trước, xem vùng phạm vi, rồi xác nhận mới ra.
enum CastType {
	INSTANT,    # bấm là ra, không cần hướng cũng không cần vùng
	SELF,       # tác động quanh bản thân, cũng ra ngay
	DIRECTION,  # cần một hướng (bắn, lướt, chém theo quạt)
	GROUND,     # cần một ĐIỂM trên mặt đất (đặt vùng, gọi sét xuống, dựng tường)
}

var cast_type: CastType = CastType.DIRECTION

## Tầm xa tối đa của kỹ năng, tính bằng pixel. Dùng để vẽ vòng phạm vi và để
## kẹp điểm đặt chiêu — người chơi không thể đặt vùng ngoài tầm.
var cast_range := 520.0

## Bán kính vùng ảnh hưởng, dùng để vẽ vòng tròn xem trước. 0 = không phải AoE.
var aoe_radius := 0.0

## Điểm đã chọn trên mặt đất, được `try_cast` ghi vào trước khi gọi `execute`.
## Nhờ vậy các lớp con đọc `aim_point` mà không phải đổi chữ ký `execute`.
var aim_point := Vector2.ZERO

## Tướng đang sở hữu skill này.
var caster: Champion = null
var cooldown_left := 0.0

## true = đây là đòn đánh thường (chuột trái), không phải kỹ năng chiến thuật.
## HUD dùng cờ này để hiển thị riêng, và nó được phép lặp lại khi giữ chuột.
var is_basic := false

## Vài skill cần chặn dùng khi đang có điều kiện đặc biệt (ví dụ đang lướt).
var requires_target_status: StringName = &""
var min_target_stacks := 0

func bind(p_caster: Champion) -> void:
	caster = p_caster

## Kỹ năng này có bắt người chơi chọn hướng hoặc chọn vùng không?
##
## Dùng ở tầng input: nếu `true` thì bấm phím chỉ "lên đạn", chưa ra chiêu.
func needs_aiming() -> bool:
	return cast_type == CastType.DIRECTION or cast_type == CastType.GROUND

## Điểm đặt chiêu có bị giới hạn tầm không?
func uses_range() -> bool:
	return cast_type == CastType.GROUND

# ------------------------------------------------------------------ vòng đời

func tick(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)

func ready() -> bool:
	return caster != null and caster.is_alive() and cooldown_left <= 0.0

## Kiểm tra đủ điều kiện để ra chiêu. Tách riêng khỏi việc thực thi để HUD có
## thể hiển thị trạng thái "chưa đủ mana" / "thiếu điều kiện" khác nhau.
func can_cast() -> bool:
	if not ready():
		return false
	if caster.mana < mana_cost:
		return false
	return true

## Trả về lý do không ra được chiêu, dùng cho HUD. Rỗng = ra được.
func block_reason() -> String:
	if caster == null or not caster.is_alive():
		return "Không thể dùng"
	if cooldown_left > 0.0:
		return "Hồi chiêu"
	if caster.mana < mana_cost:
		return "Thiếu năng lượng"
	return ""

## Điểm đặt chiêu cho kỹ năng loại GROUND.
##
## Trả về điểm người chơi đã chọn (đã được `try_cast` kẹp vào tầm). Nếu vì lý
## do nào đó điểm chưa được đặt — bot gọi thẳng, hoặc chiêu ra ngoài luồng chọn
## vùng — thì lùi về hành vi cũ: một điểm cách người niệm `fallback` theo hướng
## đang ngắm. Nhờ vậy chiêu không bao giờ rơi vào gốc toạ độ.
func ground_point(fallback: float, aim: Vector2 = Vector2.RIGHT) -> Vector2:
	if aim_point != Vector2.ZERO:
		return aim_point
	if caster == null:
		return Vector2.ZERO
	var dir := aim if aim.length_squared() > 0.0001 else caster.aim_dir
	return caster.global_position + dir.normalized() * fallback

## Được gọi khi thực sự ra chiêu. Trả về true nếu tiêu tốn lượt dùng.
##
## `target` là điểm người chơi đã chọn trên mặt đất; chỉ có ý nghĩa với kỹ năng
## loại GROUND. Với loại khác thì bỏ qua. Điểm này được kẹp vào tầm trước khi
## truyền xuống `execute` qua biến `aim_point`.
func try_cast(aim: Vector2, target: Vector2 = Vector2.ZERO) -> bool:
	if not can_cast():
		return false

	if cast_type == CastType.GROUND and caster != null:
		var from: Vector2 = caster.global_position
		var delta := target - from
		if delta.length_squared() > cast_range * cast_range:
			# Kẹp về đúng mép tầm thay vì từ chối ra chiêu — người chơi đã bấm
			# xác nhận thì nên ra chiêu, chỉ là không với tới chỗ quá xa.
			delta = delta.normalized() * cast_range
		aim_point = from + delta
	else:
		aim_point = target

	caster.spend_mana(mana_cost)
	cooldown_left = cooldown
	execute(aim)
	caster.on_skill_cast(self)
	return true

## Ghi đè ở lớp con — đây là phần hành vi thật của skill.
func execute(_aim: Vector2) -> void:
	pass

func cooldown_ratio() -> float:
	return 0.0 if cooldown <= 0.0 else clampf(cooldown_left / cooldown, 0.0, 1.0)

## Giảm hồi chiêu ngay lập tức — dùng cho các hiệu ứng "reset combo".
func refund(seconds: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - seconds)

func reset_cooldown() -> void:
	cooldown_left = 0.0

# ------------------------------------------------------- truy vấn mục tiêu
# Các hàm dưới đây giúp skill tìm mục tiêu mà không phải tự lặp qua đấu trường.

## Toàn bộ đối thủ còn sống.
func enemies() -> Array:
	if caster == null or caster.world == null:
		return []
	var out: Array = []
	for e in caster.world.enemies_of(caster):
		if e.is_alive():
			out.append(e)
	return out

## Đối thủ trong bán kính r quanh một điểm.
func enemies_in_radius(center: Vector2, r: float) -> Array:
	var out: Array = []
	for e in enemies():
		if center.distance_to(e.global_position) <= r + e.body_radius:
			out.append(e)
	return out

## Đối thủ nằm trong hình quạt (dùng cho đòn chém cận chiến).
## `half_angle` tính bằng radian, ví dụ 0.9 ~ 51 độ mỗi bên.
func enemies_in_cone(center: Vector2, dir: Vector2, reach: float, half_angle: float) -> Array:
	var out: Array = []
	var d := dir.normalized()
	for e in enemies():
		var to_e: Vector2 = e.global_position - center
		if to_e.length() > reach + e.body_radius:
			continue
		if to_e.length_squared() < 0.01:
			out.append(e)
			continue
		if absf(d.angle_to(to_e.normalized())) <= half_angle:
			out.append(e)
	return out

## Đối thủ gần nhất trong tầm, hoặc null.
func nearest_enemy_in_range(max_range: float) -> Champion:
	if caster == null:
		return null
	return caster.nearest_enemy(max_range)

## Sinh hiệu ứng hình ảnh tại một điểm (uỷ quyền cho đấu trường).
func vfx(config: Dictionary) -> void:
	if caster != null:
		caster.spawn_effect(config)
