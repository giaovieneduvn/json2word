# OCR JSON → Word (web app)

Web app nội bộ: người dùng upload file JSON kết quả OCR (định dạng
Mistral OCR — có `mistral_response.pages[].markdown` + `images[]` +
`tables[]`), server tự động dựng lại thành file `.docx` đầy đủ ảnh,
bảng, và công thức toán (Word Equation thật, không phải text).

Đây chính là pipeline đã kiểm chứng thủ công trước đó, chỉ đóng gói
thành web app để nhiều người trong nhóm dùng qua trình duyệt.

## Cấu trúc project

```
ocr2word_webapp/
├── app.py            # Flask backend (routes: / , /convert , /download)
├── converter.py       # Logic chuyển đổi (tach anh, ghep markdown, goi Pandoc)
├── templates/
│   └── index.html    # Giao diện upload
├── requirements.txt
└── work/              # Thu muc tam, tu tao khi chay (moi lan convert 1 thu muc rieng)
```

## Yêu cầu hệ thống

- Python 3.9+
- **Pandoc** đã cài trên server (bắt buộc — đây là engine chuyển đổi thật sự).
  Kiểm tra: chạy `pandoc --version` trong terminal của server.
  - Ubuntu/Debian: `sudo apt install pandoc`
  - Nếu server không cho cài qua apt, tải bản `.deb`/binary tại
    https://github.com/jgm/pandoc/releases và giải nén vào PATH.

## Chạy thử trên máy cá nhân (development)

```bash
cd ocr2word_webapp
pip install -r requirements.txt
python app.py
```

Mở trình duyệt: `http://localhost:5000`

## Triển khai thật cho cả nhóm dùng (production)

**Cách đơn giản nhất — chạy trên 1 VPS nhỏ (ví dụ Ubuntu, RAM 1-2GB đủ dùng):**

1. Cài Pandoc + Python trên VPS (xem mục Yêu cầu hệ thống ở trên).
2. Copy thư mục `ocr2word_webapp/` lên VPS.
3. Cài dependencies:
   ```bash
   cd ocr2word_webapp
   pip install -r requirements.txt
   ```
4. Chạy bằng Gunicorn (production WSGI server, thay cho server dev
   của Flask) — ví dụ chạy 3 worker, lắng nghe cổng 8000:
   ```bash
   gunicorn -w 3 -b 0.0.0.0:8000 app:app
   ```
5. Đặt Nginx phía trước để:
   - Có HTTPS (dùng Let's Encrypt / certbot)
   - Giới hạn kích thước file upload cho khớp `MAX_UPLOAD_MB` trong `app.py`
     (thêm `client_max_body_size 50m;` vào block `server` của Nginx)
   - Proxy request vào Gunicorn ở bước 4

   Ví dụ cấu hình Nginx tối thiểu:
   ```nginx
   server {
       listen 80;
       server_name ocr2word.your-domain.vn;
       client_max_body_size 50m;

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```
6. Giữ cho app luôn chạy (tự khởi động lại nếu crash / khi server
   reboot) bằng `systemd`. Tạo file
   `/etc/systemd/system/ocr2word.service`:
   ```ini
   [Unit]
   Description=OCR JSON to Word converter
   After=network.target

   [Service]
   WorkingDirectory=/duong/dan/den/ocr2word_webapp
   ExecStart=/usr/bin/gunicorn -w 3 -b 0.0.0.0:8000 app:app
   Restart=always
   User=www-data

   [Install]
   WantedBy=multi-user.target
   ```
   Sau đó:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now ocr2word
   ```

**Cách khác — dùng Docker** (nếu server đã có Docker sẵn, tránh phải
tự cài Pandoc/Python thủ công): tạo thêm 1 file `Dockerfile`:
```dockerfile
FROM python:3.11-slim
RUN apt-get update && apt-get install -y pandoc && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8000
CMD ["gunicorn", "-w", "3", "-b", "0.0.0.0:8000", "app:app"]
```
Rồi: `docker build -t ocr2word . && docker run -d -p 8000:8000 ocr2word`

## Dọn dẹp file tạm

Mỗi lần convert tạo 1 thư mục riêng trong `work/` (ảnh giải mã + file
markdown trung gian + docx kết quả). Các thư mục này **không tự xoá**.
Gợi ý dọn định kỳ bằng cron, ví dụ xoá thư mục cũ hơn 6 tiếng — gọi
hàm có sẵn `cleanup_old_work_dirs()` trong `app.py`, hoặc đơn giản
thêm 1 dòng cron:
```
0 * * * * find /duong/dan/den/ocr2word_webapp/work -maxdepth 1 -type d -mmin +360 -exec rm -rf {} \;
```

## Mở rộng thêm

- **Định dạng JSON khác Mistral OCR:** sửa hàm `detect_pages()` trong
  `converter.py` — đây là điểm duy nhất cần đổi để nhận diện cấu trúc
  JSON khác (chỉ cần trả về đúng thứ tự list các trang, mỗi trang có
  `markdown` + `images`).
- **Giới hạn ai được dùng:** thêm xác thực đơn giản (Basic Auth qua
  Nginx, hoặc 1 mật khẩu chung) nếu deploy ra ngoài internet công khai
  thay vì chỉ trong mạng nội bộ.
- **Xử lý bảng của JSON khác Mistral OCR** (nếu bảng không nằm sẵn
  dạng markdown `| a | b |` mà nằm trong khoá `tables[]` riêng): cần
  thêm bước tự sinh chuỗi markdown table từ đó trước khi ghép, tương
  tự cách `converter.py` đang xử lý ảnh từ `images[]`.
