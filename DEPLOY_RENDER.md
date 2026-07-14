# Hướng dẫn triển khai lên Render.com (từng bước)

Tài liệu này dành riêng cho project `ocr2word_webapp`, viết cho người
**chưa quen dùng VPS**. Bạn sẽ không phải tự cài Linux, không phải tự
gõ lệnh SSH — chỉ cần một tài khoản GitHub và một tài khoản Render.

Toàn bộ quá trình mất khoảng 15-20 phút cho lần đầu.

---

## Vì sao phải dùng Docker (không dùng "Python" thường trên Render)?

Render có 2 cách chạy code Python:
1. **Native runtime** — Render tự cài Python, bạn chỉ cần `pip install`. Đơn giản, nhưng **không cài được Pandoc** (Pandoc là phần mềm hệ thống, không phải thư viện Python).
2. **Docker** — bạn tự định nghĩa toàn bộ môi trường qua file `Dockerfile` (đã có sẵn trong project), Render build và chạy y hệt.

Vì converter.py cần gọi lệnh `pandoc` thật, project này **bắt buộc chọn Docker** khi tạo service trên Render. Không cần hiểu sâu về Docker — file `Dockerfile` đã viết sẵn, bạn chỉ cần chọn đúng tuỳ chọn "Docker" lúc tạo service (chi tiết ở Bước 4).

---

## Bước 1: Đưa code lên GitHub

Render lấy code từ 1 repo GitHub (hoặc GitLab/Bitbucket) để build, nên cần đưa code lên đó trước.

### 1a. Tạo tài khoản GitHub (nếu chưa có)
Vào https://github.com/signup, đăng ký miễn phí.

### 1b. Tạo 1 repository mới
1. Đăng nhập GitHub → góc trên bên phải bấm dấu **+** → **New repository**.
2. Đặt tên, ví dụ: `ocr2word-webapp`.
3. Để **Public** hoặc **Private** đều được (Private thì lúc kết nối Render cần cấp quyền truy cập, sẽ hướng dẫn ở Bước 3).
4. **Không** tick "Add a README file" (vì project mình đã có sẵn code).
5. Bấm **Create repository**.

### 1c. Đưa code lên (cách dễ nhất — không cần dùng dòng lệnh Git)
1. Trên trang repo vừa tạo, bấm **uploading an existing file** (hoặc "Add file" → "Upload files").
2. Giải nén file zip project ra máy bạn trước.
3. Kéo-thả **toàn bộ nội dung bên trong thư mục** `ocr2word_webapp/` (tức là kéo các file `app.py`, `converter.py`, `Dockerfile`, `requirements.txt`, `.dockerignore`, thư mục `templates/` — **không kéo cả thư mục `ocr2word_webapp` bọc ngoài**, mà kéo các file/thư mục con bên trong nó) vào khung upload trên GitHub.
4. Cuộn xuống, bấm **Commit changes**.

Nếu bạn quen dùng terminal, cách nhanh hơn:
```bash
cd ocr2word_webapp
git init
git add .
git commit -m "First commit"
git branch -M main
git remote add origin https://github.com/<ten-tai-khoan>/ocr2word-webapp.git
git push -u origin main
```

**Kiểm tra lại:** vào repo trên GitHub, bạn phải thấy các file `app.py`, `Dockerfile`, `requirements.txt`... nằm **ngay ở thư mục gốc** của repo (không bị lồng thêm 1 cấp thư mục `ocr2word_webapp/` nữa) — nếu bị lồng, Render sẽ không tìm thấy `Dockerfile`.

---

## Bước 2: Tạo tài khoản Render

1. Vào https://render.com → **Get Started**.
2. Đăng ký (có thể đăng ký nhanh bằng tài khoản GitHub — nên chọn cách này vì bước sau sẽ tự động kết nối luôn).

---

## Bước 3: Kết nối GitHub với Render

1. Trong Render Dashboard → vào **Account Settings** → mục **Account Security**.
2. Ở phần **Git Deployment Credentials**, bấm **Add credential**, chọn GitHub, cấp quyền cho Render truy cập vào repo bạn vừa tạo (chọn "All repositories" hoặc chỉ chọn đúng repo `ocr2word-webapp` cho an toàn).

---

## Bước 4: Tạo Web Service từ repo

1. Trong Render Dashboard, bấm **+ New** (góc trên phải) → chọn **Web Service**.
2. Danh sách repo hiện ra → tìm và bấm **Connect** vào repo `ocr2word-webapp`.
3. Điền form cấu hình:
   | Trường | Giá trị cần điền |
   |---|---|
   | **Name** | Tuỳ ý, ví dụ `ocr2word` (sẽ thành 1 phần của URL: `ocr2word.onrender.com`) |
   | **Region** | Chọn khu vực gần Việt Nam nhất đang có (Singapore nếu Render hỗ trợ, hoặc khu vực gần nhất khác) |
   | **Branch** | `main` |
   | **Root Directory** | Để trống (vì code đã nằm ở gốc repo) |
   | **Language** | **Chọn "Docker"** ⚠️ đây là bước quan trọng nhất — không chọn "Python" |
   | **Instance Type** | Chọn **Free** để dùng thử miễn phí |
4. Không cần điền Build Command / Start Command — vì Docker đã tự có sẵn trong `Dockerfile` (Render sẽ tự tìm và dùng nó).
5. Bấm **Create Web Service** (hoặc **Deploy**) ở cuối form.

---

## Bước 5: Theo dõi quá trình build

- Render sẽ tự động: kéo code → build Docker image (cài Pandoc + Python packages) → chạy container.
- Lần đầu build có thể mất **3-6 phút** (do phải cài Pandoc từ đầu).
- Theo dõi log ngay trên trang service — khi thấy dòng tương tự `Your service is live 🎉` là xong.
- Nếu build lỗi, đọc kỹ dòng đỏ trong log — lỗi phổ biến nhất là quên chọn "Docker" ở Bước 4 (Render sẽ báo không tìm thấy cách chạy Python thông thường).

---

## Bước 6: Lấy URL và kiểm tra

1. Trên trang service, Render hiển thị 1 URL dạng: `https://ocr2word.onrender.com`
2. Mở URL đó bằng trình duyệt — bạn sẽ thấy đúng giao diện upload đã làm.
3. Thử upload 1 file JSON để chắc chắn convert chạy được thật trên server (không chỉ trên máy bạn).

---

## Bước 7: Trỏ macro VBA trong Word về đúng server

Mở file `OcrJsonToWordClient.bas` (import lại vào Word nếu chưa), sửa dòng:

```vba
Private Const SERVER_URL As String = "http://192.168.1.50:8000/convert_direct"
```

thành:

```vba
Private Const SERVER_URL As String = "https://ocr2word.onrender.com/convert_direct"
```

(thay `ocr2word.onrender.com` bằng đúng URL Render cấp cho bạn ở Bước 6). Lưu ý dùng **`https://`** vì Render mặc định luôn có HTTPS sẵn.

---

## Một vài điều cần biết khi dùng gói Free của Render

- **"Ngủ" sau 15 phút không dùng:** gói Free sẽ tự tắt service nếu không có ai truy cập trong 15 phút. Lần truy cập tiếp theo sẽ mất khoảng **30-60 giây để "thức dậy"** trước khi xử lý được — đây là bình thường, không phải lỗi. Nếu nhóm dùng thường xuyên và không muốn chờ, có thể nâng lên gói trả phí thấp nhất (khoảng 7 USD/tháng) để service luôn chạy.
- **Ổ đĩa không lưu trữ lâu dài (ephemeral filesystem):** mỗi lần Render deploy lại (bạn push code mới, hoặc service tự khởi động lại), toàn bộ file trong `work/` sẽ mất sạch. Không ảnh hưởng gì đến việc convert (vì file chỉ cần tồn tại trong lúc xử lý + tải về), nhưng đừng trông cậy vào đó để lưu trữ lâu dài.
- **Dọn dẹp tự động:** `app.py` đã có sẵn 1 luồng nền tự xoá các thư mục xử lý cũ hơn 6 tiếng, để không bị đầy ổ đĩa theo thời gian — không cần làm gì thêm.
- **Cập nhật code sau này:** chỉ cần push code mới lên nhánh `main` trên GitHub (hoặc upload file mới đè lên qua giao diện web GitHub), Render sẽ **tự động build và deploy lại** — không cần vào Render bấm gì thêm.

---

## Nếu muốn giới hạn ai được dùng (khuyến nghị nếu deploy công khai)

Vì URL `onrender.com` là public trên Internet, ai có link cũng dùng được. Nếu chỉ muốn nhóm giáo viên của sachthamkhao.vn dùng, có 2 cách đơn giản:
1. **Không chia sẻ link công khai** — chỉ gửi URL cho những người cần dùng (đơn giản nhất, không cần code thêm).
2. **Thêm mật khẩu đơn giản** — có thể yêu cầu bổ sung sau nếu cần, sẽ cần sửa thêm vài dòng trong `app.py`.
