"""
converter.py
============
Loi giai bai toan: nhan file JSON OCR (dinh dang Mistral OCR, hoac
tuong tu - xem ham detect_pages() de mo rong sang dinh dang khac)
-> tra ve duong dan file .docx da hoan chinh (co day du anh, bang,
cong thuc Word Equation that).

Dung lai dung logic da kiem chung o buoc build thu cong truoc do:
  1. Doc JSON, lay danh sach trang theo dung thu tu index.
  2. Voi moi trang: luu anh base64 ra file that trong thu muc media/,
     giu nguyen ten file (img-N.jpeg) de khop voi tham chieu
     ![img-N.jpeg](img-N.jpeg) trong noi dung markdown.
  3. Noi markdown cua tat ca cac trang lai thanh 1 file .md duy nhat.
  4. Goi Pandoc (markdown + tex_math_dollars -> docx) de:
       - Tu dong build cong thuc $...$ / $$...$$ thanh Word Equation that
       - Tu dong chuyen bang markdown | a | b | thanh Table that
       - Chen anh dung vi tri
"""

import json
import base64
import os
import re
import shutil
import subprocess
import uuid


def detect_pages(data: dict):
    """
    Tra ve danh sach cac "page dict" theo dung thu tu, bat ke JSON
    dau vao la dinh dang Mistral OCR truc tiep hay da duoc boc them
    1 lop ben ngoai (vi du {"ok":true,"mistral_response":{"pages":[...]}}).

    Moi page dict duoc ky vong co it nhat 2 khoa:
      - "markdown": noi dung van ban markdown cua trang (str)
      - "images": list cac anh, moi anh la dict co "id" va "image_base64"
      - "index": so thu tu trang (int) - dung de sap xep

    Neu JSON cua ban co cau truc khac, chi can sua ham nay.
    """
    # Truong hop 1: dung format da thay: data["mistral_response"]["pages"]
    if isinstance(data, dict) and "mistral_response" in data:
        pages = data["mistral_response"].get("pages", [])
        return sorted(pages, key=lambda p: p.get("index", 0))

    # Truong hop 2: JSON la {"pages": [...]} truc tiep (khong co lop boc)
    if isinstance(data, dict) and "pages" in data:
        pages = data["pages"]
        return sorted(pages, key=lambda p: p.get("index", 0))

    # Truong hop 3: JSON chinh no da la 1 list cac page
    if isinstance(data, list):
        return sorted(data, key=lambda p: p.get("index", 0))

    raise ValueError(
        "Khong nhan dien duoc cau truc JSON. Can co 'DoMate_response.pages', "
        "'pages', hoac la 1 list cac trang. Hay sua ham detect_pages() trong "
        "converter.py cho khop voi dinh dang JSON cua ban."
    )


def convert_json_to_docx(json_path: str, work_dir: str) -> str:
    """
    Doi so:
      json_path: duong dan file JSON dau vao
      work_dir:  thu muc rieng cho lan xu ly nay (nen la 1 thu muc
                 tam thoi, moi request 1 thu muc rieng de tranh dam
                 vao nhau khi nhieu nguoi dung cung luc)

    Tra ve: duong dan file .docx da tao xong (nam trong work_dir)
    """
    media_dir = os.path.join(work_dir, "media")
    os.makedirs(media_dir, exist_ok=True)

    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    pages = detect_pages(data)
    if not pages:
        raise ValueError("File JSON khong co trang nao ca.")

    md_parts = []
    image_count = 0

    for p in pages:
        md = p.get("markdown", "")

        for img in p.get("images", []) or []:
            img_id = img.get("id")
            b64 = img.get("image_base64", "")
            if not img_id or not b64:
                continue
            if "," in b64:
                b64 = b64.split(",", 1)[1]
            try:
                raw = base64.b64decode(b64)
            except Exception:
                continue
            out_path = os.path.join(media_dir, img_id)
            with open(out_path, "wb") as imf:
                imf.write(raw)
            image_count += 1

        md_parts.append(md.strip())

    combined = "\n\n---\n\n".join(md_parts)

    # Dam bao duong dan anh trong markdown tro dung vao media/
    combined = re.sub(r'\((img-[\w\-]+\.\w+)\)', r'(media/\1)', combined)

    combined_md_path = os.path.join(work_dir, "combined.md")
    with open(combined_md_path, "w", encoding="utf-8") as f:
        f.write(combined)

    docx_path = os.path.join(work_dir, "output.docx")

    result = subprocess.run(
        [
            "pandoc",
            combined_md_path,
            "-o", docx_path,
            "--resource-path=" + work_dir,
            "-f", "markdown+tex_math_dollars",
            "-t", "docx",
            "--wrap=preserve",
        ],
        capture_output=True,
        text=True,
        timeout=180,
    )

    if result.returncode != 0:
        raise RuntimeError(f"Pandoc loi:\n{result.stderr}")

    if not os.path.exists(docx_path):
        raise RuntimeError("Pandoc chay xong nhung khong thay file output.docx")

    return docx_path


def convert_json_bytes_to_docx(json_bytes: bytes, base_work_dir: str) -> str:
    """
    Tien ich cho web app: nhan noi dung JSON dang bytes (tu file upload),
    tu tao 1 thu muc rieng biet (UUID) duoi base_work_dir de xu ly, tra
    ve duong dan file docx ket qua.
    """
    request_id = str(uuid.uuid4())
    work_dir = os.path.join(base_work_dir, request_id)
    os.makedirs(work_dir, exist_ok=True)

    json_path = os.path.join(work_dir, "input.json")
    with open(json_path, "wb") as f:
        f.write(json_bytes)

    return convert_json_to_docx(json_path, work_dir)
