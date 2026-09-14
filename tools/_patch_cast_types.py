"""Gán loại chiêu (cast_type) cho toàn bộ kỹ năng.

Trước đây mọi chiêu đều ngầm hiểu là "bắn theo hướng ngắm". Hệ thống chọn vùng
mới cần biết chiêu nào phải chờ người chơi chọn hướng, chiêu nào phải chờ chọn
một điểm trên mặt đất, và chiêu nào bấm là ra luôn.

Script này chèn ba dòng vào mỗi lớp kỹ năng, ngay sau dòng `id = &"..."`:

    cast_type = SkillBase.CastType.DIRECTION
    cast_range = 520.0
    aoe_radius = 0.0

Và đổi ba chiêu đặt vùng sang dùng `aim_point` (điểm người chơi đã chọn) thay
vì tự tính từ hướng ngắm.

Chạy: python tools/_patch_cast_types.py
"""
import pathlib
import re
import sys

# id kỹ năng -> (cast_type, cast_range, aoe_radius)
SPEC = {
    # --- Hỏa Pháp Sư ---
    "spark_bolt":       ("DIRECTION", 520.0, 0.0),
    "fireball":         ("DIRECTION", 700.0, 0.0),
    "flame_wall":       ("GROUND",    420.0, 82.0),
    "blaze_dash":       ("DIRECTION", 260.0, 0.0),
    "detonate":         ("SELF",      0.0,   320.0),
    # --- Sát Thủ Bóng Tối ---
    "dagger_strike":    ("DIRECTION", 80.0,  0.0),
    "twin_slash":       ("DIRECTION", 110.0, 0.0),
    "shadow_step":      ("SELF",      0.0,   0.0),
    "soul_mark":        ("DIRECTION", 560.0, 0.0),
    "death_blossom":    ("SELF",      0.0,   220.0),
    # --- Băng Sương Nữ ---
    "frost_shard":      ("DIRECTION", 620.0, 0.0),
    "ice_lance":        ("DIRECTION", 700.0, 0.0),
    "frost_nova":       ("SELF",      0.0,   195.0),
    "ice_slide":        ("DIRECTION", 260.0, 0.0),
    "absolute_zero":    ("SELF",      0.0,   350.0),
    # --- Lôi Đình Chiến Binh ---
    "spark_shot":       ("DIRECTION", 620.0, 0.0),
    "thunder_strike":   ("DIRECTION", 700.0, 0.0),
    "lightning_dash":   ("DIRECTION", 280.0, 0.0),
    "charge_up":        ("SELF",      0.0,   260.0),
    "heavens_thunder":  ("GROUND",    520.0, 155.0),
    # --- Thạch Vệ Binh ---
    "rock_throw":       ("DIRECTION", 620.0, 0.0),
    "boulder_roll":     ("DIRECTION", 760.0, 0.0),
    "stone_wall":       ("GROUND",    340.0, 56.0),
    "stone_shield":     ("SELF",      0.0,   190.0),
    "earthquake":       ("SELF",      0.0,   300.0),
}

ID_RE = re.compile(r'(\n\t\tid = &"([a-z_]+)"\n)')

# Ba chiêu đặt vùng: đổi sang dùng điểm người chơi đã chọn.
GROUND_EXEC = [
    (
        "FireMage.gd",
        "var center: Vector2 = caster.global_position + aim.normalized() * PLACE_DISTANCE",
        "var center: Vector2 = ground_point(PLACE_DISTANCE, aim)",
    ),
    (
        "ThunderWarrior.gd",
        "var center: Vector2 = caster.global_position + aim.normalized() * CAST_RANGE",
        "var center: Vector2 = ground_point(CAST_RANGE, aim)",
    ),
    (
        "StoneGuardian.gd",
        "var center: Vector2 = caster.global_position + aim.normalized() * PLACE_DISTANCE",
        "var center: Vector2 = ground_point(PLACE_DISTANCE, aim)",
    ),
]


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "champions"
    total = 0

    for path in sorted(root.glob("*.gd")):
        text = path.read_text(encoding="utf-8")
        newline = "\r\n" if "\r\n" in text else "\n"
        changed = False

        def insert(match: "re.Match[str]") -> str:
            nonlocal changed
            sid = match.group(2)
            if sid not in SPEC:
                print("  chưa khai báo loại chiêu:", sid)
                return match.group(1)
            if "cast_type" in text:
                pass  # vẫn chèn; kiểm tra trùng ở dưới
            ctype, crange, aoe = SPEC[sid]
            changed = True
            block = match.group(1).rstrip("\n")
            return (
                block
                + newline
                + "\t\tcast_type = SkillBase.CastType." + ctype
                + newline
                + "\t\tcast_range = %.1f" % crange
                + newline
                + "\t\taoe_radius = %.1f" % aoe
                + newline
            )

        if "cast_type = SkillBase.CastType" not in text:
            text = ID_RE.sub(insert, text)

        for filename, old, new in GROUND_EXEC:
            if path.name == filename and old in text:
                text = text.replace(old, new)
                changed = True

        if changed:
            path.write_text(text, encoding="utf-8", newline="")
            count = text.count("cast_type = SkillBase.CastType")
            total += count
            print("đã gán %2d chiêu: %s" % (count, path.name))

    print("tổng cộng:", total, "chiêu")
    return 0


if __name__ == "__main__":
    sys.exit(main())
