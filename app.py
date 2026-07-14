"""
app.py
======
Web app don gian: nguoi dung upload file JSON OCR -> server chuyen
sang .docx bang converter.py -> tra ve link tai ve.

Chay thu tren may (development):
    pip install -r requirements.txt
    python app.py
Roi mo trinh duyet: http://localhost:5000

Trien khai that (nhieu nguoi dung qua mang) xem huong dan trong
README.md di kem (dung gunicorn + nginx, hoac Docker).
"""

import os
import shutil
import threading
import time
import traceback
import uuid
from datetime import datetime, timedelta

from flask import Flask, request, render_template, send_file, jsonify, url_for

from converter import convert_json_bytes_to_docx

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORK_ROOT = os.path.join(BASE_DIR, "work")
os.makedirs(WORK_ROOT, exist_ok=True)

MAX_UPLOAD_MB = 50

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024


@app.route("/")
def index():
    return render_template("index.html", max_mb=MAX_UPLOAD_MB)


@app.route("/convert", methods=["POST"])
def convert():
    if "jsonfile" not in request.files:
        return jsonify({"error": "Ban chua chon file JSON nao."}), 400

    f = request.files["jsonfile"]
    if f.filename == "":
        return jsonify({"error": "Ban chua chon file JSON nao."}), 400

    if not f.filename.lower().endswith(".json"):
        return jsonify({"error": "File phai co duoi .json"}), 400

    try:
        json_bytes = f.read()
        docx_path = convert_json_bytes_to_docx(json_bytes, WORK_ROOT)
    except Exception as e:
        # In chi tiet loi ra log server de de debug, nhung chi tra
        # ve thong bao ngan gon cho nguoi dung
        traceback.print_exc()
        return jsonify({"error": f"Loi khi chuyen doi: {e}"}), 500

    request_id = os.path.basename(os.path.dirname(docx_path))
    download_name = os.path.splitext(f.filename)[0] + ".docx"

    return jsonify({
        "ok": True,
        "download_url": url_for("download", request_id=request_id, filename=download_name),
    })


@app.route("/convert_direct", methods=["POST"])
def convert_direct():
    """
    Giong /convert, nhung tra ve THANG file .docx (binary) trong cung
    1 request, thay vi tra JSON chua link tai rieng. Phu hop cho client
    la macro VBA / script - chi can 1 lan goi HTTP la xong, khong can
    goi them lan thu 2 de tai file.
    """
    if "jsonfile" not in request.files:
        return jsonify({"error": "Ban chua chon file JSON nao."}), 400

    f = request.files["jsonfile"]
    if f.filename == "":
        return jsonify({"error": "Ban chua chon file JSON nao."}), 400

    if not f.filename.lower().endswith(".json"):
        return jsonify({"error": "File phai co duoi .json"}), 400

    try:
        json_bytes = f.read()
        docx_path = convert_json_bytes_to_docx(json_bytes, WORK_ROOT)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Loi khi chuyen doi: {e}"}), 500

    download_name = os.path.splitext(f.filename)[0] + ".docx"
    return send_file(docx_path, as_attachment=True, download_name=download_name)


@app.route("/download/<request_id>/<path:filename>")
def download(request_id, filename):
    docx_path = os.path.join(WORK_ROOT, request_id, "output.docx")
    if not os.path.exists(docx_path):
        return "File khong ton tai hoac da bi xoa.", 404
    return send_file(docx_path, as_attachment=True, download_name=filename)


def cleanup_old_work_dirs(max_age_hours=6):
    """
    Xoa cac thu muc xu ly cu hon max_age_hours de khong day o dia.
    """
    now = datetime.now()
    if not os.path.isdir(WORK_ROOT):
        return
    for name in os.listdir(WORK_ROOT):
        path = os.path.join(WORK_ROOT, name)
        if not os.path.isdir(path):
            continue
        mtime = datetime.fromtimestamp(os.path.getmtime(path))
        if now - mtime > timedelta(hours=max_age_hours):
            shutil.rmtree(path, ignore_errors=True)


def _cleanup_loop():
    """
    Chay nen, don dep dinh ky moi 1 tieng - can thiet vi cac dia chi
    hosting nhu Render khong luon co cron job mien phi de tu goi
    cleanup_old_work_dirs() tu ben ngoai. Chay ngay trong tien trinh
    app cho don gian, khong can them dich vu nao khac.
    """
    while True:
        try:
            cleanup_old_work_dirs(max_age_hours=6)
        except Exception:
            traceback.print_exc()
        time.sleep(3600)


_cleanup_thread = threading.Thread(target=_cleanup_loop, daemon=True)
_cleanup_thread.start()


if __name__ == "__main__":
    # PORT: cac nen tang hosting nhu Render se tu dat bien moi truong
    # PORT va yeu cau app lang nghe dung cong do - khong duoc fix cung
    # 1 con so. Chay tren may ca nhan (khong co bien PORT) se mac dinh
    # dung cong 5000 nhu truoc.
    port = int(os.environ.get("PORT", 5000))
    # Chi dung debug=True khi chay thu tren may ca nhan (bien PORT
    # khong duoc dat) - khi trien khai that (co PORT tu Render), luon
    # tat debug vi day la production.
    is_local = "PORT" not in os.environ
    app.run(host="0.0.0.0", port=port, debug=is_local)
