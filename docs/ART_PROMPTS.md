# Bộ prompt sinh art cho Combo Arena (17 tướng + bộ giao diện)

Prompt viết bằng tiếng Anh vì mọi model ảnh AI hiểu tiếng Anh tốt nhất.
Phần hướng dẫn giữ tiếng Việt.

---

## 1. Khối phong cách dùng chung (STYLE) — dán trước mọi prompt

```
dark fantasy game art, 2.5D isometric look, semi-chibi heroic proportions
(1:3.5 head-to-body ratio), hand-painted PBR textures, strong rim lighting,
glowing emissive magical accents, rich saturated colours, deep shadows,
clean readable silhouette, crisp painted detail, centred composition
```

## 2. Khối loại trừ dùng chung (NEGATIVE)

```
text, letters, words, watermark, signature, logo, ui frame, border, multiple
characters, extra limbs, deformed hands, blurry, low contrast, flat lighting,
photograph, plastic 3d render, plain flat vector shapes, anime lineart,
oversized chibi head, ground shadow, scenery background, cropped head
```

## 3. Khung hình (FRAMING) — chọn theo loại ảnh

**Ảnh THẺ** (`champions/cards/`) — tỉ lệ 3:4:
```
upper body portrait, three-quarter view, centred, dark moody background with
rim light behind the shoulders, trading card art composition, empty space at
the bottom for a name banner
```

**Ảnh TRONG TRẬN** (`champions/bodies/`) — tỉ lệ 2:3:
```
full body, standing neutral pose, front view, feet exactly at the bottom edge
of the image, plain transparent background, no shadow, no ground, no scenery
```

**Cách ghép prompt hoàn chỉnh:**
`STYLE + ", " + <chủ thể tướng> + ", " + FRAMING`
→ dán vào ô prompt, dán NEGATIVE vào ô negative prompt.

---

## 4. Chủ thể từng tướng (17)

| # | id file | Chủ thể (dán vào giữa STYLE và FRAMING) |
|---|---|---|
| 1 | `fire_mage` | fire mage in ember-red and charcoal robes, ash-grey hood, tall staff topped with a molten orange crystal orb, floating embers around the hands |
| 2 | `shadow_assassin` | shadow assassin in a black-violet bodysuit, half mask, glowing purple eyes, twin curved daggers held low, wisps of dark smoke at the shoulders |
| 3 | `frost_maiden` | frost sorceress in a pale-blue layered gown, ice crystal crown, frost staff with a snowflake head, cold mist curling at her feet |
| 4 | `thunder_warrior` | thunder warrior in heavy plate armour with electric-blue energy seams, crested helm, massive warhammer crackling with lightning arcs |
| 5 | `stone_guardian` | stone golem guardian, massive moss-covered rock body, glowing amber runes carved into chest and arms, granite tower shield |
| 6 | `arcane_weaver` | arcane weaver in deep-purple mystic robes with floating crystal shards, tall crystal staff, cyan magical threads swirling around the hands |
| 7 | `mirage` | desert mirage rogue in light sand-coloured cloth wraps and a veil, twin curved cyan daggers, faint heat-shimmer distortion |
| 8 | `marksman` | marksman gunner in a long leather coat, brass goggles, long rifle with a glowing orange tracer barrel, ammo bandolier |
| 9 | `seraph` | celestial seraph healer in white and gold flowing robes, golden halo, arc of floating prayer beads, swinging incense censer |
| 10 | `artificer` | artificer engineer in a leather work apron over a teal shirt, mechanical gauntlet arm, oversized wrench, welding sparks |
| 11 | `tamer` | beast tamer in fur-trimmed ranger garb, green and earth tones, coiled long whip at the hip, feather charms |
| 12 | `time_weaver` | time weaver in a clockwork teal and gold robe, floating hourglass, orbiting golden gears, sand-like temporal particles |
| 13 | `blood_lord` | vampire blood lord in a crimson high-collar coat, pale skin, twin red claw gauntlets, faint blood-red mist aura |
| 14 | `iron_monk` | bald iron monk in wrapped sash robes, golden prayer beads necklace, heavy iron chain belt, scarred knuckles |
| 15 | `berserker` | berserker raider, massive scarred physique, fur and heavy iron plates, oversized greataxe resting on the shoulder, red war paint |
| 16 | `void_samurai` | void samurai in dark lacquered armour with purple rift cracks, oni mask with glowing violet eyes, sheathed katana held ready |
| 17 | `plague_alchemist` | plague doctor alchemist in a long-beaked leather mask and hooded cloak, backpack rack of bubbling green flasks, toxic mist at the boots |

---

## 5. Bộ giao diện (`ui/`)

| tên file | Prompt |
|---|---|
| `panel_parchment` | `ornate dark fantasy parchment panel, aged paper texture with burnt edges, gold ornamental corner filigree, dark wood frame, empty centre area for text, front view, game UI element, transparent background` |
| `card_frame` | `dark fantasy trading card frame, vertical 3:4, ornate gold and dark iron filigree border, small glowing rune gems at the four corners, empty centre, game UI element, transparent background` |
| `pedestal` | `isometric stone display pedestal, carved runic band around the top, cracked granite, faint amber glow from the rune grooves, game asset, transparent background` |
| `button_normal` | `dark fantasy game button, iron plate with thin gold trim, beveled edges, empty centre for text, front view, game UI element, transparent background` |
| `button_hover` | same as `button_normal` but `brighter glow along the top edge, warmer gold trim` |
| `title_ribbon` | `dark fantasy title banner ribbon, torn cloth with gold embroidery, horizontal, empty centre for text, transparent background` |
| `skill_slot` | `dark fantasy square skill slot frame, dark iron with a coloured gem inlay, beveled inner shadow, empty centre, game UI element, transparent background` |

---

## 6. Cách dùng theo từng tool

**Midjourney** — thêm vào cuối prompt:
`--ar 3:4 --style raw --sref <link ảnh tướng đã ưng>` (cho ảnh thẻ)
`--ar 2:3 --style raw --sref <link ảnh tướng đã ưng>` (cho ảnh trong trận)
Giữ nguyên `--sref` và `--seed` cho cả 17 ảnh → dàn tướng đồng bộ.

**Stable Diffusion / Flux (local hoặc web)** —
- Dán NEGATIVE vào ô negative prompt (bắt buộc, nếu không sẽ ra chữ và nền).
- Giữ nguyên seed + checkpoint + LoRA cho cả 17 ảnh.
- Dùng **IP-Adapter** hoặc **ControlNet reference** với ảnh tướng đầu tiên để đồng bộ style.

**Leonardo / Ideogram / Bing Image Creator / DALL·E** —
- Chỉ có một ô prompt → nối NEGATIVE vào cuối dạng "avoid: text, watermark, ...".
- Ideogram vẽ chữ tốt hơn nhưng ta **không muốn chữ**, nên cứ để NEGATIVE chặn.

**Muốn nét vẽ "đồ chơi" như ảnh mẫu của bạn hơn** → thêm vào STYLE:
`toy-like glossy shading, miniature diorama lighting, rim light from behind`

---

## 7. Quy trình đề xuất (làm 1 tướng trước, đừng làm cả 17 ngay)

1. Sinh **Hỏa Pháp Sư** — ảnh thẻ 3:4, 4 biến thể.
2. Chọn 1 ảnh ưng nhất → lưu lại **seed + prompt + ảnh đó**.
3. Đặt vào `art/champions/cards/fire_mage.png` cạnh file `ComboArena.exe`
   (xem `assets/art/README.md`) → mở game kiểm tra thực tế.
4. Ưng rồi mới dùng ảnh đó làm tham chiếu style, sinh tiếp 16 tướng.
5. Xong bộ thẻ → làm tiếp bộ ảnh trong trận (2:3, nền trong suốt).
6. Cuối cùng mới tới bộ `ui/`.

---

## 8. Bảng theo dõi tiến độ

| Nhóm | Đã có | Cần | Ghi chú |
|---|---|---|---|
| `champions/cards/` | 0 | 17 | Ưu tiên cao nhất — thay đổi thấy ngay |
| `champions/bodies/` | 0 | 17 | Ưu tiên 2 |
| `ui/` | 0 | 7 | Ưu tiên 3 |

Khi đã có ảnh trong `combo-arena/assets/art/`, chạy lại `bash tools/build.sh`
để đóng gói vào bản Windows/Android.
