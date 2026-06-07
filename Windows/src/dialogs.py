"""
dialogs.py — All application dialogs:
  MergeDialog, SplitDialog, AddTextDialog, StickyNoteDialog,
  TextEditDialog, GoToPageDialog
"""

from __future__ import annotations
from pathlib import Path
from typing import Optional
import fitz

from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QLineEdit,
    QListWidget, QListWidgetItem, QFileDialog, QComboBox, QSpinBox,
    QRadioButton, QButtonGroup, QGroupBox, QColorDialog, QCheckBox,
    QTextEdit, QDialogButtonBox, QMessageBox, QSlider, QFrame,
    QAbstractItemView,
)
from PyQt6.QtCore import Qt, QMimeData
from PyQt6.QtGui import QFont, QColor, QDragEnterEvent, QDropEvent


# ── MergeDialog ───────────────────────────────────────────────────────────────

class MergeDialog(QDialog):
    """Drag-and-drop PDF merge dialog."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Merge PDFs")
        self.setMinimumSize(480, 400)
        self._paths: list[str] = []

        layout = QVBoxLayout(self)
        layout.setSpacing(10)

        # Header
        header = QLabel("Combine multiple PDF files into one document.")
        header.setFont(QFont("Segoe UI", 9))
        header.setStyleSheet("color: #555;")
        layout.addWidget(header)

        # File list
        self._list = QListWidget()
        self._list.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self._list.setStyleSheet(
            "QListWidget { border: 2px dashed #aaa; border-radius: 6px; "
            "background: #fafafa; }"
        )
        self._list.setAcceptDrops(True)
        self._list.setMinimumHeight(200)
        self._list.model().rowsMoved.connect(self._sync_paths_from_list)
        layout.addWidget(self._list)

        # Drop hint
        self._drop_hint = QLabel("Drop PDF files here, or click Add PDFs")
        self._drop_hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._drop_hint.setStyleSheet("color: #aaa; font-size: 12px;")
        layout.addWidget(self._drop_hint)

        # Buttons row
        btn_row = QHBoxLayout()
        add_btn = QPushButton("Add PDFs…")
        add_btn.clicked.connect(self._add_files)
        remove_btn = QPushButton("Remove Selected")
        remove_btn.clicked.connect(self._remove_selected)
        btn_row.addWidget(add_btn)
        btn_row.addWidget(remove_btn)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(sep)

        # Dialog buttons
        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.button(QDialogButtonBox.StandardButton.Ok).setText("Merge & Save…")
        self._bbox.accepted.connect(self._on_merge)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

        self.setAcceptDrops(True)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent) -> None:
        for url in event.mimeData().urls():
            p = url.toLocalFile()
            if p.lower().endswith(".pdf"):
                self._add_path(p)

    def _add_path(self, path: str) -> None:
        if path not in self._paths:
            self._paths.append(path)
            self._list.addItem(QListWidgetItem(Path(path).name))
            self._drop_hint.hide()

    def _add_files(self) -> None:
        paths, _ = QFileDialog.getOpenFileNames(
            self, "Select PDFs to Merge", "", "PDF Files (*.pdf)"
        )
        for p in paths:
            self._add_path(p)

    def _remove_selected(self) -> None:
        for item in self._list.selectedItems():
            row = self._list.row(item)
            self._list.takeItem(row)
            if row < len(self._paths):
                self._paths.pop(row)

    def _sync_paths_from_list(self) -> None:
        """Reorder _paths to match the reordered list."""
        # Rebuild paths from current list order
        items = [self._list.item(i).text() for i in range(self._list.count())]
        name_to_path = {Path(p).name: p for p in self._paths}
        self._paths = [name_to_path[name] for name in items if name in name_to_path]

    def _on_merge(self) -> None:
        if len(self._paths) < 2:
            QMessageBox.warning(self, "Merge", "Add at least 2 PDF files to merge.")
            return
        save_path, _ = QFileDialog.getSaveFileName(
            self, "Save Merged PDF", "Merged.pdf", "PDF Files (*.pdf)"
        )
        if not save_path:
            return
        try:
            from .pdf_document import PDFProcessor
            merged = PDFProcessor.merge_files(self._paths)
            if merged:
                merged.save(save_path, garbage=3, deflate=True)
                merged.close()
                QMessageBox.information(
                    self, "Merge Complete",
                    f"Merged {len(self._paths)} files into:\n{save_path}"
                )
                self.accept()
            else:
                QMessageBox.critical(self, "Merge Failed", "Could not merge the PDFs.")
        except Exception as e:
            QMessageBox.critical(self, "Merge Error", str(e))


# ── SplitDialog ───────────────────────────────────────────────────────────────

class SplitDialog(QDialog):
    """Split current PDF dialog."""

    def __init__(self, doc: fitz.Document, parent=None):
        super().__init__(parent)
        self.doc = doc
        self.setWindowTitle("Split PDF")
        self.setMinimumSize(400, 320)

        layout = QVBoxLayout(self)
        layout.setSpacing(10)

        info = QLabel(
            f"Document: {doc.page_count} page{'s' if doc.page_count != 1 else ''}"
        )
        info.setFont(QFont("Segoe UI", 9, QFont.Weight.Bold))
        layout.addWidget(info)

        # Mode selection
        self._mode_group = QButtonGroup(self)

        box = QGroupBox("Split Method")
        box_layout = QVBoxLayout(box)

        self._r_every = QRadioButton("Split every N pages")
        self._r_every.setChecked(True)
        self._mode_group.addButton(self._r_every, 0)
        self._n_spin = QSpinBox()
        self._n_spin.setRange(1, max(1, doc.page_count - 1))
        self._n_spin.setValue(1)
        row1 = QHBoxLayout()
        row1.addWidget(self._r_every)
        row1.addWidget(self._n_spin)
        row1.addWidget(QLabel("pages per part"))
        row1.addStretch()
        box_layout.addLayout(row1)

        self._r_at = QRadioButton("Split at page numbers (comma-separated, 1-based)")
        self._mode_group.addButton(self._r_at, 1)
        self._at_input = QLineEdit()
        self._at_input.setPlaceholderText("e.g. 3, 7, 10")
        self._at_input.setEnabled(False)
        box_layout.addWidget(self._r_at)
        box_layout.addWidget(self._at_input)

        self._r_extract = QRadioButton("Extract page range")
        self._mode_group.addButton(self._r_extract, 2)
        range_row = QHBoxLayout()
        range_row.addWidget(self._r_extract)
        self._from_spin = QSpinBox()
        self._from_spin.setRange(1, doc.page_count)
        self._from_spin.setValue(1)
        self._to_spin = QSpinBox()
        self._to_spin.setRange(1, doc.page_count)
        self._to_spin.setValue(doc.page_count)
        self._from_spin.setEnabled(False)
        self._to_spin.setEnabled(False)
        range_row.addWidget(QLabel("From"))
        range_row.addWidget(self._from_spin)
        range_row.addWidget(QLabel("to"))
        range_row.addWidget(self._to_spin)
        range_row.addStretch()
        box_layout.addLayout(range_row)

        layout.addWidget(box)

        # Connect radio buttons
        self._r_every.toggled.connect(lambda on: self._n_spin.setEnabled(on))
        self._r_at.toggled.connect(lambda on: self._at_input.setEnabled(on))
        self._r_extract.toggled.connect(
            lambda on: (self._from_spin.setEnabled(on), self._to_spin.setEnabled(on))
        )

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(sep)

        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.button(QDialogButtonBox.StandardButton.Ok).setText("Split & Save…")
        self._bbox.accepted.connect(self._on_split)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

    def _on_split(self) -> None:
        from .pdf_document import PDFProcessor

        folder = QFileDialog.getExistingDirectory(self, "Save Parts To Folder")
        if not folder:
            return

        base = Path(getattr(self.doc, "name", "document")).stem or "document"
        mode = self._mode_group.checkedId()
        parts = []

        try:
            if mode == 0:
                n = self._n_spin.value()
                parts = PDFProcessor.split_every_n(self.doc, n)
            elif mode == 1:
                raw = self._at_input.text()
                nums = [int(x.strip()) - 1 for x in raw.split(",") if x.strip().isdigit()]
                parts = PDFProcessor.split_at_pages(self.doc, nums)
            else:
                f = self._from_spin.value() - 1
                t = self._to_spin.value() - 1
                p = PDFProcessor.extract_range(self.doc, f, t)
                parts = [p] if p else []

            if not parts:
                QMessageBox.warning(self, "Split", "No parts produced with these settings.")
                return

            saved = PDFProcessor.save_parts(parts, folder, base)
            for p in parts:
                p.close()
            QMessageBox.information(
                self, "Split Complete",
                f"Saved {len(saved)} part{'s' if len(saved) != 1 else ''} to:\n{folder}"
            )
            self.accept()
        except Exception as e:
            QMessageBox.critical(self, "Split Error", str(e))


# ── AddTextDialog (Typewriter) ────────────────────────────────────────────────

class AddTextDialog(QDialog):
    """Dialog for adding typewriter text annotations."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Add Text")
        self.setMinimumWidth(380)

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # Text input
        layout.addWidget(QLabel("Text:"))
        self.text_edit = QTextEdit()
        self.text_edit.setFixedHeight(80)
        self.text_edit.setFont(QFont("Segoe UI", 10))
        layout.addWidget(self.text_edit)

        # Options row
        opts = QHBoxLayout()

        opts.addWidget(QLabel("Font size:"))
        self.size_spin = QSpinBox()
        self.size_spin.setRange(6, 72)
        self.size_spin.setValue(14)
        opts.addWidget(self.size_spin)

        opts.addWidget(QLabel("Alignment:"))
        self.align_combo = QComboBox()
        self.align_combo.addItems(["Left", "Center", "Right"])
        opts.addWidget(self.align_combo)

        opts.addStretch()
        layout.addLayout(opts)

        # Color
        color_row = QHBoxLayout()
        color_row.addWidget(QLabel("Color:"))
        self._color = QColor(0, 0, 0)
        self._color_btn = QPushButton()
        self._color_btn.setFixedSize(28, 28)
        self._update_color_btn()
        self._color_btn.clicked.connect(self._pick_color)
        color_row.addWidget(self._color_btn)
        color_row.addStretch()
        layout.addLayout(color_row)

        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.accepted.connect(self.accept)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

    def _pick_color(self) -> None:
        c = QColorDialog.getColor(self._color, self, "Text Color")
        if c.isValid():
            self._color = c
            self._update_color_btn()

    def _update_color_btn(self) -> None:
        self._color_btn.setStyleSheet(
            f"background: {self._color.name()}; border: 1px solid #999; border-radius: 3px;"
        )

    @property
    def text(self) -> str:
        return self.text_edit.toPlainText().strip()

    @property
    def font_size(self) -> int:
        return self.size_spin.value()

    @property
    def color(self) -> QColor:
        return self._color

    @property
    def alignment(self) -> int:
        return self.align_combo.currentIndex()  # 0=left, 1=center, 2=right


# ── StickyNoteDialog ──────────────────────────────────────────────────────────

class StickyNoteDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Add Sticky Note")
        self.setMinimumWidth(320)

        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Note text:"))
        self.text_edit = QTextEdit()
        self.text_edit.setFixedHeight(100)
        layout.addWidget(self.text_edit)

        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.accepted.connect(self.accept)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

    @property
    def text(self) -> str:
        return self.text_edit.toPlainText()


# ── TextEditDialog ────────────────────────────────────────────────────────────

class TextEditDialog(QDialog):
    def __init__(self, current_text: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Edit Text Block")
        self.setMinimumWidth(400)

        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Edit the text in this block:"))
        self.text_edit = QTextEdit()
        self.text_edit.setPlainText(current_text)
        self.text_edit.setFont(QFont("Segoe UI", 10))
        self.text_edit.setFixedHeight(120)
        layout.addWidget(self.text_edit)

        note = QLabel(
            "Note: The original text will be whited-out and replaced with new text."
        )
        note.setFont(QFont("Segoe UI", 8))
        note.setStyleSheet("color: #888;")
        note.setWordWrap(True)
        layout.addWidget(note)

        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.accepted.connect(self.accept)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

    @property
    def text(self) -> str:
        return self.text_edit.toPlainText().strip()


# ── GoToPageDialog ────────────────────────────────────────────────────────────

class GoToPageDialog(QDialog):
    def __init__(self, current: int, total: int, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Go to Page")
        self.setFixedSize(260, 130)

        layout = QVBoxLayout(self)
        layout.setSpacing(10)

        row = QHBoxLayout()
        row.addWidget(QLabel("Page number:"))
        self._spin = QSpinBox()
        self._spin.setRange(1, total)
        self._spin.setValue(current + 1)
        row.addWidget(self._spin)
        row.addWidget(QLabel(f"of {total}"))
        layout.addLayout(row)

        self._bbox = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._bbox.accepted.connect(self.accept)
        self._bbox.rejected.connect(self.reject)
        layout.addWidget(self._bbox)

    @property
    def page_index(self) -> int:
        return self._spin.value() - 1
