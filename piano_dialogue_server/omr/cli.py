from __future__ import annotations

import argparse
from pathlib import Path

from .convert import OMRConvertError, convert_to_musicxml


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Convert score PDF/image to MusicXML using oemer.")
    parser.add_argument("--input", required=True, type=Path, help="Input score path (.pdf/.png/.jpg/.jpeg)")
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "out" / "omr",
        help="Root directory for conversion jobs",
    )
    parser.add_argument("--pdf-dpi", type=int, default=300, help="PDF render DPI (default: 300)")
    parser.add_argument(
        "--page",
        type=int,
        default=1,
        help="1-based page index to process. MVP supports only page 1 for multi-page PDFs.",
    )
    parser.add_argument(
        "--normalize-photo",
        action="store_true",
        help="Apply lightweight normalization to photo inputs",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        job = convert_to_musicxml(
            args.input,
            output_root=args.output_root,
            pdf_dpi=args.pdf_dpi,
            normalize_photo=args.normalize_photo,
            page=args.page,
        )
    except OMRConvertError as error:
        print(f"OMR conversion failed: {error}")
        return 1

    print(f"job_dir={job.root}")
    print(f"musicxml_path={job.musicxml_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
