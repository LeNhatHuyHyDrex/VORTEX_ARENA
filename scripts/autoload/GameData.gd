extends Node
## Sổ đăng ký tướng + hằng số dùng chung toàn game.

## Một tick mô phỏng = 1/60s. Mọi logic combat đều bám theo hằng số này để
## máy chủ và máy khách cho ra kết quả giống nhau.
const TICK_RATE := 60
const TICK_DELTA := 1.0 / 60.0

## Cổng mặc định cho LAN.
const DEFAULT_PORT := 27960

## Cách vào trận.
enum Mode {
	SOLO,      # luyện tập với bot, một máy
	HOST,      # mở phòng LAN, mình là chủ phòng
	CLIENT,    # vào phòng LAN của người khác
	PRACTICE,  # phòng luyện tập: không tính ván, có bảng bật/tắt để thử combo
}

## Độ khó bot trong chế độ solo.
enum Difficulty {
	EASY,      # phản ứng chậm, né ít, ra chiêu thưa
	NORMAL,    # cân bằng — mặc định
	HARD,      # phản ứng nhanh, né nhiều, ra chiêu tích cực
}

## Các bản đồ đấu trường.
enum MapType {
	CLASSIC,      # bản đồ gốc, không có cơ chế đặc biệt
	LAVA_RIFT,    # vết nứt magma gây sát thương dồn nếu đứng trên
	FROZEN_LAKE,  # băng trơn, giảm ma sát, trượt xa hơn
	STORM_EYE,    # vùng an toàn thu hẹp dần + sét đánh ngẫu nhiên
}

const MAP_INFO := {
	MapType.CLASSIC: {
		"name": "Đấu Trường Cổ Điển",
		"tagline": "Sân chuẩn, công bằng, không có bất ngờ.",
		"color": Color("ff7a2f"),
		"hint": "Không có cơ chế đặc biệt — thuần kỹ năng.",
	},
	MapType.LAVA_RIFT: {
		"name": "Vết Nứt Magma",
		"tagline": "Mặt đất nứt ra, magma phun trào gây sát thương liên tục.",
		"color": Color("ef4444"),
		"hint": "Tránh đứng trên các vết nứt đỏ — chúng gây Bỏng và sát thương theo nhịp.",
	},
	MapType.FROZEN_LAKE: {
		"name": "Hồ Băng Vĩnh Cửu",
		"tagline": "Băng trơn khiến mọi chuyển động đều có quán tính lớn.",
		"color": Color("38bdf8"),
		"hint": "Dừng lại chậm hơn rất nhiều — tính toán đường lùi trước khi lao vào.",
	},
	MapType.STORM_EYE: {
		"name": "Mắt Bão",
		"tagline": "Vùng an toàn thu hẹp dần, sét đánh ngoài vùng an toàn.",
		"color": Color("a78bfa"),
		"hint": "Vòng tròn an toàn sẽ thu nhỏ sau 12 giây. Ở ngoài = nhận sát thương tăng dần.",
	},
}

const MAP_ORDER: Array[int] = [MapType.CLASSIC, MapType.LAVA_RIFT, MapType.FROZEN_LAKE, MapType.STORM_EYE]

## Thời gian hồi bất tử sau khi trúng đòn (giây).
const HIT_IFRAME := 0.35

## Các loại status. Đây là "từ vựng" để các skill tương tác với nhau —
## skill A tạo ra status, skill B tiêu thụ status đó.
const ST_BURN := &"burn"          # Bỏng: stack theo số lần trúng lửa
const ST_MARK := &"mark"          # Khóa Hồn: bị đánh dấu, skill khác khai thác
const ST_SLOW := &"slow"          # Làm chậm
const ST_SHIELD := &"shield"      # Khiên tạm thời
const ST_EMPOWER := &"empower"    # Đòn kế tiếp được tăng cường (chí mạng)
const ST_FREEZE := &"freeze"      # Đóng băng: không đi được, không ra chiêu
const ST_CHARGE := &"charge"      # Tích Điện: bị sét đánh trúng thì lan sang mục tiêu gần
const ST_BREAK := &"break"        # Vỡ Giáp: nhận thêm sát thương
const ST_HASTE := &"haste"        # Tăng tốc chạy
const ST_POISON := &"poison"      # Nhiễm Độc: dồn stack, chiêu độc khai thác

## Màu chủ đạo cho từng status, dùng cho HUD và hiệu ứng.
const STATUS_COLORS := {
	ST_BURN: Color("ff7a2f"),
	ST_MARK: Color("a855f7"),
	ST_SLOW: Color("38bdf8"),
	ST_SHIELD: Color("22d3ee"),
	ST_EMPOWER: Color("facc15"),
	ST_FREEZE: Color("93e5ff"),
	ST_CHARGE: Color("ffe066"),
	ST_BREAK: Color("f97316"),
	ST_HASTE: Color("86efac"),
	ST_POISON: Color("a3e635"),
}

const STATUS_NAMES := {
	ST_BURN: "Bỏng",
	ST_MARK: "Khóa Hồn",
	ST_SLOW: "Chậm",
	ST_SHIELD: "Khiên",
	ST_EMPOWER: "Chí Mạng",
	ST_FREEZE: "Đóng Băng",
	ST_CHARGE: "Tích Điện",
	ST_BREAK: "Vỡ Giáp",
	ST_HASTE: "Tăng Tốc",
	ST_POISON: "Nhiễm Độc",
}

## Danh sách tướng. Thêm tướng mới = thêm 1 dòng ở đây + 1 file trong
## scripts/champions/.
const CHAMPION_SCRIPTS := {
	&"fire_mage": preload("res://scripts/champions/FireMage.gd"),
	&"shadow_assassin": preload("res://scripts/champions/ShadowAssassin.gd"),
	&"frost_maiden": preload("res://scripts/champions/FrostMaiden.gd"),
	&"thunder_warrior": preload("res://scripts/champions/ThunderWarrior.gd"),
	&"stone_guardian": preload("res://scripts/champions/StoneGuardian.gd"),
	&"arcane_weaver": preload("res://scripts/champions/ArcaneWeaver.gd"),
	&"mirage": preload("res://scripts/champions/Mirage.gd"),
	&"marksman": preload("res://scripts/champions/Marksman.gd"),
	&"seraph": preload("res://scripts/champions/Seraph.gd"),
	&"artificer": preload("res://scripts/champions/Artificer.gd"),
	&"tamer": preload("res://scripts/champions/Tamer.gd"),
	&"time_weaver": preload("res://scripts/champions/TimeWeaver.gd"),
	&"blood_lord": preload("res://scripts/champions/BloodLord.gd"),
	&"iron_monk": preload("res://scripts/champions/IronMonk.gd"),
	&"berserker": preload("res://scripts/champions/Berserker.gd"),
	&"void_samurai": preload("res://scripts/champions/VoidSamurai.gd"),
	&"plague_alchemist": preload("res://scripts/champions/PlagueAlchemist.gd"),
}

## Thứ tự hiển thị trong menu chọn tướng.
const CHAMPION_ORDER: Array[StringName] = [
	&"fire_mage", &"shadow_assassin", &"frost_maiden", &"thunder_warrior",
	&"stone_guardian", &"arcane_weaver",
	&"mirage", &"marksman", &"seraph", &"artificer", &"tamer", &"time_weaver",
	&"blood_lord", &"iron_monk", &"berserker", &"void_samurai", &"plague_alchemist",
]

## Thông tin rút gọn để vẽ nút chọn tướng ở menu mà không cần khởi tạo cả class.
const CHAMPION_INFO := {
	&"fire_mage": {
		"name": "Hỏa Pháp Sư",
		"tagline": "Dồn stack Bỏng rồi kích nổ",
		"color": Color("ff7a2f"),
		"role": "Sát thương tầm xa",
	},
	&"shadow_assassin": {
		"name": "Sát Thủ Bóng Tối",
		"tagline": "Đánh dấu, dịch chuyển, kết liễu",
		"color": Color("a855f7"),
		"role": "Cận chiến bùng nổ",
	},
	&"frost_maiden": {
		"name": "Băng Sương Nữ",
		"tagline": "Làm chậm, đóng băng, rồi đập vỡ",
		"color": Color("7dd3fc"),
		"role": "Khống chế",
	},
	&"thunder_warrior": {
		"name": "Lôi Đình Chiến Binh",
		"tagline": "Tích điện rồi trút sét lan",
		"color": Color("facc15"),
		"role": "Sát thương lan",
	},
	&"stone_guardian": {
		"name": "Thạch Vệ Binh",
		"tagline": "Đá lăn đè đạn, dựng tường chặn đường",
		"color": Color("a8a29e"),
		"role": "Chống chịu",
	},
	&"arcane_weaver": {
		"name": "Hư Không Pháp Sư",
		"tagline": "Đặt vùng nổ, mở hố đen, dịch chuyển xuyên không gian",
		"color": Color("8b5cf6"),
		"role": "Kiểm soát vùng",
	},
	&"mirage": {
		"name": "Hư Ảnh",
		"tagline": "Lướt né rồi đánh trả, để lại bóng và quay về",
		"color": Color("22d3ee"),
		"role": "Sát thủ dịch chuyển",
	},
	&"marksman": {
		"name": "Xạ Thủ",
		"tagline": "Đứng yên sạc lực, bắn xuyên nhiều mục tiêu",
		"color": Color("facc15"),
		"role": "Bắn xa",
	},
	&"seraph": {
		"name": "Thiên Sứ",
		"tagline": "Khiên phản đòn, vùng thiêng hồi máu",
		"color": Color("fde68a"),
		"role": "Hỗ trợ",
	},
	&"artificer": {
		"name": "Luyện Thuật Sư",
		"tagline": "Rải mìn, dựng bẫy laser, đặt trụ pháo",
		"color": Color("fb923c"),
		"role": "Đặt bẫy",
	},
	&"tamer": {
		"name": "Chủ Ưng",
		"tagline": "Gọi đàn sói, chỉ huy chúng lao vào đối thủ",
		"color": Color("4ade80"),
		"role": "Triệu hồi",
	},
	&"time_weaver": {
		"name": "Thời Sư",
		"tagline": "Bẻ cong thời gian: tua lại vị trí, kết tinh sự chậm trễ",
		"color": Color("fb7185"),
		"role": "Khống chế thời gian",
	},
	&"blood_lord": {
		"name": "Huyết Bá",
		"tagline": "Vuốt máu áp sát, càng đánh trúng càng hồi sức",
		"color": Color("dc2626"),
		"role": "Đấu sĩ hút máu",
	},
	&"iron_monk": {
		"name": "Thiết Quyền Sư",
		"tagline": "Liên quyền tốc độ cao, lướt gió áp sát, kim chung trấn giữ",
		"color": Color("fbbf24"),
		"role": "Cận chiến linh hoạt",
	},
	&"berserker": {
		"name": "Cuồng Chiến",
		"tagline": "Nhảy dập vỡ giáp, gầm tăng lực — càng yếu máu càng mạnh",
		"color": Color("f43f5e"),
		"role": "Đấu sĩ trâu bò",
	},
	&"void_samurai": {
		"name": "Kiếm Thánh",
		"tagline": "Rút kiếm chớp nhoáng, dồn Sát Ý rồi rút kiếm kết liễu",
		"color": Color("818cf8"),
		"role": "Sát thủ chớp nhoáng",
	},
	&"plague_alchemist": {
		"name": "Độc Sư",
		"tagline": "Rải độc dồn stack, rồi kích nổ dịch độc dứt điểm",
		"color": Color("84cc16"),
		"role": "Sát thương tầm xa",
	},
}

## Mẹo combo gợi ý, hiện ở menu chọn tướng.
##
## Cố ý không viết sẵn "combo chuẩn" mà mô tả quy luật tương tác — người chơi
## tự ráp thứ tự tuỳ tình huống. Mỗi câu đều nêu rõ status sinh ra / tiêu thụ.
const COMBO_HINTS := {
	&"fire_mage":
		"Hỏa Cầu dồn Bỏng. Đứng trong Tường Lửa thì Bỏng tiếp tục cộng dồn. Lướt Lửa xuyên qua người đang Bỏng sẽ hồi ngay Hỏa Cầu. Bùng Nổ ăn hết stack Bỏng — dồn càng nhiều, nổ càng mạnh.",
	&"shadow_assassin":
		"Khóa Hồn là chìa khóa: mỗi stack +6% sát thương bạn gây ra. Ảnh Bộ dịch chuyển, rồi Chém Đôi kế tiếp thành chí mạng. Tử Ảnh kết liễu, và ăn gấp 2.5 lần nếu đối thủ dưới 35% máu.",
	&"frost_maiden":
		"Băng Tiễn gây Lạnh. Bắn lần nữa vào người đang Lạnh thành ĐÓNG BĂNG. Vòng Băng đập vỡ người đang đóng băng để gây sát thương lớn. Trượt Băng rải vệt lạnh — vừa rút lui vừa dọn đường cho Băng Tiễn.",
	&"thunder_warrior":
		"Lướt Sét và Nạp Điện đều gắn Tích Điện. Sét Đánh trúng người đang Tích Điện sẽ LAN sang kẻ đứng gần. Thiên Lôi gọi sét xuống vị trí chỉ định — trúng người Tích Điện thì vừa đau vừa choáng.",
	&"stone_guardian":
		"Đá Lăn có sức mạnh đạn cao nhất, đè bẹp mọi đạn tầm xa yếu hơn. Tường Đá chặn cả người lẫn đạn. Khiên Đá dán VỠ GIÁP lên kẻ địch gần, rồi Địa Chấn đánh vào chỗ VỠ GIÁP đó để choáng.",
	&"arcane_weaver":
		"Mọi chiêu đều là chọn vùng: bấm phím để xem vòng phạm vi, bấm chuột trái để chốt. Q đánh dấu, F ăn thêm sát thương lên mục tiêu đã đánh dấu. R mở Hố Đen hút đối thủ vào giữa, giữ họ lại cho Q và F. E dịch chuyển — đặt vùng ra xa là rút lui, đặt sát đối thủ là áp sát, và luôn để lại một vụ nổ ở chỗ vừa đứng.",
	&"mirage":
		"Nội tại tự đặt bóng sau lưng mỗi 4 giây. Q lướt tức thì và để lại bóng tại chỗ cũ; E quay về đúng chỗ cái bóng đó. Chuỗi đẹp nhất: Q lướt xuyên qua đối thủ, đánh vài nhát, rồi E quay về chỗ cũ — đối thủ không biết bạn đang ở đâu. R khiến chiêu tiếp theo bắn thêm một bản từ vị trí bóng.",
	&"marksman":
		"Đứng yên để sạc Tâm Điểm, tối đa +50% sát thương đánh thường — nhưng di chuyển là mất sạch. E lướt NGƯỢC hướng ngắm để giữ khoảng cách mà vẫn giữ được hướng bắn. R đổi khả năng di chuyển lấy tầm bắn và sát thương gấp đôi. F bắn một viên xuyên qua mọi thứ trên đường bay.",
	&"seraph":
		"Thắng bằng cách sống lâu chứ không phải giết nhanh. Mọi lần hồi máu đều sinh thêm khiên. E tạo khiên phản 30% sát thương đạn về kẻ bắn. R dựng vùng hồi máu và tăng tốc — đứng trong đó thì gần như không thể bị dồn chết. F giáng cột sáng xuống vùng chọn, dùng để đẩy đối thủ ra khỏi vùng của mình.",
	&"artificer":
		"Tướng duy nhất chơi bằng cách chuẩn bị trước. Nội tại tự đặt mìn sau lưng mỗi 8 giây. Q đặt mìn, R dựng hàng rào laser vuông góc với hướng ngắm, F dựng trụ pháo tự bắn trong 5 giây. Người chơi giỏi sẽ dồn đối thủ vào một góc đã rải mìn từ trước.",
	&"tamer":
		"Sát thương đến từ đàn sói chứ không phải từ bạn. Q gọi một con, E ra lệnh cho nó lao tới và choáng, R gọi thêm hai con thành đàn ba. F cho cả bạn lẫn đàn cùng lao về một hướng. Đối thủ phải chọn giữa bắn bạn hay bắn thú — cả hai đều là sai lầm.",
	&"time_weaver":
		"Cả bộ kỹ năng xoay quanh stack Chậm. Đánh thường và Q gắn Chậm; Q là vùng đồng hồ rút máu theo nhịp. E Vòng Lùi quay bạn về vị trí 2.2 giây trước — chiêu thoát bẫy mạnh nhất game. R Ngưng Trôi biến MỖI stack Chậm trên đối thủ thành sát thương rồi gắn Khóa Hồn — dồn Chậm đủ nhiều rồi nổ. F lướt về một hướng để lại ba vệt thời gian chặn đuổi. Nội tại tự cho khiên + tăng tốc khi tụt nửa máu.",
	&"blood_lord":
		"Mọi đòn trúng đều hồi máu cho bạn — đó là nội tại, nên cận chiến chính là môi trường sống của Huyết Bá. Q Đàn Dơi lướt xuyên người: vừa gây sát thương vừa hồi 3 máu mỗi kẻ bị xuyên, dùng để áp sát hoặc rút lui. W Huyết Tiễn hút 40% sát thương làm máu. E Trường Sinh cho khiên + hồi máu để sống sót qua đợt burst. R Dòng Máu mở vùng hút kéo địch vào — đứng trong đó bạn hồi máu còn đối thủ chết dần.",
	&"iron_monk":
		"Nội tại Nhịp Quyền thưởng CHÍ MẠNG cho đòn đánh thường kế tiếp mỗi 3 kỹ năng tung ra — đếm nhịp rồi bật, đừng spam chiêu vô nghĩa. Q Phong Bộ trượt gió áp sát. E Thiên Chưởng Ấn hất văng + dán Vỡ Giáp. R Nhất Quyền Trấn Hồn cộng thêm sát thương lên kẻ đã Vỡ Giáp — mở màn bằng E rồi kết liễu bằng F. W Chung Vàng cho khiên + tăng tốc để đỡ đợt burst.",
	&"berserker":
		"Càng yếu máu, mọi sát thương bạn gây ra càng nặng (tối đa +45%) — đổi máu là chiến thuật, không phải sơ suất. Q Bước Nhảy Chém nhảy tới nơi chỉ định rồi đập vỡ mặt đất, dùng nó để áp sát chứ đừng chạy bộ. W Chiến Hào cho khiên + tăng tốc + chậm địch quanh mình. E Xoáy Rìu quét quanh người khi bị vây. R Phán Quyết cộng tới 30 sát thương theo MÁU ĐÃ MẤT của mục tiêu — chiêu kết liễu đúng nghĩa.",
	&"void_samurai":
		"Mỗi kỹ năng cộng 1 stack Sát Ý (+7% sát thương, tối đa 5); đánh thường trúng thì tiêu sạch — nên đánh xen kẽ chiêu và đòn thường để giữ nhịp. Q Nghịch Phong Trảm và E Hư Không Bước (lao xuyên + 2 Khóa Hồn) là nguồn tích ý chính. W Nhất Đao Lưu chém dài 250px và cho Chí Mạng đòn kế tiếp. Chuỗi chuẩn: E → W → thường → Q → thường. R Vạn Kiếm Mộ là vùng mưa kiếm múc máu theo nhịp — đặt đúng chỗ đối thủ đang lùi.",
	&"plague_alchemist":
		"Đánh thường (Ném Bình Độc), W Tiêu Độc Tiễn và Q Vực Độc đều gắn Nhiễm Độc — W dồn 3 stack nhanh nhất. Nội tại Cấy Độc hoàn 1.5 năng lượng mỗi lần đánh trúng kẻ đang nhiễm độc, nên xoay chiêu liên tục không sợ cạn mana. R Đại Nổ Dịch Bệnh đốt MỖI stack độc thành 7 sát thương: dồn 6-8 stack rồi nổ một phát rất đau. E Thanh Lọc tẩy mọi trạng thái xấu trên mình (kể cả độc) + khiên + tăng tốc — chiêu sống sót khi bị áp sát.",
}

## Quy luật va chạm đạn, hiện ở menu để người chơi hiểu vì sao đạn bị đè.
const CLASH_HINT := "Hai đạn bắn ngược chiều chạm nhau: đạn mạnh hơn đập vỡ đạn yếu hơn, nhưng bị hao tầm bay tương ứng với sức mạnh của viên đạn nó vừa đè. Ngang sức thì cả hai cùng tan."

func champion_ids() -> Array[StringName]:
	# duplicate() trả về Array thường, phải gán lại vào mảng có kiểu.
	var out: Array[StringName] = []
	out.assign(CHAMPION_ORDER)
	return out

func champion_script(id: StringName) -> GDScript:
	return CHAMPION_SCRIPTS.get(id, null)

func champion_display_name(id: StringName) -> String:
	var info: Dictionary = CHAMPION_INFO.get(id, {})
	return info.get("name", String(id))

func champion_color(id: StringName) -> Color:
	var info: Dictionary = CHAMPION_INFO.get(id, {})
	return info.get("color", Color.WHITE)

## Lấy tên và mô tả nội tại của tướng, để menu hiện được mà không phải dựng cả
## một Champion ra chỉ để đọc hai chuỗi.
##
## Trả về Dictionary rỗng nếu tướng chưa khai báo nội tại — menu tự bỏ qua phần
## đó chứ không vỡ.
func champion_passive_info(id: StringName) -> Dictionary:
	var script: GDScript = champion_script(id)
	if script == null:
		return {}
	var builder: Object = script.new()
	if builder == null or not builder.has_method("build_passive"):
		return {}
	var p = builder.build_passive()
	if p == null:
		return {}
	return {"name": p.display_name, "description": p.description}

## Lấy IPv4 nội bộ của máy này để hiện cho người chơi gõ vào máy kia.
## Trả về "127.0.0.1" nếu không tìm được.
func get_local_ip() -> String:
	var ips := IP.get_local_addresses()
	var fallback := "127.0.0.1"
	# Gán qua biến String tường minh vì phần tử mảng trả về kiểu Variant.
	for raw in ips:
		var addr: String = raw
		# Ưu tiên dải LAN thông dụng, bỏ qua loopback và IPv6.
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	for raw in ips:
		var addr: String = raw
		if not addr.contains(":") and not addr.begins_with("127."):
			return addr
	return fallback

## Phát hiện IP ảo của Tailscale nếu người chơi đã cài.
##
## Tailscale cấp cho mỗi máy một IP trong dải CGNAT 100.64.0.0 - 100.127.255.255
## (thường viết gọn là 100.x.x.x). Khi thấy địa chỉ thuộc dải này nghĩa là
## Tailscale đang chạy trên máy — hai máy cùng tài khoản sẽ "nhìn thấy" nhau
## qua internet như thể đang cùng một mạng LAN.
## Trả về "" nếu không có (chưa cài hoặc chưa bật).
func get_tailscale_ip() -> String:
	for raw in IP.get_local_addresses():
		var addr: String = raw
		if not addr.begins_with("100."):
			continue
		# Chỉ nhận dải 100.64 - 100.127 của Tailscale, bỏ các dải khác.
		var parts := addr.split(".")
		if parts.size() == 4:
			var second := int(parts[1])
			if second >= 64 and second <= 127:
				return addr
	return ""
