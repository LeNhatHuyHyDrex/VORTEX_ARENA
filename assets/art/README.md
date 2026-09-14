# Khe cắm art (asset raster) — thả ảnh vào là game tự nâng cấp

Game tự dò ảnh ở **3 nơi**, theo thứ tự ưu tiên. Chỉ cần đặt đúng tên file là
ảnh được dùng ngay; **không có ảnh thì game vẽ vector như cũ** — không bao giờ vỡ.

| Ưu tiên | Vị trí | Dùng khi nào |
|---|---|---|
| 1 | `res://assets/art/<nhóm>/<tên>.png` | Ảnh nằm trong project, đóng gói luôn khi build |
| 2 | `<cạnh file .exe>/art/<nhóm>/<tên>.png` | **Thử nhanh** — thả ảnh cạnh game, KHÔNG cần build lại |
| 3 | `user://art/<nhóm>/<tên>.png` | Android / máy không ghi được cạnh file game |

## Các nhóm và tên file

### 1. `champions/cards/<id_tướng>.png` — ảnh thẻ chọn tướng
- Tỉ lệ **3:4** (khuyến nghị 768×1024), PNG nền trong suốt.
- Nội dung: **nửa người trên** (đầu + thân + vũ khí), nhìn thẳng, nền tối.
- Game vẽ khung viền + tên tướng **đè lên trên** → ảnh **không cần chữ**.
- Ảnh được cắt kiểu "cover" nên mép thừa sẽ bị cắt, đặt nhân vật ở giữa khung.

### 2. `champions/bodies/<id_tướng>.png` — ảnh nhân vật trong trận
- Tỉ lệ **2:3** (khuyến nghị 512×768), PNG nền trong suốt.
- Nội dung: **toàn thân**, đứng thẳng, nhìn thẳng (game tự lật ngang khi đi trái).
- **Đáy ảnh = mặt đất** (chân nhân vật chạm mép dưới). Game vẽ bóng đổ và bệ đá
  bên dưới, nên ảnh **không cần bóng, không cần nền, không cần chữ**.

### 3. `ui/<tên>.png` — mảnh giao diện dùng chung
Tên file (đặt đúng như vậy nếu muốn game dùng):
`panel_parchment`, `card_frame`, `pedestal`, `button_normal`, `button_hover`,
`title_ribbon`, `skill_slot`

## Danh sách id tướng (17)

```
fire_mage          shadow_assassin   frost_maiden      thunder_warrior
stone_guardian     arcane_weaver     mirage            marksman
seraph             artificer         tamer             time_weaver
blood_lord         iron_monk         berserker         void_samurai
plague_alchemist
```

## Cách thử nhanh (không cần build lại)

1. Sinh ảnh bằng tool AI bạn có (xem `docs/ART_PROMPTS.md` để lấy prompt sẵn).
2. Tạo thư mục `art/champions/cards/` **cạnh file `ComboArena.exe`**.
3. Đặt file, ví dụ `art/champions/cards/fire_mage.png`.
4. Mở game → vào màn chọn tướng → thẻ Hỏa Pháp Sư dùng ảnh mới.

Muốn đóng gói ảnh vào bản build thì chép vào `combo-arena/assets/art/...` rồi
chạy `bash tools/build.sh`.

## Quy tắc để cả dàn tướng trông cùng một thế giới

1. **Cùng một model + cùng seed + cùng style prefix** cho cả 17 ảnh.
2. Sinh 1 tướng trước, ưng rồi mới dùng nó làm ảnh tham chiếu style cho 16 tướng
   còn lại (Midjourney `--sref`, SDXL IP-Adapter, hoặc "reference image" trong
   các tool khác).
3. **Không để AI vẽ chữ** trong ảnh — chữ trong ảnh AI luôn sai chính tả.
   Chữ do game vẽ, sắc nét và đổi ngôn ngữ được.
