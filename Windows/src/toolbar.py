"""
toolbar.py — Annotation toolbar matching the Mac version's grouped layout.
Groups: Navigate | Comment | Draw | Text | Insert
"""

from __future__ import annotations
from PyQt6.QtWidgets import (
    QWidget, QHBoxLayout, QVBoxLayout, QLabel, QPushButton, QFrame,
    QColorDialog, QMenu, QSizePolicy,
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QColor, QPainter, QPixmap, QIcon, QFont
from .models import AnnotationTool


# ── helpers ───────────────────────────────────────────────────────────────────

def _color_icon(color: QColor, size: int = 14) -> QIcon:
    """Create a small filled square icon for color swatches."""
    pix = QPixmap(size, size)
    pix.fill(color)
    return QIcon(pix)


def _group_separator() -> QFrame:
    sep = QFrame()
    sep.setFrameShape(QFrame.Shape.VLine)
    sep.setFrameShadow(QFrame.Shadow.Sunken)
    sep.setFixedWidth(2)
    sep.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Expanding)
    return sep


def _group_label(text: str) -> QLabel:
    lbl = QLabel(text.upper())
    font = QFont()
    font.setPointSize(7)
    font.setBold(True)
    lbl.setFont(font)
    lbl.setStyleSheet("color: #888; padding: 0 4px;")
    lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
    return lbl


# ── ToolButton ────────────────────────────────────────────────────────────────

class ToolButton(QPushButton):
    """A single tool toggle button with icon text + label below."""

    def __init__(self, tool: AnnotationTool, parent=None):
        super().__init__(parent)
        self.tool = tool
        self._selected = False

        layout = QVBoxLayout(self)
        layout.setContentsMargins(2, 3, 2, 3)
        layout.setSpacing(1)

        self._icon_lbl = QLabel(tool.unicode_icon)
        self._icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        font_icon = QFont("Segoe UI", 13)
        self._icon_lbl.setFont(font_icon)

        self._name_lbl = QLabel(tool.display_name)
        self._name_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        font_name = QFont("Segoe UI", 7)
        self._name_lbl.setFont(font_name)

        layout.addWidget(self._icon_lbl)
        layout.addWidget(self._name_lbl)

        self.setFixedWidth(52)
        self.setCheckable(True)
        self.setToolTip(tool.tooltip)
        self.setFlat(True)
        self._refresh_style()

    def setChecked(self, checked: bool) -> None:
        self._selected = checked
        super().setChecked(checked)
        self._refresh_style()

    def _refresh_style(self) -> None:
        if self._selected:
            self.setStyleSheet(
                "QPushButton { background: #0078D4; border-radius: 5px; }"
                "QLabel { color: white; }"
            )
        else:
            self.setStyleSheet(
                "QPushButton { background: transparent; border-radius: 5px; }"
                "QPushButton:hover { background: #e0e0e0; }"
                "QLabel { color: #333; }"
            )


# ── MarkupButton (highlight/underline/strikethrough with color chevron) ───────

class MarkupButton(QWidget):
    """
    Compound widget: [tool apply button] + [▾ color chevron].
    Clicking the main button applies the markup.
    Clicking ▾ opens a color picker.
    """

    apply_clicked = pyqtSignal(AnnotationTool)
    color_changed = pyqtSignal(AnnotationTool, QColor)

    def __init__(self, tool: AnnotationTool, default_color: QColor, parent=None):
        super().__init__(parent)
        self.tool = tool
        self._color = default_color

        outer = QHBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # Main button
        self._btn = QPushButton()
        layout = QVBoxLayout(self._btn)
        layout.setContentsMargins(2, 3, 2, 1)
        layout.setSpacing(1)

        icon_lbl = QLabel(tool.unicode_icon)
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_lbl.setFont(QFont("Segoe UI", 13))
        name_lbl = QLabel(tool.display_name)
        name_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        name_lbl.setFont(QFont("Segoe UI", 7))

        # Color swatch strip
        self._swatch = QLabel()
        self._swatch.setFixedHeight(3)
        self._swatch.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._update_swatch()

        layout.addWidget(icon_lbl)
        layout.addWidget(name_lbl)
        layout.addWidget(self._swatch)

        self._btn.setFixedWidth(46)
        self._btn.setFlat(True)
        self._btn.setToolTip(tool.tooltip)
        self._btn.clicked.connect(lambda: self.apply_clicked.emit(self.tool))
        self._btn.setStyleSheet(
            "QPushButton { background: transparent; border-radius: 5px; }"
            "QPushButton:hover { background: #e0e0e0; }"
        )

        # Chevron button
        self._chev = QPushButton("▾")
        self._chev.setFixedSize(14, 44)
        self._chev.setFlat(True)
        self._chev.setFont(QFont("Segoe UI", 7))
        self._chev.setToolTip(f"Change {tool.display_name} color")
        self._chev.setStyleSheet(
            "QPushButton { background: transparent; color: #888; }"
            "QPushButton:hover { background: #ddd; }"
        )
        self._chev.clicked.connect(self._pick_color)

        outer.addWidget(self._btn)
        outer.addWidget(self._chev)

        # Border
        self.setStyleSheet(
            "MarkupButton { border: 1px solid #ccc; border-radius: 5px; }"
        )

    @property
    def color(self) -> QColor:
        return self._color

    def _update_swatch(self) -> None:
        self._swatch.setStyleSheet(
            f"background: {self._color.name()}; border-radius: 1px;"
        )

    def _pick_color(self) -> None:
        dlg = QColorDialog(self._color, self)
        dlg.setWindowTitle(f"{self.tool.display_name} Color")
        if dlg.exec():
            self._color = dlg.selectedColor()
            self._update_swatch()
            self.color_changed.emit(self.tool, self._color)


# ── AnnotationToolbar ─────────────────────────────────────────────────────────

class AnnotationToolbar(QWidget):
    """
    Full annotation toolbar with grouped tool buttons.
    Emits:
      tool_selected(AnnotationTool)
      markup_apply(AnnotationTool)        — for markup tools (highlight etc.)
      markup_color_changed(AnnotationTool, QColor)
      stroke_color_changed(QColor)
    """

    tool_selected = pyqtSignal(AnnotationTool)
    markup_apply = pyqtSignal(AnnotationTool)
    markup_color_changed = pyqtSignal(AnnotationTool, QColor)
    stroke_color_changed = pyqtSignal(QColor)
    delete_annotation = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._current_tool = AnnotationTool.SELECT
        self._tool_buttons: dict[AnnotationTool, ToolButton] = {}
        self._markup_buttons: dict[AnnotationTool, MarkupButton] = {}
        self._build()

    def _build(self) -> None:
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(8, 4, 8, 4)
        main_layout.setSpacing(2)

        def add_group(label: str, tools: list):
            main_layout.addWidget(_group_label(label))
            for t in tools:
                if isinstance(t, AnnotationTool) and t.is_markup:
                    default = {
                        AnnotationTool.HIGHLIGHT: QColor(255, 255, 0),
                        AnnotationTool.UNDERLINE: QColor(0, 0, 255),
                        AnnotationTool.STRIKETHROUGH: QColor(255, 0, 0),
                    }.get(t, QColor(0, 0, 0))
                    mb = MarkupButton(t, default)
                    mb.apply_clicked.connect(self.markup_apply.emit)
                    mb.color_changed.connect(self.markup_color_changed.emit)
                    self._markup_buttons[t] = mb
                    main_layout.addWidget(mb)
                elif isinstance(t, AnnotationTool):
                    btn = ToolButton(t)
                    btn.clicked.connect(lambda checked, tool=t: self._on_tool_click(tool))
                    self._tool_buttons[t] = btn
                    main_layout.addWidget(btn)
                elif t == "|":
                    main_layout.addWidget(_group_separator())

        add_group("Navigate", [AnnotationTool.SELECT, AnnotationTool.HAND])
        main_layout.addWidget(_group_separator())
        add_group("Comment", [
            AnnotationTool.STICKY_NOTE,
            AnnotationTool.HIGHLIGHT,
            AnnotationTool.UNDERLINE,
            AnnotationTool.STRIKETHROUGH,
        ])
        main_layout.addWidget(_group_separator())
        add_group("Draw", [
            AnnotationTool.INK,
            AnnotationTool.RECTANGLE,
            AnnotationTool.OVAL,
            AnnotationTool.LINE,
        ])
        main_layout.addWidget(_group_separator())
        add_group("Text", [AnnotationTool.TYPEWRITER, AnnotationTool.EDIT_TEXT])
        main_layout.addWidget(_group_separator())
        add_group("Insert", [AnnotationTool.INSERT_IMAGE])

        main_layout.addStretch()

        # Stroke color button (for draw tools)
        self._stroke_label = QLabel("Stroke:")
        self._stroke_label.setFont(QFont("Segoe UI", 8))
        self._stroke_label.setStyleSheet("color: #666;")
        self._stroke_btn = QPushButton()
        self._stroke_btn.setFixedSize(26, 26)
        self._stroke_btn.setToolTip("Stroke / draw color")
        self._stroke_color = QColor(0, 0, 0)
        self._stroke_btn.setIcon(_color_icon(self._stroke_color, 20))
        self._stroke_btn.clicked.connect(self._pick_stroke_color)
        self._stroke_label.hide()
        self._stroke_btn.hide()
        main_layout.addWidget(self._stroke_label)
        main_layout.addWidget(self._stroke_btn)

        # Delete button (shown when annotation is selected)
        self._delete_btn = QPushButton("🗑 Delete")
        self._delete_btn.setFixedHeight(28)
        self._delete_btn.setFont(QFont("Segoe UI", 8))
        self._delete_btn.setStyleSheet(
            "QPushButton { color: #c00; border: 1px solid #c00; "
            "border-radius: 4px; padding: 2px 8px; }"
            "QPushButton:hover { background: #ffeeee; }"
        )
        self._delete_btn.hide()
        self._delete_btn.clicked.connect(self.delete_annotation.emit)
        main_layout.addWidget(self._delete_btn)

        # Start with SELECT active
        self._set_active(AnnotationTool.SELECT)

        self.setStyleSheet("AnnotationToolbar { background: #f5f5f5; "
                           "border-bottom: 1px solid #ccc; }")
        self.setFixedHeight(60)

    def _on_tool_click(self, tool: AnnotationTool) -> None:
        # Toggle off if already selected
        if self._current_tool == tool:
            tool = AnnotationTool.SELECT
        self._set_active(tool)
        self.tool_selected.emit(tool)

    def _set_active(self, tool: AnnotationTool) -> None:
        self._current_tool = tool
        for t, btn in self._tool_buttons.items():
            btn.setChecked(t == tool)
        # Show/hide stroke color for drawing tools
        is_draw = tool in (AnnotationTool.INK, AnnotationTool.RECTANGLE,
                           AnnotationTool.OVAL, AnnotationTool.LINE)
        self._stroke_label.setVisible(is_draw)
        self._stroke_btn.setVisible(is_draw)

    def set_tool_externally(self, tool: AnnotationTool) -> None:
        """Called when tool is changed from outside (e.g. keyboard shortcut)."""
        self._set_active(tool)

    def show_annotation_selected(self, selected: bool) -> None:
        self._delete_btn.setVisible(selected)

    def _pick_stroke_color(self) -> None:
        dlg = QColorDialog(self._stroke_color, self)
        dlg.setWindowTitle("Stroke Color")
        if dlg.exec():
            self._stroke_color = dlg.selectedColor()
            self._stroke_btn.setIcon(_color_icon(self._stroke_color, 20))
            self.stroke_color_changed.emit(self._stroke_color)

    def get_markup_color(self, tool: AnnotationTool) -> QColor:
        if tool in self._markup_buttons:
            return self._markup_buttons[tool].color
        return QColor(255, 255, 0)
