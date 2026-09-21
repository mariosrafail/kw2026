from __future__ import annotations

import base64
import copy
import io
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import tkinter as tk
from tkinter import colorchooser, filedialog, messagebox
from PIL import Image, ImageDraw, ImageTk


APP_NAME = "KW Character Builder"
SIZE = 64
DISPLAY_SIZE = 512
CELL = DISPLAY_SIZE // SIZE
FACES = ["front", "back", "right", "left", "top", "bottom"]
FACE_LABELS = {
    "front": "FRONT",
    "back": "BACK",
    "right": "RIGHT",
    "left": "LEFT",
    "top": "TOP",
    "bottom": "BOTTOM",
}
FACE_TO_BB = {
    "front": "north",
    "back": "south",
    "right": "east",
    "left": "west",
    "top": "up",
    "bottom": "down",
}
OPPOSITE = {
    "front": "back",
    "back": "front",
    "right": "left",
    "left": "right",
    "top": "bottom",
    "bottom": "top",
}


@dataclass
class PartDef:
    id: str
    label: str
    anchor: Tuple[float, float, float]


PARTS = [
    PartDef("head", "HEAD", (0.0, 40.0, 0.0)),
    PartDef("torso", "TORSO", (0.0, 22.0, 0.0)),
    PartDef("left_arm", "LEFT ARM", (-8.0, 24.0, 0.0)),
    PartDef("right_arm", "RIGHT ARM", (8.0, 24.0, 0.0)),
    PartDef("left_leg", "LEFT LEG", (-4.5, 3.0, -1.0)),
    PartDef("right_leg", "RIGHT LEG", (4.5, 3.0, -1.0)),
]
PART_BY_ID = {p.id: p for p in PARTS}


BG = "#09131d"
PANEL = "#102735"
PANEL_2 = "#12394b"
CYAN = "#57efff"
CYAN_DARK = "#0e7184"
MAGENTA = "#ff4bb8"
TEXT = "#e7faff"
MUTED = "#8eb7c5"
RED = "#ff4660"
GREEN = "#5cf4b4"


def rgba_pack(arr: np.ndarray) -> np.ndarray:
    a = arr.astype(np.uint32)
    return (
        (a[..., 0] << 24)
        | (a[..., 1] << 16)
        | (a[..., 2] << 8)
        | a[..., 3]
    )


def image_to_data_uri(image: Image.Image) -> str:
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def image_from_data_uri(value: str) -> Image.Image:
    payload = value.split(",", 1)[1] if "," in value else value
    return Image.open(io.BytesIO(base64.b64decode(payload))).convert("RGBA")


def default_output_dir() -> Path:
    desktop = Path.home() / "Desktop" / "KW_Blockbench" / "Generated"
    desktop.mkdir(parents=True, exist_ok=True)
    return desktop


def find_blockbench() -> Path | None:
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Blockbench" / "Blockbench.exe",
        Path(os.environ.get("PROGRAMFILES", "")) / "Blockbench" / "Blockbench.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Blockbench" / "Blockbench.exe",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def repo_root() -> Path:
    if getattr(sys, "frozen", False):
        # dist/KW Character Builder.exe -> kw_character_builder -> tools -> repo
        return Path(sys.executable).resolve().parents[3]
    return Path(__file__).resolve().parents[2]


def current_outrage_template_path() -> Path:
    filename = "Outrage_FullBody_v11_slimmer_body_foot.bbmodel"
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        bundled = Path(getattr(sys, "_MEIPASS")) / "kw_templates" / filename
        if bundled.exists():
            return bundled
    return repo_root() / "art_source" / "blockbench" / "outrage" / filename


class PixelStore:
    def __init__(self) -> None:
        self.images: Dict[str, Dict[str, Image.Image]] = {
            part.id: {face: Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)) for face in FACES}
            for part in PARTS
        }
        self.anchors = {part.id: list(part.anchor) for part in PARTS}

    def clear(self) -> None:
        for part in PARTS:
            for face in FACES:
                self.images[part.id][face] = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self.anchors = {part.id: list(part.anchor) for part in PARTS}


class CharacterBuilderApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title(APP_NAME)
        self.geometry("1220x820")
        self.minsize(1050, 720)
        self.configure(bg=BG)

        self.store = PixelStore()
        self.part_id = "head"
        self.face = "front"
        self.tool = "brush"
        self.color = "#8f1d27"
        self.brush_size = 1
        self.painting = False
        self.last_cell: Tuple[int, int] | None = None
        self.preview_photo: ImageTk.PhotoImage | None = None
        self.cuboid_editor: CuboidEditorWindow | None = None

        self.mode_var = tk.StringVar(value="forgiving")
        self.voxel_var = tk.DoubleVar(value=1.0)
        self.white_alpha_var = tk.BooleanVar(value=False)
        self.grid_opacity_var = tk.IntVar(value=45)
        self.status_var = tk.StringVar(value="READY // transparent pixels become empty 3D space")
        self.color_var = tk.StringVar(value=self.color)
        self.anchor_vars = [tk.DoubleVar(), tk.DoubleVar(), tk.DoubleVar()]

        self.part_buttons: Dict[str, tk.Button] = {}
        self.face_buttons: Dict[str, tk.Button] = {}
        self.tool_buttons: Dict[str, tk.Button] = {}

        self._build_ui()
        self._bind_shortcuts()
        self._sync_anchor_fields()
        self._refresh_preview()

    # ---------------- UI ----------------

    def _button(self, parent, text, command, *, bg=PANEL_2, fg=TEXT, width=None, font=("Segoe UI", 9, "bold")):
        b = tk.Button(
            parent,
            text=text,
            command=command,
            bg=bg,
            fg=fg,
            activebackground=CYAN_DARK,
            activeforeground="white",
            relief="flat",
            bd=0,
            padx=10,
            pady=7,
            cursor="hand2",
            font=font,
            highlightthickness=1,
            highlightbackground="#286177",
        )
        if width:
            b.configure(width=width)
        return b

    def _build_ui(self) -> None:
        title_bar = tk.Frame(self, bg="#081018", height=54)
        title_bar.pack(fill="x")
        tk.Label(
            title_bar,
            text="KW CHARACTER BUILDER",
            bg="#081018",
            fg=CYAN,
            font=("Consolas", 19, "bold"),
        ).pack(side="left", padx=18, pady=11)
        tk.Label(
            title_bar,
            text="6-VIEW PIXEL → BLOCKBENCH 3D",
            bg="#081018",
            fg=MAGENTA,
            font=("Consolas", 9, "bold"),
        ).pack(side="right", padx=18)
        self._button(
            title_bar,
            "3D BLOCK EDITOR",
            self._open_cuboid_editor,
            bg="#15576c",
            fg="white",
            width=16,
            font=("Consolas", 9, "bold"),
        ).pack(side="right", padx=(0, 2), pady=8)

        part_bar = tk.Frame(self, bg=BG)
        part_bar.pack(fill="x", padx=12, pady=(10, 4))
        for part in PARTS:
            b = self._button(part_bar, part.label, lambda pid=part.id: self._select_part(pid), width=12)
            b.pack(side="left", padx=3)
            self.part_buttons[part.id] = b

        face_bar = tk.Frame(self, bg=BG)
        face_bar.pack(fill="x", padx=12, pady=(2, 8))
        for face in FACES:
            b = self._button(face_bar, FACE_LABELS[face], lambda f=face: self._select_face(f), width=10, font=("Consolas", 9, "bold"))
            b.pack(side="left", padx=3)
            self.face_buttons[face] = b

        body = tk.Frame(self, bg=BG)
        body.pack(fill="both", expand=True, padx=12, pady=(0, 10))

        canvas_panel = tk.Frame(body, bg=PANEL, highlightthickness=1, highlightbackground="#2a6b80")
        canvas_panel.pack(side="left", fill="both", expand=True, padx=(0, 10))

        tool_bar = tk.Frame(canvas_panel, bg=PANEL)
        tool_bar.pack(fill="x", padx=10, pady=9)
        for tool, label in [("brush", "BRUSH [B]"), ("eraser", "ERASER [E]"), ("picker", "PICKER [P]")]:
            b = self._button(tool_bar, label, lambda t=tool: self._select_tool(t), width=12)
            b.pack(side="left", padx=3)
            self.tool_buttons[tool] = b

        self.color_button = self._button(tool_bar, self.color.upper(), self._choose_color, bg=self.color, fg="white", width=10)
        self.color_button.pack(side="left", padx=(12, 3))
        tk.Label(tool_bar, text="BRUSH", bg=PANEL, fg=MUTED, font=("Consolas", 8, "bold")).pack(side="left", padx=(12, 3))
        self.brush_spin = tk.Spinbox(
            tool_bar, from_=1, to=8, width=3, command=self._brush_changed,
            bg="#07141d", fg=TEXT, insertbackground=TEXT, buttonbackground=PANEL_2,
            relief="flat", font=("Consolas", 10, "bold"),
        )
        self.brush_spin.delete(0, "end")
        self.brush_spin.insert(0, "1")
        self.brush_spin.pack(side="left")

        grid_controls = tk.Frame(tool_bar, bg=PANEL)
        grid_controls.pack(side="right", padx=(10, 0))
        tk.Label(
            grid_controls,
            text="GRID",
            bg=PANEL,
            fg=MUTED,
            font=("Consolas", 8, "bold"),
        ).pack(side="left", padx=(0, 4))
        self.grid_scale = tk.Scale(
            grid_controls,
            from_=0,
            to=100,
            orient="horizontal",
            variable=self.grid_opacity_var,
            command=self._grid_opacity_changed,
            showvalue=False,
            length=120,
            bg=PANEL,
            fg=TEXT,
            troughcolor="#07141d",
            activebackground=CYAN,
            highlightthickness=0,
            bd=0,
            sliderrelief="flat",
        )
        self.grid_scale.pack(side="left")
        self.grid_opacity_label = tk.Label(
            grid_controls,
            text="45%",
            width=4,
            anchor="e",
            bg=PANEL,
            fg=CYAN,
            font=("Consolas", 8, "bold"),
        )
        self.grid_opacity_label.pack(side="left", padx=(3, 0))

        canvas_holder = tk.Frame(canvas_panel, bg="#0b1720")
        canvas_holder.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        self.canvas = tk.Canvas(
            canvas_holder,
            width=DISPLAY_SIZE,
            height=DISPLAY_SIZE,
            bg="#111b23",
            highlightthickness=1,
            highlightbackground=CYAN_DARK,
            cursor="crosshair",
        )
        self.canvas.pack(expand=True)
        self.canvas.bind("<ButtonPress-1>", self._paint_start)
        self.canvas.bind("<B1-Motion>", self._paint_move)
        self.canvas.bind("<ButtonRelease-1>", self._paint_end)
        self.canvas.bind("<ButtonPress-3>", self._pick_from_canvas)

        side = tk.Frame(body, bg=PANEL, width=335, highlightthickness=1, highlightbackground="#2a6b80")
        side.pack(side="right", fill="y")
        side.pack_propagate(False)

        self._section_label(side, "PNG / FACE")
        row = tk.Frame(side, bg=PANEL)
        row.pack(fill="x", padx=10, pady=4)
        self._button(row, "IMPORT PNG", self._import_face, width=12).pack(side="left", padx=2)
        self._button(row, "EXPORT PNG", self._export_face_png, width=12).pack(side="left", padx=2)
        self._button(
            side,
            "IMPORT 6 NAMED PNGs",
            self._import_six_faces,
            bg="#15576c",
            fg="white",
            font=("Consolas", 9, "bold"),
        ).pack(fill="x", padx=12, pady=(3, 4))
        row = tk.Frame(side, bg=PANEL)
        row.pack(fill="x", padx=10, pady=4)
        self._button(row, "FLIP H", lambda: self._flip_face(True), width=8).pack(side="left", padx=2)
        self._button(row, "FLIP V", lambda: self._flip_face(False), width=8).pack(side="left", padx=2)
        self._button(row, "CLEAR", self._clear_face, width=8, bg="#5f2132").pack(side="left", padx=2)
        tk.Checkbutton(
            side,
            text="Treat near-white as transparent on import",
            variable=self.white_alpha_var,
            bg=PANEL,
            fg=MUTED,
            selectcolor="#07141d",
            activebackground=PANEL,
            activeforeground=TEXT,
            font=("Segoe UI", 8),
        ).pack(anchor="w", padx=13, pady=(3, 8))

        self._section_label(side, "PART POSITION")
        pos = tk.Frame(side, bg=PANEL)
        pos.pack(fill="x", padx=10, pady=4)
        for i, axis in enumerate("XYZ"):
            tk.Label(pos, text=axis, bg=PANEL, fg=CYAN, font=("Consolas", 9, "bold")).grid(row=0, column=i * 2, padx=(4, 1))
            e = tk.Entry(pos, textvariable=self.anchor_vars[i], width=7, bg="#07141d", fg=TEXT, insertbackground=TEXT, relief="flat")
            e.grid(row=0, column=i * 2 + 1, padx=(0, 5))
            e.bind("<FocusOut>", lambda _e: self._anchor_changed())
            e.bind("<Return>", lambda _e: self._anchor_changed())

        opts = tk.Frame(side, bg=PANEL)
        opts.pack(fill="x", padx=12, pady=5)
        tk.Label(opts, text="VOXEL SIZE", bg=PANEL, fg=MUTED, font=("Consolas", 8, "bold")).grid(row=0, column=0, sticky="w")
        tk.Entry(opts, textvariable=self.voxel_var, width=7, bg="#07141d", fg=TEXT, insertbackground=TEXT, relief="flat").grid(row=0, column=1, padx=7)
        tk.Label(opts, text="MODE", bg=PANEL, fg=MUTED, font=("Consolas", 8, "bold")).grid(row=1, column=0, sticky="w", pady=6)
        mode_menu = tk.OptionMenu(opts, self.mode_var, "forgiving", "strict")
        mode_menu.configure(bg=PANEL_2, fg=TEXT, activebackground=CYAN_DARK, relief="flat", highlightthickness=0, width=10)
        mode_menu["menu"].configure(bg=PANEL_2, fg=TEXT)
        mode_menu.grid(row=1, column=1, padx=7)

        desc = (
            "FORGIVING: better for hand-drawn views.\n"
            "STRICT: all painted silhouettes must intersect.\n\n"
            "Transparent pixels = empty 3D space.\n"
            "Your RGB colors are preserved in the generated atlas."
        )
        tk.Label(side, text=desc, justify="left", bg=PANEL, fg="#9fc3cf", font=("Segoe UI", 8), wraplength=300).pack(anchor="w", padx=13, pady=5)

        self._section_label(side, "PROJECT")
        row = tk.Frame(side, bg=PANEL)
        row.pack(fill="x", padx=10, pady=4)
        self._button(row, "SAVE", self._save_project, width=10).pack(side="left", padx=2)
        self._button(row, "LOAD", self._load_project, width=10).pack(side="left", padx=2)
        self._button(row, "NEW", self._new_project, width=8, bg="#5f2132").pack(side="left", padx=2)

        self._button(
            side,
            "EXPORT TO BLOCKBENCH",
            self._export_to_blockbench,
            bg="#0d7785",
            fg="white",
            font=("Consolas", 12, "bold"),
        ).pack(fill="x", padx=12, pady=(14, 6), ipady=7)

        tk.Label(
            side,
            text="Creates .bbmodel + transparent PNG atlas\nand opens the model directly in Blockbench.",
            justify="center",
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI", 8),
        ).pack(pady=(0, 8))

        status = tk.Label(
            self,
            textvariable=self.status_var,
            anchor="w",
            bg="#071018",
            fg=GREEN,
            font=("Consolas", 8, "bold"),
            padx=12,
            pady=6,
        )
        status.pack(fill="x", side="bottom")

        self._refresh_tabs()

    def _section_label(self, parent, text: str) -> None:
        frame = tk.Frame(parent, bg=PANEL)
        frame.pack(fill="x", padx=10, pady=(12, 3))
        tk.Label(frame, text=text, bg=PANEL, fg=MAGENTA, font=("Consolas", 10, "bold")).pack(side="left")
        tk.Frame(frame, bg="#365e70", height=1).pack(side="left", fill="x", expand=True, padx=(8, 0))

    def _bind_shortcuts(self) -> None:
        self.bind("b", lambda _e: self._select_tool("brush"))
        self.bind("e", lambda _e: self._select_tool("eraser"))
        self.bind("p", lambda _e: self._select_tool("picker"))
        self.bind("<Control-s>", lambda _e: self._save_project())
        self.bind("<Control-o>", lambda _e: self._load_project())

    def _open_cuboid_editor(self) -> None:
        if self.cuboid_editor is not None and self.cuboid_editor.winfo_exists():
            self.cuboid_editor.deiconify()
            self.cuboid_editor.lift()
            return
        self.cuboid_editor = CuboidEditorWindow(self)

    # ---------------- drawing ----------------

    def _current_image(self) -> Image.Image:
        return self.store.images[self.part_id][self.face]

    def _select_part(self, part_id: str) -> None:
        self._anchor_changed()
        self.part_id = part_id
        self._sync_anchor_fields()
        self._refresh_tabs()
        self._refresh_preview()

    def _select_face(self, face: str) -> None:
        self.face = face
        self._refresh_tabs()
        self._refresh_preview()

    def _select_tool(self, tool: str) -> None:
        self.tool = tool
        self._refresh_tabs()

    def _refresh_tabs(self) -> None:
        for pid, button in self.part_buttons.items():
            active = pid == self.part_id
            button.configure(bg=CYAN_DARK if active else PANEL_2, fg="white" if active else TEXT)
        for face, button in self.face_buttons.items():
            active = face == self.face
            button.configure(bg="#7a1b62" if active else PANEL_2, fg="white" if active else TEXT)
        for tool, button in self.tool_buttons.items():
            active = tool == self.tool
            button.configure(bg=CYAN_DARK if active else PANEL_2)

    def _choose_color(self) -> None:
        result = colorchooser.askcolor(self.color, title="Choose pixel color")
        if result and result[1]:
            self.color = result[1]
            self.color_var.set(self.color)
            self.color_button.configure(text=self.color.upper(), bg=self.color)

    def _brush_changed(self) -> None:
        try:
            self.brush_size = max(1, min(8, int(self.brush_spin.get())))
        except ValueError:
            self.brush_size = 1

    def _grid_opacity_changed(self, value=None) -> None:
        try:
            opacity = int(round(float(value))) if value is not None else int(self.grid_opacity_var.get())
        except (TypeError, ValueError, tk.TclError):
            opacity = 45
        opacity = max(0, min(100, opacity))
        self.grid_opacity_var.set(opacity)
        if hasattr(self, "grid_opacity_label"):
            self.grid_opacity_label.configure(text=f"{opacity}%")
        if hasattr(self, "canvas"):
            self._refresh_preview()

    def _canvas_cell(self, event) -> Tuple[int, int]:
        w = max(1, self.canvas.winfo_width())
        h = max(1, self.canvas.winfo_height())
        x = max(0, min(SIZE - 1, int(event.x / w * SIZE)))
        y = max(0, min(SIZE - 1, int(event.y / h * SIZE)))
        return x, y

    def _paint_start(self, event) -> None:
        self._brush_changed()
        self.painting = True
        cell = self._canvas_cell(event)
        self.last_cell = cell
        self._paint_cell(*cell)

    def _paint_move(self, event) -> None:
        if not self.painting:
            return
        cell = self._canvas_cell(event)
        if self.last_cell:
            for x, y in self._line_cells(self.last_cell, cell):
                self._paint_cell(x, y, refresh=False)
            self._refresh_preview()
        self.last_cell = cell

    def _paint_end(self, _event) -> None:
        self.painting = False
        self.last_cell = None

    def _pick_from_canvas(self, event) -> None:
        x, y = self._canvas_cell(event)
        pixel = self._current_image().getpixel((x, y))
        if pixel[3] > 0:
            self.color = "#%02x%02x%02x" % pixel[:3]
            self.color_button.configure(text=self.color.upper(), bg=self.color)
            self._select_tool("brush")

    @staticmethod
    def _line_cells(a: Tuple[int, int], b: Tuple[int, int]):
        x0, y0 = a
        x1, y1 = b
        dx = abs(x1 - x0)
        sx = 1 if x0 < x1 else -1
        dy = -abs(y1 - y0)
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        out = []
        while True:
            out.append((x0, y0))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return out

    def _paint_cell(self, x: int, y: int, refresh: bool = True) -> None:
        if self.tool == "picker":
            pixel = self._current_image().getpixel((x, y))
            if pixel[3] > 0:
                self.color = "#%02x%02x%02x" % pixel[:3]
                self.color_button.configure(text=self.color.upper(), bg=self.color)
            self._select_tool("brush")
            return

        img = self._current_image()
        draw = ImageDraw.Draw(img)
        size = self.brush_size
        box = [x, y, min(SIZE - 1, x + size - 1), min(SIZE - 1, y + size - 1)]
        if self.tool == "eraser":
            draw.rectangle(box, fill=(0, 0, 0, 0))
        else:
            rgb = tuple(int(self.color[i:i + 2], 16) for i in (1, 3, 5))
            draw.rectangle(box, fill=rgb + (255,))
        if refresh:
            self._refresh_preview()

    def _refresh_preview(self) -> None:
        # Checkerboard first.
        preview = Image.new("RGBA", (DISPLAY_SIZE, DISPLAY_SIZE), (20, 29, 36, 255))
        d = ImageDraw.Draw(preview)
        check = 16
        for y in range(0, DISPLAY_SIZE, check):
            for x in range(0, DISPLAY_SIZE, check):
                if (x // check + y // check) % 2:
                    d.rectangle([x, y, x + check - 1, y + check - 1], fill=(39, 53, 63, 255))

        scaled = self._current_image().resize((DISPLAY_SIZE, DISPLAY_SIZE), Image.Resampling.NEAREST)
        preview.alpha_composite(scaled)

        # UI-only 64x64 grid. Draw it on a separate RGBA layer so the
        # opacity slider affects only the visible overlay, never image data.
        opacity = max(0, min(100, int(self.grid_opacity_var.get()))) / 100.0
        if opacity > 0:
            grid = Image.new("RGBA", (DISPLAY_SIZE, DISPLAY_SIZE), (0, 0, 0, 0))
            gd = ImageDraw.Draw(grid)
            major_alpha = int(round(255 * opacity))
            minor_alpha = int(round(major_alpha * (42.0 / 115.0)))
            for i in range(SIZE + 1):
                p = min(DISPLAY_SIZE - 1, i * CELL)
                major = i % 8 == 0
                color = (93, 222, 241, major_alpha if major else minor_alpha)
                gd.line([(p, 0), (p, DISPLAY_SIZE - 1)], fill=color, width=1)
                gd.line([(0, p), (DISPLAY_SIZE - 1, p)], fill=color, width=1)
            preview = Image.alpha_composite(preview, grid)

        self.preview_photo = ImageTk.PhotoImage(preview.convert("RGB"))
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor="nw", image=self.preview_photo)

    def _clear_face(self) -> None:
        if not messagebox.askyesno(APP_NAME, f"Clear {PART_BY_ID[self.part_id].label} / {FACE_LABELS[self.face]}?"):
            return
        self.store.images[self.part_id][self.face] = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self._refresh_preview()

    def _flip_face(self, horizontal: bool) -> None:
        method = Image.Transpose.FLIP_LEFT_RIGHT if horizontal else Image.Transpose.FLIP_TOP_BOTTOM
        self.store.images[self.part_id][self.face] = self._current_image().transpose(method)
        self._refresh_preview()

    @staticmethod
    def _face_from_filename(path: str | Path) -> str | None:
        stem = Path(path).stem.lower()
        tokens = {token for token in re.split(r"[^a-z0-9]+", stem) if token}
        aliases = {
            "front": {"front"},
            "back": {"back", "rear"},
            "right": {"right"},
            "left": {"left"},
            "top": {"top", "up"},
            "bottom": {"bottom", "down", "bot"},
        }
        matches = [face for face, names in aliases.items() if tokens.intersection(names)]
        return matches[0] if len(matches) == 1 else None

    def _load_import_image(self, path: str | Path) -> Tuple[Image.Image, Tuple[int, int]]:
        with Image.open(path) as source:
            img = source.convert("RGBA")
        original_size = img.size
        if img.size != (SIZE, SIZE):
            img = img.resize((SIZE, SIZE), Image.Resampling.NEAREST)
        if self.white_alpha_var.get():
            arr = np.array(img)
            mask = (arr[..., 0] > 248) & (arr[..., 1] > 248) & (arr[..., 2] > 248)
            arr[mask, 3] = 0
            img = Image.fromarray(arr, "RGBA")
        return img, original_size

    def _import_face(self) -> None:
        path = filedialog.askopenfilename(
            title=f"Import PNG for {PART_BY_ID[self.part_id].label} / {FACE_LABELS[self.face]}",
            filetypes=[("PNG", "*.png"), ("Images", "*.png;*.jpg;*.jpeg;*.webp")],
        )
        if not path:
            return
        try:
            img, original_size = self._load_import_image(path)
            self.store.images[self.part_id][self.face] = img
            self._refresh_preview()
            resize_note = "" if original_size == (SIZE, SIZE) else f" // {original_size[0]}x{original_size[1]} -> {SIZE}x{SIZE}"
            self._status(f"IMPORTED {FACE_LABELS[self.face]} // {Path(path).name}{resize_note}")
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not import image:\n{exc}")

    def _import_six_faces(self) -> None:
        paths = filedialog.askopenfilenames(
            title=f"Import 6 named PNGs for {PART_BY_ID[self.part_id].label}",
            filetypes=[("PNG", "*.png"), ("Images", "*.png;*.jpg;*.jpeg;*.webp")],
        )
        if not paths:
            return

        mapping: Dict[str, str] = {}
        unknown: List[str] = []
        duplicates: List[str] = []
        for path in paths:
            face = self._face_from_filename(path)
            if face is None:
                unknown.append(Path(path).name)
            elif face in mapping:
                duplicates.append(FACE_LABELS[face])
            else:
                mapping[face] = path

        missing = [FACE_LABELS[face] for face in FACES if face not in mapping]
        if unknown or duplicates or missing or len(paths) != len(FACES):
            details = [
                "Select exactly 6 images whose filenames contain one face name:",
                "front, back, right, left, top, bottom.",
            ]
            if missing:
                details.append("\nMissing: " + ", ".join(missing))
            if unknown:
                details.append("\nUnrecognized: " + ", ".join(unknown))
            if duplicates:
                details.append("\nDuplicate face names: " + ", ".join(sorted(set(duplicates))))
            messagebox.showerror(APP_NAME, "\n".join(details))
            return

        try:
            loaded = {face: self._load_import_image(mapping[face])[0] for face in FACES}
            self.store.images[self.part_id].update(loaded)
            self._refresh_preview()
            self._status(f"IMPORTED 6 PNGs // {PART_BY_ID[self.part_id].label}")
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not import the six images:\n{exc}")

    def _export_face_png(self) -> None:
        default = f"kw_{self.part_id}_{self.face}.png"
        path = filedialog.asksaveasfilename(title="Export face PNG", defaultextension=".png", initialfile=default, filetypes=[("PNG", "*.png")])
        if path:
            self._current_image().save(path, "PNG")
            self._status(f"EXPORTED PNG // {Path(path).name}")

    # ---------------- projects ----------------

    def _anchor_changed(self) -> None:
        try:
            self.store.anchors[self.part_id] = [float(v.get()) for v in self.anchor_vars]
        except (ValueError, tk.TclError):
            pass

    def _sync_anchor_fields(self) -> None:
        anchor = self.store.anchors[self.part_id]
        for i in range(3):
            self.anchor_vars[i].set(anchor[i])

    def _project_payload(self) -> dict:
        self._anchor_changed()
        parts = {}
        for part in PARTS:
            parts[part.id] = {face: image_to_data_uri(self.store.images[part.id][face]) for face in FACES}
        return {
            "version": 2,
            "size": SIZE,
            "voxel_size": float(self.voxel_var.get()),
            "mode": self.mode_var.get(),
            "anchors": self.store.anchors,
            "parts": parts,
        }

    def _save_project(self) -> None:
        path = filedialog.asksaveasfilename(
            title="Save KW Character Project",
            defaultextension=".kwchar.json",
            initialfile="KW_character.kwchar.json",
            filetypes=[("KW Character Project", "*.kwchar.json"), ("JSON", "*.json")],
        )
        if not path:
            return
        Path(path).write_text(json.dumps(self._project_payload()), encoding="utf-8")
        self._status(f"PROJECT SAVED // {Path(path).name}")

    def _load_project(self) -> None:
        path = filedialog.askopenfilename(title="Load KW Character Project", filetypes=[("KW Character Project", "*.kwchar.json;*.json"), ("JSON", "*.json")])
        if not path:
            return
        try:
            payload = json.loads(Path(path).read_text(encoding="utf-8"))
            self.voxel_var.set(float(payload.get("voxel_size", 1.0)))
            self.mode_var.set(payload.get("mode", "forgiving"))
            anchors = payload.get("anchors", {})
            for part in PARTS:
                if part.id in anchors:
                    self.store.anchors[part.id] = [float(x) for x in anchors[part.id][:3]]
                for face in FACES:
                    value = payload.get("parts", {}).get(part.id, {}).get(face)
                    if value:
                        self.store.images[part.id][face] = image_from_data_uri(value).resize((SIZE, SIZE), Image.Resampling.NEAREST)
            self._sync_anchor_fields()
            self._refresh_preview()
            self._status(f"PROJECT LOADED // {Path(path).name}")
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not load project:\n{exc}")

    def _new_project(self) -> None:
        if not messagebox.askyesno(APP_NAME, "Clear all parts and start a new character?"):
            return
        self.store.clear()
        self.part_id = "head"
        self.face = "front"
        self._sync_anchor_fields()
        self._refresh_tabs()
        self._refresh_preview()
        self._status("NEW CHARACTER // ready")

    # ---------------- reconstruction ----------------

    @staticmethod
    def _face_arrays(images: Dict[str, Image.Image]):
        rgba = {face: np.asarray(images[face].convert("RGBA"), dtype=np.uint8) for face in FACES}
        alpha = {face: rgba[face][..., 3] > 8 for face in FACES}
        packed = {face: rgba_pack(rgba[face]) for face in FACES}
        return rgba, alpha, packed

    @staticmethod
    def _mapped_alpha(alpha: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        # Treat every editor face exactly as it is drawn/imported. Older builds
        # silently mirrored BACK/LEFT and flipped BOTTOM, which made matching
        # six-view PNG sets diverge during reconstruction.
        return {
            "front": alpha["front"][::-1, :][:, None, :],
            "back": alpha["back"][::-1, :][:, None, :],
            "right": alpha["right"][::-1, :][:, :, None],
            "left": alpha["left"][::-1, :][:, :, None],
            "top": alpha["top"][None, :, :],
            "bottom": alpha["bottom"][None, :, :],
        }

    @staticmethod
    def _mapped_color(packed: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        return {
            "front": packed["front"][::-1, :][:, None, :],
            "back": packed["back"][::-1, :][:, None, :],
            "right": packed["right"][::-1, :][:, :, None],
            "left": packed["left"][::-1, :][:, :, None],
            "top": packed["top"][None, :, :],
            "bottom": packed["bottom"][None, :, :],
        }

    def _visual_hull(self, part_id: str):
        images = self.store.images[part_id]
        _rgba, alpha2, packed2 = self._face_arrays(images)
        active = {face: bool(alpha2[face].any()) for face in FACES}
        if not any(active.values()):
            return None
        missing = []
        for a, b in [("front", "back"), ("left", "right"), ("top", "bottom")]:
            if not active[a] and not active[b]:
                missing.append((a, b))
        if missing:
            raise ValueError(
                f"{PART_BY_ID[part_id].label}: draw at least one view in each axis pair "
                f"(front/back, left/right, top/bottom)."
            )

        ma = self._mapped_alpha(alpha2)
        mc = self._mapped_color(packed2)

        def pair_ok(a: str, b: str):
            if not active[a]:
                return ma[b]
            if not active[b]:
                return ma[a]
            return (ma[a] & ma[b]) if self.mode_var.get() == "strict" else (ma[a] | ma[b])

        occupied = pair_ok("front", "back") & pair_ok("left", "right") & pair_ok("top", "bottom")
        if not occupied.any():
            raise ValueError(f"{PART_BY_ID[part_id].label}: the six silhouettes do not overlap enough to create 3D volume.")

        # Colors fall back to the opposite view when the exact face pixel is transparent.
        colors = {}
        for face in FACES:
            opp = OPPOSITE[face]
            colors[face] = np.where(ma[face], mc[face], mc[opp]).astype(np.uint32)

        # Hash the six projected colors into a 64-bit signature for greedy merging.
        primes = {
            "front": np.uint64(11400714819323198485),
            "back": np.uint64(14029467366897019727),
            "right": np.uint64(1609587929392839161),
            "left": np.uint64(9650029242287828579),
            "top": np.uint64(2870177450012600261),
            "bottom": np.uint64(7046029254386353131),
        }
        signature = np.zeros((SIZE, SIZE, SIZE), dtype=np.uint64)
        for face in FACES:
            signature ^= colors[face].astype(np.uint64) * primes[face]

        coords = np.argwhere(occupied)  # y, z, x
        mins = coords.min(axis=0)
        maxs = coords.max(axis=0)
        return {
            "occupied": occupied,
            "signature": signature,
            "alpha": alpha2,
            "active": active,
            "mins": mins,
            "maxs": maxs,
        }

    @staticmethod
    def _merge_hull(hull) -> List[Tuple[int, int, int, int, int, int]]:
        occ = hull["occupied"]
        sig = hull["signature"]
        visited = np.zeros_like(occ, dtype=bool)
        coords = np.argwhere(occ)
        boxes = []

        for y, z, x in coords:
            y = int(y); z = int(z); x = int(x)
            if visited[y, z, x]:
                continue
            s = sig[y, z, x]

            x1 = x
            while x1 + 1 < SIZE and occ[y, z, x1 + 1] and not visited[y, z, x1 + 1] and sig[y, z, x1 + 1] == s:
                x1 += 1

            z1 = z
            while z1 + 1 < SIZE:
                nz = z1 + 1
                row_occ = occ[y, nz, x:x1 + 1]
                row_vis = visited[y, nz, x:x1 + 1]
                row_sig = sig[y, nz, x:x1 + 1]
                if not row_occ.all() or row_vis.any() or not (row_sig == s).all():
                    break
                z1 = nz

            y1 = y
            while y1 + 1 < SIZE:
                ny = y1 + 1
                slab_occ = occ[ny, z:z1 + 1, x:x1 + 1]
                slab_vis = visited[ny, z:z1 + 1, x:x1 + 1]
                slab_sig = sig[ny, z:z1 + 1, x:x1 + 1]
                if not slab_occ.all() or slab_vis.any() or not (slab_sig == s).all():
                    break
                y1 = ny

            visited[y:y1 + 1, z:z1 + 1, x:x1 + 1] = True
            boxes.append((x, y, z, x1, y1, z1))
            if len(boxes) > 4000:
                raise ValueError("This part generated more than 4000 cuboids. Simplify the silhouettes/colors or increase brush regions.")
        return boxes

    def _build_atlas(self) -> Image.Image:
        atlas = Image.new("RGBA", (SIZE * len(FACES), SIZE * len(PARTS)), (0, 0, 0, 0))
        for row, part in enumerate(PARTS):
            for col, face in enumerate(FACES):
                atlas.alpha_composite(self.store.images[part.id][face], (col * SIZE, row * SIZE))
        return atlas

    @staticmethod
    def _mapped_pixel(face: str, x: int, y: int, z: int) -> Tuple[int, int]:
        sy = SIZE - 1 - y
        if face == "front": return x, sy
        if face == "back": return x, sy
        if face == "right": return z, sy
        if face == "left": return z, sy
        if face == "top": return x, z
        return x, z

    def _atlas_uv_for_face(self, part_index: int, part_id: str, face: str, x: int, y: int, z: int) -> Tuple[int, int]:
        image = self.store.images[part_id][face]
        u, v = self._mapped_pixel(face, x, y, z)
        if image.getpixel((u, v))[3] <= 8:
            face = OPPOSITE[face]
            image = self.store.images[part_id][face]
            u, v = self._mapped_pixel(face, x, y, z)
        face_index = FACES.index(face)
        return face_index * SIZE + u, part_index * SIZE + v

    @staticmethod
    def _group_record(name: str, group_uuid: str, origin: List[float]) -> dict:
        return {
            "name": name,
            "uuid": group_uuid,
            "export": True,
            "locked": False,
            "scope": 0,
            "selected": False,
            "visibility": True,
            "_static": {"properties": {}, "temp_data": {}},
            "origin": origin,
            "rotation": [0, 0, 0],
            "color": 0,
            "children": [],
            "reset": False,
            "shade": True,
            "mirror_uv": False,
            "autouv": 0,
            "isOpen": True,
            "primary_selected": False,
        }

    def _generate_bbmodel(self, output_path: Path, part_ids: set[str] | None = None) -> Tuple[Path, Path, int]:
        self._anchor_changed()
        voxel_size = max(0.1, float(self.voxel_var.get()))
        atlas = self._build_atlas()
        atlas_path = output_path.with_name(output_path.stem + "_atlas.png")
        atlas.save(atlas_path, "PNG")

        elements = []
        groups = []
        outliner = []
        total_boxes = 0

        for part_index, part in enumerate(PARTS):
            if part_ids is not None and part.id not in part_ids:
                continue
            hull = self._visual_hull(part.id)
            if hull is None:
                continue
            boxes = self._merge_hull(hull)
            anchor = [float(x) for x in self.store.anchors[part.id]]
            group_uuid = str(uuid.uuid4())
            group_children = []
            group_record = self._group_record("KW_" + part.label.replace(" ", "_"), group_uuid, anchor)
            groups.append(group_record)

            mins = hull["mins"]  # y,z,x
            maxs = hull["maxs"]
            center_x = (int(mins[2]) + int(maxs[2]) + 1) / 2.0
            center_y = (int(mins[0]) + int(maxs[0]) + 1) / 2.0
            center_z = (int(mins[1]) + int(maxs[1]) + 1) / 2.0

            for index, (x0, y0, z0, x1, y1, z1) in enumerate(boxes, 1):
                element_uuid = str(uuid.uuid4())
                from_pos = [
                    anchor[0] + (x0 - center_x) * voxel_size,
                    anchor[1] + (y0 - center_y) * voxel_size,
                    anchor[2] + (z0 - center_z) * voxel_size,
                ]
                to_pos = [
                    anchor[0] + (x1 + 1 - center_x) * voxel_size,
                    anchor[1] + (y1 + 1 - center_y) * voxel_size,
                    anchor[2] + (z1 + 1 - center_z) * voxel_size,
                ]
                faces = {}
                for face in FACES:
                    u, v = self._atlas_uv_for_face(part_index, part.id, face, x0, y0, z0)
                    faces[FACE_TO_BB[face]] = {"uv": [u, v, u + 1, v + 1], "texture": 0}
                elements.append({
                    "name": f"{part.id}_{index:03d}",
                    "box_uv": False,
                    "render_order": "default",
                    "locked": False,
                    "export": True,
                    "scope": 0,
                    "allow_mirror_modeling": True,
                    "from": from_pos,
                    "to": to_pos,
                    "autouv": 0,
                    "color": part_index % 8,
                    "origin": anchor,
                    "faces": faces,
                    "type": "cube",
                    "uuid": element_uuid,
                })
                group_children.append(element_uuid)
                total_boxes += 1

            outliner.append({
                "uuid": group_uuid,
                "isOpen": True,
                "name": group_record["name"],
                "origin": anchor,
                "export": True,
                "children": group_children,
            })

        if not elements:
            raise ValueError("Nothing to export. Draw at least one complete body part first.")

        atlas_uri = image_to_data_uri(atlas)
        texture_uuid = str(uuid.uuid4())
        texture = {
            "name": atlas_path.name,
            "path": str(atlas_path).replace("\\", "/"),
            "folder": "",
            "namespace": "",
            "id": "0",
            "group": "",
            "scope": 0,
            "width": atlas.width,
            "height": atlas.height,
            "uv_width": atlas.width,
            "uv_height": atlas.height,
            "particle": False,
            "use_as_default": True,
            "layers_enabled": False,
            "sync_to_project": "",
            "file_format": "png",
            "render_mode": "default",
            "render_sides": "auto",
            "wrap_mode": "limited",
            "pbr_channel": "color",
            "fps": 7,
            "frame_time": 1,
            "frame_order_type": "loop",
            "frame_order": "",
            "frame_interpolate": False,
            "visible": True,
            "internal": True,
            "saved": True,
            "uuid": texture_uuid,
            "source": atlas_uri,
        }
        model = {
            "meta": {"format_version": "5.0", "model_format": "free", "box_uv": False},
            "name": output_path.stem,
            "model_identifier": "kw.generated." + output_path.stem.lower().replace(" ", "_"),
            "resolution": {"width": atlas.width, "height": atlas.height},
            "elements": elements,
            "groups": groups,
            "outliner": outliner,
            "textures": [texture],
        }
        output_path.write_text(json.dumps(model, separators=(",", ":")), encoding="utf-8")
        return output_path, atlas_path, total_boxes

    def _export_to_blockbench(self) -> None:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        output = default_output_dir() / f"KW_Character_{timestamp}.bbmodel"
        try:
            self._status("GENERATING 3D // please wait", color=MAGENTA)
            self.update_idletasks()
            bbmodel, atlas, cubes = self._generate_bbmodel(output)
            exe = find_blockbench()
            if exe:
                subprocess.Popen([str(exe), str(bbmodel)], cwd=str(bbmodel.parent))
            else:
                os.startfile(str(bbmodel))
            self._status(f"EXPORTED // {cubes} cuboids // opened in Blockbench", color=GREEN)
            messagebox.showinfo(
                APP_NAME,
                f"Done.\n\n{bbmodel.name}\n{atlas.name}\n\nGenerated {cubes} cuboids and opened the model in Blockbench.",
            )
        except Exception as exc:
            self._status("EXPORT FAILED", color=RED)
            messagebox.showerror(APP_NAME, str(exc))

    def _status(self, text: str, color: str = GREEN) -> None:
        self.status_var.set(text)
        # Bottom label is the last widget packed into root.
        for child in self.winfo_children():
            if isinstance(child, tk.Label) and str(child.cget("textvariable")) == str(self.status_var):
                child.configure(fg=color)


class CuboidEditorWindow(tk.Toplevel):
    """Small Blockbench-style cuboid geometry editor.

    The six-view workflow remains useful for producing a starting volume, but
    the final geometry can be corrected here as explicit cuboids. This also
    lets us load the game's real authored head instead of trying to infer it
    from silhouettes.
    """

    FACE_KEYS = ("north", "south", "east", "west", "up", "down")

    def __init__(self, owner: CharacterBuilderApp) -> None:
        super().__init__(owner)
        self.owner = owner
        self.title("KW Character Builder // 3D Cuboid Editor")
        self.geometry("1180x790")
        self.minsize(980, 680)
        self.configure(bg=BG)
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        self.model: dict | None = None
        self.elements: List[dict] = []
        self.source_path: Path | None = None
        self.texture_images: List[Image.Image | None] = []
        self.scope_group_name: str | None = None
        self.scope_original_ids: set[str] = set()
        self.default_add_group_uuid: str | None = None
        self.selected_index: int | None = None
        self.canvas_items: Dict[int, int] = {}

        self.yaw = math.radians(-35.0)
        self.pitch = math.radians(-22.0)
        self.zoom = 1.0
        self._orbit_last: Tuple[int, int] | None = None

        self.status_3d_var = tk.StringVar(value="LOAD CURRENT HEAD or build a starting volume FROM 6 VIEWS")
        self.name_var = tk.StringVar(value="")
        self.coord_vars = [tk.DoubleVar(value=0.0) for _ in range(6)]
        self.step_var = tk.DoubleVar(value=1.0)

        self._build_ui()
        self.after(50, self._render_3d)

    def _build_ui(self) -> None:
        top = tk.Frame(self, bg="#081018")
        top.pack(fill="x")
        tk.Label(
            top,
            text="3D CUBOID EDITOR",
            bg="#081018",
            fg=CYAN,
            font=("Consolas", 17, "bold"),
        ).pack(side="left", padx=14, pady=10)

        source_bar = tk.Frame(self, bg=BG)
        source_bar.pack(fill="x", padx=10, pady=(8, 5))
        self.owner._button(
            source_bar, "CURRENT OUTRAGE HEAD", self._load_current_head,
            bg="#7a1b62", fg="white", font=("Consolas", 9, "bold"),
        ).pack(side="left", padx=3)
        self.owner._button(
            source_bar, "FROM 6 VIEWS", self._from_six_views,
            bg="#15576c", fg="white", font=("Consolas", 9, "bold"),
        ).pack(side="left", padx=3)
        self.owner._button(
            source_bar, "LOAD .BBMODEL", self._load_dialog,
            font=("Consolas", 9, "bold"),
        ).pack(side="left", padx=3)
        self.owner._button(
            source_bar, "EXPORT + OPEN BLOCKBENCH", self._export_and_open,
            bg="#0d7785", fg="white", font=("Consolas", 9, "bold"),
        ).pack(side="right", padx=3)

        body = tk.Frame(self, bg=BG)
        body.pack(fill="both", expand=True, padx=10, pady=(0, 8))

        view_panel = tk.Frame(body, bg=PANEL, highlightthickness=1, highlightbackground="#2a6b80")
        view_panel.pack(side="left", fill="both", expand=True, padx=(0, 8))

        view_toolbar = tk.Frame(view_panel, bg=PANEL)
        view_toolbar.pack(fill="x", padx=8, pady=7)
        for label, yaw, pitch in [
            ("ISO", -35, -22),
            ("FRONT", 0, 0),
            ("BACK", 180, 0),
            ("LEFT", 90, 0),
            ("RIGHT", -90, 0),
            ("TOP", 0, -90),
        ]:
            self.owner._button(
                view_toolbar,
                label,
                lambda y=yaw, p=pitch: self._set_view(y, p),
                width=7,
                font=("Consolas", 8, "bold"),
            ).pack(side="left", padx=2)
        self.owner._button(
            view_toolbar, "FIT", self._fit_view, width=6, font=("Consolas", 8, "bold")
        ).pack(side="right", padx=2)

        self.canvas3d = tk.Canvas(
            view_panel,
            bg="#0b1117",
            highlightthickness=1,
            highlightbackground=CYAN_DARK,
            cursor="arrow",
        )
        self.canvas3d.pack(fill="both", expand=True, padx=8, pady=(0, 8))
        self.canvas3d.bind("<ButtonPress-1>", self._select_from_canvas)
        self.canvas3d.bind("<ButtonPress-3>", self._orbit_start)
        self.canvas3d.bind("<B3-Motion>", self._orbit_move)
        self.canvas3d.bind("<ButtonRelease-3>", self._orbit_end)
        self.canvas3d.bind("<MouseWheel>", self._zoom_wheel)
        self.canvas3d.bind("<Configure>", lambda _e: self._render_3d())

        side = tk.Frame(body, bg=PANEL, width=350, highlightthickness=1, highlightbackground="#2a6b80")
        side.pack(side="right", fill="y")
        side.pack_propagate(False)

        tk.Label(
            side,
            text="BLOCKS",
            bg=PANEL,
            fg=MAGENTA,
            font=("Consolas", 10, "bold"),
        ).pack(anchor="w", padx=10, pady=(10, 3))
        self.block_list = tk.Listbox(
            side,
            bg="#07141d",
            fg=TEXT,
            selectbackground=CYAN_DARK,
            selectforeground="white",
            relief="flat",
            bd=0,
            height=13,
            activestyle="none",
            font=("Consolas", 9),
            exportselection=False,
        )
        self.block_list.pack(fill="x", padx=10)
        self.block_list.bind("<<ListboxSelect>>", self._select_list)

        name_row = tk.Frame(side, bg=PANEL)
        name_row.pack(fill="x", padx=10, pady=(7, 3))
        tk.Label(name_row, text="NAME", bg=PANEL, fg=MUTED, font=("Consolas", 8, "bold")).pack(side="left")
        tk.Entry(
            name_row,
            textvariable=self.name_var,
            bg="#07141d",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
        ).pack(side="left", fill="x", expand=True, padx=(7, 0))

        coords = tk.Frame(side, bg=PANEL)
        coords.pack(fill="x", padx=10, pady=4)
        labels = ("FROM X", "FROM Y", "FROM Z", "TO X", "TO Y", "TO Z")
        for i, label in enumerate(labels):
            r, c = divmod(i, 3)
            cell = tk.Frame(coords, bg=PANEL)
            cell.grid(row=r, column=c, padx=2, pady=2, sticky="ew")
            tk.Label(cell, text=label, bg=PANEL, fg=MUTED, font=("Consolas", 7, "bold")).pack(anchor="w")
            tk.Entry(
                cell,
                textvariable=self.coord_vars[i],
                width=8,
                bg="#07141d",
                fg=TEXT,
                insertbackground=TEXT,
                relief="flat",
                font=("Consolas", 9),
            ).pack(fill="x")
            coords.grid_columnconfigure(c, weight=1)

        self.owner._button(
            side, "APPLY NAME + COORDS", self._apply_coords,
            bg="#15576c", fg="white", font=("Consolas", 9, "bold"),
        ).pack(fill="x", padx=10, pady=(3, 7))

        step_row = tk.Frame(side, bg=PANEL)
        step_row.pack(fill="x", padx=10, pady=(1, 3))
        tk.Label(step_row, text="MOVE STEP", bg=PANEL, fg=MUTED, font=("Consolas", 8, "bold")).pack(side="left")
        tk.Entry(
            step_row,
            textvariable=self.step_var,
            width=7,
            bg="#07141d",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
            font=("Consolas", 9),
        ).pack(side="left", padx=7)

        moves = tk.Frame(side, bg=PANEL)
        moves.pack(fill="x", padx=10, pady=3)
        for i, (label, axis, direction) in enumerate([
            ("-X", 0, -1), ("+X", 0, 1),
            ("-Y", 1, -1), ("+Y", 1, 1),
            ("-Z", 2, -1), ("+Z", 2, 1),
        ]):
            self.owner._button(
                moves,
                label,
                lambda a=axis, d=direction: self._nudge(a, d),
                width=5,
                font=("Consolas", 8, "bold"),
            ).grid(row=i // 2, column=i % 2, padx=2, pady=2, sticky="ew")
            moves.grid_columnconfigure(i % 2, weight=1)

        edit_row = tk.Frame(side, bg=PANEL)
        edit_row.pack(fill="x", padx=10, pady=(5, 2))
        self.owner._button(
            edit_row, "ADD CUBE", self._add_box, width=9, bg="#24576a"
        ).pack(side="left", padx=2)
        self.owner._button(
            edit_row, "DUPLICATE +X", self._duplicate_selected, width=11, bg="#24576a"
        ).pack(side="left", padx=2)
        self.owner._button(
            edit_row, "DELETE", self._delete_selected, width=8, bg="#5f2132"
        ).pack(side="left", padx=2)

        tk.Label(
            side,
            text="LEFT CLICK: select block\nRIGHT DRAG: orbit • WHEEL: zoom\n\nSix-view reconstruction is a starting point.\nFinish the real shape here with explicit cuboids.",
            justify="left",
            bg=PANEL,
            fg="#9fc3cf",
            font=("Segoe UI", 8),
            wraplength=320,
        ).pack(anchor="w", padx=11, pady=(8, 4))

        status = tk.Label(
            self,
            textvariable=self.status_3d_var,
            anchor="w",
            bg="#071018",
            fg=GREEN,
            font=("Consolas", 8, "bold"),
            padx=10,
            pady=5,
        )
        status.pack(fill="x", side="bottom")

    def _set_status(self, text: str) -> None:
        self.status_3d_var.set(text)

    def _on_close(self) -> None:
        self.owner.cuboid_editor = None
        self.destroy()

    def _current_head_path(self) -> Path:
        return current_outrage_template_path()

    def _load_current_head(self) -> None:
        path = self._current_head_path()
        if not path.exists():
            messagebox.showerror(APP_NAME, f"Current Outrage head was not found:\n{path}", parent=self)
            return
        self._load_model(path, group_name="Outrage_Head")

    def _load_dialog(self) -> None:
        path = filedialog.askopenfilename(
            parent=self,
            title="Load Blockbench cuboid model",
            filetypes=[("Blockbench model", "*.bbmodel"), ("JSON", "*.json")],
        )
        if path:
            self._load_model(Path(path))

    @staticmethod
    def _group_element_ids(data: dict, group_name: str) -> set[str]:
        group_names = {
            str(group.get("uuid")): str(group.get("name", ""))
            for group in data.get("groups", [])
            if group.get("uuid")
        }
        target_ids = {uuid_ for uuid_, name in group_names.items() if name == group_name}
        if not target_ids:
            return set()

        def collect(node) -> set[str]:
            if isinstance(node, str):
                return {node}
            if isinstance(node, dict):
                found: set[str] = set()
                for child in node.get("children", []):
                    found.update(collect(child))
                return found
            return set()

        def find_target(node) -> set[str]:
            if not isinstance(node, dict):
                return set()
            if str(node.get("uuid")) in target_ids:
                return collect(node)
            for child in node.get("children", []):
                found = find_target(child)
                if found:
                    return found
            return set()

        for node in data.get("outliner", []):
            found = find_target(node)
            if found:
                return found
        return set()

    @staticmethod
    def _element_group_map(data: dict) -> Dict[str, str]:
        mapping: Dict[str, str] = {}

        def walk(node, parent_group: str | None = None) -> None:
            if isinstance(node, str):
                if parent_group:
                    mapping[node] = parent_group
                return
            if not isinstance(node, dict):
                return
            group_uuid = str(node.get("uuid") or parent_group or "")
            for child in node.get("children", []):
                walk(child, group_uuid or parent_group)

        for node in data.get("outliner", []):
            walk(node)
        return mapping

    def _load_model(self, path: Path, group_name: str | None = None) -> None:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            rotated_groups = [
                str(group.get("name", "Group"))
                for group in data.get("groups", [])
                if any(abs(float(v)) > 1e-6 for v in group.get("rotation", [0, 0, 0])[:3])
            ]
            rotated_elements = [
                str(element.get("name", "Cube"))
                for element in data.get("elements", [])
                if any(abs(float(v)) > 1e-6 for v in element.get("rotation", [0, 0, 0])[:3])
            ]
            if rotated_groups or rotated_elements:
                raise ValueError(
                    "This 3D editor currently supports axis-aligned cuboids only. "
                    "Remove Blockbench rotations first."
                )
            allowed_ids = self._group_element_ids(data, group_name) if group_name else set()
            if group_name and not allowed_ids:
                raise ValueError(f"Could not find Blockbench group '{group_name}'.")
            elements = [
                copy.deepcopy(e)
                for e in data.get("elements", [])
                if e.get("type", "cube") == "cube"
                and isinstance(e.get("from"), list)
                and isinstance(e.get("to"), list)
                and len(e["from"]) >= 3
                and len(e["to"]) >= 3
                and (not allowed_ids or str(e.get("uuid")) in allowed_ids)
            ]
            if not elements:
                raise ValueError("The model does not contain editable cuboids.")

            self.model = copy.deepcopy(data)
            group_map = self._element_group_map(data)
            for element in elements:
                group_uuid = group_map.get(str(element.get("uuid")))
                if group_uuid:
                    element["_kw_group_uuid"] = group_uuid
            self.elements = elements
            self.source_path = path
            self.scope_group_name = group_name
            self.scope_original_ids = set(allowed_ids)
            self.default_add_group_uuid = None
            if group_name:
                group_names = {
                    str(group.get("name", "")): str(group.get("uuid", ""))
                    for group in data.get("groups", [])
                }
                self.default_add_group_uuid = group_names.get("Head_Core") or group_names.get(group_name)
            self.texture_images = self._decode_textures(self.model, path)
            self.selected_index = 0
            self._reload_list()
            self._fit_view()
            scope = f" // {group_name}" if group_name else ""
            self._set_status(f"LOADED // {path.name}{scope} // {len(self.elements)} cuboids")
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not load Blockbench model:\n{exc}", parent=self)

    def _decode_textures(self, model: dict, model_path: Path) -> List[Image.Image | None]:
        out: List[Image.Image | None] = []
        for texture in model.get("textures", []):
            img: Image.Image | None = None
            try:
                source = str(texture.get("source", ""))
                if source.startswith("data:image"):
                    img = image_from_data_uri(source)
                else:
                    raw_path = str(texture.get("path", "")).strip()
                    if raw_path:
                        tex_path = Path(raw_path)
                        if not tex_path.is_absolute():
                            tex_path = model_path.parent / tex_path
                        if tex_path.exists():
                            img = Image.open(tex_path).convert("RGBA")
                            texture["source"] = image_to_data_uri(img)
            except Exception:
                img = None
            out.append(img)
        return out

    def _from_six_views(self) -> None:
        temp_dir = Path(tempfile.gettempdir())
        stem = f"kwcb_edit_{uuid.uuid4().hex[:10]}"
        bb_path = temp_dir / f"{stem}.bbmodel"
        atlas_path: Path | None = None
        try:
            bb_path, atlas_path, cubes = self.owner._generate_bbmodel(
                bb_path,
                part_ids={self.owner.part_id},
            )
            self._load_model(bb_path)
            self._set_status(
                f"6-VIEW STARTING VOLUME // {PART_BY_ID[self.owner.part_id].label} // "
                f"{cubes} cuboids // edit the shape manually"
            )
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not build the six-view starting volume:\n{exc}", parent=self)
        finally:
            for path in (bb_path, atlas_path):
                if path is not None:
                    try:
                        Path(path).unlink(missing_ok=True)
                    except Exception:
                        pass

    def _reload_list(self) -> None:
        self.block_list.delete(0, "end")
        for index, element in enumerate(self.elements):
            self.block_list.insert("end", f"{index + 1:02d}  {element.get('name', 'Cube')}")
        if self.elements:
            if self.selected_index is None or self.selected_index >= len(self.elements):
                self.selected_index = 0
            self.block_list.selection_clear(0, "end")
            self.block_list.selection_set(self.selected_index)
            self.block_list.see(self.selected_index)
            self._sync_fields()
        else:
            self.selected_index = None
            self.name_var.set("")
        self._render_3d()

    def _select_list(self, _event=None) -> None:
        selection = self.block_list.curselection()
        if not selection:
            return
        self.selected_index = int(selection[0])
        self._sync_fields()
        self._render_3d()

    def _select_index(self, index: int) -> None:
        if not (0 <= index < len(self.elements)):
            return
        self.selected_index = index
        self.block_list.selection_clear(0, "end")
        self.block_list.selection_set(index)
        self.block_list.see(index)
        self._sync_fields()
        self._render_3d()

    def _sync_fields(self) -> None:
        if self.selected_index is None or not (0 <= self.selected_index < len(self.elements)):
            return
        element = self.elements[self.selected_index]
        self.name_var.set(str(element.get("name", "Cube")))
        coords = [float(v) for v in element["from"][:3]] + [float(v) for v in element["to"][:3]]
        for var, value in zip(self.coord_vars, coords):
            var.set(value)

    def _apply_coords(self) -> None:
        if self.selected_index is None:
            return
        try:
            values = [float(v.get()) for v in self.coord_vars]
        except (ValueError, tk.TclError):
            messagebox.showerror(APP_NAME, "Coordinates must be numeric.", parent=self)
            return
        for axis in range(3):
            a, b = values[axis], values[axis + 3]
            if math.isclose(a, b):
                messagebox.showerror(APP_NAME, "A cuboid cannot have zero size on an axis.", parent=self)
                return
            if a > b:
                values[axis], values[axis + 3] = b, a
        element = self.elements[self.selected_index]
        element["from"] = values[:3]
        element["to"] = values[3:]
        element["name"] = self.name_var.get().strip() or "Cube"
        self._reload_list()
        self._set_status(f"UPDATED // {element['name']}")

    def _step(self) -> float:
        try:
            return max(0.1, abs(float(self.step_var.get())))
        except (ValueError, tk.TclError):
            return 1.0

    def _nudge(self, axis: int, direction: int) -> None:
        if self.selected_index is None:
            return
        delta = self._step() * direction
        element = self.elements[self.selected_index]
        element["from"][axis] = float(element["from"][axis]) + delta
        element["to"][axis] = float(element["to"][axis]) + delta
        origin = element.get("origin")
        if isinstance(origin, list) and len(origin) >= 3:
            origin[axis] = float(origin[axis]) + delta
        self._sync_fields()
        self._render_3d()

    @staticmethod
    def _default_faces() -> dict:
        return {
            face: {"uv": [0, 0, 1, 1], "texture": 0}
            for face in CuboidEditorWindow.FACE_KEYS
        }

    def _add_box(self) -> None:
        step = self._step()
        if self.selected_index is not None and self.elements:
            source = self.elements[self.selected_index]
            style_faces = copy.deepcopy(source.get("faces", self._default_faces()))
            group_uuid = source.get("_kw_group_uuid") or self.default_add_group_uuid
            base = [float(v) for v in source.get("to", [0, 0, 0])[:3]]
            base[1] = float(source.get("from", [0, 0, 0])[1])
            base[2] = float(source.get("from", [0, 0, 0])[2])
        else:
            style_faces = self._default_faces()
            group_uuid = self.default_add_group_uuid
            base = [0.0, 0.0, 0.0]
        element_uuid = str(uuid.uuid4())
        element = {
            "name": f"Cube_{len(self.elements) + 1:02d}",
            "box_uv": False,
            "render_order": "default",
            "locked": False,
            "export": True,
            "from": list(base),
            "to": [base[0] + step, base[1] + step, base[2] + step],
            "autouv": 0,
            "origin": [base[0] + step / 2, base[1] + step / 2, base[2] + step / 2],
            "faces": style_faces,
            "type": "cube",
            "uuid": element_uuid,
        }
        if group_uuid:
            element["_kw_group_uuid"] = str(group_uuid)
        self.elements.append(element)
        self.selected_index = len(self.elements) - 1
        self._reload_list()
        self._set_status("ADDED CUBE // edit FROM/TO or move it with the axis controls")

    def _duplicate_selected(self) -> None:
        if self.selected_index is None:
            return
        clone = copy.deepcopy(self.elements[self.selected_index])
        clone["uuid"] = str(uuid.uuid4())
        clone["name"] = str(clone.get("name", "Cube")) + "_copy"
        delta = self._step()
        clone["from"][0] = float(clone["from"][0]) + delta
        clone["to"][0] = float(clone["to"][0]) + delta
        if isinstance(clone.get("origin"), list) and len(clone["origin"]) >= 3:
            clone["origin"][0] = float(clone["origin"][0]) + delta
        self.elements.append(clone)
        self.selected_index = len(self.elements) - 1
        self._reload_list()
        self._set_status(f"DUPLICATED // {clone['name']}")

    def _delete_selected(self) -> None:
        if self.selected_index is None:
            return
        element = self.elements[self.selected_index]
        if not messagebox.askyesno(APP_NAME, f"Delete {element.get('name', 'this block')}?", parent=self):
            return
        del self.elements[self.selected_index]
        self.selected_index = min(self.selected_index, len(self.elements) - 1) if self.elements else None
        self._reload_list()
        self._set_status("BLOCK DELETED")

    def _set_view(self, yaw_deg: float, pitch_deg: float) -> None:
        self.yaw = math.radians(yaw_deg)
        self.pitch = math.radians(pitch_deg)
        self._render_3d()

    def _fit_view(self) -> None:
        self.zoom = 1.0
        self._render_3d()

    def _orbit_start(self, event) -> None:
        self._orbit_last = (event.x, event.y)

    def _orbit_move(self, event) -> None:
        if self._orbit_last is None:
            return
        dx = event.x - self._orbit_last[0]
        dy = event.y - self._orbit_last[1]
        self._orbit_last = (event.x, event.y)
        self.yaw += dx * 0.012
        self.pitch = max(math.radians(-89), min(math.radians(89), self.pitch + dy * 0.012))
        self._render_3d()

    def _orbit_end(self, _event) -> None:
        self._orbit_last = None

    def _zoom_wheel(self, event) -> None:
        factor = 1.12 if event.delta > 0 else 1 / 1.12
        self.zoom = max(0.15, min(8.0, self.zoom * factor))
        self._render_3d()

    def _select_from_canvas(self, event) -> None:
        hits = self.canvas3d.find_overlapping(event.x, event.y, event.x, event.y)
        for item in reversed(hits):
            if item in self.canvas_items:
                self._select_index(self.canvas_items[item])
                return

    @staticmethod
    def _rotate_point(point: Tuple[float, float, float], yaw: float, pitch: float) -> Tuple[float, float, float]:
        x, y, z = point
        cy, sy = math.cos(yaw), math.sin(yaw)
        x1 = x * cy + z * sy
        z1 = -x * sy + z * cy
        cp, sp = math.cos(pitch), math.sin(pitch)
        y2 = y * cp - z1 * sp
        z2 = y * sp + z1 * cp
        return x1, y2, z2

    def _model_bounds(self) -> Tuple[List[float], List[float]]:
        if not self.elements:
            return [-1, -1, -1], [1, 1, 1]
        mins = [float("inf")] * 3
        maxs = [float("-inf")] * 3
        for element in self.elements:
            for axis in range(3):
                mins[axis] = min(mins[axis], float(element["from"][axis]), float(element["to"][axis]))
                maxs[axis] = max(maxs[axis], float(element["from"][axis]), float(element["to"][axis]))
        return mins, maxs

    def _texture_index(self, face: dict) -> int:
        tex = face.get("texture", 0)
        try:
            return int(tex)
        except (TypeError, ValueError):
            if self.model:
                for index, texture in enumerate(self.model.get("textures", [])):
                    if str(texture.get("uuid", "")) == str(tex):
                        return index
            return 0

    def _texture_for_face(self, face: dict) -> Image.Image | None:
        index = self._texture_index(face)
        if 0 <= index < len(self.texture_images):
            return self.texture_images[index]
        return None

    def _element_color(self, element: dict) -> Tuple[int, int, int]:
        faces = element.get("faces", {})
        for key in ("north", "east", "up", "south", "west", "down"):
            face = faces.get(key)
            if not isinstance(face, dict):
                continue
            img = self._texture_for_face(face)
            uv = face.get("uv")
            if img is None or not isinstance(uv, list) or len(uv) < 4:
                continue
            texture_index = self._texture_index(face)
            textures = self.model.get("textures", []) if self.model else []
            texture = textures[texture_index] if 0 <= texture_index < len(textures) else {}
            uv_w = max(1.0, float(texture.get("uv_width", texture.get("width", img.width))))
            uv_h = max(1.0, float(texture.get("uv_height", texture.get("height", img.height))))
            u = (float(uv[0]) + float(uv[2])) / 2.0
            v = (float(uv[1]) + float(uv[3])) / 2.0
            px = max(0, min(img.width - 1, int(u / uv_w * img.width)))
            py = max(0, min(img.height - 1, int(v / uv_h * img.height)))
            pixel = img.getpixel((px, py))
            if pixel[3] > 0:
                return int(pixel[0]), int(pixel[1]), int(pixel[2])
        name = str(element.get("name", "")).lower()
        if "eye" in name:
            return 8, 12, 16
        if "horn" in name:
            return 245, 22, 45
        return 132, 10, 22

    @staticmethod
    def _shade(rgb: Tuple[int, int, int], factor: float) -> str:
        r = max(0, min(255, int(rgb[0] * factor)))
        g = max(0, min(255, int(rgb[1] * factor)))
        b = max(0, min(255, int(rgb[2] * factor)))
        return f"#{r:02x}{g:02x}{b:02x}"

    def _render_3d(self) -> None:
        if not hasattr(self, "canvas3d"):
            return
        canvas = self.canvas3d
        canvas.delete("all")
        self.canvas_items.clear()
        w = max(2, canvas.winfo_width())
        h = max(2, canvas.winfo_height())
        if not self.elements:
            canvas.create_text(
                w / 2,
                h / 2,
                text="NO 3D MODEL\n\nLoad the current head, load a .bbmodel,\nor generate a starting volume from the six views.",
                fill=MUTED,
                justify="center",
                font=("Consolas", 11, "bold"),
            )
            return

        mins, maxs = self._model_bounds()
        center = [(mins[i] + maxs[i]) / 2.0 for i in range(3)]
        span = max(maxs[i] - mins[i] for i in range(3))
        scale = min(w, h) * 0.62 / max(1.0, span) * self.zoom
        cx, cy = w / 2.0, h / 2.0

        face_defs = [
            ("north", (0, 1, 2, 3), 1.00),
            ("south", (4, 5, 6, 7), 0.78),
            ("west", (0, 4, 7, 3), 0.72),
            ("east", (1, 5, 6, 2), 0.90),
            ("down", (0, 1, 5, 4), 0.62),
            ("up", (3, 2, 6, 7), 1.12),
        ]
        draw_faces = []
        for index, element in enumerate(self.elements):
            x0, y0, z0 = [float(v) for v in element["from"][:3]]
            x1, y1, z1 = [float(v) for v in element["to"][:3]]
            vertices = [
                (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
            ]
            transformed = []
            for vx, vy, vz in vertices:
                rx, ry, rz = self._rotate_point((vx - center[0], vy - center[1], vz - center[2]), self.yaw, self.pitch)
                transformed.append((cx + rx * scale, cy - ry * scale, rz))
            base_color = self._element_color(element)
            for face_key, ids, shade in face_defs:
                pts = [(transformed[i][0], transformed[i][1]) for i in ids]
                depth = sum(transformed[i][2] for i in ids) / len(ids)
                draw_faces.append((depth, index, face_key, pts, self._shade(base_color, shade)))

        draw_faces.sort(key=lambda item: item[0])
        for _depth, index, _face_key, pts, fill in draw_faces:
            flat = [coord for pt in pts for coord in pt]
            selected = index == self.selected_index
            item = canvas.create_polygon(
                *flat,
                fill=fill,
                outline=CYAN if selected else "#274550",
                width=2 if selected else 1,
            )
            self.canvas_items[item] = index

        # Screen-space origin axes provide orientation without altering geometry.
        origin = self._rotate_point((-center[0], -center[1], -center[2]), self.yaw, self.pitch)
        ox, oy = cx + origin[0] * scale, cy - origin[1] * scale
        for axis, label, color in [
            ((2.5, 0, 0), "X", "#ff586d"),
            ((0, 2.5, 0), "Y", "#62f5b9"),
            ((0, 0, 2.5), "Z", "#5deeff"),
        ]:
            end = self._rotate_point(
                (axis[0] - center[0], axis[1] - center[1], axis[2] - center[2]),
                self.yaw,
                self.pitch,
            )
            ex, ey = cx + end[0] * scale, cy - end[1] * scale
            canvas.create_line(ox, oy, ex, ey, fill=color, width=2)
            canvas.create_text(ex, ey, text=label, fill=color, font=("Consolas", 8, "bold"))

        if self.selected_index is not None:
            element = self.elements[self.selected_index]
            canvas.create_text(
                10,
                10,
                anchor="nw",
                text=f"{element.get('name', 'Cube')}  //  {len(self.elements)} blocks",
                fill=CYAN,
                font=("Consolas", 9, "bold"),
            )

    def _export_and_open(self) -> None:
        if not self.model or not self.elements:
            messagebox.showerror(APP_NAME, "Load or generate a 3D model first.", parent=self)
            return
        initial = (self.source_path.stem + "_edited.bbmodel") if self.source_path else "KW_edited_model.bbmodel"
        path = filedialog.asksaveasfilename(
            parent=self,
            title="Export edited Blockbench model",
            defaultextension=".bbmodel",
            initialfile=initial,
            filetypes=[("Blockbench model", "*.bbmodel")],
        )
        if not path:
            return
        try:
            output = Path(path)
            model = copy.deepcopy(self.model)
            edited_elements = copy.deepcopy(self.elements)
            for element in edited_elements:
                element["uuid"] = str(element.get("uuid") or uuid.uuid4())
            edited_ids = {str(element["uuid"]) for element in edited_elements}

            if self.scope_group_name and self.scope_original_ids:
                untouched = [
                    copy.deepcopy(element)
                    for element in model.get("elements", [])
                    if str(element.get("uuid")) not in self.scope_original_ids
                ]
                model["elements"] = untouched + [
                    {key: value for key, value in element.items() if not key.startswith("_kw_")}
                    for element in edited_elements
                ]

                deleted_ids = self.scope_original_ids - edited_ids
                new_by_group: Dict[str, List[str]] = {}
                for element in edited_elements:
                    element_uuid = str(element["uuid"])
                    if element_uuid in self.scope_original_ids:
                        continue
                    group_uuid = str(element.get("_kw_group_uuid") or self.default_add_group_uuid or "")
                    if group_uuid:
                        new_by_group.setdefault(group_uuid, []).append(element_uuid)

                def rebuild_node(node):
                    if isinstance(node, str):
                        return None if node in deleted_ids else node
                    if not isinstance(node, dict):
                        return node
                    rebuilt = copy.deepcopy(node)
                    children = []
                    for child in node.get("children", []):
                        value = rebuild_node(child)
                        if value is not None:
                            children.append(value)
                    group_uuid = str(node.get("uuid", ""))
                    for element_uuid in new_by_group.get(group_uuid, []):
                        if element_uuid not in children:
                            children.append(element_uuid)
                    rebuilt["children"] = children
                    return rebuilt

                model["outliner"] = [
                    rebuilt for rebuilt in (rebuild_node(node) for node in model.get("outliner", []))
                    if rebuilt is not None
                ]
                # Keep the source groups and pivots exactly as authored. This
                # preserves the Outrage_Head rig expected by the game bake.
            else:
                elements = [
                    {key: value for key, value in element.items() if not key.startswith("_kw_")}
                    for element in edited_elements
                ]
                model["elements"] = elements
                group_uuid = str(uuid.uuid4())
                group = CharacterBuilderApp._group_record("KW_EDITED_CUBOIDS", group_uuid, [0.0, 0.0, 0.0])
                child_ids = [element["uuid"] for element in elements]
                model["groups"] = [group]
                model["outliner"] = [{
                    "uuid": group_uuid,
                    "isOpen": True,
                    "name": "KW_EDITED_CUBOIDS",
                    "origin": [0.0, 0.0, 0.0],
                    "export": True,
                    "children": child_ids,
                }]

            model["name"] = output.stem
            model["model_identifier"] = "kw.edited." + re.sub(r"[^a-z0-9_]+", "_", output.stem.lower())
            output.write_text(json.dumps(model, separators=(",", ":")), encoding="utf-8")

            exe = find_blockbench()
            if exe:
                subprocess.Popen([str(exe), str(output)], cwd=str(output.parent))
            else:
                os.startfile(str(output))
            self._set_status(f"EXPORTED // {len(model['elements'])} total cuboids // opened in Blockbench")
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"Could not export edited model:\n{exc}", parent=self)


def main() -> None:
    app = CharacterBuilderApp()
    app.mainloop()


if __name__ == "__main__":
    main()
