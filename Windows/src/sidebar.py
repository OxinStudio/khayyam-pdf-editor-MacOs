"""
sidebar.py — Thumbnails + Outline sidebar, matching Mac SidebarView.
"""

from __future__ import annotations
from typing import Optional
import fitz
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QListWidget, QListWidgetItem,
    QTreeWidget, QTreeWidgetItem, QLabel, QPushButton, QLineEdit,
    QStackedWidget, QFrame, QScrollArea,
)
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QRunnable, QThreadPool, QObject
from PyQt6.QtGui import QPixmap, QImage, QIcon, QFont, QColor


# ── thumbnail worker ──────────────────────────────────────────────────────────

class _ThumbnailSignals(QObject):
    done = pyqtSignal(int, QPixmap)


class _ThumbnailTask(QRunnable):
    def __init__(self, doc: fitz.Document, page_idx: int, zoom: float = 0.2):
        super().__init__()
        self.doc = doc
        self.page_idx = page_idx
        self.zoom = zoom
        self.signals = _ThumbnailSignals()

    def run(self) -> None:
        try:
            page = self.doc[self.page_idx]
            mat = fitz.Matrix(self.zoom, self.zoom)
            pix = page.get_pixmap(matrix=mat, alpha=False)
            img = QImage(bytes(pix.samples), pix.width, pix.height,
                         pix.stride, QImage.Format.Format_RGB888)
            self.signals.done.emit(self.page_idx, QPixmap.fromImage(img))
        except Exception:
            pass


# ── ThumbnailSidebar ──────────────────────────────────────────────────────────

class ThumbnailSidebar(QWidget):
    page_clicked = pyqtSignal(int)

    THUMB_W = 120
    THUMB_H = 160

    def __init__(self, parent=None):
        super().__init__(parent)
        self._doc: Optional[fitz.Document] = None
        self._current_page = 0
        self._pool = QThreadPool.globalInstance()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self._list = QListWidget()
        self._list.setViewMode(QListWidget.ViewMode.IconMode)
        self._list.setIconSize(QSize(self.THUMB_W, self.THUMB_H))
        self._list.setResizeMode(QListWidget.ResizeMode.Adjust)
        self._list.setSpacing(6)
        self._list.setMovement(QListWidget.Movement.Static)
        self._list.setUniformItemSizes(True)
        self._list.setStyleSheet(
            "QListWidget { background: #3a3a3a; border: none; }"
            "QListWidget::item { color: #ddd; border: none; }"
            "QListWidget::item:selected { background: #0078D4; border-radius: 4px; }"
        )
        self._list.itemClicked.connect(
            lambda item: self.page_clicked.emit(self._list.row(item))
        )
        layout.addWidget(self._list)

    def load_document(self, doc: fitz.Document) -> None:
        self._doc = doc
        self._list.clear()
        placeholder = QPixmap(self.THUMB_W, self.THUMB_H)
        placeholder.fill(QColor(200, 200, 200))
        for i in range(doc.page_count):
            item = QListWidgetItem(QIcon(placeholder), f"  {i + 1}")
            item.setSizeHint(QSize(self.THUMB_W + 16, self.THUMB_H + 24))
            item.setTextAlignment(Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignBottom)
            self._list.addItem(item)
        # Generate thumbnails in background
        for i in range(doc.page_count):
            task = _ThumbnailTask(doc, i, zoom=self.THUMB_W / max(doc[i].rect.width, 1))
            task.signals.done.connect(self._set_thumbnail)
            self._pool.start(task)

    def _set_thumbnail(self, idx: int, pix: QPixmap) -> None:
        if idx < self._list.count():
            self._list.item(idx).setIcon(QIcon(pix))

    def set_current_page(self, idx: int) -> None:
        self._current_page = idx
        if idx < self._list.count():
            self._list.setCurrentRow(idx)
            self._list.scrollToItem(self._list.item(idx))

    def clear(self) -> None:
        self._list.clear()
        self._doc = None


# ── OutlineSidebar ────────────────────────────────────────────────────────────

class OutlineSidebar(QWidget):
    page_clicked = pyqtSignal(int)

    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self._tree = QTreeWidget()
        self._tree.setHeaderHidden(True)
        self._tree.setStyleSheet(
            "QTreeWidget { background: #f8f8f8; border: none; font-size: 12px; }"
            "QTreeWidget::item:hover { background: #e0ecf8; }"
            "QTreeWidget::item:selected { background: #0078D4; color: white; }"
        )
        self._tree.itemClicked.connect(self._on_item_clicked)
        layout.addWidget(self._tree)

        self._empty_label = QLabel("This PDF has no outline.")
        self._empty_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._empty_label.setStyleSheet("color: #888; font-size: 12px;")
        self._empty_label.hide()
        layout.addWidget(self._empty_label)

    def load_document(self, doc: fitz.Document) -> None:
        self._tree.clear()
        toc = doc.get_toc(simple=False)
        if not toc:
            self._tree.hide()
            self._empty_label.show()
            return
        self._tree.show()
        self._empty_label.hide()

        stack = [(-1, self._tree.invisibleRootItem())]
        for level, title, page, *_ in toc:
            parent_item = stack[-1][1]
            while len(stack) > 1 and stack[-1][0] >= level:
                stack.pop()
            parent_item = stack[-1][1]
            item = QTreeWidgetItem(parent_item, [title or "—"])
            item.setData(0, Qt.ItemDataRole.UserRole, page - 1)
            stack.append((level, item))
        self._tree.expandAll()

    def _on_item_clicked(self, item: QTreeWidgetItem, _col: int) -> None:
        page_idx = item.data(0, Qt.ItemDataRole.UserRole)
        if page_idx is not None and page_idx >= 0:
            self.page_clicked.emit(page_idx)

    def clear(self) -> None:
        self._tree.clear()


# ── SearchPanel ───────────────────────────────────────────────────────────────

class SearchPanel(QWidget):
    """Search bar with prev/next controls."""
    search_requested = pyqtSignal(str)
    prev_result = pyqtSignal()
    next_result = pyqtSignal()
    cleared = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 4, 6, 4)
        layout.setSpacing(4)

        self._input = QLineEdit()
        self._input.setPlaceholderText("Search in PDF…")
        self._input.setFont(QFont("Segoe UI", 9))
        self._input.returnPressed.connect(self._on_search)
        self._input.textChanged.connect(self._on_text_changed)

        self._count_lbl = QLabel("")
        self._count_lbl.setFont(QFont("Segoe UI", 8))
        self._count_lbl.setStyleSheet("color: #888;")

        self._prev_btn = QPushButton("▲")
        self._prev_btn.setFixedSize(22, 22)
        self._prev_btn.setFont(QFont("Segoe UI", 9))
        self._prev_btn.setEnabled(False)
        self._prev_btn.clicked.connect(self.prev_result.emit)

        self._next_btn = QPushButton("▼")
        self._next_btn.setFixedSize(22, 22)
        self._next_btn.setFont(QFont("Segoe UI", 9))
        self._next_btn.setEnabled(False)
        self._next_btn.clicked.connect(self.next_result.emit)

        layout.addWidget(self._input, stretch=1)
        layout.addWidget(self._count_lbl)
        layout.addWidget(self._prev_btn)
        layout.addWidget(self._next_btn)

    def _on_search(self) -> None:
        q = self._input.text().strip()
        if q:
            self.search_requested.emit(q)

    def _on_text_changed(self, text: str) -> None:
        if not text:
            self._count_lbl.setText("")
            self._prev_btn.setEnabled(False)
            self._next_btn.setEnabled(False)
            self.cleared.emit()

    def set_result_count(self, n: int) -> None:
        if n == 0:
            self._count_lbl.setText("No results")
            self._prev_btn.setEnabled(False)
            self._next_btn.setEnabled(False)
        else:
            self._count_lbl.setText(f"{n} result{'s' if n != 1 else ''}")
            self._prev_btn.setEnabled(True)
            self._next_btn.setEnabled(True)


# ── SidebarWidget (combines all panels) ──────────────────────────────────────

class SidebarWidget(QWidget):
    page_clicked = pyqtSignal(int)
    search_requested = pyqtSignal(str)
    search_prev = pyqtSignal()
    search_next = pyqtSignal()
    search_cleared = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumWidth(120)
        self.setMaximumWidth(240)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Mode switcher
        switcher = QWidget()
        sw_layout = QHBoxLayout(switcher)
        sw_layout.setContentsMargins(4, 4, 4, 4)
        sw_layout.setSpacing(2)

        self._pages_btn = QPushButton("Pages")
        self._outline_btn = QPushButton("Outline")
        for btn in (self._pages_btn, self._outline_btn):
            btn.setCheckable(True)
            btn.setFixedHeight(24)
            btn.setFont(QFont("Segoe UI", 8))
        self._pages_btn.setChecked(True)
        self._pages_btn.clicked.connect(lambda: self._switch_mode(0))
        self._outline_btn.clicked.connect(lambda: self._switch_mode(1))

        sw_layout.addWidget(self._pages_btn)
        sw_layout.addWidget(self._outline_btn)
        layout.addWidget(switcher)

        # Search bar (only in pages mode)
        self._search = SearchPanel()
        self._search.search_requested.connect(self.search_requested.emit)
        self._search.prev_result.connect(self.search_prev.emit)
        self._search.next_result.connect(self.search_next.emit)
        self._search.cleared.connect(self.search_cleared.emit)
        layout.addWidget(self._search)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setFrameShadow(QFrame.Shadow.Sunken)
        layout.addWidget(sep)

        # Stacked panels
        self._stack = QStackedWidget()
        self._thumbs = ThumbnailSidebar()
        self._thumbs.page_clicked.connect(self.page_clicked.emit)
        self._outline = OutlineSidebar()
        self._outline.page_clicked.connect(self.page_clicked.emit)
        self._stack.addWidget(self._thumbs)
        self._stack.addWidget(self._outline)
        layout.addWidget(self._stack, stretch=1)

        self.setStyleSheet("SidebarWidget { background: #f0f0f0; "
                           "border-right: 1px solid #ccc; }")

    def _switch_mode(self, idx: int) -> None:
        self._stack.setCurrentIndex(idx)
        self._pages_btn.setChecked(idx == 0)
        self._outline_btn.setChecked(idx == 1)
        self._search.setVisible(idx == 0)

    def load_document(self, doc: fitz.Document) -> None:
        self._thumbs.load_document(doc)
        self._outline.load_document(doc)

    def set_current_page(self, idx: int) -> None:
        self._thumbs.set_current_page(idx)

    def set_search_result_count(self, n: int) -> None:
        self._search.set_result_count(n)

    def clear(self) -> None:
        self._thumbs.clear()
        self._outline.clear()
