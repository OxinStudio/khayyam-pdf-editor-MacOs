"""
models.py — Shared data types for Khayyam PDF Editor (Windows)
"""

from enum import Enum
from dataclasses import dataclass
import fitz  # PyMuPDF


class AnnotationTool(Enum):
    # Navigate
    SELECT = "select"
    HAND = "hand"
    # Comment
    STICKY_NOTE = "stickyNote"
    HIGHLIGHT = "highlight"
    UNDERLINE = "underline"
    STRIKETHROUGH = "strikethrough"
    # Draw
    INK = "ink"
    RECTANGLE = "rectangle"
    OVAL = "oval"
    LINE = "line"
    # Text
    TYPEWRITER = "typewriter"
    EDIT_TEXT = "editText"
    # Insert
    INSERT_IMAGE = "insertImage"

    @property
    def display_name(self) -> str:
        return {
            "select": "Select", "hand": "Hand",
            "stickyNote": "Note",
            "highlight": "Highlight", "underline": "Underline", "strikethrough": "Strike",
            "ink": "Draw", "rectangle": "Rect", "oval": "Oval", "line": "Line",
            "typewriter": "Type", "editText": "Edit Text", "insertImage": "Image",
        }.get(self.value, self.value)

    @property
    def tooltip(self) -> str:
        return {
            "select": "Select & move annotations",
            "hand": "Pan / scroll the document",
            "stickyNote": "Add a sticky note — click to place",
            "highlight": "Highlight text — drag to select, then apply",
            "underline": "Underline text — drag to select, then apply",
            "strikethrough": "Strikethrough text — drag to select, then apply",
            "ink": "Freehand drawing — click and drag",
            "rectangle": "Rectangle — drag to draw",
            "oval": "Oval / circle — drag to draw",
            "line": "Line — drag to draw",
            "typewriter": "Typewriter — click to add text on the page",
            "editText": "Edit existing PDF text",
            "insertImage": "Insert an image from file",
        }.get(self.value, self.display_name)

    @property
    def unicode_icon(self) -> str:
        return {
            "select": "↖", "hand": "✋",
            "stickyNote": "📌",
            "highlight": "▌", "underline": "U̲", "strikethrough": "S̶",
            "ink": "✏", "rectangle": "▭", "oval": "⬭", "line": "╱",
            "typewriter": "T", "editText": "✎",
            "insertImage": "🖼",
        }.get(self.value, "·")

    @property
    def is_markup(self) -> bool:
        return self in (
            AnnotationTool.HIGHLIGHT,
            AnnotationTool.UNDERLINE,
            AnnotationTool.STRIKETHROUGH,
        )

    @property
    def is_shape(self) -> bool:
        return self in (
            AnnotationTool.RECTANGLE,
            AnnotationTool.OVAL,
            AnnotationTool.LINE,
        )

    @property
    def is_drawing(self) -> bool:
        return self in (
            AnnotationTool.INK,
            AnnotationTool.RECTANGLE,
            AnnotationTool.OVAL,
            AnnotationTool.LINE,
        )


@dataclass
class TextBlock:
    """Represents a detectable text block for in-place editing."""
    page_index: int
    rect: fitz.Rect
    text: str
    block_no: int = 0
