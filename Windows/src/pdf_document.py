"""
pdf_document.py — High-level PDF file operations (merge, split, extract).
Mirrors PDFProcessor.swift from the Mac version.
"""

from pathlib import Path
from typing import Optional
import fitz  # PyMuPDF


class PDFProcessor:
    """Static utilities for PDF manipulation: merge, split, extract."""

    # ── Merge ─────────────────────────────────────────────────────────────────

    @staticmethod
    def merge(docs: list[fitz.Document]) -> Optional[fitz.Document]:
        """Merge a list of open fitz.Document objects into one."""
        if not docs:
            return None
        merged = fitz.open()
        for doc in docs:
            merged.insert_pdf(doc)
        return merged if merged.page_count > 0 else None

    @staticmethod
    def merge_files(paths: list[str]) -> Optional[fitz.Document]:
        """Merge PDFs from file paths."""
        docs = []
        for p in paths:
            try:
                docs.append(fitz.open(p))
            except Exception:
                pass
        result = PDFProcessor.merge(docs)
        for d in docs:
            d.close()
        return result

    # ── Split ─────────────────────────────────────────────────────────────────

    @staticmethod
    def split_every_n(doc: fitz.Document, n: int) -> list[fitz.Document]:
        """Split into chunks of n pages each."""
        if n <= 0:
            return []
        results = []
        total = doc.page_count
        start = 0
        while start < total:
            end = min(start + n, total)
            chunk = PDFProcessor.extract_range(doc, start, end - 1)
            if chunk:
                results.append(chunk)
            start = end
        return results

    @staticmethod
    def split_at_pages(doc: fitz.Document, split_points: list[int]) -> list[fitz.Document]:
        """Split at specific page indices (each index starts a new document)."""
        boundaries = sorted(set([0] + split_points + [doc.page_count]))
        results = []
        for i in range(len(boundaries) - 1):
            start = boundaries[i]
            end = boundaries[i + 1]
            if start < end:
                chunk = PDFProcessor.extract_range(doc, start, end - 1)
                if chunk:
                    results.append(chunk)
        return results

    @staticmethod
    def extract_range(doc: fitz.Document, from_page: int, to_page: int) -> Optional[fitz.Document]:
        """Extract pages from_page..to_page (0-indexed, inclusive) into a new doc."""
        new_doc = fitz.open()
        new_doc.insert_pdf(doc, from_page=from_page, to_page=to_page)
        return new_doc if new_doc.page_count > 0 else None

    # ── Save helpers ──────────────────────────────────────────────────────────

    @staticmethod
    def save(doc: fitz.Document, path: str) -> bool:
        """Save doc to path, with incremental save if same file."""
        try:
            source = getattr(doc, "name", "")
            if source and Path(source).resolve() == Path(path).resolve():
                doc.saveIncr()
            else:
                doc.save(path, garbage=3, deflate=True)
            return True
        except Exception:
            try:
                doc.save(path, garbage=3, deflate=True)
                return True
            except Exception:
                return False

    @staticmethod
    def save_parts(parts: list[fitz.Document], folder: str, base_name: str) -> list[str]:
        """Save a list of split parts to folder with numbered names."""
        saved = []
        folder_path = Path(folder)
        folder_path.mkdir(parents=True, exist_ok=True)
        pad = len(str(len(parts)))
        for i, part in enumerate(parts, 1):
            name = f"{base_name}_part{str(i).zfill(pad)}.pdf"
            dest = str(folder_path / name)
            if PDFProcessor.save(part, dest):
                saved.append(dest)
        return saved
