from __future__ import annotations

import shutil
import sys
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from omr.convert import OMRConvertError, convert_to_musicxml


router = APIRouter(prefix="/omr", tags=["omr"])


@router.post("/convert")
async def convert_score(
    file: UploadFile = File(...),
    inline_xml: bool = Form(False),
    page: int = Form(1),
    pdf_dpi: int = Form(300),
    normalize_photo: bool = Form(False),
) -> dict[str, str]:
    filename = file.filename or "score.pdf"
    suffix = Path(filename).suffix.lower()
    if suffix not in {".pdf", ".png", ".jpg", ".jpeg"}:
        raise HTTPException(status_code=400, detail=f"unsupported file extension: {suffix}")

    upload_dir = ROOT_DIR / "out" / "omr" / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    upload_path = upload_dir / filename

    try:
        with upload_path.open("wb") as destination:
            shutil.copyfileobj(file.file, destination)
    finally:
        await file.close()

    try:
        job = convert_to_musicxml(
            upload_path,
            pdf_dpi=pdf_dpi,
            normalize_photo=normalize_photo,
            page=page,
        )
    except OMRConvertError as error:
        raise HTTPException(status_code=500, detail=str(error)) from error

    result: dict[str, str] = {
        "status": "ok",
        "musicxml_path": str(job.musicxml_path),
        "job_dir": str(job.root),
    }
    if inline_xml:
        result["musicxml"] = job.musicxml_path.read_text(encoding="utf-8")
    return result
