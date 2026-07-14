# Dockerfile
# ==========
# Dung de trien khai web app nay len Render.com (hoac bat ky noi nao
# ho tro Docker). Diem quan trong nhat: cai dat "pandoc" - day la
# phan mem he thong (khong phai thu vien Python), nen KHONG THE dung
# native Python runtime cua Render (native runtime chi chay duoc
# "pip install", khong cai duoc pandoc).

FROM python:3.11-slim

# Cai pandoc (dung cho converter.py) - day la ly do BAT BUOC phai
# dung Docker thay vi native runtime cua Render.
RUN apt-get update && \
    apt-get install -y --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Render se tu dat bien moi truong PORT va gui traffic vao dung cong
# do. Khong duoc hardcode 1 so cu the (vd 5000 hay 8000) trong lenh
# CMD - phai doc tu bien $PORT luc container thuc su chay.
# Dung "shell form" (khong dung [] JSON form) de $PORT duoc thay the
# gia tri that su, vi JSON form khong cho phep bien moi truong.
CMD gunicorn -w 3 -b 0.0.0.0:$PORT app:app --timeout 120
