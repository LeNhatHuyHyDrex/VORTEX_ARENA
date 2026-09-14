"""Thêm hàm basic_attack_preview() vào từng file tướng.

Menu chọn tướng cần hiện cả đánh thường, mà skill_preview() chỉ trả 4 kỹ năng.
Script này chèn một hàm riêng ngay sau skill_preview().
"""
import pathlib
import re
import sys

NAMES = {
    "FireMage.gd": "SparkBolt",
    "ShadowAssassin.gd": "DaggerStrike",
    "FrostMaiden.gd": "FrostShard",
    "ThunderWarrior.gd": "SparkShot",
    "StoneGuardian.gd": "RockThrow",
}

PATTERN = re.compile(
    r"(func skill_preview\(\) -> Array:\r?\n\treturn \[[^\]]*\]\r?\n)"
)

root = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "champions"
for filename, cls in NAMES.items():
    path = root / filename
    text = path.read_text(encoding="utf-8")
    if "basic_attack_preview" in text:
        print("skip (already has it):", filename)
        continue
    match = PATTERN.search(text)
    if match is None:
        print("NO MATCH:", filename)
        continue
    newline = "\r\n" if "\r\n" in match.group(1) else "\n"
    addition = (
        match.group(1)
        + newline
        + "## Đánh thường cũng cần hiện trong menu, nên trả riêng một bản."
        + newline
        + "func basic_attack_preview():"
        + newline
        + "\treturn " + cls + ".new()"
        + newline
    )
    path.write_text(text.replace(match.group(1), addition), encoding="utf-8", newline="")
    print("added:", filename)

sys.exit(0)
