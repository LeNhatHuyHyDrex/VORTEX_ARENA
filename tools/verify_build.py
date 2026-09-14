#!/usr/bin/env python3
"""Kiểm tra bản build có thật sự chứa mã mới hay không.

Vì sao cần: Godot đôi khi "build xong" mà thực ra thất bại (thiếu APPDATA, thiếu
export template...), để lại file .exe/.apk cũ từ lần build trước. Người dùng mở
lên thấy đúng giao diện cũ và không hiểu vì sao sửa mã rồi mà game không đổi.
Script này mở thẳng sản phẩm ra, đếm xem có đủ tướng và các file mới không.

Dùng:
    python tools/verify_build.py
    python tools/verify_build.py --expect 12
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXE = ROOT / "build" / "windows" / "ComboArena.exe"
APK = ROOT / "build" / "android" / "ComboArena-debug.apk"

# Những file "đánh dấu": nếu thiếu một trong số này thì bản build chắc chắn cũ.
MARKERS = [
    "champions/Mirage",
    "champions/Marksman",
    "champions/Seraph",
    "champions/Artificer",
    "champions/Tamer",
    "champions/TimeWeaver",
    "champions/ArcaneWeaver",
    "ui/PauseMenu",
    "core/Passive",
    "ui/CastIndicator",
    "world/DamageNumber",
]


def read_exe_index(path: Path) -> set[str]:
    """Quét tên tài nguyên trong file .exe có PCK nhúng.

    Godot xuất script dạng `X.gd.remap` trỏ tới `X.gdc` (bytecode), nên tên file
    gốc vẫn còn nguyên trong gói. Quét chuỗi là đủ, không cần bóc PCK.
    """
    data = path.read_bytes()
    found: set[str] = set()
    for m in re.finditer(rb"res://[A-Za-z0-9_./\-]{6,160}", data):
        found.add(m.group().decode("ascii", "replace"))
    return found


def read_apk_index(path: Path) -> set[str]:
    with zipfile.ZipFile(path) as z:
        return set(z.namelist())


def check(label: str, index: set[str], expect_champs: int) -> bool:
    print(f"\n--- {label} ---")
    ok = True

    champs = {n for n in index if "/champions/" in n and n.endswith((".gd", ".gdc"))}
    names = {n.rsplit("/", 1)[-1].split(".")[0] for n in champs}
    print(f"  tướng trong bản build: {len(names)}")
    for n in sorted(names):
        print(f"    - {n}")
    if len(names) < expect_champs:
        print(f"  THIẾU: kỳ vọng {expect_champs} tướng, chỉ có {len(names)}")
        ok = False

    print("  file đánh dấu:")
    for marker in MARKERS:
        hit = any(marker in n for n in index)
        print(f"    {'có ' if hit else 'KHÔNG CÓ'} {marker}")
        if not hit:
            ok = False

    print(f"  => {label}: {'ĐẠT' if ok else 'KHÔNG ĐẠT'}")
    return ok


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--expect", type=int, default=17,
                    help="số tướng kỳ vọng (mặc định 17: 12 cũ + 5 mới)")
    args = ap.parse_args()

    if not EXE.exists() and not APK.exists():
        print("Không tìm thấy sản phẩm build nào. Chạy tools/build.sh trước.",
              file=sys.stderr)
        return 1

    ok = True
    if EXE.exists():
        ok &= check(f"Windows ({EXE.name})", read_exe_index(EXE), args.expect)
    if APK.exists():
        ok &= check(f"Android ({APK.name})", read_apk_index(APK), args.expect)

    print()
    if ok:
        print("Tất cả bản build đều chứa mã mới.")
        return 0
    print("Ít nhất một bản build còn cũ — chạy lại tools/build.sh.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
