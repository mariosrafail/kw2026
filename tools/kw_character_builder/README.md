# KW Character Builder (standalone)

This is the primary character-authoring tool for the six-view workflow.

It is a standalone Windows UI, not a Blockbench dialog.

On the development machine, the packaged app is built as:

`dist/KW Character Builder.exe`

Run `build_windows.cmd` to rebuild it after changing `app.py`.

## Workflow

1. Open **KW Character Builder**.
2. Select a body part (`HEAD`, `TORSO`, arms, legs).
3. Paint the six transparent 64x64 views, import a PNG into the current face, or use **IMPORT 6 NAMED PNGs** to load a complete part at once.
   - Batch filenames must contain `front`, `back`, `right`, `left`, `top`, and `bottom`.
   - Imported images are converted to RGBA and resized to 64x64 with nearest-neighbor scaling when needed.
   - PNG alpha and RGB colors are preserved by default. The optional near-white-to-transparent toggle is intended for old references with white backgrounds.
   - Faces are reconstructed exactly in the orientation shown in the editor. The builder does not silently mirror `BACK` / `LEFT` or flip `BOTTOM`; use the visible **FLIP H/V** controls only when a source image actually needs it.
4. Press **EXPORT TO BLOCKBENCH**.
5. The app generates:
   - a `.bbmodel`
   - a transparent PNG atlas
   - cuboid geometry reconstructed from the six silhouettes
6. Blockbench opens the generated `.bbmodel` automatically.

Transparent pixels become empty 3D space. RGB colors from the painted pixels are retained in the generated atlas/UVs.

The standalone app supports PNG import/export per face, six-face batch PNG import, optional white-to-alpha conversion for old references, brush/eraser/picker, a live 0–100% grid-opacity control, flip H/V, part positioning, forgiving/strict reconstruction, and save/load `.kwchar.json` projects.

The older `tools/blockbench/kw_character_builder` Blockbench plugin can remain as an experimental bridge, but the standalone builder is the intended UI.
