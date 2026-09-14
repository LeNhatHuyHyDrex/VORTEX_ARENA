# -*- coding: utf-8 -*-
"""
Sinh model 3D cho 17 tướng Combo Arena bằng Meshy Text-to-3D API.

Cách dùng
---------
1. Cài thư viện:      pip install requests
2. Đặt API key:       set MESHY_API_KEY=xxxx        (Windows)
                       export MESHY_API_KEY=xxxx     (Linux/macOS)
                       (hoặc truyền --api-key xxxx)
3. Chạy toàn bộ:      python tools/generate_hero_assets.py
   Chạy vài tướng:    python tools/generate_hero_assets.py --heroes fire_mage,void_samurai
   Bỏ qua bước poll:  python tools/generate_hero_assets.py --no-wait   (chỉ tạo task + in ID)

Kết quả: model .glb + texture nằm tại assets/models/<tướng>/
Script có tính tiếp nối (resume): tướng đã có .glb sẽ bị bỏ qua ở lần chạy sau.

Tích hợp vào Godot 4.7 (tham khảo)
----------------------------------
- Copy thư mục assets/models/<tướng>/ vào project Godot (nội dung glb đã nhúng
  texture PBR trong chính file, Godot import .glb tự động thành PackedScene +
  mesh + material; mở Import dock để tinh chỉnh).
- Hiện game vẽ tướng bằng vector 2D procedural (ChampionVisual.gd). Muốn dùng
  model: dựng viewport 3D (SubViewport + DirectionalLight3D + Camera3D xoay
  isometric ~30 độ) rồi render từng model thành sprite sheet 8 hướng, thay
  dần cho lớp `_draw()`; hoặc giữ model làm "chiến tướng 3D" ở màn chọn
  tướng (chân dung xoay được) — chuẩn MOBA 2.5D hiện đại.
- 8000 poly / model là mức nhẹ: draw 17 tướng đồng thời vẫn ổn trên mobile.

Tham số sinh theo yêu cầu: low-poly stylized, ~8000 poly, texture rich,
PBR bật, canh đứng (A-pose), xuất .glb.
"""

import argparse
import os
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Thiếu thư viện 'requests'. Cài bằng:  pip install requests")
    sys.exit(1)

# ------------------------------------------------------------------ cấu hình

API_BASE = "https://api.meshy.ai/openapi/v1"
POLL_INTERVAL = 10.0          # giây giữa 2 lần hỏi trạng thái
POLL_TIMEOUT = 900.0          # tối đa 15 phút / model

# Phong cách chung: dồn hết "template dark-fantasy semi-chibi" vào BASE để
# prompt từng tướng chỉ cần mô tả đặc điểm riêng — nhất quán toàn bộ dàn nhân vật.
STYLE_BASE = (
    "stylized dark fantasy game hero, semi-chibi proportions, "
    "compact heroic silhouette (1:3.5 head-to-body ratio), "
    "clean simplified geometry, smooth silhouette-friendly shapes, "
    "hand-painted PBR textures, rich saturated colors, "
    "subtle emissive glow on magical accents, "
    "A-pose, standing upright, facing forward, "
    "single character, full body, no background, no base, no text"
)

# Danh sách 17 tướng — id khớp CHAMPION_ORDER trong GameData.gd.
HEROES: dict[str, str] = {
    "fire_mage": (
        "fire mage in ember-red and charcoal robes, ash-grey hood, "
        "casting staff topped with molten orange crystal orb, "
        "floating embers, glowing amber runes on sleeves"
    ),
    "shadow_assassin": (
        "shadow assassin in tight black-violet suit, half-mask, glowing purple eyes, "
        "twin curved daggers held low, wisps of dark smoke trailing the shoulders"
    ),
    "frost_maiden": (
        "frost sorceress in pale-blue layered dress, ice crystal crown, "
        "frost staff with snowflake head, frozen mist at her feet, "
        "cool white-cyan emissive trims"
    ),
    "thunder_warrior": (
        "thunder warrior in heavy plate armor with electric-blue energy seams, "
        "crested helm, massive war hammer crackling with lightning arcs"
    ),
    "stone_guardian": (
        "stone golem guardian, massive moss-covered rock body, "
        "glowing amber runes carved in chest and arms, "
        "tower shield of carved granite, gentle giant posture"
    ),
    "arcane_weaver": (
        "arcane weaver in deep-purple mystic robes with floating crystal shards, "
        "tall crystal staff, cyan magical threads swirling around hands, hooded"
    ),
    "mirage": (
        "desert mirage rogue, light sand-colored cloth wraps and veil, "
        "twin curved cyan daggers, heat-shimmer particles, agile stance"
    ),
    "marksman": (
        "marksman gunner in long leather coat, brass goggles, "
        "long rifle with glowing orange tracer barrel, ammo bandolier"
    ),
    "seraph": (
        "celestial seraph healer, white and gold flowing robes, golden halo, "
        "arc of floating prayer beads, swinging incense censer trailing warm light"
    ),
    "artificer": (
        "goblin-friendly artificer engineer, leather work apron over teal shirt, "
        "mechanical gauntlet arm, oversized wrench, welding sparks, brass pipes"
    ),
    "tamer": (
        "beast tamer in fur-trimmed ranger garb, green and earth tones, "
        "coiled long whip at hip, feather charms, confident wild stance"
    ),
    "time_weaver": (
        "time weaver in clockwork-themed teal and gold robe, floating hourglass, "
        "orbiting golden gears, sand-like temporal particles"
    ),
    "blood_lord": (
        "vampire blood lord aristocrat, crimson high-collar coat, pale skin, "
        "twin red claw gauntlets, faint blood-red mist aura"
    ),
    "iron_monk": (
        "bald iron monk, simple wrapped sash robes, golden prayer beads necklace, "
        "heavy iron chain belt, calm disciplined martial stance, scarred knuckles"
    ),
    "berserker": (
        "berserker raider, massive scarred physique, fur and heavy iron plates, "
        "oversized greataxe on shoulder, red war paint, battle roar stance"
    ),
    "void_samurai": (
        "void samurai in dark lacquered armor with purple rift cracks, "
        "onmask with glowing violet eyes, sheathed katana held ready, "
        "swallowing starlight void effects"
    ),
    "plague_alchemist": (
        "plague doctor alchemist, long-beaked leather mask, hooded cloak, "
        "backpack rack of bubbling green flasks, toxic mist around boots"
    ),
}


# -------------------------------------------------------------------- API

def create_task(session: requests.Session, api_key: str, prompt: str) -> str:
    """Tạo task text-to-3D, trả về task id."""
    resp = session.post(
        f"{API_BASE}/text-to-3d",
        headers={"Authorization": f"Bearer {api_key}"},
        json={
            "prompt": prompt,
            "art_style": "low-poly",        # stylized; đổi "vivid" nếu muốn mượt hơn
            "target_polycount": 8000,        # nhẹ enough cho mobile, đủ nét cho 2.5D
            "texture_richness": 2,           # 2 = high
            "enable_pbr": True,
            "alignment": "vertical",         # canh đứng — nhân vật A-pose
            "should_use_primitive_uv": False,
            "negative_prompt": (
                "extra limbs, deformed hands, blurry, photorealistic, "
                "multiple characters, weapons duplicated, text, watermark"
            ),
        },
        timeout=60,
    )
    resp.raise_for_status()
    data = resp.json()
    # API trả {"result": "<id>"}; một số bản trả thẳng id.
    return data.get("result") or data.get("id") or data.get("task_id")


def poll_task(session: requests.Session, api_key: str, task_id: str,
              no_wait: bool) -> dict:
    """Hỏi trạng thái task tới khi SUCCEEDED/FAILED. Trả JSON cuối."""
    deadline = time.time() + POLL_TIMEOUT
    while True:
        resp = session.get(
            f"{API_BASE}/text-to-3d/{task_id}",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=60,
        )
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status", "")
        progress = data.get("progress", 0)
        if status in ("SUCCEEDED", "FAILED", "EXPIRED"):
            return data
        if no_wait:
            return data
        if time.time() > deadline:
            print(f"    ! Hết thời gian chờ ({int(POLL_TIMEOUT)}s), dừng poll.")
            return data
        print(f"    ... {status} {progress}%", end="\r", flush=True)
        time.sleep(POLL_INTERVAL)


def download(session: requests.Session, url: str, dest: Path) -> bool:
    """Tải file (glb/texture) về dest. Bỏ qua nếu url rỗng."""
    if not url:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    with session.get(url, stream=True, timeout=300) as r:
        r.raise_for_status()
        tmp = dest.with_suffix(dest.suffix + ".part")
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 16):
                f.write(chunk)
        tmp.replace(dest)
    size_kb = dest.stat().st_size / 1024
    print(f"    + {dest.name}  ({size_kb:,.0f} KB)")
    return True


# ------------------------------------------------------------------- chính

def main() -> None:
    root = Path(__file__).resolve().parent.parent      # thư mục gốc project
    default_out = root / "assets" / "models"

    ap = argparse.ArgumentParser(description="Sinh model 3D tướng bằng Meshy API.")
    ap.add_argument("--heroes", default="",
                    help="Danh sách id tướng cách nhau bởi dấu phẩy. Mặc định: tất cả.")
    ap.add_argument("--out", default=str(default_out), help="Thư mục lưu model.")
    ap.add_argument("--api-key", default="",
                    help="Meshy API key (ưu tiên env MESHY_API_KEY).")
    ap.add_argument("--no-wait", action="store_true",
                    help="Chỉ tạo task và in ID, không chờ hoàn thành.")
    ap.add_argument("--force", action="store_true",
                    help="Sinh lại cả khi .glb đã tồn tại.")
    args = ap.parse_args()

    api_key = args.api_key or os.environ.get("MESHY_API_KEY", "")
    if not api_key:
        print("Chưa có API key. Đặt biến môi trường MESHY_API_KEY hoặc dùng --api-key.")
        sys.exit(1)

    wanted = [h.strip() for h in args.heroes.split(",") if h.strip()]
    heroes = {h: HEROES[h] for h in wanted} if wanted else dict(HEROES)
    for h in heroes:
        if h not in HEROES:
            print(f"! Không biết tướng '{h}'. Các id hợp lệ: {', '.join(HEROES)}")
            sys.exit(1)

    out_root = Path(args.out)
    session = requests.Session()
    ok: list[str] = []
    failed: list[str] = []

    print(f"Meshy Text-to-3D — {len(heroes)} tướng → {out_root}")
    for idx, (hero_id, look) in enumerate(heroes.items(), 1):
        dest_dir = out_root / hero_id
        glb_path = dest_dir / f"{hero_id}.glb"
        print(f"\n[{idx}/{len(heroes)}] {hero_id}")

        if glb_path.exists() and not args.force:
            print("    = đã có .glb, bỏ qua (dùng --force để sinh lại).")
            ok.append(hero_id)
            continue

        prompt = f"{STYLE_BASE}, {look}"
        try:
            task_id = create_task(session, api_key, prompt)
        except requests.RequestException as e:
            print(f"    ! tạo task lỗi: {e}")
            failed.append(hero_id)
            continue
        print(f"    task: {task_id}")

        data = poll_task(session, api_key, task_id, args.no_wait)
        status = data.get("status", "?")
        if status != "SUCCEEDED":
            print(f"\n    ! trạng thái: {status} — xem lại task {task_id} trên meshy.ai")
            failed.append(hero_id)
            continue

        urls: dict = data.get("model_urls") or {}
        pbr_urls: dict = data.get("pbr_model_urls") or {}
        got = download(session, urls.get("glb") or pbr_urls.get("glb"), glb_path)
        # Ảnh xem trước + bản PBR khác nếu API trả kèm.
        download(session, data.get("thumbnail_url"), dest_dir / "preview.png")
        for fmt in ("obj", "fbx", "usdz"):
            download(session, urls.get(fmt), dest_dir / f"{hero_id}.{fmt}")
        if got:
            ok.append(hero_id)
        else:
            print("    ! không có đường dẫn .glb trong kết quả.")
            failed.append(hero_id)

    print(f"\nXong: {len(ok)} thành công, {len(failed)} lỗi.")
    if failed:
        print("Lỗi:", ", ".join(failed))
    print("Bước tiếp theo: copy assets/models/<tướng>/ vào project Godot "
          "và import (Godot tự nhận .glb). Xem hướng dẫn tích hợp ở đầu file này.")


if __name__ == "__main__":
    main()
