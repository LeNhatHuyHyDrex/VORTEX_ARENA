#!/usr/bin/env bash
# Đóng gói Combo Arena cho Windows và Android.
#
# Ba cái bẫy đã gặp thật khi viết script này — tất cả đều làm build "có vẻ chạy"
# nhưng thực ra thất bại, hoặc sinh ra bản cũ mà người dùng không biết:
#
# 1. APPDATA bị rỗng. Godot trên Windows đọc `%APPDATA%/Godot/` để lấy export
#    template và cấu hình JDK. Trong shell không phải cmd.exe (Git Bash, MSYS,
#    CI) biến này rất hay không được truyền sang. Khi đó Godot rớt về chế độ
#    "self-contained": tạo ./Godot/ ngay trong project rồi báo
#    "No export template found at the expected path: ./Godot/export_templates/...".
#    → Script phải tự đặt APPDATA.
#
# 2. Thư mục làm việc nằm trong project. Cùng hậu quả như trên: Godot tạo
#    ./Godot/ cục bộ. → Chạy từ thư mục ngoài project và truyền --path tuyệt đối.
#
# 3. Đường dẫn kiểu Git Bash (`/c/Users/...`). Godot là file thực thi Windows,
#    không hiểu dạng này. → Đổi bằng `pwd -W`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# pwd -W chỉ có trên Git Bash / MSYS. Trên Linux/macOS thì dùng pwd thường.
if PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -W 2>/dev/null)"; then
  :
else
  PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

GODOT="${GODOT:-$PROJECT_DIR/../_engine/Godot_v4.7.2-stable_win64_console.exe}"
export GODOT

# --- 1. Đảm bảo APPDATA tồn tại ------------------------------------------------
# Đây là bước quan trọng nhất. Không có nó, Godot dùng ./Godot/ cục bộ và mọi
# export đều thất bại với thông báo nói về export template — đánh lừa là lỗi
# thiếu template, trong khi template vẫn nằm yên trong %APPDATA%.
if [[ -z "${APPDATA:-}" ]]; then
  if [[ -n "${USERPROFILE:-}" ]]; then
    # USERPROFILE thường là `C:\Users\ASUS` — đổi gạch chéo cho Godot hiểu.
    APPDATA="${USERPROFILE//\\//}/AppData/Roaming"
  elif [[ -n "${HOME:-}" ]]; then
    APPDATA="${HOME}/AppData/Roaming"
  else
    echo "Không đoán được APPDATA. Đặt thủ công:" >&2
    echo "  export APPDATA='C:/Users/<tên>/AppData/Roaming'" >&2
    exit 1
  fi
  export APPDATA
fi

if [[ ! -d "$APPDATA" ]]; then
  echo "APPDATA không tồn tại: $APPDATA" >&2
  echo "Đặt thủ công: export APPDATA='C:/Users/<tên>/AppData/Roaming'" >&2
  exit 1
fi

# --- 2. Dọn thư mục Godot/ rơi rớt trong project -------------------------------
# Nếu từng chạy Godot với cwd nằm trong project, nó sẽ để lại thư mục này.
# Để lại thì lần build sau Godot lại đọc cấu hình từ đó, và lại thất bại.
for STRAY in "$PROJECT_DIR/Godot" "$PROJECT_DIR/NVIDIA Corporation"; do
  if [[ -d "$STRAY" ]]; then
    echo "Dọn thư mục rác: $STRAY"
    rm -rf "$STRAY"
  fi
done

# --- 3. Chạy Godot từ thư mục ngoài project ------------------------------------
if [[ ! -f "$GODOT" ]]; then
  echo "Không tìm thấy Godot tại: $GODOT" >&2
  echo "Đặt biến môi trường GODOT trỏ tới file thực thi Godot 4.7." >&2
  exit 1
fi

NEUTRAL_CWD="${NEUTRAL_CWD:-/tmp}"
mkdir -p "$NEUTRAL_CWD" 2>/dev/null || true
cd "$NEUTRAL_CWD" || {
  echo "Không thể chuyển tới thư mục trung gian: $NEUTRAL_CWD" >&2
  exit 1
}

echo "Project: $PROJECT_DIR"
echo "Godot:   $GODOT"
echo "APPDATA: $APPDATA"
echo "cwd:     $(pwd)"
echo

echo "==> Kiểm tra script trước khi build"
# grep trả về 1 khi không tìm thấy dòng nào — đó mới là kết quả tốt.
if "$GODOT" --headless --path "$PROJECT_DIR" --quit-after 600 2>&1 \
    | grep -E "SCRIPT ERROR|Parse Error"; then
  echo >&2
  echo "Còn lỗi script ở trên, dừng build." >&2
  exit 1
fi
echo "    Không có lỗi script."
echo

# Chạy export, đồng thời bắt sẵn hai dấu hiệu của chế độ self-contained để báo
# lỗi rõ ràng thay vì để người dùng tự đoán.
run_export() {
  local label="$1"; shift
  echo "==> $label"
  local log
  log="$("$@" 2>&1)"
  echo "$log" | grep -vE '^\s*\[\s*[0-9]+%|^\s*\[ DONE \]' | sed 's/^/    /'
  if echo "$log" | grep -qE "No export template found|Cannot open directory '\./Godot|Could not open 'user://'"; then
    echo >&2
    echo "Godot đang ở chế độ self-contained (đọc ./Godot/ thay vì %APPDATA%/Godot/)." >&2
    echo "Kiểm tra biến APPDATA: hiện tại là [$APPDATA]" >&2
    exit 1
  fi
  echo
}

run_export "Windows (release)" "$GODOT" --headless --path "$PROJECT_DIR" \
  --export-release "Windows Desktop" "$PROJECT_DIR/build/windows/ComboArena.exe"

run_export "Android (debug, đã ký bằng khoá debug)" "$GODOT" --headless \
  --path "$PROJECT_DIR" \
  --export-debug "Android" "$PROJECT_DIR/build/android/ComboArena-debug.apk"

# --- 4. Báo cáo, kèm mốc thời gian để biết chắc file vừa được ghi --------------
echo "Xong. Sản phẩm:"
ls -la --time-style=+"%Y-%m-%d %H:%M:%S" \
  "$PROJECT_DIR/build/windows/ComboArena.exe" \
  "$PROJECT_DIR/build/android/ComboArena-debug.apk"
echo
echo "Build lúc: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# --- 5. Mở sản phẩm ra đếm thử có đủ tướng không --------------------------------
# Bước này ngăn tình huống khó chịu nhất: build báo xong nhưng thực ra thất bại,
# để lại file cũ, người dùng mở lên thấy game không đổi mà không hiểu tại sao.
if command -v python >/dev/null 2>&1; then
  PY=python
elif command -v python3 >/dev/null 2>&1; then
  PY=python3
else
  PY=""
fi
if [[ -n "$PY" && -f "$PROJECT_DIR/tools/verify_build.py" ]]; then
  echo "==> Kiểm tra bản build"
  ( cd "$PROJECT_DIR" && "$PY" tools/verify_build.py ) || {
    echo >&2
    echo "Bản build KHÔNG chứa mã mới. Xem lại các bước trên." >&2
    exit 1
  }
else
  echo "Bỏ qua bước kiểm tra (không tìm thấy python hoặc tools/verify_build.py)."
fi
